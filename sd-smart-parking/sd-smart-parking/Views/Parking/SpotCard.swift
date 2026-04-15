//
//  SpotCard.swift
//  ParkingApp
//
//  Created by Mateo on 19/02/26.
//

import SwiftUI

struct SpotCardView: View {
    let spot: ParkingSpot
    var isGerente: Bool = false
    @EnvironmentObject var vm: ParkingViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showQRScanner = false

    /// True when this spot's owner also holds another occupied spot (admin view).
    private var isDuplicate: Bool {
        guard isGerente, let email = spot.reservedByEmail, !email.isEmpty else { return false }
        return vm.duplicateSpotGroups.contains { $0.email == email }
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(spot.isAvailable ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .frame(width: 45, height: 45)

                Image(systemName: "car.fill")
                    .font(.system(size: 22))
                    .foregroundColor(spot.isAvailable ? .green : .red)
            }

            VStack(spacing: 2) {
                Text("\(spot.number)")
                    .font(.system(size: 14, weight: .bold))

                Text(spot.isAvailable ? "Available" : "Occupied")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            if isGerente {
                Text(spot.isAvailable ? "Tap to occupy" : "Tap to free")
                    .font(.system(size: 9))
                    .foregroundColor(spot.isAvailable ? .green.opacity(0.8) : .red.opacity(0.8))
            } else if spot.isAvailable {
                Label("Scan QR", systemImage: "qrcode.viewfinder")
                    .font(.system(size: 9))
                    .foregroundColor(.blue.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 3)
        // Duplicate warning badge (admin only)
        .overlay(alignment: .topTrailing) {
            if isDuplicate {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.orange)
                    .padding(6)
            }
        }
        .onTapGesture {
            if isGerente {
                withAnimation(.spring()) {
                    vm.reserveSpot(spot)
                }
            } else if spot.isAvailable {
                showQRScanner = true
            }
        }
        .sheet(isPresented: $showQRScanner) {
            SpotQRSheet(spot: spot) {
                withAnimation(.spring()) {
                    // Record the user's email against this spot so we can
                    // detect duplicates and block the view if they scan again.
                    vm.reserveSpotForUser(spot, userEmail: authVM.currentUserEmail ?? "")
                }
            }
        }
    }
}
