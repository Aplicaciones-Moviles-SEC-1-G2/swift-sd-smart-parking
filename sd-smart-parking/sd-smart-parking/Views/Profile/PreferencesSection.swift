//
//  PreferencesSection.swift
//  sd-smart-parking
//

import SwiftUI

/// Form section that lets a driver declare a mobility limitation and pick a
/// preferred floor. Designed to be embedded inside a `Form` (e.g. EditProfileView).
struct PreferencesSection: View {
    @Binding var hasMobilityLimitation: Bool
    @Binding var preferredFloor: Int?
    let availableFloors: [Int]

    var body: some View {
        Section {
            Toggle(isOn: $hasMobilityLimitation) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Mobility-friendly recommendations", systemImage: "figure.roll")
                        .font(.body)
                    Text("Suggest the spot closest to the elevator on the lowest available floor.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Picker(selection: preferredFloorBinding) {
                Text("No preference").tag(Int?.none)
                ForEach(availableFloors, id: \.self) { floor in
                    Text("Floor \(floor)").tag(Int?.some(floor))
                }
            } label: {
                Label("Preferred floor", systemImage: "building.2.fill")
            }

            if hasMobilityLimitation, preferredFloor != nil {
                Label(
                    "Your preferred floor takes priority — we'll pick the spot closest to the elevator on that floor. If it's full, we'll fall back to the lowest available floor.",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }
        } header: {
            Text("Parking preferences")
        } footer: {
            Text("Used by the Spots tab to personalize the recommended floor.")
        }
    }

    /// Bridges the optional binding into the Picker (the Picker tag accepts
    /// `Int?` directly thanks to the explicit tag types above).
    private var preferredFloorBinding: Binding<Int?> {
        Binding(
            get: { preferredFloor },
            set: { preferredFloor = $0 }
        )
    }
}

#Preview {
    @Previewable @State var mobility = false
    @Previewable @State var floor: Int? = nil
    return Form {
        PreferencesSection(
            hasMobilityLimitation: $mobility,
            preferredFloor: $floor,
            availableFloors: [1, 2, 3]
        )
    }
}
