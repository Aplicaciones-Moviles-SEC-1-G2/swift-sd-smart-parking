import Foundation
import SwiftUI
import Combine

// MARK: - Models

struct ParkingSession: Identifiable, Codable {
    let id: String
    let plate: String
    let floor: Int
    let date: Date
    let durationHours: Double
    let costCOP: Double
    let hitCap: Bool
}

struct ParkingHistoryCache: Codable {
    let sessions: [ParkingSession]
    let savedAt: Date
}

enum HistoryFilter: String, CaseIterable, Identifiable {
    case all   = "All"
    case week  = "Week"
    case month = "Month"
    case year  = "Year"
    var id: String { rawValue }
}

// MARK: - Actor
// Swift actor serialises access to its state and schedules work on its own
// executor — completely off the MainActor — providing data-race safety without
// manual locking. This is the third concurrency primitive used in this sprint
// (async let in PersonalStatsViewModel, withTaskGroup in FloorMonitorViewModel).
private actor HistoryProcessor {
    func buildSessions(
        from records: [VehicleRecord],
        userPlates: Set<String>
    ) -> [ParkingSession] {
        records
            .filter { $0.type == .exit && userPlates.contains($0.plate.uppercased()) }
            .compactMap { r -> ParkingSession? in
                guard let dur = r.durationHours, dur > 0 else { return nil }
                let cost = ParkingConfig.calculateFee(hours: dur, currentDayTotal: 0)
                return ParkingSession(
                    id:            "\(r.plate)-\(r.timestamp.timeIntervalSince1970)",
                    plate:         r.plate,
                    floor:         r.floor ?? 0,
                    date:          r.timestamp,
                    durationHours: dur,
                    costCOP:       cost,
                    hitCap:        r.hitDailyCap
                )
            }
            .sorted { $0.date > $1.date }
    }
}

// MARK: - ViewModel

@MainActor
final class ParkingHistoryViewModel: ObservableObject {
    @Published private(set) var allSessions:  [ParkingSession] = []
    @Published           var filter:          HistoryFilter    = .all
    @Published private(set) var isLoading     = false
    @Published private(set) var isOfflineCopy = false
    @Published private(set) var lastUpdated:  Date?            = nil

    private let processor = HistoryProcessor()

    // NSCache: in-memory layer, evicted under memory pressure
    private let memCache: NSCache<NSString, HistoryBox> = {
        let c = NSCache<NSString, HistoryBox>()
        c.countLimit = 3
        return c
    }()

    // KeyValueStore: JSON disk layer — survives app restarts, served when offline
    private let diskStore = KeyValueStore<String, ParkingHistoryCache>(
        scope: "juanes.parking_history"
    )

    // MARK: - Derived collections

    var filteredSessions: [ParkingSession] {
        let now = Date()
        let cal = Calendar.current
        return allSessions.filter { s in
            switch filter {
            case .all:   return true
            case .week:  return cal.isDate(s.date, equalTo: now, toGranularity: .weekOfYear)
            case .month: return cal.isDate(s.date, equalTo: now, toGranularity: .month)
            case .year:  return cal.isDate(s.date, equalTo: now, toGranularity: .year)
            }
        }
    }

    var sessionsByMonth: [(String, [ParkingSession])] {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        let grouped = Dictionary(grouping: filteredSessions) { s in fmt.string(from: s.date) }
        return grouped.sorted { lhs, rhs in
            (lhs.value.first?.date ?? .distantPast) > (rhs.value.first?.date ?? .distantPast)
        }
    }

    // MARK: - Load

    func load(records: [VehicleRecord], userPlates: Set<String>) async {
        guard !userPlates.isEmpty else { return }
        let key = cacheKey(for: userPlates)

        // Memory cache hit — no recomputation or disk I/O needed
        if let hit = memCache.object(forKey: key as NSString) {
            allSessions   = hit.value.sessions
            lastUpdated   = hit.value.savedAt
            isOfflineCopy = false
            return
        }

        isLoading = true

        // Delegate heavy filtering + mapping to the actor — runs off MainActor
        let built = await processor.buildSessions(from: records, userPlates: userPlates)

        let cache = ParkingHistoryCache(sessions: built, savedAt: Date())
        memCache.setObject(HistoryBox(cache), forKey: key as NSString)
        diskStore.put(cache, forKey: key)

        allSessions   = built
        lastUpdated   = cache.savedAt
        isOfflineCopy = false
        isLoading     = false
    }

    /// Serve persisted cache when offline — memory first, then disk.
    func loadCachedIfOffline(userPlates: Set<String>) {
        let key = cacheKey(for: userPlates)
        if let hit = memCache.object(forKey: key as NSString) {
            allSessions = hit.value.sessions
            lastUpdated = hit.value.savedAt
            isOfflineCopy = false
        } else if let disk = diskStore[key] {
            allSessions = disk.sessions
            lastUpdated = disk.savedAt
            isOfflineCopy = true
        }
    }

    private func cacheKey(for plates: Set<String>) -> String {
        "hist_\(plates.sorted().joined(separator: ","))"
    }
}

// NSCache requires AnyObject values — box wraps the Codable struct.
private final class HistoryBox: @unchecked Sendable {
    let value: ParkingHistoryCache
    init(_ v: ParkingHistoryCache) { value = v }
}
