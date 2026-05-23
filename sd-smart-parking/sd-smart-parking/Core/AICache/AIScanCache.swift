//
//  AIScanCache.swift
//  sd-smart-parking
//
//  In-memory NSCache for VehicleIdentification results keyed by SHA256 of
//  the JPEG bytes of the resized scan image. Saves Gemini calls when the
//  Gerente re-scans the same vehicle.
//
//  Distinct from SpotCacheManager (Juanes' NSCache for parking spots) by
//  domain (Gemini results vs spots), key shape (image hash vs floor label),
//  value wrapping (boxed struct vs NSArray), and capacity rationale.
//

import Foundation
import UIKit
import CryptoKit

/// Wrapper that lets `VehicleIdentification` (a struct) live inside `NSCache`,
/// which only accepts `AnyObject` values. Carries the byte cost so the cache
/// can apply totalCostLimit-driven eviction.
final class CachedIdentificationBox: NSObject {
    let value: VehicleIdentification
    let cost: Int

    init(value: VehicleIdentification, cost: Int) {
        self.value = value
        self.cost = cost
    }
}

final class AIScanCache: @unchecked Sendable {
    static let shared = AIScanCache()

    /// `countLimit = 30`: a Gerente shift averages ~30 unique scans
    /// (8 hours x 3-4 cars/hour). `totalCostLimit = 1 MB`: typical
    /// JPEG-compressed scan after resize-to-1280 weighs 30-50 KB, so
    /// the cost limit kicks in before the count limit and bounds memory.
    private let cache: NSCache<NSString, CachedIdentificationBox>

    /// Internal init exposed for tests; production paths should use `.shared`.
    init(countLimit: Int = 30, totalCostLimit: Int = 1 * 1024 * 1024) {
        let c = NSCache<NSString, CachedIdentificationBox>()
        c.countLimit = countLimit
        c.totalCostLimit = totalCostLimit
        self.cache = c
    }

    /// SHA256 hex of the JPEG (quality 0.7) representation of the image.
    /// Stable across calls for byte-identical inputs; collisions are
    /// cryptographically unlikely.
    func key(for image: UIImage) -> NSString? {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return nil }
        return Self.key(forJPEGData: data)
    }

    // Pure SHA256 — `nonisolated` so callers on background tasks (Sprint 4
    // image-prep offload) can compute the cache key without bouncing back
    // to the MainActor for what is fundamentally CPU work.
    nonisolated static func key(forJPEGData data: Data) -> NSString {
        let digest = SHA256.hash(data: data)
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        return hex as NSString
    }

    func get(_ key: NSString) -> VehicleIdentification? {
        cache.object(forKey: key)?.value
    }

    func put(_ value: VehicleIdentification, for key: NSString, cost: Int) {
        cache.setObject(
            CachedIdentificationBox(value: value, cost: cost),
            forKey: key,
            cost: cost
        )
    }

    func clear() {
        cache.removeAllObjects()
    }
}
