//
//  VehicleAIScannerViewModelTests.swift
//  sd-smart-parkingTests
//
//  Covers the cache HIT path of `VehicleAIScannerViewModel.analyze`. The MISS
//  path goes through Gemini and is exercised manually in the simulator; here we
//  inject fresh AIScanCache / ScanHistoryStore / ScanStats instances so the HIT
//  branch stays a pure synchronous, deterministic test.
//

import Foundation
import Testing
import UIKit
@testable import sd_smart_parking

@MainActor
@Suite("VehicleAIScannerViewModelCacheHit")
struct VehicleAIScannerViewModelCacheHitTests {

    // MARK: - Fixtures

    private func makeImage(width: Int = 80, height: Int = 80, color: UIColor = .red) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private func makeIdentification(brand: String = "toyota", plate: String = "ABC123") -> VehicleIdentification {
        VehicleIdentification(
            plate: plate,
            plateVisible: true,
            color: "white",
            brand: brand,
            model: "corolla"
        )
    }

    /// Returns the SHA256 key the VM will compute for a given image (after the
    /// same resize-to-1280 + JPEG(0.7) pipeline). Pre-populating the cache with
    /// this key forces the HIT branch.
    private func cacheKey(for image: UIImage) -> NSString {
        let resized = resize(image, maxSide: 1280)
        let jpeg = resized.jpegData(compressionQuality: 0.7)!
        return AIScanCache.key(forJPEGData: jpeg)
    }

    private func resize(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return image }
        let scale = maxSide / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    private func tempHistoryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ai-scanner-vm-test-\(UUID().uuidString).json")
    }

    private func waitForBarrier(on store: ScanHistoryStore) {
        // loadAll() shares the concurrent queue with the barrier write, so
        // calling it forces every preceding append to flush first.
        _ = store.loadAll()
    }

    // MARK: - Tests

    @Test func cacheHitAppendsToHistory() async throws {
        let cache = AIScanCache()
        let historyURL = tempHistoryURL()
        defer { try? FileManager.default.removeItem(at: historyURL) }
        let history = ScanHistoryStore(fileURL: historyURL)
        let stats = ScanStats(store: KeyValueStore<String, Int>(scope: "vmtest-history-\(UUID().uuidString)"))
        let vm = VehicleAIScannerViewModel(cache: cache, history: history, stats: stats)

        let image = makeImage()
        let key = cacheKey(for: image)
        let id = makeIdentification(plate: "HIT001")
        cache.put(id, for: key, cost: 1024)

        vm.analyze(image: image)

        // HIT branch is fully synchronous — no Task involved.
        if case let .success(returned) = vm.state {
            #expect(returned == id)
        } else {
            Issue.record("Expected .success state after cache HIT, got \(vm.state)")
        }

        waitForBarrier(on: history)
        let entries = history.loadAll()
        #expect(entries.count == 1)
        #expect(entries.first?.identification.plate == "HIT001")
        #expect(entries.first?.imageHashHex == key as String)

        stats.reset()
    }

    @Test func cacheHitIncrementsStats() async throws {
        let cache = AIScanCache()
        let historyURL = tempHistoryURL()
        defer { try? FileManager.default.removeItem(at: historyURL) }
        let history = ScanHistoryStore(fileURL: historyURL)
        let stats = ScanStats(store: KeyValueStore<String, Int>(scope: "vmtest-stats-\(UUID().uuidString)"))
        let vm = VehicleAIScannerViewModel(cache: cache, history: history, stats: stats)

        let image = makeImage(color: .blue)
        let key = cacheKey(for: image)
        let id = makeIdentification(brand: "mazda", plate: "HIT002")
        cache.put(id, for: key, cost: 1024)

        vm.analyze(image: image)
        vm.analyze(image: image)

        let top = stats.topBrands(5)
        let mazdaCount = top.first { $0.brand == "mazda" }?.count
        #expect(mazdaCount == 2)

        stats.reset()
    }

    @Test func cacheHitDoesNotAppendOnMissingKey() async throws {
        // Sanity check: if the cache lookup misses, the HIT branch is skipped,
        // so analyze launches a Gemini Task instead. We cannot fully exercise
        // that here without a real network; we only assert that no history is
        // written synchronously when the cache is empty.
        let cache = AIScanCache()
        let historyURL = tempHistoryURL()
        defer { try? FileManager.default.removeItem(at: historyURL) }
        let history = ScanHistoryStore(fileURL: historyURL)
        let stats = ScanStats(store: KeyValueStore<String, Int>(scope: "vmtest-miss-\(UUID().uuidString)"))
        let vm = VehicleAIScannerViewModel(cache: cache, history: history, stats: stats)

        let image = makeImage(color: .green)

        vm.analyze(image: image)

        // Synchronously after analyze returns we should be in .analyzing,
        // because the MISS branch kicked off a Task and is awaiting Gemini.
        if case .analyzing = vm.state {
            // expected
        } else {
            Issue.record("Expected .analyzing state after cache MISS, got \(vm.state)")
        }

        waitForBarrier(on: history)
        // Nothing flushed to history yet — that only happens after Gemini
        // returns, which won't happen in the test environment.
        #expect(history.loadAll().isEmpty)

        stats.reset()
    }
}
