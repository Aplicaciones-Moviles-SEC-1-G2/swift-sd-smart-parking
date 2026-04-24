import Foundation

// NSCache<NSString, NSArray> — keys are floor labels, values are [ParkingSpot]
// NSCache is thread-safe by default and evicts under memory pressure (LRU-like policy).
//
// countLimit: 500 — max entries before eviction kicks in regardless of memory.
// totalCostLimit: 2 MB — sum of per-object costs; each ParkingSpot is counted as ~1 KB.
// Cost is set when writing via setObject(_:forKey:cost:) so the cache can enforce the budget.
final class SpotCacheManager {
    static let shared = SpotCacheManager()

    private let cache: NSCache<NSString, NSArray> = {
        let c = NSCache<NSString, NSArray>()
        c.countLimit = 500
        c.totalCostLimit = 2 * 1_024 * 1_024
        return c
    }()

    private init() {}

    func store(_ spots: [ParkingSpot]) {
        let byFloor = Dictionary(grouping: spots, by: { $0.floor })
        for (floor, floorSpots) in byFloor {
            let key = "floor_\(floor)" as NSString
            let cost = floorSpots.count * 1_024
            cache.setObject(floorSpots as NSArray, forKey: key, cost: cost)
        }
    }

    func spots(forFloor floor: Int) -> [ParkingSpot]? {
        cache.object(forKey: "floor_\(floor)" as NSString) as? [ParkingSpot]
    }

    func allCachedSpots(floors: [Int]) -> [ParkingSpot] {
        floors.flatMap { spots(forFloor: $0) ?? [] }
    }

    func invalidate() {
        cache.removeAllObjects()
    }
}
