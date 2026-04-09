//
//  ParkingTimeStatusTests.swift
//  sd-smart-parkingTests
//

import Foundation
import Testing
@testable import sd_smart_parking

// MARK: - Helpers

/// April 9, 2026 = Thursday (weekday)
private func makeDate(hour: Int, minute: Int = 0) -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 4
    components.day = 9
    components.hour = hour
    components.minute = minute
    return Calendar.current.date(from: components)!
}

/// April 4, 2026 = Saturday (weekend)
private func makeWeekendDate(hour: Int, minute: Int = 0) -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 4
    components.day = 4
    components.hour = hour
    components.minute = minute
    return Calendar.current.date(from: components)!
}

// MARK: - DemandLevel Tests (Weekday)

@Suite("DemandLevel")
struct DemandLevelTests {

    @Test func peakAt0600() {
        #expect(PeakHoursSchedule.demandLevel(at: makeDate(hour: 6)) == .peak)
    }

    @Test func peakAt0830() {
        #expect(PeakHoursSchedule.demandLevel(at: makeDate(hour: 8, minute: 30)) == .peak)
    }

    @Test func peakEndsAt0900() {
        #expect(PeakHoursSchedule.demandLevel(at: makeDate(hour: 9)) == .normal)
    }

    @Test func valleyAt1200() {
        #expect(PeakHoursSchedule.demandLevel(at: makeDate(hour: 12)) == .valley)
    }

    @Test func valleyAt1430() {
        #expect(PeakHoursSchedule.demandLevel(at: makeDate(hour: 14, minute: 30)) == .valley)
    }

    @Test func valleyEndsAt1500() {
        #expect(PeakHoursSchedule.demandLevel(at: makeDate(hour: 15)) == .normal)
    }

    @Test func normalAt1000() {
        #expect(PeakHoursSchedule.demandLevel(at: makeDate(hour: 10)) == .normal)
    }

    @Test func normalAt2000() {
        #expect(PeakHoursSchedule.demandLevel(at: makeDate(hour: 20)) == .normal)
    }

    @Test func normalAt0500() {
        #expect(PeakHoursSchedule.demandLevel(at: makeDate(hour: 5)) == .normal)
    }
}

// MARK: - DemandLevel Tests (Weekend)

@Suite("DemandLevelWeekend")
struct DemandLevelWeekendTests {

    @Test func weekendIsDetected() {
        #expect(PeakHoursSchedule.isWeekend(at: makeWeekendDate(hour: 12)))
    }

    @Test func weekdayIsNotWeekend() {
        #expect(!PeakHoursSchedule.isWeekend(at: makeDate(hour: 12)))
    }

    @Test func weekendMorningIsValley() {
        #expect(PeakHoursSchedule.demandLevel(at: makeWeekendDate(hour: 7)) == .valley)
    }

    @Test func weekendPeakHourIsValleyInstead() {
        #expect(PeakHoursSchedule.demandLevel(at: makeWeekendDate(hour: 8)) == .valley)
    }

    @Test func weekendAfternoonIsValley() {
        #expect(PeakHoursSchedule.demandLevel(at: makeWeekendDate(hour: 14)) == .valley)
    }

    @Test func weekendEveningIsValley() {
        #expect(PeakHoursSchedule.demandLevel(at: makeWeekendDate(hour: 20)) == .valley)
    }

    @Test func weekendOutsideHoursIsNormal() {
        #expect(PeakHoursSchedule.demandLevel(at: makeWeekendDate(hour: 3)) == .normal)
    }
}

// MARK: - OperatingStatus Tests

@Suite("OperatingStatus")
struct OperatingStatusTests {

    @Test func closedAt0300() {
        let status = PeakHoursSchedule.operatingStatus(at: makeDate(hour: 3), openingHour: 6, closingHour: 22)
        #expect(status == .closed(opensAt: 6))
    }

    @Test func closedAt2300() {
        let status = PeakHoursSchedule.operatingStatus(at: makeDate(hour: 23), openingHour: 6, closingHour: 22)
        #expect(status == .closed(opensAt: 6))
    }

    @Test func closedExactlyAtClosing() {
        let status = PeakHoursSchedule.operatingStatus(at: makeDate(hour: 22), openingHour: 6, closingHour: 22)
        #expect(status == .closed(opensAt: 6))
    }

    @Test func openAt0600() {
        let status = PeakHoursSchedule.operatingStatus(at: makeDate(hour: 6), openingHour: 6, closingHour: 22)
        #expect(status == .open)
    }

    @Test func openAt1200() {
        let status = PeakHoursSchedule.operatingStatus(at: makeDate(hour: 12), openingHour: 6, closingHour: 22)
        #expect(status == .open)
    }

    @Test func closingSoonAt2135() {
        let status = PeakHoursSchedule.operatingStatus(at: makeDate(hour: 21, minute: 35), openingHour: 6, closingHour: 22)
        #expect(status == .closingSoon(minutesLeft: 25))
    }

    @Test func closingSoonAt2145() {
        let status = PeakHoursSchedule.operatingStatus(at: makeDate(hour: 21, minute: 45), openingHour: 6, closingHour: 22)
        #expect(status == .closingSoon(minutesLeft: 15))
    }

    @Test func notClosingSoonAt2100() {
        let status = PeakHoursSchedule.operatingStatus(at: makeDate(hour: 21), openingHour: 6, closingHour: 22)
        #expect(status == .open)
    }

    @Test func closingSoonEdgeAt2130() {
        let status = PeakHoursSchedule.operatingStatus(at: makeDate(hour: 21, minute: 30), openingHour: 6, closingHour: 22)
        #expect(status == .closingSoon(minutesLeft: 30))
    }
}

// MARK: - Custom Hours Tests

@Suite("OperatingStatusCustomHours")
struct OperatingStatusCustomHoursTests {

    @Test func customHoursOpen() {
        let status = PeakHoursSchedule.operatingStatus(at: makeDate(hour: 8), openingHour: 8, closingHour: 20)
        #expect(status == .open)
    }

    @Test func customHoursClosed() {
        let status = PeakHoursSchedule.operatingStatus(at: makeDate(hour: 7), openingHour: 8, closingHour: 20)
        #expect(status == .closed(opensAt: 8))
    }

    @Test func customHoursClosingSoon() {
        let status = PeakHoursSchedule.operatingStatus(at: makeDate(hour: 19, minute: 35), openingHour: 8, closingHour: 20)
        #expect(status == .closingSoon(minutesLeft: 25))
    }
}

// MARK: - Transition Countdown Tests

@Suite("TransitionCountdown")
struct TransitionCountdownTests {

    @Test func peakShowsCountdownToNormal() {
        let result = PeakHoursSchedule.transitionCountdown(
            at: makeDate(hour: 7, minute: 30), openingHour: 6, closingHour: 22
        )
        #expect(result == "1h 30m para horario normal")
    }

    @Test func valleyShowsCountdownToNormal() {
        let result = PeakHoursSchedule.transitionCountdown(
            at: makeDate(hour: 13), openingHour: 6, closingHour: 22
        )
        #expect(result == "2h 0m para horario normal")
    }

    @Test func normalShowsNextValley() {
        let result = PeakHoursSchedule.transitionCountdown(
            at: makeDate(hour: 10), openingHour: 6, closingHour: 22
        )
        #expect(result == "2h 0m para horas valle")
    }

    @Test func normalShowsClosingWhenNoMoreTransitions() {
        let result = PeakHoursSchedule.transitionCountdown(
            at: makeDate(hour: 16), openingHour: 6, closingHour: 22
        )
        #expect(result == "6h 0m para cierre")
    }

    @Test func weekendValleyShowsClosingCountdown() {
        let result = PeakHoursSchedule.transitionCountdown(
            at: makeWeekendDate(hour: 10), openingHour: 6, closingHour: 22
        )
        #expect(result == "12h 0m para cierre")
    }

    @Test func closedReturnsNil() {
        let result = PeakHoursSchedule.transitionCountdown(
            at: makeDate(hour: 3), openingHour: 6, closingHour: 22
        )
        #expect(result == nil)
    }

    @Test func closingSoonReturnsNil() {
        let result = PeakHoursSchedule.transitionCountdown(
            at: makeDate(hour: 21, minute: 45), openingHour: 6, closingHour: 22
        )
        #expect(result == nil)
    }
}
