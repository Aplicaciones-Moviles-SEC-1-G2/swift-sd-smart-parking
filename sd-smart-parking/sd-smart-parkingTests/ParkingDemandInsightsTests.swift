//
//  ParkingDemandInsightsTests.swift
//  sd-smart-parkingTests
//

import Foundation
import Testing
@testable import sd_smart_parking

private let weekdayRef = DateComponents(year: 2026, month: 4, day: 9) // Thursday
private let weekendRef = DateComponents(year: 2026, month: 4, day: 4) // Saturday

private func makeRecord(
    type: RecordType,
    on base: DateComponents,
    hour: Int
) -> VehicleRecord {
    var comps = base
    comps.hour = hour
    let date = Calendar.current.date(from: comps)!
    return VehicleRecord(
        id: UUID().uuidString,
        plate: "ABC123",
        type: type,
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

private func weekdayRecords(type: RecordType, hour: Int, count: Int) -> [VehicleRecord] {
    (0..<count).map { _ in makeRecord(type: type, on: weekdayRef, hour: hour) }
}

private func weekendRecords(type: RecordType, hour: Int, count: Int) -> [VehicleRecord] {
    (0..<count).map { _ in makeRecord(type: type, on: weekendRef, hour: hour) }
}

@Suite("ParkingDemandInsights histogram")
struct ParkingDemandInsightsHistogram {

    @Test func buildsEmptyHistogramsFromEmptyInput() {
        let insights = ParkingDemandInsights.build(from: [])
        #expect(insights.totalEntries == 0)
        #expect(insights.totalExits == 0)
        #expect(insights.weekdayEntryCounts.count == 24)
        #expect(insights.weekdayEntryCounts.allSatisfy { $0.count == 0 })
        #expect(insights.weekendExitCounts.count == 24)
    }

    @Test func countsEntriesAndExitsIntoCorrectBuckets() {
        var records: [VehicleRecord] = []
        records += weekdayRecords(type: .entry, hour: 8, count: 3)
        records += weekdayRecords(type: .exit, hour: 17, count: 2)
        records += weekendRecords(type: .entry, hour: 11, count: 4)
        records += weekendRecords(type: .exit, hour: 15, count: 1)

        let insights = ParkingDemandInsights.build(from: records)
        #expect(insights.totalEntries == 7)
        #expect(insights.totalExits == 3)
        #expect(insights.weekdayEntryCounts.first { $0.hour == 8 }?.count == 3)
        #expect(insights.weekdayExitCounts.first { $0.hour == 17 }?.count == 2)
        #expect(insights.weekendEntryCounts.first { $0.hour == 11 }?.count == 4)
        #expect(insights.weekendExitCounts.first { $0.hour == 15 }?.count == 1)
        // Cross-bucket contamination check:
        #expect(insights.weekendEntryCounts.first { $0.hour == 8 }?.count == 0)
        #expect(insights.weekdayEntryCounts.first { $0.hour == 11 }?.count == 0)
    }
}

@Suite("ParkingDemandInsights recommendations")
struct ParkingDemandInsightsRecommendations {

    @Test func recommendsHoursWithFewestEntriesInOperatingWindow() {
        var records: [VehicleRecord] = []
        records += weekdayRecords(type: .entry, hour: 8, count: 10)   // busiest
        records += weekdayRecords(type: .entry, hour: 9, count: 2)
        records += weekdayRecords(type: .entry, hour: 11, count: 1)   // quietest w/ evidence
        records += weekdayRecords(type: .entry, hour: 17, count: 3)
        // Hours with 0 recorded entries are ambiguous (quiet vs. unobserved)
        // and must be excluded from recommendations.

        let insights = ParkingDemandInsights.build(from: records)
        let best = insights.bestEntryHours(weekend: false, openingHour: 6, closingHour: 22, topN: 2)
        #expect(best.count == 2)
        #expect(best.first?.hour == 11)
        #expect(best.allSatisfy { $0.count > 0 })
        #expect(best.allSatisfy { (6..<22).contains($0.hour) })
    }

    @Test func recommendsHoursWithFewestExits() {
        var records: [VehicleRecord] = []
        records += weekdayRecords(type: .exit, hour: 17, count: 10)
        records += weekdayRecords(type: .exit, hour: 18, count: 5)
        records += weekdayRecords(type: .exit, hour: 13, count: 1)

        let insights = ParkingDemandInsights.build(from: records)
        let best = insights.bestExitHours(weekend: false, openingHour: 6, closingHour: 22, topN: 1)
        #expect(best.first?.hour == 13)
        #expect(best.first?.count == 1)
    }

    @Test func excludesHoursWithNoRecordedActivity() {
        // 12 weekday entries all clustered in one hour: enough to clear the
        // sample floor, but only one evidence-backed hour to recommend.
        let records = weekdayRecords(type: .entry, hour: 14, count: 12)
        let insights = ParkingDemandInsights.build(from: records)
        let best = insights.bestEntryHours(weekend: false, openingHour: 6, closingHour: 22, topN: 3)
        #expect(best.count == 1)
        #expect(best.first?.hour == 14)
    }

    @Test func emptyWhenBelowMinSampleForRecommendation() {
        // Only 5 entries — below the 10-sample floor.
        let records = weekdayRecords(type: .entry, hour: 8, count: 5)
        let insights = ParkingDemandInsights.build(from: records)
        #expect(insights.bestEntryHours(weekend: false, openingHour: 6, closingHour: 22).isEmpty)
    }

    @Test func bucketsAreIsolated() {
        var records: [VehicleRecord] = []
        records += weekdayRecords(type: .entry, hour: 8, count: 15)
        // Weekend bucket has nothing — recommendation must be empty for it.
        let insights = ParkingDemandInsights.build(from: records)
        #expect(insights.bestEntryHours(weekend: true, openingHour: 6, closingHour: 22).isEmpty)
        #expect(!insights.bestEntryHours(weekend: false, openingHour: 6, closingHour: 22).isEmpty)
    }
}
