//
//  TripPlannerSheetView.swift
//  sd-smart-parking
//

import SwiftUI

struct TripPlannerSheetView: View {
    @StateObject private var tripVM = TripPlannerViewModel()
    @EnvironmentObject var config: ParkingConfig
    @Environment(\.dismiss) private var dismiss

    private var validationError: String? {
        tripVM.validationError(openingHour: config.openingHour, closingHour: config.closingHour)
    }

    var body: some View {
        NavigationStack {
            Form {
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
                    HStack {
                        Text("COP")
                            .foregroundColor(.secondary)
                        Text("\(Int(tripVM.estimatedCost()))")
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
        }
    }
}

#Preview {
    TripPlannerSheetView()
        .environmentObject(ParkingConfig())
}
