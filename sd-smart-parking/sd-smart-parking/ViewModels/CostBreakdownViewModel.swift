import Foundation
import SwiftUI
import Combine

// MARK: - Models

struct MonthlyCostPoint: Identifiable, Codable {
    var id: String { month }
    let month: String
    let totalCOP: Double
    let sessionCount: Int
}

struct CostBreakdownSnapshot: Codable {
    let monthlyPoints: [MonthlyCostPoint]
    let avgPerSession: Double
    let capHitPct: Double
    let costPerFloor: [String: Double]
    let totalAllTime: Double
    let savedAt: Date
}

// MARK: - ViewModel

@MainActor
final class CostBreakdownViewModel: ObservableObject {
    @Published private(set) var snapshot:     CostBreakdownSnapshot?
    @Published private(set) var isLoading     = false
    @Published private(set) var isOfflineCopy = false

    // NSCache: same-session re-renders are free, evicted under memory pressure
    private let memCache: NSCache<NSString, CostBox> = {
        let c = NSCache<NSString, CostBox>()
        c.countLimit = 3
        return c
    }()

    // KeyValueStore: disk layer — survives restarts and serves offline reads
    private let diskStore = KeyValueStore<String, CostBreakdownSnapshot>(
        scope: "juanes.cost_breakdown"
    )

    // MARK: - Load

    func load(records: [VehicleRecord], userPlates: Set<String>) async {
        guard !userPlates.isEmpty else { return }
        let key = "cost_\(userPlates.sorted().joined(separator: ","))"

        if let hit = memCache.object(forKey: key as NSString) {
            snapshot = hit.value; isOfflineCopy = false; return
        }

        isLoading = true

        // Extract Sendable-safe value-type slices before spawning concurrent tasks
        let exits = records.filter {
            $0.type == .exit && userPlates.contains($0.plate.uppercased())
        }
        let exitsCopy   = exits
        let durations   = exits.compactMap { $0.durationHours }
        let capFlags    = exits.map        { $0.hitDailyCap }
        let floorTuples = exits.compactMap { r -> (Double, Int)? in
            guard let dur = r.durationHours, let floor = r.floor else { return nil }
            return (dur, floor)
        }

        // Four independent metrics computed concurrently via async let.
        // Each nonisolated static func runs on Swift's cooperative thread pool.
        async let monthlyTask = Self.computeMonthly(exitsCopy)
        async let avgTask     = Self.computeAvgPerSession(durations)
        async let capTask     = Self.computeCapHitRate(capFlags)
        async let floorTask   = Self.computeFloorCosts(floorTuples)

        let (monthly, avg, capRate, floorCosts) = await (
            monthlyTask, avgTask, capTask, floorTask
        )

        let result = CostBreakdownSnapshot(
            monthlyPoints: monthly,
            avgPerSession: avg,
            capHitPct:     capRate,
            costPerFloor:  floorCosts,
            totalAllTime:  monthly.reduce(0) { $0 + $1.totalCOP },
            savedAt:       Date()
        )

        memCache.setObject(CostBox(result), forKey: key as NSString)
        diskStore.put(result, forKey: key)
        snapshot = result; isOfflineCopy = false; isLoading = false
    }

    /// Serve cached data when the device is offline — memory first, then disk.
    func loadCachedIfOffline(userPlates: Set<String>) {
        let key = "cost_\(userPlates.sorted().joined(separator: ","))"
        if let hit = memCache.object(forKey: key as NSString) {
            snapshot = hit.value; isOfflineCopy = false
        } else if let disk = diskStore[key] {
            snapshot = disk; isOfflineCopy = true
        }
    }

    // MARK: - nonisolated helpers (run concurrently on cooperative thread pool)

    private nonisolated static func computeMonthly(
        _ exits: [VehicleRecord]
    ) async -> [MonthlyCostPoint] {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM yyyy"
        var buckets: [String: (cost: Double, count: Int)] = [:]
        for r in exits {
            guard let dur = r.durationHours else { continue }
            let k    = fmt.string(from: r.timestamp)
            let cost = ParkingConfig.calculateFee(hours: dur, currentDayTotal: 0)
            let cur  = buckets[k] ?? (cost: 0, count: 0)
            buckets[k] = (cost: cur.cost + cost, count: cur.count + 1)
        }
        let sortFmt = DateFormatter(); sortFmt.dateFormat = "MMM yyyy"
        return buckets
            .map { MonthlyCostPoint(month: $0.key, totalCOP: $0.value.cost,
                                    sessionCount: $0.value.count) }
            .sorted {
                (sortFmt.date(from: $0.month) ?? .distantPast) <
                (sortFmt.date(from: $1.month) ?? .distantPast)
            }
    }

    private nonisolated static func computeAvgPerSession(
        _ durations: [Double]
    ) async -> Double {
        guard !durations.isEmpty else { return 0 }
        let total = durations.reduce(0) {
            $0 + ParkingConfig.calculateFee(hours: $1, currentDayTotal: 0)
        }
        return total / Double(durations.count)
    }

    private nonisolated static func computeCapHitRate(
        _ flags: [Bool]
    ) async -> Double {
        guard !flags.isEmpty else { return 0 }
        return Double(flags.filter { $0 }.count) / Double(flags.count) * 100
    }

    private nonisolated static func computeFloorCosts(
        _ data: [(Double, Int)]
    ) async -> [String: Double] {
        var sums   = [Int: Double]()
        var counts = [Int: Int]()
        for (dur, floor) in data {
            let cost = ParkingConfig.calculateFee(hours: dur, currentDayTotal: 0)
            sums[floor,   default: 0] += cost
            counts[floor, default: 0] += 1
        }
        return sums.reduce(into: [String: Double]()) { dict, entry in
            guard let n = counts[entry.key], n > 0 else { return }
            dict["Floor \(entry.key)"] = entry.value / Double(n)
        }
    }
}

private final class CostBox: @unchecked Sendable {
    let value: CostBreakdownSnapshot
    init(_ v: CostBreakdownSnapshot) { value = v }
}
