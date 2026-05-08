//
//  LRUCacheTests.swift
//  sd-smart-parkingTests
//

import Foundation
import Testing
@testable import sd_smart_parking

@Suite("LRUCache")
struct LRUCacheTests {

    @Test func emptyCacheReturnsNil() async throws {
        let c = LRUCache<String, Int>(capacity: 5)
        #expect(c.get("anything") == nil)
        #expect(c.count == 0)
    }

    @Test func putThenGetReturnsValue() async throws {
        let c = LRUCache<String, Int>(capacity: 5)
        c.put(42, for: "answer")
        #expect(c.get("answer") == 42)
        #expect(c.count == 1)
    }

    @Test func putUpdatesExistingValueWithoutGrowingCount() async throws {
        let c = LRUCache<String, Int>(capacity: 5)
        c.put(1, for: "k")
        c.put(99, for: "k")
        #expect(c.get("k") == 99)
        #expect(c.count == 1)
    }

    @Test func capacityOverflowEvictsLeastRecentlyUsed() async throws {
        let c = LRUCache<String, Int>(capacity: 2)
        c.put(1, for: "a")
        c.put(2, for: "b")
        c.put(3, for: "c") // evicts "a"

        #expect(c.get("a") == nil)
        #expect(c.get("b") == 2)
        #expect(c.get("c") == 3)
        #expect(c.count == 2)
    }

    @Test func getPromotesEntryToMostRecentlyUsed() async throws {
        let c = LRUCache<String, Int>(capacity: 2)
        c.put(1, for: "a")
        c.put(2, for: "b")
        _ = c.get("a")        // promotes "a" -> MRU; "b" is now LRU
        c.put(3, for: "c")    // evicts "b"

        #expect(c.get("b") == nil)
        #expect(c.get("a") == 1)
        #expect(c.get("c") == 3)
    }

    @Test func clearRemovesEverything() async throws {
        let c = LRUCache<String, Int>(capacity: 3)
        c.put(1, for: "a"); c.put(2, for: "b"); c.put(3, for: "c")
        c.clear()
        #expect(c.count == 0)
        #expect(c.get("a") == nil)
        #expect(c.get("c") == nil)
    }

    @Test func capacityOneAlwaysHoldsLatest() async throws {
        let c = LRUCache<String, Int>(capacity: 1)
        c.put(1, for: "a")
        c.put(2, for: "b")
        c.put(3, for: "c")
        #expect(c.count == 1)
        #expect(c.get("c") == 3)
        #expect(c.get("a") == nil)
    }

    @Test func clearReleasesNodes() async throws {
        // Defends "no retention cycles in the doubly-linked node graph" — if
        // prev/next references created a strong cycle, the boxed value would
        // outlive the cache even after `clear()`.
        final class Box { let v: Int; init(_ v: Int) { self.v = v } }
        let cache = LRUCache<String, Box>(capacity: 2)

        weak var ref: Box?
        do {
            let box = Box(42)
            ref = box
            cache.put(box, for: "k")
        }
        cache.clear()
        #expect(ref == nil)
    }
}

@Suite("TripCacheKey")
struct TripCacheKeyTests {

    @Test func smallArrivalDifferenceLandsInSameBucket() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let later = now.addingTimeInterval(60) // +1 minute
        let k1 = TripCacheKey(arrivalDate: now, durationHours: 1.0)
        let k2 = TripCacheKey(arrivalDate: later, durationHours: 1.0)
        #expect(k1 == k2) // same 5-min bucket
    }

    @Test func crossingBucketBoundaryProducesDifferentKey() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let later = now.addingTimeInterval(301) // +5 min 1 sec
        let k1 = TripCacheKey(arrivalDate: now, durationHours: 1.0)
        let k2 = TripCacheKey(arrivalDate: later, durationHours: 1.0)
        #expect(k1 != k2)
    }

    @Test func smallDurationDifferenceLandsInSameBucket() async throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let k1 = TripCacheKey(arrivalDate: date, durationHours: 1.00)
        let k2 = TripCacheKey(arrivalDate: date, durationHours: 1.04) // +2.4 min
        #expect(k1 == k2)
    }

    @Test func differentDurationsProduceDifferentKeys() async throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let k1 = TripCacheKey(arrivalDate: date, durationHours: 1.0)
        let k2 = TripCacheKey(arrivalDate: date, durationHours: 1.5)
        #expect(k1 != k2)
    }

    @Test func durationBucketIsFlooredNotRounded() async throws {
        // Asymmetric bucketing fix: arrival truncates via Int(...) cast and
        // duration now matches with `.rounded(.down)`. Under round-to-nearest,
        // 1.49h would round up into bucket 18 (matching 1.50h); flooring
        // keeps 1.49h in bucket 17 with 1.45h, which is the intended policy.
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let k145 = TripCacheKey(arrivalDate: date, durationHours: 1.45)
        let k149 = TripCacheKey(arrivalDate: date, durationHours: 1.49)
        let k150 = TripCacheKey(arrivalDate: date, durationHours: 1.50)
        #expect(k145 == k149)
        #expect(k149 != k150)
    }
}
