//
//  ParkingClosedCardView.swift
//  sd-smart-parking
//

import SwiftUI

struct ParkingClosedCardView: View {
    let opensAtHour: Int
    let now: Date
    @Binding var selectedTab: Int
    @Binding var showTripPlanner: Bool

    private var opensTomorrow: Bool {
        let currentHour = Calendar.current.component(.hour, from: now)
        return currentHour >= opensAtHour
    }

    private var opensLabel: String {
        if opensTomorrow {
            return "Opens tomorrow at \(opensAtHour):00"
        }
        return "Opens today at \(opensAtHour):00"
    }

    private var countdown: String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: now)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let openingMinutes = opensAtHour * 60

        let minutesUntilOpen: Int
        if currentMinutes < openingMinutes {
            minutesUntilOpen = openingMinutes - currentMinutes
        } else {
            minutesUntilOpen = (24 * 60 - currentMinutes) + openingMinutes
        }

        let hours = minutesUntilOpen / 60
        let mins = minutesUntilOpen % 60

        if hours > 0 {
            return "Opens in \(hours)h \(mins)m"
        }
        return "Opens in \(mins)m"
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("Parking Closed")
                .font(.system(size: 24, weight: .bold))

            Text(opensLabel)
                .font(.system(size: 16))
                .foregroundColor(.gray)

            Text(countdown)
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(Capsule())

            VStack(spacing: 12) {
                Button(action: { withAnimation { selectedTab = 2 } }) {
                    Label("Navigate to Parking", systemImage: "paperplane.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }

                Button(action: { withAnimation { selectedTab = 1 } }) {
                    Label("Spot View", systemImage: "calendar")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                }

                Button(action: { showTripPlanner = true }) {
                    Label("Plan Trip", systemImage: "calendar.badge.clock")
                        .font(.headline)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange, lineWidth: 2)
                        )
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 20)
    }
}

#Preview("Opens Tomorrow") {
    ParkingClosedCardView(opensAtHour: 6, now: Date(), selectedTab: .constant(0), showTripPlanner: .constant(false))
}
