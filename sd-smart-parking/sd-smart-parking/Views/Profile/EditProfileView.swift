//
//  EditProfileView.swift
//  ParkingApp
//
//  Created by Mateo on 25/02/26.
//
import SwiftUI

struct EditProfileView: View {
    // 1. Inyectamos el Repositorio
    @EnvironmentObject var userRepo: UserRepository
    @EnvironmentObject var parkingVM: ParkingViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var email: String = ""

    // Parking preferences (mirrors UserPreferences)
    @State private var hasMobilityLimitation: Bool = false
    @State private var preferredFloor: Int? = nil

    /// Local-only display toggle persisted via UserDefaults. `diego.` prefix
    /// keeps the namespace separate from teammate keys (e.g. biometricsEnabled).
    @AppStorage("diego.profile.showDemandBadgeOnDashboard") private var showDemandBadge: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal information") {
                    TextField("Name", text: $name)
                    TextField("E-mail", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }

                PreferencesSection(
                    hasMobilityLimitation: $hasMobilityLimitation,
                    preferredFloor: $preferredFloor,
                    availableFloors: availableFloors
                )

                Section("Display preferences") {
                    Toggle("Mostrar badge de demanda en Dashboard", isOn: $showDemandBadge)
                }
            }
            .navigationTitle("Edit Profile")
            .onAppear {
                // 2. Cargamos los datos desde el repositorio
                if let user = userRepo.currentUser {
                    name = user.name
                    email = user.email
                    hasMobilityLimitation = user.preferences?.hasMobilityLimitation ?? false
                    preferredFloor = user.preferences?.preferredFloor
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // 3. Llamada al Repositorio (maneja lógica offline/online)
                        userRepo.updateProfile(newName: name, newEmail: email)
                        userRepo.updatePreferences(
                            UserPreferences(
                                hasMobilityLimitation: hasMobilityLimitation,
                                preferredFloor: preferredFloor
                            )
                        )
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }

    private var availableFloors: [Int] {
        let configured = max(1, parkingVM.config.numberOfFloors)
        return Array(1...configured)
    }
}
