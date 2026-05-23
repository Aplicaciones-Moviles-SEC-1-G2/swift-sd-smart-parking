//
//  PinnedPlate.swift
//  sd-smart-parking
//
//  Sprint 4 / Diego — local-storage feature.
//
//  Minimal Codable value the Gerente keeps locally to bookmark plates they
//  look up often. Persisted via KeyValueStore (Documents/diego.kv/...) so it
//  survives app restarts and is available offline.
//

import Foundation

struct PinnedPlate: Identifiable, Codable, Hashable {
    let plate: String
    let pinnedAt: Date
    var note: String?

    var id: String { plate }
}
