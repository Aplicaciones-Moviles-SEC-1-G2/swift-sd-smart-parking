//
//  BiometricLockView.swift
//  sd-smart-parking
//

import SwiftUI
import LocalAuthentication

struct BiometricLockView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var userRepo: UserRepository
    private var biometricIcon: String {
        switch authVM.biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.fill"
        }
    }

    private var biometricLabel: String {
        switch authVM.biometricType {
        case .faceID: return "Sign in with Face ID"
        case .touchID: return "Sign in with Touch ID"
        default: return "Unlock"
        }
    }

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "car.side.lock.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                Text("SD Parking")
                    .font(.largeTitle.bold())
                Text("Authenticate to continue")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Image(systemName: biometricIcon)
                .font(.system(size: 72))
                .foregroundColor(.blue)

            VStack(spacing: 16) {
                Button {
                    Task { await authVM.authenticateWithBiometrics() }
                } label: {
                    Label(biometricLabel, systemImage: biometricIcon)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(15)
                }
                .padding(.horizontal, 40)

                if let error = authVM.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button("Use Password Instead") {
                    authVM.biometricsEnabled = false
                    authVM.requiresBiometricUnlock = false
                    authVM.signOut(userRepo: userRepo  )
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .onAppear {
            // Automatically trigger Face ID on appear
            Task { await authVM.authenticateWithBiometrics() }
        }
    }
}
