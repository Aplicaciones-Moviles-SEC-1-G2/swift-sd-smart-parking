//
//  TripPlannerViewModelTests.swift
//  sd-smart-parkingTests
//

import Combine
import EventKit
import Foundation
import Testing
@testable import sd_smart_parking

// MARK: - Mock

private class MockCalendarStore: CalendarEventStoring {
    var statusToReturn: EKAuthorizationStatus = .writeOnly
    var requestAccessResult = true
    var requestAccessError: Error?
    var savedEvent: EKEvent?
    var saveError: Error?

    func authorizationStatus(for entityType: EKEntityType) -> EKAuthorizationStatus {
        statusToReturn
    }

    func requestWriteOnlyAccessToEvents() async throws -> Bool {
        if let error = requestAccessError { throw error }
        return requestAccessResult
    }

    func save(_ event: EKEvent, span: EKSpan, commit: Bool) throws {
        if let error = saveError { throw error }
        savedEvent = event
    }

    func makeEvent() -> EKEvent {
        EKEvent(eventStore: EKEventStore())
    }
}

// MARK: - Helpers

private func makeDate(hour: Int, minute: Int = 0, weekday: Int? = nil) -> Date {
    var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    comps.hour = hour
    comps.minute = minute
    comps.second = 0

    var date = Calendar.current.date(from: comps)!

    if let weekday {
        let current = Calendar.current.component(.weekday, from: date)
        let daysToAdd = (weekday - current + 7) % 7
        if daysToAdd > 0 {
            date = Calendar.current.date(byAdding: .day, value: daysToAdd, to: date)!
        }
    }
    return date
}

// MARK: - Cost Estimation

@Suite("TripPlannerCostEstimation")
struct TripPlannerCostTests {

    @Test func cost_1hour_returns2000() {
        let vm = TripPlannerViewModel(store: MockCalendarStore())
        vm.arrivalDate = makeDate(hour: 10)
        vm.leaveDate = makeDate(hour: 11)
        #expect(vm.estimatedCost() == 2000)
    }

    @Test func cost_halfHour_returns1000() {
        let vm = TripPlannerViewModel(store: MockCalendarStore())
        vm.arrivalDate = makeDate(hour: 10)
        vm.leaveDate = makeDate(hour: 10, minute: 30)
        #expect(vm.estimatedCost() == 1000)
    }

    @Test func cost_8hours_cappedAtDailyCap() {
        let vm = TripPlannerViewModel(store: MockCalendarStore())
        vm.arrivalDate = makeDate(hour: 10)
        vm.leaveDate = makeDate(hour: 18)
        #expect(vm.estimatedCost() == 16000)
    }
}

// MARK: - Validation

@Suite("TripPlannerValidation")
struct TripPlannerValidationTests {

    @Test func arrivalAt3AM_isInvalid() {
        let vm = TripPlannerViewModel(store: MockCalendarStore())
        vm.arrivalDate = makeDate(hour: 3)
        #expect(!vm.isArrivalValid(openingHour: 6, closingHour: 22))
        #expect(vm.validationError(openingHour: 6, closingHour: 22) != nil)
    }

    @Test func arrivalAt22_isInvalid() {
        let vm = TripPlannerViewModel(store: MockCalendarStore())
        vm.arrivalDate = makeDate(hour: 22)
        #expect(!vm.isArrivalValid(openingHour: 6, closingHour: 22))
    }

    @Test func arrivalAt10AM_isValid() {
        let vm = TripPlannerViewModel(store: MockCalendarStore())
        vm.arrivalDate = makeDate(hour: 10)
        vm.leaveDate = makeDate(hour: 12)
        #expect(vm.isArrivalValid(openingHour: 6, closingHour: 22))
        #expect(vm.validationError(openingHour: 6, closingHour: 22) == nil)
    }

    @Test func leaveBeforeArrival_isInvalid() {
        let vm = TripPlannerViewModel(store: MockCalendarStore())
        vm.arrivalDate = makeDate(hour: 14)
        vm.leaveDate = makeDate(hour: 12)
        #expect(vm.validationError(openingHour: 6, closingHour: 22) != nil)
    }

    @Test func clampLeaveDate_capsAtClosing() {
        let vm = TripPlannerViewModel(store: MockCalendarStore())
        vm.arrivalDate = makeDate(hour: 20)
        vm.leaveDate = makeDate(hour: 23) // past closing
        vm.clampLeaveDate(closingHour: 22)
        let leaveHour = Calendar.current.component(.hour, from: vm.leaveDate)
        #expect(leaveHour <= 22)
    }

    @Test func clampLeaveDate_pushesAfterArrival() {
        let vm = TripPlannerViewModel(store: MockCalendarStore())
        vm.arrivalDate = makeDate(hour: 15)
        vm.leaveDate = makeDate(hour: 14) // before arrival
        vm.clampLeaveDate(closingHour: 22)
        #expect(vm.leaveDate > vm.arrivalDate)
    }
}

// MARK: - Peak Detection

@Suite("TripPlannerPeakDetection")
struct TripPlannerPeakTests {

    @Test func weekdayAt7AM_isPeak() {
        let vm = TripPlannerViewModel(store: MockCalendarStore())
        vm.arrivalDate = makeDate(hour: 7, weekday: 2)
        #expect(vm.isPeak)
    }

    @Test func weekdayAt10AM_isNotPeak() {
        let vm = TripPlannerViewModel(store: MockCalendarStore())
        vm.arrivalDate = makeDate(hour: 10, weekday: 2)
        #expect(!vm.isPeak)
    }

    @Test func weekendAt8AM_isNotPeak() {
        let vm = TripPlannerViewModel(store: MockCalendarStore())
        vm.arrivalDate = makeDate(hour: 8, weekday: 7)
        #expect(!vm.isPeak)
    }
}

// MARK: - Calendar Export

@Suite("TripPlannerCalendarExport")
struct TripPlannerExportTests {

    @Test func exportTrip_savesCorrectEvent() async {
        let mock = MockCalendarStore()
        mock.statusToReturn = .writeOnly
        let vm = TripPlannerViewModel(store: mock)
        vm.arrivalDate = makeDate(hour: 10)
        vm.leaveDate = makeDate(hour: 12)

        await vm.exportTrip(parkingName: "SD Building Parking", closingHour: 22)

        #expect(mock.savedEvent != nil)
        #expect(mock.savedEvent?.title?.contains("Planned Trip") == true)
        #expect(mock.savedEvent?.location?.contains("SD Building Parking") == true)
        #expect(mock.savedEvent?.notes?.contains("COP") == true)
        #expect(vm.alertTitle == "Event Added")
        #expect(vm.didExport)
    }

    @Test func exportTrip_denied_showsAlert() async {
        let mock = MockCalendarStore()
        mock.statusToReturn = .denied
        let vm = TripPlannerViewModel(store: mock)

        await vm.exportTrip(parkingName: "SD", closingHour: 22)

        #expect(mock.savedEvent == nil)
        #expect(vm.alertTitle == "Calendar Access Denied")
    }

    @Test func consecutiveExports_dipDidExportThroughFalse() async {
        // Regression guard: TripPlannerSheetView listens via
        // `.onChange(of: tripVM.didExport)` and only inserts a SavedTripPlan
        // when the flag transitions false → true. If `exportTrip` does not
        // reset the flag at the top, the second consecutive Add-to-Calendar
        // tap silently drops the SwiftData write.
        let mock = MockCalendarStore()
        mock.statusToReturn = .writeOnly
        let vm = TripPlannerViewModel(store: mock)
        vm.arrivalDate = makeDate(hour: 10)
        vm.leaveDate = makeDate(hour: 12)

        await vm.exportTrip(parkingName: "X", closingHour: 22)
        #expect(vm.didExport)

        var emissions: [Bool] = []
        let cancellable = vm.$didExport.sink { emissions.append($0) }

        await vm.exportTrip(parkingName: "X", closingHour: 22)
        cancellable.cancel()

        // Initial replay of `true`, then `false` from the reset at the top
        // of exportTrip, then `true` again when saveTrip completes.
        #expect(emissions.first == true)
        #expect(emissions.contains(false))
        #expect(emissions.last == true)
    }
}
