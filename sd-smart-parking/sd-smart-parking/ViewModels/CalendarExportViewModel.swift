//
//  CalendarExportViewModel.swift
//  sd-smart-parking
//

import Combine
import EventKit
import Foundation

// MARK: - Protocol for testing boundary

protocol CalendarEventStoring {
    func authorizationStatus(for entityType: EKEntityType) -> EKAuthorizationStatus
    func requestWriteOnlyAccessToEvents() async throws -> Bool
    func save(_ event: EKEvent, span: EKSpan, commit: Bool) throws
    func makeEvent() -> EKEvent
}

extension EKEventStore: CalendarEventStoring {
    func authorizationStatus(for entityType: EKEntityType) -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: entityType)
    }

    func makeEvent() -> EKEvent {
        let event = EKEvent(eventStore: self)
        event.calendar = self.defaultCalendarForNewEvents
        return event
    }
}

// MARK: - ViewModel

class CalendarExportViewModel: ObservableObject {
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""

    private let store: CalendarEventStoring

    init(store: CalendarEventStoring = EKEventStore()) {
        self.store = store
    }

    func exportEvent(record: VehicleRecord, parkingName: String, closingHour: Int) async {
        let status = store.authorizationStatus(for: .event)

        switch status {
        case .notDetermined:
            do {
                let granted = try await store.requestWriteOnlyAccessToEvents()
                if granted {
                    await saveEvent(record: record, parkingName: parkingName, closingHour: closingHour)
                } else {
                    await showDeniedAlert()
                }
            } catch {
                await showErrorAlert(error)
            }
        case .writeOnly, .fullAccess, .authorized:
            await saveEvent(record: record, parkingName: parkingName, closingHour: closingHour)
        case .denied, .restricted:
            await showDeniedAlert()
        @unknown default:
            await showDeniedAlert()
        }
    }

    // MARK: - Private

    private func saveEvent(record: VehicleRecord, parkingName: String, closingHour: Int) async {
        let event = store.makeEvent()
        event.title = "Parked at SD Building \u{2014} \(record.plate)"
        event.location = "\(parkingName), Universidad de los Andes"
        event.startDate = record.timestamp

        // End = min(start + 2h, closingHour on the same day)
        let calendar = Calendar.current
        let twoHoursLater = record.timestamp.addingTimeInterval(2 * 3600)
        let closingDate = calendar.date(bySettingHour: closingHour, minute: 0, second: 0, of: record.timestamp) ?? twoHoursLater
        event.endDate = min(twoHoursLater, closingDate)

        do {
            try store.save(event, span: .thisEvent, commit: true)
            await showSuccessAlert()
        } catch {
            await showErrorAlert(error)
        }
    }

    private func showSuccessAlert() async {
        await MainActor.run {
            alertTitle = "Event Added"
            alertMessage = "Your parking session was added to Calendar."
            showAlert = true
        }
    }

    private func showDeniedAlert() async {
        await MainActor.run {
            alertTitle = "Calendar Access Denied"
            alertMessage = "Enable calendar access in Settings to export parking events."
            showAlert = true
        }
    }

    private func showErrorAlert(_ error: Error) async {
        await MainActor.run {
            alertTitle = "Error"
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}
