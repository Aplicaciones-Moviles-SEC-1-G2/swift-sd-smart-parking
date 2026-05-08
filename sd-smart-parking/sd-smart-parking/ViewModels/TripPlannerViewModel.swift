//
//  TripPlannerViewModel.swift
//  sd-smart-parking
//

import Combine
import EventKit
import Foundation

class TripPlannerViewModel: ObservableObject {
    @Published var arrivalDate: Date
    @Published var leaveDate: Date
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    @Published var didExport = false

    private let store: CalendarEventStoring

    /// Capacity = 5: a typical user explores 2-3 alternative arrival/duration
    /// combinations before locking in a plan. 5 leaves headroom without
    /// holding stale entries forever.
    private let costCache = LRUCache<TripCacheKey, Double>(capacity: 5)

    init(store: CalendarEventStoring = EKEventStore()) {
        self.store = store
        let calendar = Calendar.current
        let now = Date()
        let nextHour = calendar.date(byAdding: .hour, value: 1, to: now)!
        let arrival = calendar.date(bySetting: .minute, value: 0, of: nextHour) ?? nextHour
        self.arrivalDate = arrival
        self.leaveDate = arrival.addingTimeInterval(3600) // +1h default
    }

    // MARK: - Computed

    var durationHours: Double {
        max(leaveDate.timeIntervalSince(arrivalDate) / 3600, 0)
    }

    var demandLevel: DemandLevel {
        PeakHoursSchedule.demandLevel(at: arrivalDate)
    }

    var isPeak: Bool {
        demandLevel == .peak
    }

    func arrivalCountdown(openingHour: Int, closingHour: Int) -> String? {
        PeakHoursSchedule.transitionCountdown(at: arrivalDate, openingHour: openingHour, closingHour: closingHour)
    }

    // MARK: - Validation

    func isArrivalValid(openingHour: Int, closingHour: Int) -> Bool {
        let hour = Calendar.current.component(.hour, from: arrivalDate)
        return hour >= openingHour && hour < closingHour
    }

    func maxLeaveDate(closingHour: Int) -> Date {
        Calendar.current.date(bySettingHour: closingHour, minute: 0, second: 0, of: arrivalDate)
            ?? arrivalDate.addingTimeInterval(3600)
    }

    func validationError(openingHour: Int, closingHour: Int) -> String? {
        let hour = Calendar.current.component(.hour, from: arrivalDate)
        if hour < openingHour {
            return "Parking opens at \(openingHour):00"
        }
        if hour >= closingHour {
            return "Parking closes at \(closingHour):00"
        }
        if leaveDate <= arrivalDate {
            return "Leave time must be after arrival"
        }
        let leaveHour = Calendar.current.component(.hour, from: leaveDate)
        let leaveMinute = Calendar.current.component(.minute, from: leaveDate)
        if leaveHour > closingHour || (leaveHour == closingHour && leaveMinute > 0) {
            return "Parking closes at \(closingHour):00"
        }
        return nil
    }

    func clampLeaveDate(closingHour: Int) {
        // Keep leave after arrival
        if leaveDate <= arrivalDate {
            leaveDate = arrivalDate.addingTimeInterval(3600)
        }
        // Cap at closing
        let maxLeave = maxLeaveDate(closingHour: closingHour)
        if leaveDate > maxLeave {
            leaveDate = maxLeave
        }
    }

    // MARK: - Cost

    func estimatedCost() -> Double {
        let key = TripCacheKey(arrivalDate: arrivalDate, durationHours: durationHours)
        if let cached = costCache.get(key) { return cached }
        let cost = ParkingConfig.calculateFee(hours: durationHours, currentDayTotal: 0)
        costCache.put(cost, for: key)
        return cost
    }

    // MARK: - SwiftData Hand-off

    /// Pure value snapshot the SwiftUI layer turns into a `SavedTripPlan`
    /// (a SwiftData @Model). Keeping this VM free of SwiftData types means
    /// the @Model never crosses out of MainActor.
    func makeExportSnapshot(parkingName: String) -> TripExportSnapshot {
        TripExportSnapshot(
            arrivalDate: arrivalDate,
            leaveDate: leaveDate,
            parkingName: parkingName,
            estimatedCostCOP: estimatedCost(),
            wasExportedToCalendar: didExport
        )
    }

    // MARK: - Calendar Export

    func exportTrip(parkingName: String, closingHour: Int) async {
        // Reset the one-shot event flag so `.onChange(of: tripVM.didExport)` in
        // TripPlannerSheetView fires on every successful export. Without this,
        // a second consecutive Add-to-Calendar tap would not insert another
        // SavedTripPlan because `.onChange(of:)` only fires on transitions.
        await MainActor.run { didExport = false }

        let status = store.authorizationStatus(for: .event)

        switch status {
        case .notDetermined:
            do {
                let granted = try await store.requestWriteOnlyAccessToEvents()
                if granted {
                    await saveTrip(parkingName: parkingName, closingHour: closingHour)
                } else {
                    await showDeniedAlert()
                }
            } catch {
                await showErrorAlert(error)
            }
        case .writeOnly, .fullAccess, .authorized:
            await saveTrip(parkingName: parkingName, closingHour: closingHour)
        case .denied, .restricted:
            await showDeniedAlert()
        @unknown default:
            await showDeniedAlert()
        }
    }

    // MARK: - Private

    private func saveTrip(parkingName: String, closingHour: Int) async {
        let event = store.makeEvent()
        event.title = "Planned Trip \u{2014} SD Building Parking"
        event.location = "\(parkingName), Universidad de los Andes"
        event.startDate = arrivalDate

        let closingDate = Calendar.current.date(bySettingHour: closingHour, minute: 0, second: 0, of: arrivalDate) ?? leaveDate
        event.endDate = min(leaveDate, closingDate)

        let cost = estimatedCost()
        event.notes = "Estimated cost: COP \(Int(cost))"

        do {
            try store.save(event, span: .thisEvent, commit: true)
            await MainActor.run {
                alertTitle = "Event Added"
                alertMessage = "Your planned trip was added to Calendar."
                showAlert = true
                didExport = true
            }
        } catch {
            await showErrorAlert(error)
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
