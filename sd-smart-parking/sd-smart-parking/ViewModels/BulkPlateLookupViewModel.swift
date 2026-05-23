//
//  BulkPlateLookupViewModel.swift
//  sd-smart-parking
//
//  Sprint 4 / Diego — multi-threading feature + caching feature.
//
//  Drives BulkPlateLookupView. Two responsibilities:
//
//   1) Concurrency (rubric a): every plate the Gerente enters is queried in
//      parallel via `withTaskGroup`. Fan-out is DYNAMIC (driven by user
//      input), which is what justifies using a task group instead of the
//      fixed `async let` and `actor` patterns already shipped by Juanes.
//
//   2) Caching (rubric c): per-plate results live in a two-layer cache:
//        • Memory: NSCache<NSString, CachedLookupBox>, evicts under
//          pressure, instant within-session re-reads.
//        • Disk: KeyValueStore<String, CachedLookup> at
//          Documents/diego.kv/diego.recent-lookups.json, survives restarts
//          and serves as the offline fallback.
//      Read order is memory → disk → Firestore. Writes go to both layers.
//
//  Offline behaviour: skips the TaskGroup, serves whatever the cache (memory
//  + disk) has. If the cache misses too we additionally bucket
//  `ParkingViewModel.vehicleRecords` (the live Firestore snapshot kept in
//  memory by `listenToRecords`) as a final fallback.
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
final class BulkPlateLookupViewModel: ObservableObject {

    // MARK: - Tunables

    private static let recentTermsLimit = 10
    private static let diskCacheMaxEntries = 50
    private static let recentTermsKey = "diego.recent-lookup-terms"

    // MARK: - State

    @Published var rawInput: String = ""
    @Published private(set) var resultsByPlate: [String: [VehicleRecord]] = [:]
    @Published private(set) var inFlight: Set<String> = []
    @Published private(set) var lastError: String?
    @Published private(set) var lastRunAt: Date?
    @Published private(set) var servedFromLocalSnapshot: Bool = false
    /// Plates whose currently-shown result came from the disk/memory cache.
    /// Cleared once Firestore returns a fresh result for that plate.
    @Published private(set) var cachedPlates: Set<String> = []
    /// Most-recent search inputs, newest first, deduped.
    @Published private(set) var recentTerms: [String] = []

    // MARK: - Caches

    private let memoryCache = NSCache<NSString, CachedLookupBox>()
    private let diskCache: KeyValueStore<String, CachedLookup>
    private let db = Firestore.firestore()
    private let defaults: UserDefaults

    // MARK: - Init

    init(
        diskScope: String = "diego.recent-lookups",
        defaults: UserDefaults = .standard
    ) {
        self.diskCache = KeyValueStore<String, CachedLookup>(scope: diskScope)
        self.defaults = defaults
        memoryCache.countLimit = 50
        loadRecentTerms()
    }

    // MARK: - Public API

    /// Parses `rawInput`, normalises plates and runs them in parallel.
    /// `localFallback` is the in-memory snapshot owned by `ParkingViewModel`,
    /// used when the network is down and the cache misses.
    func search(isOnline: Bool, localFallback: [VehicleRecord]) async {
        let plates = parsePlates(rawInput)
        guard !plates.isEmpty else {
            lastError = "Enter at least one plate."
            return
        }

        lastError = nil
        rememberRecentTerm(rawInput)

        await run(plates: plates, isOnline: isOnline, localFallback: localFallback)
    }

    /// Rerun a previous search term without retyping it (called from the
    /// Recent searches list in the view).
    func rerun(
        term: String,
        isOnline: Bool,
        localFallback: [VehicleRecord]
    ) async {
        rawInput = term
        await search(isOnline: isOnline, localFallback: localFallback)
    }

    func clear() {
        rawInput = ""
        resultsByPlate = [:]
        inFlight = []
        lastError = nil
        lastRunAt = nil
        servedFromLocalSnapshot = false
        cachedPlates = []
    }

    func clearRecentTerms() {
        recentTerms = []
        defaults.removeObject(forKey: Self.recentTermsKey)
    }

    /// Plate parsing exposed so the view can show cards in input order.
    func parsePlates(_ raw: String) -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: ",;"))
        var seen = Set<String>()
        var ordered: [String] = []
        for piece in raw.components(separatedBy: separators) {
            let cleaned = piece.uppercased().trimmingCharacters(in: .whitespaces)
            guard !cleaned.isEmpty, !seen.contains(cleaned) else { continue }
            seen.insert(cleaned)
            ordered.append(cleaned)
        }
        return ordered
    }

    // MARK: - Core search

    private func run(
        plates: [String],
        isOnline: Bool,
        localFallback: [VehicleRecord]
    ) async {
        resultsByPlate = [:]
        cachedPlates = []
        inFlight = Set(plates)
        servedFromLocalSnapshot = !isOnline

        // Step 1: serve everything we already have cached so the UI fills
        // immediately. This is what makes a repeat search feel instant.
        for plate in plates {
            if let hit = cacheLookup(plate: plate) {
                resultsByPlate[plate] = hit.records
                cachedPlates.insert(plate)
                if !isOnline {
                    inFlight.remove(plate)
                }
            }
        }

        // Step 2: choose the source of truth for the next refresh.
        if !isOnline {
            // Offline: fill any cache misses from the in-memory Firestore
            // snapshot bucketed by plate.
            let bucketed = Dictionary(grouping: localFallback) { $0.plate.uppercased() }
            for plate in plates where resultsByPlate[plate] == nil {
                resultsByPlate[plate] = bucketed[plate] ?? []
                inFlight.remove(plate)
            }
            lastRunAt = Date()
            return
        }

        // Online: refresh every plate concurrently via TaskGroup so cached
        // entries get replaced with fresh data.
        await withTaskGroup(of: (String, [VehicleRecord]).self) { group in
            for plate in plates {
                group.addTask { [db] in
                    let records = await Self.fetchRecords(for: plate, db: db)
                    return (plate, records)
                }
            }

            for await (plate, records) in group {
                resultsByPlate[plate] = records
                cachedPlates.remove(plate)
                inFlight.remove(plate)
                writeCache(plate: plate, records: records)
            }
        }

        lastRunAt = Date()
    }

    // MARK: - Cache layer

    private func cacheLookup(plate: String) -> CachedLookup? {
        if let box = memoryCache.object(forKey: plate as NSString) {
            return box.value
        }
        if let onDisk = diskCache[plate] {
            // Backfill the memory layer so the next read in this session
            // doesn't touch disk.
            memoryCache.setObject(CachedLookupBox(onDisk), forKey: plate as NSString)
            return onDisk
        }
        return nil
    }

    private func writeCache(plate: String, records: [VehicleRecord]) {
        let entry = CachedLookup(plate: plate, records: records, cachedAt: Date())
        memoryCache.setObject(CachedLookupBox(entry), forKey: plate as NSString)
        diskCache.put(entry, forKey: plate)
        trimDiskCacheIfNeeded()
    }

    /// Keep the disk cache bounded by evicting the oldest entries. Cheap
    /// because the snapshot is tiny — we only walk it after a write.
    private func trimDiskCacheIfNeeded() {
        let snap = diskCache.snapshot()
        guard snap.count > Self.diskCacheMaxEntries else { return }
        let oldest = snap.values
            .sorted { $0.cachedAt < $1.cachedAt }
            .prefix(snap.count - Self.diskCacheMaxEntries)
        for entry in oldest {
            diskCache.remove(entry.plate)
            memoryCache.removeObject(forKey: entry.plate as NSString)
        }
    }

    // MARK: - Recent terms

    private func loadRecentTerms() {
        recentTerms = defaults.stringArray(forKey: Self.recentTermsKey) ?? []
    }

    private func rememberRecentTerm(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var next = recentTerms.filter { $0 != trimmed }
        next.insert(trimmed, at: 0)
        if next.count > Self.recentTermsLimit {
            next = Array(next.prefix(Self.recentTermsLimit))
        }
        recentTerms = next
        defaults.set(next, forKey: Self.recentTermsKey)
    }

    // MARK: - Firestore

    nonisolated private static func fetchRecords(
        for plate: String,
        db: Firestore
    ) async -> [VehicleRecord] {
        do {
            let snapshot = try await db.collection("vehicleRecords")
                .whereField("plate", isEqualTo: plate)
                .order(by: "timestamp", descending: true)
                .limit(to: 25)
                .getDocuments()

            return snapshot.documents.compactMap { Self.decode(doc: $0) }
        } catch {
            return []
        }
    }

    nonisolated private static func decode(doc: QueryDocumentSnapshot) -> VehicleRecord? {
        let data = doc.data()
        guard let plate     = data["plate"]     as? String,
              let typeRaw   = data["type"]      as? String,
              let type      = RecordType(rawValue: typeRaw),
              let timestamp = (data["timestamp"] as? Timestamp)?.dateValue()
        else { return nil }

        return VehicleRecord(
            id: doc.documentID,
            plate: plate,
            type: type,
            timestamp: timestamp,
            floor: data["floor"] as? Int,
            spotNumber: data["spotNumber"] as? Int,
            photoURL: data["photoURL"] as? String,
            isRegistered: data["isRegistered"] as? Bool ?? false,
            ownerEmail: data["ownerEmail"] as? String,
            ocrConfidence: data["ocrConfidence"] as? Double ?? 1.0,
            durationHours: data["durationHours"] as? Double,
            hitDailyCap: data["hitDailyCap"] as? Bool ?? false
        )
    }
}

// MARK: - NSCache box

/// NSCache requires class values; wrap the Codable struct in a thin box.
private final class CachedLookupBox {
    let value: CachedLookup
    init(_ value: CachedLookup) { self.value = value }
}
