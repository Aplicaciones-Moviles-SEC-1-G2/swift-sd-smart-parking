//
//  ParkingDemandInsights.swift
//  sd-smart-parking
//

import Foundation

/// Hour-by-hour view of entries and exits derived from `VehicleRecord`s. Feeds
/// the insights sheet opened from the dashboard banner.
///
/// Separate from `HistoricDemandSchedule`:
/// - `HistoricDemandSchedule` collapses hours into peak/valley ranges for the
///   banner and gates on sample size for classification accuracy.
/// - `ParkingDemandInsights` exposes the raw counts for charting and produces
///   arrival/departure recommendations. It is always buildable (returns empty
///   histograms when there is no data) so the sheet can explain the
///   cold-start state instead of failing to open.
struct ParkingDemandInsights: Equatable {

    struct HourlyCount: Identifiable, Equatable {
        let hour: Int
        let count: Int
        var id: Int { hour }
        /// `08:00`-style label, suitable for chart axis marks.
        var label: String { String(format: "%02d:00", hour) }
    }

    let weekdayEntryCounts: [HourlyCount]
    let weekdayExitCounts: [HourlyCount]
    let weekendEntryCounts: [HourlyCount]
    let weekendExitCounts: [HourlyCount]
    let totalEntries: Int
    let totalExits: Int

    /// Minimum number of entries/exits required inside the selected bucket
    /// before arrival/departure recommendations are shown. Below this, every
    /// hour is essentially tied at 0–1 and picking a "best" hour is noise.
    static let minSampleForRecommendation = 10

    static func build(from records: [VehicleRecord]) -> ParkingDemandInsights {
        let calendar = Calendar.current
        var weekdayEntry = Array(repeating: 0, count: 24)
        var weekdayExit = Array(repeating: 0, count: 24)
        var weekendEntry = Array(repeating: 0, count: 24)
        var weekendExit = Array(repeating: 0, count: 24)
        var totalEntries = 0
        var totalExits = 0

        for record in records {
            let comps = calendar.dateComponents([.hour, .weekday], from: record.timestamp)
            guard let hour = comps.hour, (0..<24).contains(hour) else { continue }
            let isWeekend = (comps.weekday == 1 || comps.weekday == 7)
            switch record.type {
            case .entry:
                totalEntries += 1
                if isWeekend { weekendEntry[hour] += 1 } else { weekdayEntry[hour] += 1 }
            case .exit:
                totalExits += 1
                if isWeekend { weekendExit[hour] += 1 } else { weekdayExit[hour] += 1 }
            }
        }

        return ParkingDemandInsights(
            weekdayEntryCounts: toHourly(weekdayEntry),
            weekdayExitCounts: toHourly(weekdayExit),
            weekendEntryCounts: toHourly(weekendEntry),
            weekendExitCounts: toHourly(weekendExit),
            totalEntries: totalEntries,
            totalExits: totalExits
        )
    }

    private static func toHourly(_ counts: [Int]) -> [HourlyCount] {
        counts.enumerated().map { HourlyCount(hour: $0.offset, count: $0.element) }
    }

    // MARK: - Recommendations

    /// Operating-hour slots with the fewest historic entries — least
    /// competition for spots when arriving. Hours with zero recorded activity
    /// are excluded: a 0-count hour is ambiguous (truly idle vs. never
    /// observed), so we only recommend hours backed by real evidence. Returns
    /// an empty array below `minSampleForRecommendation`.
    func bestEntryHours(weekend: Bool, openingHour: Int, closingHour: Int, topN: Int = 3) -> [HourlyCount] {
        let bucket = weekend ? weekendEntryCounts : weekdayEntryCounts
        let bucketTotal = bucket.reduce(0) { $0 + $1.count }
        guard bucketTotal >= Self.minSampleForRecommendation else { return [] }
        return Array(
            bucket
                .filter { (openingHour..<closingHour).contains($0.hour) && $0.count > 0 }
                .sorted { $0.count < $1.count }
                .prefix(topN)
        )
    }

    /// Operating-hour slots with the fewest historic exits — quietest
    /// departure windows, so drivers avoid a rush at the exit gate. Same
    /// evidence filter as `bestEntryHours`.
    func bestExitHours(weekend: Bool, openingHour: Int, closingHour: Int, topN: Int = 3) -> [HourlyCount] {
        let bucket = weekend ? weekendExitCounts : weekdayExitCounts
        let bucketTotal = bucket.reduce(0) { $0 + $1.count }
        guard bucketTotal >= Self.minSampleForRecommendation else { return [] }
        return Array(
            bucket
                .filter { (openingHour..<closingHour).contains($0.hour) && $0.count > 0 }
                .sorted { $0.count < $1.count }
                .prefix(topN)
        )
    }

    func totalForBucket(weekend: Bool) -> (entries: Int, exits: Int) {
        if weekend {
            return (
                weekendEntryCounts.reduce(0) { $0 + $1.count },
                weekendExitCounts.reduce(0) { $0 + $1.count }
            )
        }
        return (
            weekdayEntryCounts.reduce(0) { $0 + $1.count },
            weekdayExitCounts.reduce(0) { $0 + $1.count }
        )
    }
}
