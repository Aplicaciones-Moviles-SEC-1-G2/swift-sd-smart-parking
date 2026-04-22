//
//  HistoricDemandSchedule.swift
//  sd-smart-parking
//

import Foundation

/// Per-hour peak/valley classification derived from historic `VehicleRecord`
/// entries in Firestore. When enough samples are available, this is used in
/// place of `PeakHoursSchedule`'s hardcoded ranges.
///
/// Algorithm per bucket (weekday / weekend):
/// 1. Build a 24-hour histogram of entry counts.
/// 2. Compute mean and standard deviation over the *active* hours (hours with
///    at least one entry), so dead-of-night zeros don't pull the mean down.
/// 3. Classify each active hour: `peak` if count ≥ mean + 0.5σ,
///    `valley` if count ≤ max(1, mean − 0.5σ), else `normal`.
/// 4. Merge contiguous peak/valley hours into ranges compatible with the
///    existing countdown logic.
struct HistoricDemandSchedule: Equatable {
    let weekdayPeakRanges: [HourRange]
    let weekdayValleyRanges: [HourRange]
    let weekendPeakRanges: [HourRange]
    let weekendValleyRanges: [HourRange]
    let sampleSize: Int

    struct HourRange: Equatable {
        let start: Int
        let end: Int
    }

    static let minSampleSize = 20
    private static let stddevMultiplier = 0.5

    /// Returns `nil` when the total number of entry records is below
    /// `minSampleSize`, or when no bucket yields any classified hour — callers
    /// should fall back to `PeakHoursSchedule`'s hardcoded defaults in that case.
    static func build(from records: [VehicleRecord]) -> HistoricDemandSchedule? {
        let entries = records.filter { $0.type == .entry }
        guard entries.count >= minSampleSize else { return nil }

        let calendar = Calendar.current
        var weekdayHistogram = Array(repeating: 0, count: 24)
        var weekendHistogram = Array(repeating: 0, count: 24)
        var weekdayCount = 0
        var weekendCount = 0

        for record in entries {
            let components = calendar.dateComponents([.hour, .weekday], from: record.timestamp)
            guard let hour = components.hour, (0..<24).contains(hour) else { continue }
            let weekday = components.weekday ?? 0
            let isWeekend = (weekday == 1 || weekday == 7)
            if isWeekend {
                weekendHistogram[hour] += 1
                weekendCount += 1
            } else {
                weekdayHistogram[hour] += 1
                weekdayCount += 1
            }
        }

        let (weekdayPeaks, weekdayValleys) = weekdayCount >= minSampleSize
            ? classify(weekdayHistogram)
            : ([], [])
        let (weekendPeaks, weekendValleys) = weekendCount >= minSampleSize
            ? classify(weekendHistogram)
            : ([], [])

        let classifiedAnything =
            !weekdayPeaks.isEmpty || !weekdayValleys.isEmpty ||
            !weekendPeaks.isEmpty || !weekendValleys.isEmpty
        guard classifiedAnything else { return nil }

        return HistoricDemandSchedule(
            weekdayPeakRanges: weekdayPeaks,
            weekdayValleyRanges: weekdayValleys,
            weekendPeakRanges: weekendPeaks,
            weekendValleyRanges: weekendValleys,
            sampleSize: weekdayCount + weekendCount
        )
    }

    /// Hours that count as "active" — at least one entry observed. At least
    /// three active hours are required to produce a meaningful distribution.
    private static func classify(_ histogram: [Int]) -> (peaks: [HourRange], valleys: [HourRange]) {
        let active = histogram.enumerated().filter { $0.element > 0 }
        guard active.count >= 3 else { return ([], []) }

        let values = active.map { Double($0.element) }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        let stddev = variance.squareRoot()

        // Flat histogram → nothing worth classifying.
        guard stddev > 0 else { return ([], []) }

        let peakThreshold = mean + stddevMultiplier * stddev
        let valleyThreshold = max(1.0, mean - stddevMultiplier * stddev)

        var peakHours: [Int] = []
        var valleyHours: [Int] = []
        for (hour, count) in active {
            let c = Double(count)
            if c >= peakThreshold {
                peakHours.append(hour)
            } else if c <= valleyThreshold {
                valleyHours.append(hour)
            }
        }

        return (mergeRanges(peakHours), mergeRanges(valleyHours))
    }

    /// Collapses a sorted list of individual hours into half-open ranges
    /// `[start, end)` the existing countdown logic expects.
    private static func mergeRanges(_ hours: [Int]) -> [HourRange] {
        guard !hours.isEmpty else { return [] }
        let sorted = hours.sorted()
        var result: [HourRange] = []
        var start = sorted[0]
        var prev = sorted[0]
        for h in sorted.dropFirst() {
            if h == prev + 1 {
                prev = h
            } else {
                result.append(HourRange(start: start, end: prev + 1))
                start = h
                prev = h
            }
        }
        result.append(HourRange(start: start, end: prev + 1))
        return result
    }
}
