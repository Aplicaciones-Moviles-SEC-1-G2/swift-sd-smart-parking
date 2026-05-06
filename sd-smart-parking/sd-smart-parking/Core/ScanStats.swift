//
//  ScanStats.swift
//  sd-smart-parking
//
//  Counts how many times each vehicle brand has been scanned, persisted via
//  KeyValueStore. Surfaced in the Gerente profile as "Top brands scanned".
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ScanStats: ObservableObject {
    static let shared = ScanStats()

    private let store: KeyValueStore<String, Int>

    init(store: KeyValueStore<String, Int>? = nil) {
        self.store = store ?? KeyValueStore<String, Int>(scope: "scan_brand_count")
    }

    /// Increments the count for the given brand (case-insensitive). Skips
    /// "unknown" results so they do not pollute the leaderboard.
    func increment(brand: String) {
        let normalized = brand.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized != "unknown" else { return }
        let next = (store[normalized] ?? 0) + 1
        store[normalized] = next
        objectWillChange.send()
    }

    /// Returns the top `limit` brands by scan count, descending.
    func topBrands(_ limit: Int = 3) -> [(brand: String, count: Int)] {
        store.snapshot()
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .prefix(limit)
            .map { (brand: $0.key, count: $0.value) }
    }

    func reset() {
        store.clear()
        objectWillChange.send()
    }
}
