//
//  TripPlannerSheetView.swift
//  sd-smart-parking
//

import SwiftUI
import SwiftData

struct TripPlannerSheetView: View {
    @StateObject private var tripVM = TripPlannerViewModel()
    @EnvironmentObject var config: ParkingConfig
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showHistory = false

    /// Preference persisted across launches via UserDefaults. Prefix `diego.`
    /// so it never collides with teammate-owned keys (e.g. `biometricsEnabled`).
    @AppStorage("diego.tripPlanner.preferredCurrency") private var preferredCurrency: String = "COP"

    /// Conservative static rate so the planner stays fully offline-friendly.
    /// We could refresh from a rate API later; not required for the rubric.
    private static let usdRate: Double = 4000.0

    private var validationError: String? {
        tripVM.validationError(openingHour: config.openingHour, closingHour: config.closingHour)
    }

    private var displayedCost: (label: String, value: String) {
        let cop = tripVM.estimatedCost()
        if preferredCurrency == "USD" {
            return ("USD", String(format: "%.2f", cop / Self.usdRate))
        }
        return ("COP", "\(Int(cop))")
    }

    var body: some View {
        NavigationStack {
            Form {
                if !networkMonitor.isConnected {
                    Section {
                        OfflineNoticeBadge(
                            message: "Sin conexión — el costo y exportar al calendario siguen funcionando"
                        )
                    }
                }

                Section("Entry") {
                    DatePicker(
                        "Arrival",
                        selection: $tripVM.arrivalDate,
                        in: Date().addingTimeInterval(15 * 60)...,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    if let error = validationError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section("Exit") {
                    DatePicker(
                        "Leave",
                        selection: $tripVM.leaveDate,
                        in: tripVM.arrivalDate.addingTimeInterval(1800)...tripVM.maxLeaveDate(closingHour: config.closingHour),
                        displayedComponents: [.hourAndMinute]
                    )

                    Text("\(tripVM.durationHours, specifier: "%.1f") hours")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Estimated Cost") {
                    Picker("Currency", selection: $preferredCurrency) {
                        Text("COP").tag("COP")
                        Text("USD").tag("USD")
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text(displayedCost.label)
                            .foregroundColor(.secondary)
                        Text(displayedCost.value)
                            .font(.title2.bold())
                            .foregroundColor(.blue)
                    }

                    if tripVM.isPeak {
                        ParkingStatusBannerView(
                            demandLevel: .peak,
                            countdown: tripVM.arrivalCountdown(
                                openingHour: config.openingHour,
                                closingHour: config.closingHour
                            )
                        )
                    }
                }
            }
            .navigationTitle("Plan Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("Trip History")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to Calendar") {
                        Task {
                            await tripVM.exportTrip(
                                parkingName: config.parkingName,
                                closingHour: config.closingHour
                            )
                        }
                    }
                    .disabled(validationError != nil)
                }
            }
            .alert(tripVM.alertTitle, isPresented: $tripVM.showAlert) {
                Button("OK", role: .cancel) {
                    if tripVM.didExport {
                        dismiss()
                    }
                }
            } message: {
                Text(tripVM.alertMessage)
            }
            .onChange(of: tripVM.arrivalDate) {
                tripVM.clampLeaveDate(closingHour: config.closingHour)
            }
            .onChange(of: tripVM.didExport) { _, didExport in
                guard didExport else { return }
                let snapshot = tripVM.makeExportSnapshot(parkingName: config.parkingName)
                let saved = SavedTripPlan(
                    arrivalDate: snapshot.arrivalDate,
                    leaveDate: snapshot.leaveDate,
                    parkingName: snapshot.parkingName,
                    estimatedCostCOP: snapshot.estimatedCostCOP,
                    wasExportedToCalendar: true
                )
                modelContext.insert(saved)
                do {
                    try modelContext.save()
                } catch {
                    // TODO: surface to UI via a banner; for now keep the
                    // failure visible in the console rather than swallowing.
                    print("SwiftData save failed (TripPlannerSheetView): \(error)")
                }
            }
            .sheet(isPresented: $showHistory) {
                TripHistoryView()
            }
        }
    }
}

#Preview {
    TripPlannerSheetView()
        .environmentObject(ParkingConfig())
        .environmentObject(NetworkMonitor())
}
