//
//  TripCacheKey.swift
//  sd-smart-parking
//
//  Composite key for caching computed trip costs in the LRUCache.
//
//  Uses 5-minute buckets on both arrival and duration so small slider
//  adjustments still produce cache hits — keying on the raw Date would mean
//  the cache only ever pegs on identical user clicks, which never happens
//  via a continuous DatePicker.
//

import Foundation

struct TripCacheKey: Hashable {
    let arrivalBucket: Int
    let durationBucket: Int

    /// Five-minute buckets — picked because the DatePicker's minute step is
    /// usually 1 or 5, so a 5-minute window absorbs the typical jitter and
    /// is small enough that the cached cost is still a faithful approximation.
    static let arrivalBucketSeconds: TimeInterval = 300.0
    static let durationBucketsPerHour: Double = 12.0

    init(arrivalDate: Date, durationHours: Double) {
        // Floor on both axes so the bucketing policy is symmetric — arrival
        // already truncates via the `Int(...)` cast, and explicit `.rounded(.down)`
        // makes the duration side line up rather than rounding to nearest.
        self.arrivalBucket = Int(arrivalDate.timeIntervalSince1970 / Self.arrivalBucketSeconds)
        self.durationBucket = Int((durationHours * Self.durationBucketsPerHour).rounded(.down))
    }
}
