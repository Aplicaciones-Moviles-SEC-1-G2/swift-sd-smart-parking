//
//  ConfigurationView.swift
//  ParkingApp
//
//  Created by Mateo on 27/02/26.
//
// ConfigurationView.swift
import SwiftUI

struct ConfigurationView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var settings = ParkingConfig()
    @State private var showSaveConfirmation = false
    @StateObject var userRepo = UserRepository()
    var body: some View {
        NavigationStack {
            List {

                // MARK: - Header del Gerente
                Section {
                    HStack(spacing: 15) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.gradient)
                                .frame(width: 60, height: 60)

                            Image(systemName: "person.badge.key.fill")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(authVM.currentUserEmail ?? "Manager")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text("Manager")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - Parking Settings
                Section {
                    LabeledContent("Parking Name") {
                        TextField("Name", text: $settings.parkingName)
                            .multilineTextAlignment(.trailing)
                    }

                    Stepper("Floors: \(settings.numberOfFloors)", value: $settings.numberOfFloors, in: 1...10)

                    Stepper("Spots per Floor: \(settings.spotsPerFloor)", value: $settings.spotsPerFloor, in: 1...100)

                } header: {
                    Label("Parking", systemImage: "building.2.fill")
                }

                // MARK: - Pricing
                Section {
                    LabeledContent("Hourly Rate") {
                        HStack {
                            Text("COP")
                                .foregroundColor(.secondary)
                            TextField("Rate", value: $settings.hourlyRate, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                        }
                    }

                    LabeledContent("Daily Cap") {
                        HStack {
                            Text("COP")
                                .foregroundColor(.secondary)
                            Text(ParkingConfig.dailyCap.formatted(.number))
                                .foregroundColor(.secondary)
                        }
                    }

                } header: {
                    Label("Pricing", systemImage: "dollarsign.circle.fill")
                } footer: {
                    Text("The daily cap is fixed at COP 16,000 per vehicle.")
                }

                // MARK: - OCR Settings
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Confidence Threshold")
                            Spacer()
                            Text("\(Int(settings.ocrConfidenceThreshold * 100))%")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $settings.ocrConfidenceThreshold, in: 0.5...0.95, step: 0.05)
                            .tint(.blue)
                    }
                } header: {
                    Label("Camera & OCR", systemImage: "camera.fill")
                } footer: {
                    Text("Records below this threshold will be flagged for manual review.")
                }

                // MARK: - Operating Hours
                Section {
                    Stepper("Opening: \(settings.openingHour):00", value: $settings.openingHour, in: 0...settings.closingHour - 1)
                    Stepper("Closing: \(settings.closingHour):00", value: $settings.closingHour, in: settings.openingHour + 1...23)
                } header: {
                    Label("Operating Hours", systemImage: "clock.fill")
                }

                // MARK: - Logout
                Button(role: .destructive) {
                    authVM.signOut(userRepo: userRepo)
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                    }
                }
            }
            .navigationTitle("Configuration")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { await settings.save() }
                        showSaveConfirmation = true
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Settings Saved", isPresented: $showSaveConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your changes have been applied successfully.")
            }
        }
    }
}

#Preview {
    ConfigurationView()
        .environmentObject(AuthViewModel())
}
