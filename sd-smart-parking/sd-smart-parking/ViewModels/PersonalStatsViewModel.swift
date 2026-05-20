import Foundation
import SwiftUI
import Combine

// Codable snapshot — persisted to disk via KeyValueStore and cached in NSCache.
struct PersonalStatsSnapshot: Codable {
    let totalSessions: Int
    let totalHours: Double
    let totalCostCOP: Double
    let avgDurationHours: Double
    let busiestDayName: String?
    let busiestDayCount: Int
    let mostUsedFloor: Int?
    let mostUsedFloorCount: Int
    // Weekday key = abbreviated name ("Mon", "Tue", …), value = avg hours
    let weekdayAvgDurations: [String: Double]
    let savedAt: Date
}

// MARK: - ViewModel

@MainActor
final class PersonalStatsViewModel: ObservableObject {

    @Published private(set) var snapshot: PersonalStatsSnapshot?
    @Published private(set) var isLoading   = false
    @Published private(set) var isOfflineCopy = false

    // NSCache: in-memory layer — survives navigation within the session,
    // evicted under memory pressure. countLimit=3 since one user has one key.
    private let memCache: NSCache<NSString, PersonalStatsBox> = {
        let c = NSCache<NSString, PersonalStatsBox>()
        c.countLimit = 3
        return c
    }()

    // KeyValueStore: disk layer — survives app restarts, served when offline.
    private let diskCache = KeyValueStore<String, PersonalStatsSnapshot>(scope: "juanes.personal_stats")

    // MARK: - Public API

    /// Compute stats concurrently using `async let`, then cache in both layers.
    func load(records: [VehicleRecord], userPlates: Set<String>) async {
        guard !userPlates.isEmpty else { return }
        let key = cacheKey(for: userPlates)

        // Hit memory cache first — no recomputation needed
        if let hit = memCache.object(forKey: key as NSString) {
            snapshot      = hit.value
            isOfflineCopy = false
            return
        }

        isLoading = true

        // Extract Sendable-safe primitives on the MainActor before spawning
        // concurrent child tasks (avoids Sendable capture warnings on struct fields)
        let exits       = records.filter { $0.type == .exit  && userPlates.contains($0.plate.uppercased()) }
        let allRecords  = records.filter { userPlates.contains($0.plate.uppercased()) }
        let durations   = exits.compactMap { $0.durationHours }
        let timestamps  = exits.map        { $0.timestamp }
        let floors      = allRecords.compactMap { $0.floor }
        let tsAndDur: [(Date, Double)] = exits.compactMap {
            guard let d = $0.durationHours else { return nil }
            return ($0.timestamp, d)
        }

        // Five independent stats computed concurrently via async let.
        // Each spawns a child task on Swift's cooperative thread pool.
        async let sessionsTask   = Self.countItems(timestamps.count)
        async let hoursTask      = Self.sumDoubles(durations)
        async let busiestDayTask = Self.findBusiestWeekday(timestamps)
        async let floorTask      = Self.findMostFrequentFloor(floors)
        async let weekdaysTask   = Self.avgDurationsByWeekday(tsAndDur)

        let (sessions, hours, busDay, topFloor, weekdays) = await (
            sessionsTask, hoursTask, busiestDayTask, floorTask, weekdaysTask
        )

        let totalCost = durations.reduce(0.0) {
            $0 + ParkingConfig.calculateFee(hours: $1, currentDayTotal: 0)
        }

        let result = PersonalStatsSnapshot(
            totalSessions:      sessions,
            totalHours:         hours,
            totalCostCOP:       totalCost,
            avgDurationHours:   sessions > 0 ? hours / Double(sessions) : 0,
            busiestDayName:     busDay?.name,
            busiestDayCount:    busDay?.count ?? 0,
            mostUsedFloor:      topFloor?.floor,
            mostUsedFloorCount: topFloor?.count ?? 0,
            weekdayAvgDurations: weekdays,
            savedAt:            Date()
        )

        snapshot      = result
        isOfflineCopy = false
        isLoading     = false

        // Persist to both layers for offline access
        memCache.setObject(PersonalStatsBox(result), forKey: key as NSString)
        diskCache.put(result, forKey: key)
    }

    /// Serve cached stats when offline — memory first, then disk.
    func loadCachedIfOffline(userPlates: Set<String>) {
        let key = cacheKey(for: userPlates)
        if let hit = memCache.object(forKey: key as NSString) {
            snapshot      = hit.value
            isOfflineCopy = false
        } else if let persisted = diskCache[key] {
            snapshot      = persisted
            isOfflineCopy = true
        }
    }

    // MARK: - nonisolated helpers
    // Declared nonisolated so Swift schedules them on the cooperative thread pool
    // when invoked via async let — enabling true parallel execution.

    private nonisolated static func countItems(_ n: Int) async -> Int { n }

    private nonisolated static func sumDoubles(_ values: [Double]) async -> Double {
        values.reduce(0, +)
    }

    private nonisolated static func findBusiestWeekday(
        _ timestamps: [Date]
    ) async -> (name: String, count: Int)? {
        let names = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
        var counts = [Int: Int]()
        for ts in timestamps {
            let wd = Calendar.current.component(.weekday, from: ts)
            counts[wd, default: 0] += 1
        }
        guard let max = counts.max(by: { $0.value < $1.value }) else { return nil }
        return (name: names[max.key - 1], count: max.value)
    }

    private nonisolated static func findMostFrequentFloor(
        _ floors: [Int]
    ) async -> (floor: Int, count: Int)? {
        var counts = [Int: Int]()
        for f in floors { counts[f, default: 0] += 1 }
        guard let max = counts.max(by: { $0.value < $1.value }) else { return nil }
        return (floor: max.key, count: max.value)
    }

    private nonisolated static func avgDurationsByWeekday(
        _ data: [(Date, Double)]
    ) async -> [String: Double] {
        let names = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
        var sums   = [Int: Double]()
        var counts = [Int: Int]()
        for (ts, dur) in data {
            guard dur > 0 else { continue }
            let wd = Calendar.current.component(.weekday, from: ts)
            sums[wd,   default: 0] += dur
            counts[wd, default: 0] += 1
        }
        return sums.reduce(into: [String: Double]()) { result, entry in
            result[names[entry.key - 1]] = entry.value / Double(counts[entry.key]!)
        }
    }

    // MARK: - Helpers

    private func cacheKey(for plates: Set<String>) -> String {
        "stats_\(plates.sorted().joined(separator: ","))"
    }
}

// NSCache requires AnyObject values — this box wraps the struct.
private final class PersonalStatsBox: @unchecked Sendable {
    let value: PersonalStatsSnapshot
    init(_ v: PersonalStatsSnapshot) { value = v }
}
