import Foundation
import SwiftUI
import Combine

struct FloorSnapshot: Identifiable {
    let floor: Int
    let available: Int
    let total: Int
    let avgStayHours: Double
    let trend: Trend
    let snapshotAt: Date

    var id: Int { floor }

    enum Trend { case up, down, same }

    var occupancyPct: Double {
        guard total > 0 else { return 0 }
        return Double(total - available) / Double(total)
    }
}

// MARK: - ViewModel

@MainActor
final class FloorMonitorViewModel: ObservableObject {

    @Published private(set) var floorSnapshots: [Int: FloorSnapshot] = [:]
    @Published           var watchedFloors: Set<Int> = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshed: Date? = nil

    // Persists the user's watched/favourited floors between sessions
    private let watchStore = KeyValueStore<String, [Int]>(scope: "juanes.floor_watch")

    init() { loadWatchedFloors() }

    // MARK: - Watched floors (local storage)

    func loadWatchedFloors() {
        if let stored = watchStore["watched"] {
            watchedFloors = Set(stored)
        }
    }

    func toggleWatch(floor: Int) {
        if watchedFloors.contains(floor) {
            watchedFloors.remove(floor)
        } else {
            watchedFloors.insert(floor)
        }
        watchStore.put(Array(watchedFloors).sorted(), forKey: "watched")
    }

    // MARK: - Concurrent refresh (withTaskGroup)
    // Each floor's stats are computed in a separate child task so all floors
    // are processed in parallel rather than sequentially.
    func refresh(spots: [ParkingSpot], records: [VehicleRecord]) async {
        guard !spots.isEmpty else { return }
        isRefreshing = true

        let floors     = Dictionary(grouping: spots, by: { $0.floor }).keys.sorted()
        let previous   = floorSnapshots

        var newSnapshots = [Int: FloorSnapshot]()

        await withTaskGroup(of: FloorSnapshot.self) { group in
            for floor in floors {
                // Capture value-type slices — safe across task boundaries
                let floorSpots   = spots.filter   { $0.floor == floor }
                let floorRecords = records.filter  { $0.floor == floor }
                let prevAvail    = previous[floor]?.available

                group.addTask {
                    let available = floorSpots.filter { $0.isAvailable }.count
                    let total     = floorSpots.count
                    let exits     = floorRecords.filter { $0.type == .exit }
                    let durSum    = exits.compactMap { $0.durationHours }.reduce(0, +)
                    let avgStay   = exits.isEmpty ? 0.0 : durSum / Double(exits.count)

                    let trend: FloorSnapshot.Trend = {
                        guard let prev = prevAvail else { return .same }
                        if available > prev { return .up   }
                        if available < prev { return .down }
                        return .same
                    }()

                    return FloorSnapshot(
                        floor: floor, available: available, total: total,
                        avgStayHours: avgStay, trend: trend, snapshotAt: Date()
                    )
                }
            }

            for await snap in group {
                newSnapshots[snap.floor] = snap
            }
        }

        floorSnapshots = newSnapshots
        lastRefreshed  = Date()
        isRefreshing   = false
    }

    // MARK: - Derived

    var sortedSnapshots: [FloorSnapshot] {
        floorSnapshots.values.sorted { $0.floor < $1.floor }
    }

    var watchedSnapshots: [FloorSnapshot] {
        sortedSnapshots.filter { watchedFloors.contains($0.floor) }
    }

    var unwatchedSnapshots: [FloorSnapshot] {
        sortedSnapshots.filter { !watchedFloors.contains($0.floor) }
    }
}
