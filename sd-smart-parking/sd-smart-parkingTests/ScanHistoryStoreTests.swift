//
//  ScanHistoryStoreTests.swift
//  sd-smart-parkingTests
//

import Foundation
import Testing
@testable import sd_smart_parking

@Suite("ScanHistoryStore")
struct ScanHistoryStoreTests {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("scan-history-test-\(UUID().uuidString).json")
    }

    private func makeEntry(plate: String = "ABC123") -> ScanHistoryEntry {
        ScanHistoryEntry(
            identification: VehicleIdentification(
                plate: plate,
                plateVisible: true,
                color: "white",
                brand: "toyota",
                model: "corolla"
            ),
            imageHashHex: "deadbeef"
        )
    }

    private func waitForBarrier(on store: ScanHistoryStore) {
        // loadAll() goes through the same concurrent queue so calling it
        // forces every preceding barrier write to complete first.
        _ = store.loadAll()
    }

    @Test func appendThenLoadRoundTrip() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ScanHistoryStore(fileURL: url)

        store.append(makeEntry(plate: "XYZ001"))
        waitForBarrier(on: store)

        let all = store.loadAll()
        #expect(all.count == 1)
        #expect(all.first?.identification.plate == "XYZ001")
    }

    @Test func ringBufferEvictsOldestBeyondMaxEntries() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ScanHistoryStore(fileURL: url, maxEntries: 3)

        store.append(makeEntry(plate: "AAA001"))
        store.append(makeEntry(plate: "BBB002"))
        store.append(makeEntry(plate: "CCC003"))
        store.append(makeEntry(plate: "DDD004")) // pushes AAA001 out
        waitForBarrier(on: store)

        let all = store.loadAll()
        #expect(all.count == 3)
        let plates = all.map { $0.identification.plate }
        #expect(plates.first == "DDD004") // newest at index 0
        #expect(!plates.contains("AAA001"))
    }

    @Test func corruptionReturnsEmpty() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not json".utf8).write(to: url)
        let store = ScanHistoryStore(fileURL: url)

        #expect(store.loadAll().isEmpty)
    }

    @Test func clearRemovesFile() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ScanHistoryStore(fileURL: url)

        store.append(makeEntry())
        waitForBarrier(on: store)
        #expect(store.loadAll().isEmpty == false)

        store.clear()
        waitForBarrier(on: store)
        #expect(store.loadAll().isEmpty)
    }
}
