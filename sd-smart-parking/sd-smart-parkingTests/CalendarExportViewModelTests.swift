//
//  CalendarExportViewModelTests.swift
//  sd-smart-parkingTests
//

import EventKit
import Foundation
import Testing
@testable import sd_smart_parking

// MARK: - Mock

private class MockCalendarEventStore: CalendarEventStoring {
    var statusToReturn: EKAuthorizationStatus = .notDetermined
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

// MARK: - Tests

@Suite("CalendarExportViewModel")
struct CalendarExportTests {

    private func makeRecord(plate: String = "ABC123", timestamp: Date = Date()) -> VehicleRecord {
        VehicleRecord(
            plate: plate,
            type: .entry,
            timestamp: timestamp,
            floor: 2,
            spotNumber: 5,
            photoURL: nil,
            isRegistered: true,
            ownerEmail: "test@uniandes.edu.co",
            ocrConfidence: 1.0
        )
    }

    @Test func exportEvent_whenAccessGranted_savesCorrectEvent() async {
        let mock = MockCalendarEventStore()
        mock.statusToReturn = .notDetermined
        mock.requestAccessResult = true
        let vm = CalendarExportViewModel(store: mock)
        let record = makeRecord(plate: "XYZ789")

        await vm.exportEvent(record: record, parkingName: "SD Building Parking", closingHour: 22)

        #expect(mock.savedEvent != nil)
        #expect(mock.savedEvent?.title?.contains("XYZ789") == true)
        #expect(mock.savedEvent?.location?.contains("SD Building Parking") == true)
        let delta = abs(mock.savedEvent!.startDate.timeIntervalSince(record.timestamp))
        #expect(delta < 1.0)
        #expect(vm.alertTitle == "Event Added")
    }

    @Test func exportEvent_whenAccessDenied_showsDenialAlert() async {
        let mock = MockCalendarEventStore()
        mock.statusToReturn = .notDetermined
        mock.requestAccessResult = false
        let vm = CalendarExportViewModel(store: mock)

        await vm.exportEvent(record: makeRecord(), parkingName: "SD", closingHour: 22)

        #expect(mock.savedEvent == nil)
        #expect(vm.alertTitle == "Calendar Access Denied")
    }

    @Test func exportEvent_whenSaveThrows_showsErrorAlert() async {
        let mock = MockCalendarEventStore()
        mock.statusToReturn = .writeOnly
        mock.saveError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Save failed"])
        let vm = CalendarExportViewModel(store: mock)

        await vm.exportEvent(record: makeRecord(), parkingName: "SD", closingHour: 22)

        #expect(vm.alertTitle == "Error")
        #expect(vm.alertMessage.contains("Save failed"))
    }

    @Test func exportEvent_endTime_cappedAtClosingHour() async {
        let mock = MockCalendarEventStore()
        mock.statusToReturn = .writeOnly
        let vm = CalendarExportViewModel(store: mock)

        // 21:00 + 2h = 23:00, but closing is 22:00 → end should be 22:00
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 21; comps.minute = 0; comps.second = 0
        let late = Calendar.current.date(from: comps)!
        let record = makeRecord(timestamp: late)

        await vm.exportEvent(record: record, parkingName: "SD", closingHour: 22)

        let expectedEnd = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: late)!
        #expect(mock.savedEvent?.endDate == expectedEnd)
    }

    @Test func exportEvent_endTime_usesDefault2Hours() async {
        let mock = MockCalendarEventStore()
        mock.statusToReturn = .writeOnly
        let vm = CalendarExportViewModel(store: mock)

        // 10:00 + 2h = 12:00, closing at 22:00 → end should be 12:00
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 10; comps.minute = 0; comps.second = 0
        let morning = Calendar.current.date(from: comps)!
        let record = makeRecord(timestamp: morning)

        await vm.exportEvent(record: record, parkingName: "SD", closingHour: 22)

        let expectedEnd = morning.addingTimeInterval(2 * 3600)
        #expect(mock.savedEvent?.endDate == expectedEnd)
    }
}
