//
//  LoginView.swift
//  ParkingApp
//
//  Created by Mateo on 19/02/26.
//
import SwiftUI
import GoogleSignInSwift
import LocalAuthentication

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @State private var email = ""
    @State private var password = ""
    /// Cached snapshot of `MicrosoftKeychain.lastEmail()` so we don't pay an
    /// XPC round-trip to `securityd` on every body recompose. Refreshed on
    /// appear and after any auth attempt completes.
    @State private var lastMicrosoftEmail: String?
    private var biometricIcon: String {
        authVM.biometricType == .touchID ? "touchid" : "faceid"
    }

    private var biometricLabel: String {
        authVM.biometricType == .touchID ? "Continue with Touch ID" : "Continue with Face ID"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: 30) {

                // MARK: - Logo/Header
                VStack(spacing: 10) {
                    Image(systemName: "car.side.lock.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    Text("SD parking")
                        .font(.largeTitle.bold())
                }

                // MARK: - Form
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue.opacity(0.7))
                            .frame(width: 30)
                        TextField("Email Address", text: $email)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.blue.opacity(0.7))
                            .frame(width: 30)
                        SecureField("Password", text: $password)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)

                if let error = authVM.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }

                // MARK: - Login Button
                Button {
                    Task { await authVM.signIn(username: email, password: password) }
                } label: {
                    HStack {
                        if authVM.isLoading {
                            ProgressView().tint(.white).padding(.trailing, 10)
                        }
                        Text(authVM.isLoading ? "Signing in..." : "Login")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(email.isEmpty || password.count < 4 ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .opacity(networkMonitor.isConnected ? 1.0 : 0.45)
                }
                .disabled(!networkMonitor.isConnected || authVM.isLoading || email.isEmpty || password.count < 4)
                .padding(.horizontal, 24)

                // MARK: - Divider
                HStack {
                    Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3))
                    Text("or").font(.caption).foregroundColor(.secondary)
                    Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3))
                }
                .padding(.horizontal, 24)

                // MARK: - Google Button
                Button {
                    Task { await authVM.signInWithGoogle() }
                } label: {
                    HStack(spacing: 12) {
                        Image("Google_Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text("Continue with Google")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                    .opacity(networkMonitor.isConnected ? 1.0 : 0.45)
                }
                .contentShape(Rectangle())
                .disabled(!networkMonitor.isConnected || authVM.isLoading)
                .padding(.horizontal, 24)

                // MARK: - Microsoft Button
                if let lastEmail = lastMicrosoftEmail {
                    Text("Last Microsoft user: \(lastEmail)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)
                }
                Button {
                    Task { await authVM.signInWithMicrosoft() }
                } label: {
                    HStack(spacing: 12) {
                        Image("Microsoft_Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text("Continue with Microsoft")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                    .opacity(networkMonitor.isConnected ? 1.0 : 0.45)
                }
                .contentShape(Rectangle())
                .disabled(!networkMonitor.isConnected || authVM.isLoading)
                .padding(.horizontal, 24)

                if !networkMonitor.isConnected {
                    Text("Sin conexión — los métodos online están deshabilitados. Usa Face ID si tienes sesión guardada.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)
                }

                // MARK: - Face ID / Touch ID Button
                Button {
                    Task { await authVM.signInWithBiometrics() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: biometricIcon)
                            .font(.system(size: 20))
                        Text(biometricLabel)
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 24)

                // MARK: - Registration Link
                NavigationLink {
                    RegistrationView()
                } label: {
                    HStack {
                        Text("Don't have an account?")
                        Text("Register")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.blue)
                }
                .padding(.bottom, 20)

                #if DEBUG
                VStack(spacing: 12) {
                    Text("Dev Tools")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button("Login as User") { authVM.loginAsUser() }
                            .font(.caption)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)

                        Button("Login as Manager") { authVM.loginAsGerente() }
                            .font(.caption)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.1))
                            .foregroundColor(.orange)
                            .cornerRadius(8)
                    }
                }
                .padding(.top, 20)
                #endif
            }
            .padding(.top, 40)
            }
            .navigationBarHidden(true)
        }
        .onAppear { lastMicrosoftEmail = MicrosoftKeychain.lastEmail() }
        .onChange(of: authVM.isLoading) { _, isLoading in
            if !isLoading { lastMicrosoftEmail = MicrosoftKeychain.lastEmail() }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
        .environmentObject(NetworkMonitor())
}
