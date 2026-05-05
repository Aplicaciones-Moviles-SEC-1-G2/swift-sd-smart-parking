//
//  AIScanCacheTests.swift
//  sd-smart-parkingTests
//

import Foundation
import Testing
import UIKit
@testable import sd_smart_parking

@Suite("AIScanCache")
struct AIScanCacheTests {

    private func makeImage(width: Int, height: Int, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private func sampleIdentification(plate: String = "ABC123") -> VehicleIdentification {
        VehicleIdentification(
            plate: plate,
            plateVisible: true,
            color: "white",
            brand: "toyota",
            model: "corolla"
        )
    }

    @Test func storesAndReturnsValue() async throws {
        let cache = AIScanCache()
        let img = makeImage(width: 100, height: 100, color: .red)
        let key = try #require(cache.key(for: img))
        let id = sampleIdentification()

        cache.put(id, for: key, cost: 1024)
        #expect(cache.get(key) == id)
    }

    @Test func missReturnsNil() async throws {
        let cache = AIScanCache()
        let img = makeImage(width: 100, height: 100, color: .green)
        let key = try #require(cache.key(for: img))

        #expect(cache.get(key) == nil)
    }

    @Test func sameBytesProduceSameKey() async throws {
        let cache = AIScanCache()
        let imgA = makeImage(width: 50, height: 50, color: .blue)
        let imgB = makeImage(width: 50, height: 50, color: .blue)

        let keyA = try #require(cache.key(for: imgA))
        let keyB = try #require(cache.key(for: imgB))

        #expect(keyA == keyB)
    }

    @Test func differentImagesProduceDifferentKeys() async throws {
        let cache = AIScanCache()
        let imgA = makeImage(width: 50, height: 50, color: .blue)
        let imgB = makeImage(width: 50, height: 50, color: .yellow)

        let keyA = try #require(cache.key(for: imgA))
        let keyB = try #require(cache.key(for: imgB))

        #expect(keyA != keyB)
    }

    @Test func clearRemovesAllEntries() async throws {
        let cache = AIScanCache()
        let img = makeImage(width: 10, height: 10, color: .black)
        let key = try #require(cache.key(for: img))

        cache.put(sampleIdentification(), for: key, cost: 100)
        cache.clear()

        #expect(cache.get(key) == nil)
    }

    @Test func keyForJPEGDataIsStable() async throws {
        let bytes = Data((0..<256).map { UInt8($0) })
        let key1 = AIScanCache.key(forJPEGData: bytes)
        let key2 = AIScanCache.key(forJPEGData: bytes)
        #expect(key1 == key2)
        #expect((key1 as String).count == 64) // SHA256 hex = 32 bytes * 2 chars
    }
}
