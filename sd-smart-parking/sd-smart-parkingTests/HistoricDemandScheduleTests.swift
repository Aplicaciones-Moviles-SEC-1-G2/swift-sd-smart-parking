//
//  HistoricDemandScheduleTests.swift
//  sd-smart-parkingTests
//

import Foundation
import Testing
@testable import sd_smart_parking

// MARK: - Helpers

/// Weekday: April 9, 2026 is a Thursday.
private let weekdayYear = 2026
private let weekdayMonth = 4
private let weekdayDay = 9

/// Weekend: April 4, 2026 is a Saturday.
private let weekendYear = 2026
private let weekendMonth = 4
private let weekendDay = 4

private func weekdayEntry(hour: Int, minute: Int = 0) -> VehicleRecord {
    var comps = DateComponents()
    comps.year = weekdayYear
    comps.month = weekdayMonth
    comps.day = weekdayDay
    comps.hour = hour
    comps.minute = minute
    let date = Calendar.current.date(from: comps)!
    return VehicleRecord(
        id: UUID().uuidString,
        plate: "ABC123",
        type: .entry,
        timestamp: date,
        floor: nil,
        spotNumber: nil,
        photoURL: nil,
        isRegistered: false,
        ownerEmail: nil,
        ocrConfidence: 1.0,
        durationHours: nil,
        hitDailyCap: false
    )
}

private func weekendEntry(hour: Int, minute: Int = 0) -> VehicleRecord {
    var comps = DateComponents()
    comps.year = weekendYear
    comps.month = weekendMonth
    comps.day = weekendDay
    comps.hour = hour
    comps.minute = minute
    let date = Calendar.current.date(from: comps)!
    return VehicleRecord(
        id: UUID().uuidString,
        plate: "ABC123",
        type: .entry,
        timestamp: date,
        floor: nil,
        spotNumber: nil,
        photoURL: nil,
        isRegistered: false,
        ownerEmail: nil,
        ocrConfidence: 1.0,
        durationHours: nil,
        hitDailyCap: false
    )
}

/// Build `count` entries at the same hour on a weekday.
private func weekdayEntries(hour: Int, count: Int) -> [VehicleRecord] {
    (0..<count).map { _ in weekdayEntry(hour: hour) }
}

private func weekendEntries(hour: Int, count: Int) -> [VehicleRecord] {
    (0..<count).map { _ in weekendEntry(hour: hour) }
}

// MARK: - Insufficient data → nil

@Suite("HistoricDemandSchedule build guard")
struct HistoricDemandScheduleBuildGuard {

    @Test func returnsNilWhenUnderMinSampleSize() {
        // 19 entries — below the 20-sample floor.
        let records = weekdayEntries(hour: 8, count: 19)
        #expect(HistoricDemandSchedule.build(from: records) == nil)
    }

    @Test func returnsNilWhenHistogramIsCompletelyFlat() {
        // 30 entries all at the same hour: only one active hour,
        // so classify() bails on the "need ≥3 active hours" guard.
        let records = weekdayEntries(hour: 8, count: 30)
        #expect(HistoricDemandSchedule.build(from: records) == nil)
    }

    @Test func exitRecordsAreIgnored() {
        // 30 exits — even though there are enough records, none are entries.
        let exits: [VehicleRecord] = (0..<30).map { _ in
            let r = weekdayEntry(hour: 8)
            return VehicleRecord(
                id: r.id,
                plate: r.plate,
                type: .exit,
                timestamp: r.timestamp,
                floor: nil,
                spotNumber: nil,
                photoURL: nil,
                isRegistered: false,
                ownerEmail: nil,
                ocrConfidence: 1.0,
                durationHours: nil,
                hitDailyCap: false
            )
        }
        #expect(HistoricDemandSchedule.build(from: exits) == nil)
    }
}

// MARK: - Classification

@Suite("HistoricDemandSchedule classification")
struct HistoricDemandScheduleClassification {

    /// Skewed weekday histogram:
    ///   hour  8: 15 entries   ← clear peak
    ///   hour 12:  1 entry     ← clear valley
    ///   hour 14:  1 entry     ← clear valley
    ///   hour 16:  5 entries   ← normal
    @Test func identifiesWeekdayPeakAndValleys() {
        var records: [VehicleRecord] = []
        records += weekdayEntries(hour: 8, count: 15)
        records += weekdayEntries(hour: 12, count: 1)
        records += weekdayEntries(hour: 14, count: 1)
        records += weekdayEntries(hour: 16, count: 5)

        let schedule = HistoricDemandSchedule.build(from: records)
        #expect(schedule != nil)
        guard let schedule else { return }

        #expect(schedule.weekdayPeakRanges.contains { $0.start <= 8 && 8 < $0.end })
        #expect(schedule.weekdayValleyRanges.contains { $0.start <= 12 && 12 < $0.end })
        #expect(schedule.weekdayValleyRanges.contains { $0.start <= 14 && 14 < $0.end })
        // Hour 16 should not fall in peak or valley.
        #expect(!schedule.weekdayPeakRanges.contains { $0.start <= 16 && 16 < $0.end })
        #expect(!schedule.weekdayValleyRanges.contains { $0.start <= 16 && 16 < $0.end })
    }

    /// Contiguous peak hours collapse into a single range.
    @Test func mergesContiguousPeakHoursIntoRange() {
        var records: [VehicleRecord] = []
        records += weekdayEntries(hour: 8, count: 10)
        records += weekdayEntries(hour: 9, count: 10)
        records += weekdayEntries(hour: 13, count: 1)
        records += weekdayEntries(hour: 15, count: 1)
        records += weekdayEntries(hour: 17, count: 5)

        let schedule = HistoricDemandSchedule.build(from: records)
        #expect(schedule != nil)
        guard let schedule else { return }

        let mergedPeak = schedule.weekdayPeakRanges.first { $0.start == 8 }
        #expect(mergedPeak != nil)
        #expect(mergedPeak?.end == 10) // half-open: covers hours 8 and 9.
    }

    /// Weekday and weekend buckets are classified independently. Each bucket
    /// needs ≥20 entries for `build` to invoke the classifier.
    @Test func separatesWeekdayAndWeekendBuckets() {
        var records: [VehicleRecord] = []
        records += weekdayEntries(hour: 8, count: 15)
        records += weekdayEntries(hour: 12, count: 1)
        records += weekdayEntries(hour: 14, count: 1)
        records += weekdayEntries(hour: 16, count: 5)

        records += weekendEntries(hour: 11, count: 15)
        records += weekendEntries(hour: 15, count: 1)
        records += weekendEntries(hour: 17, count: 1)
        records += weekendEntries(hour: 19, count: 5)

        let schedule = HistoricDemandSchedule.build(from: records)
        #expect(schedule != nil)
        guard let schedule else { return }

        #expect(schedule.weekdayPeakRanges.contains { $0.start <= 8 && 8 < $0.end })
        #expect(schedule.weekendPeakRanges.contains { $0.start <= 11 && 11 < $0.end })
        // Weekday peak should not include hour 11, weekend peak should not include hour 8.
        #expect(!schedule.weekdayPeakRanges.contains { $0.start <= 11 && 11 < $0.end })
        #expect(!schedule.weekendPeakRanges.contains { $0.start <= 8 && 8 < $0.end })
    }
}

// MARK: - Integration with PeakHoursSchedule

@Suite("PeakHoursSchedule with historic schedule")
struct PeakHoursScheduleWithHistoric {

    private func weekdayDate(hour: Int, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = weekdayYear
        comps.month = weekdayMonth
        comps.day = weekdayDay
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps)!
    }

    @Test func usesHistoricRangesWhenAvailable() {
        // Historic data peaks at hour 16 — different from the hardcoded 6–9 peak.
        var records: [VehicleRecord] = []
        records += weekdayEntries(hour: 16, count: 15)
        records += weekdayEntries(hour: 10, count: 1)
        records += weekdayEntries(hour: 12, count: 1)
        records += weekdayEntries(hour: 20, count: 4)

        let schedule = HistoricDemandSchedule.build(from: records)
        #expect(schedule != nil)

        // At 16:00, historic says peak; hardcoded would say normal.
        #expect(PeakHoursSchedule.demandLevel(at: weekdayDate(hour: 16), using: schedule) == .peak)
        // At 7:00, historic has no data → bucket has non-empty ranges (from
        // the 16h peak + 10h/12h valleys) so historic wins and returns normal.
        #expect(PeakHoursSchedule.demandLevel(at: weekdayDate(hour: 7), using: schedule) == .normal)
    }

    @Test func fallsBackToHardcodedWhenScheduleIsNil() {
        // nil schedule → hardcoded weekday peak 6–9 applies.
        #expect(PeakHoursSchedule.demandLevel(at: weekdayDate(hour: 7), using: nil) == .peak)
        #expect(PeakHoursSchedule.demandLevel(at: weekdayDate(hour: 13), using: nil) == .valley)
    }

    @Test func transitionCountdownUsesHistoricRanges() {
        var records: [VehicleRecord] = []
        records += weekdayEntries(hour: 16, count: 15)
        records += weekdayEntries(hour: 10, count: 1)
        records += weekdayEntries(hour: 12, count: 1)
        records += weekdayEntries(hour: 20, count: 4)

        let schedule = HistoricDemandSchedule.build(from: records)
        let countdown = PeakHoursSchedule.transitionCountdown(
            at: weekdayDate(hour: 16, minute: 30),
            openingHour: 6,
            closingHour: 22,
            using: schedule
        )
        #expect(countdown != nil)
        // We're inside the historic peak at 16 — countdown must reference
        // exit from peak, not closing.
        #expect(countdown?.contains("normal") == true)
    }
}
