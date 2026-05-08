//
//  KeyValueStoreTests.swift
//  sd-smart-parkingTests
//

import Foundation
import Testing
@testable import sd_smart_parking

@Suite("KeyValueStore")
struct KeyValueStoreTests {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("kv-test-\(UUID().uuidString).json")
    }

    private func waitForBarrier<K, V>(on store: KeyValueStore<K, V>) {
        // snapshot() goes through the same concurrent queue as writes, so
        // calling it after a put/remove forces every preceding barrier to flush.
        _ = store.snapshot()
    }

    @Test func putGetRoundTrip() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = KeyValueStore<String, Int>(scope: "test", fileURL: url)

        store.put(7, forKey: "alpha")
        waitForBarrier(on: store)
        #expect(store["alpha"] == 7)
    }

    @Test func removeNullsTheValue() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = KeyValueStore<String, Int>(scope: "test", fileURL: url)

        store.put(1, forKey: "a")
        store.put(2, forKey: "b")
        store.remove("a")
        waitForBarrier(on: store)

        #expect(store["a"] == nil)
        #expect(store["b"] == 2)
    }

    @Test func reloadFromDiskKeepsValues() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let s1 = KeyValueStore<String, Int>(scope: "test", fileURL: url)
            s1.put(99, forKey: "persisted")
            waitForBarrier(on: s1)
        }
        let s2 = KeyValueStore<String, Int>(scope: "test", fileURL: url)
        #expect(s2["persisted"] == 99)
    }

    @Test func snapshotReflectsCurrentState() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = KeyValueStore<String, Int>(scope: "test", fileURL: url)

        store.put(10, forKey: "x")
        store.put(20, forKey: "y")
        waitForBarrier(on: store)

        let snap = store.snapshot()
        #expect(snap.count == 2)
        #expect(snap["x"] == 10)
        #expect(snap["y"] == 20)
    }

    @Test func clearRemovesAll() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = KeyValueStore<String, Int>(scope: "test", fileURL: url)
        store.put(1, forKey: "a")
        waitForBarrier(on: store)

        store.clear()
        waitForBarrier(on: store)
        #expect(store.count == 0)
    }
}

@Suite("ScanStats")
struct ScanStatsTests {

    @MainActor
    private func makeStats() -> ScanStats {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("scanstats-\(UUID().uuidString).json")
        return ScanStats(
            store: KeyValueStore<String, Int>(scope: "scanstats", fileURL: url)
        )
    }

    @Test @MainActor func incrementCountsBrand() async throws {
        let stats = makeStats()
        stats.increment(brand: "Toyota")
        stats.increment(brand: "toyota")
        stats.increment(brand: "Mazda")

        let top = stats.topBrands(5)
        #expect(top.first?.brand == "toyota")
        #expect(top.first?.count == 2)
        #expect(top.contains { $0.brand == "mazda" && $0.count == 1 })
    }

    @Test @MainActor func ignoresUnknownBrand() async throws {
        let stats = makeStats()
        stats.increment(brand: "unknown")
        stats.increment(brand: "  ")
        stats.increment(brand: "Mazda")

        let top = stats.topBrands(5)
        #expect(top.count == 1)
        #expect(top.first?.brand == "mazda")
    }

    @Test @MainActor func topBrandsRespectsLimitAndOrder() async throws {
        let stats = makeStats()
        for _ in 0..<3 { stats.increment(brand: "Toyota") }
        for _ in 0..<5 { stats.increment(brand: "Mazda") }
        for _ in 0..<1 { stats.increment(brand: "Ford") }

        let top = stats.topBrands(2)
        #expect(top.count == 2)
        #expect(top[0].brand == "mazda")
        #expect(top[1].brand == "toyota")
    }
}
