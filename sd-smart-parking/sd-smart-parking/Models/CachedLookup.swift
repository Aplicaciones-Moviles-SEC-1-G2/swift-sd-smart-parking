//
//  CachedLookup.swift
//  sd-smart-parking
//
//  Sprint 4 / Diego — caching feature.
//
//  Disk-persisted snapshot of a single plate's last bulk-lookup result.
//  Lives inside KeyValueStore<String, CachedLookup> scoped to
//  "diego.recent-lookups" so the BulkPlateLookupView can serve previously
//  fetched results instantly on a repeat search (and stay useful offline).
//

import Foundation

struct CachedLookup: Codable, Hashable {
    let plate: String
    let records: [VehicleRecord]
    let cachedAt: Date
}
