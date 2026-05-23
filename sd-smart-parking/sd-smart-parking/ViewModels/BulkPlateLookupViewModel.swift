//
//  BulkPlateLookupViewModel.swift
//  sd-smart-parking
//
//  Sprint 4 / Diego — multi-threading feature.
//
//  Drives BulkPlateLookupView: the Gerente pastes/types multiple plates and
//  every plate is queried against Firestore CONCURRENTLY using
//  `withTaskGroup`. Results stream into `resultsByPlate` as each child task
//  completes so SwiftUI re-renders incrementally instead of waiting for the
//  whole batch.
//
//  Why `withTaskGroup` instead of `async let`?
//  Juanes' analytics already uses `async let` (fixed fan-out of 5 stats) and
//  an `actor` (history serialization). `withTaskGroup` is the right pick
//  here because fan-out is DYNAMIC — it equals however many plates the
//  Gerente typed. Demonstrates a third concurrency primitive without
//  duplicating teammate work.
//
//  Offline behavior lives here too: when the network is down we skip the
//  TaskGroup and filter `ParkingViewModel.vehicleRecords` (already kept in
//  memory by the existing Firestore listener) so the screen still shows the
//  most recent local snapshot.
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
final class BulkPlateLookupViewModel: ObservableObject {

    // MARK: - State

    @Published var rawInput: String = ""
    @Published private(set) var resultsByPlate: [String: [VehicleRecord]] = [:]
    @Published private(set) var inFlight: Set<String> = []
    @Published private(set) var lastError: String?
    @Published private(set) var lastRunAt: Date?
    @Published private(set) var servedFromLocalSnapshot: Bool = false

    private let db = Firestore.firestore()

    // MARK: - Public API

    /// Parses `rawInput`, normalises plates and runs them in parallel.
    /// `localFallback` is the in-memory snapshot owned by `ParkingViewModel`,
    /// used when the network is down.
    func search(isOnline: Bool, localFallback: [VehicleRecord]) async {
        let plates = parsePlates(rawInput)
        guard !plates.isEmpty else {
            lastError = "Enter at least one plate."
            return
        }

        lastError = nil
        resultsByPlate = [:]
        inFlight = Set(plates)
        servedFromLocalSnapshot = !isOnline

        if !isOnline {
            // Offline path: bucket the cached records by plate. O(n) over the
            // already-loaded snapshot, no Firestore round-trip.
            let bucketed = Dictionary(grouping: localFallback) { $0.plate.uppercased() }
            for plate in plates {
                resultsByPlate[plate] = bucketed[plate] ?? []
                inFlight.remove(plate)
            }
            lastRunAt = Date()
            return
        }

        // Online path: one child task per plate, all running concurrently.
        await withTaskGroup(of: (String, [VehicleRecord]).self) { group in
            for plate in plates {
                group.addTask { [db] in
                    let records = await Self.fetchRecords(for: plate, db: db)
                    return (plate, records)
                }
            }

            for await (plate, records) in group {
                self.resultsByPlate[plate] = records
                self.inFlight.remove(plate)
            }
        }

        lastRunAt = Date()
    }

    func clear() {
        rawInput = ""
        resultsByPlate = [:]
        inFlight = []
        lastError = nil
        lastRunAt = nil
        servedFromLocalSnapshot = false
    }

    // MARK: - Plate parsing

    /// Splits on newlines, commas, or whitespace; upper-cases; drops empties;
    /// dedupes preserving input order.
    func parsePlates(_ raw: String) -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;"))
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

    // MARK: - Firestore

    /// Pulls every vehicleRecord matching `plate` and decodes it the same way
    /// `ParkingViewModel.listenToRecords()` does. Static + nonisolated so it
    /// can be safely invoked from any TaskGroup child without crossing actor
    /// boundaries.
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
