//
//  PinnedPlatesViewModel.swift
//  sd-smart-parking
//
//  Sprint 4 / Diego — local-storage feature.
//
//  Drives PinnedPlatesView. Persists Gerente-pinned plates on disk via
//  KeyValueStore<String, PinnedPlate> scoped to "diego.pinned-plates"
//  (Documents/diego.kv/diego.pinned-plates.json).
//
//  Storage choice:
//    KeyValueStore writes a JSON blob keyed by plate, so every operation
//    (pin/unpin/exists) is O(1) on the in-memory dictionary, with a
//    barrier-write JSON encode happening on the store's concurrent queue.
//    Picked over SwiftData / CoreData because the dataset is tiny and the
//    existing K/V store is already approved infrastructure in this repo.
//
//  Works fully offline by definition — there is no network round-trip.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class PinnedPlatesViewModel: ObservableObject {

    @Published private(set) var pinned: [PinnedPlate] = []

    private let store: KeyValueStore<String, PinnedPlate>

    init(scope: String = "diego.pinned-plates") {
        self.store = KeyValueStore<String, PinnedPlate>(scope: scope)
        reload()
    }

    // MARK: - Public API

    func isPinned(_ plate: String) -> Bool {
        store[normalize(plate)] != nil
    }

    func pin(_ plate: String, note: String? = nil) {
        let key = normalize(plate)
        guard !key.isEmpty else { return }
        let entry = PinnedPlate(plate: key, pinnedAt: Date(), note: note)
        store.put(entry, forKey: key)
        reload()
    }

    func unpin(_ plate: String) {
        store.remove(normalize(plate))
        reload()
    }

    func toggle(_ plate: String) {
        let key = normalize(plate)
        if isPinned(key) { unpin(key) } else { pin(key) }
    }

    func updateNote(_ plate: String, note: String?) {
        let key = normalize(plate)
        guard var current = store[key] else { return }
        current.note = note?.isEmpty == true ? nil : note
        store.put(current, forKey: key)
        reload()
    }

    // MARK: - Internals

    /// Read the on-disk snapshot and sort most-recent-pin-first.
    func reload() {
        pinned = store.snapshot()
            .values
            .sorted { $0.pinnedAt > $1.pinnedAt }
    }

    private func normalize(_ plate: String) -> String {
        plate.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
