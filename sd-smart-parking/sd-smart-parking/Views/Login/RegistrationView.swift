//
//  RegistrationView.swift
//  ParkingApp
//
//  Created by Mateo on 26/02/26.
//
import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject var authVM: AuthViewModel

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    // MARK: - Validation helpers

    private var isValidEmail: Bool {
        email.contains("@") && email.contains(".")
    }

    private var passwordsMatch: Bool {
        password == confirmPassword
    }

    var isFormValid: Bool {
        name.count >= 2 &&
        name.count <= 50 &&
        isValidEmail &&
        password.count >= 6 &&
        password.count <= 20 &&
        passwordsMatch
    }

    // MARK: - Body

    var body: some View {
        Form {

            // MARK: Header
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                    Text("Create Account")
                        .font(.title.bold())
                    Text("Fill in every field to continue.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            // MARK: Personal info
            Section(header: Text("Personal info")) {

                // Full name
                VStack(alignment: .leading, spacing: 5) {
                    fieldLabel("Full name", icon: "person.fill")
                    TextField("e.g. Juan Pérez", text: $name)
                        .textContentType(.name)

                    if name.isEmpty {
                        hint("Your full name, between 2 and 50 characters.")
                    } else if name.count < 2 {
                        error("Too short — enter at least 2 characters.")
                    } else if name.count > 50 {
                        error("Too long — maximum 50 characters allowed.")
                    } else {
                        valid("Looks good!")
                    }
                }
                .padding(.vertical, 4)

                // Email
                VStack(alignment: .leading, spacing: 5) {
                    fieldLabel("Email address", icon: "envelope.fill")
                    TextField("e.g. juan@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textContentType(.emailAddress)

                    if email.isEmpty {
                        hint("Used to log in — must include @ and a domain.")
                    } else if !email.contains("@") {
                        error("Missing @ — enter a valid email (e.g. juan@mail.com).")
                    } else if !email.contains(".") {
                        error("Missing domain — enter a valid email (e.g. juan@mail.com).")
                    } else {
                        valid("Valid email address.")
                    }
                }
                .padding(.vertical, 4)
            }

            // MARK: Security
            Section(header: Text("Security")) {

                // Password
                VStack(alignment: .leading, spacing: 5) {
                    fieldLabel("Password", icon: "lock.fill")
                    SecureField("At least 6 characters", text: $password)
                        .textContentType(.newPassword)

                    if password.isEmpty {
                        hint("Between 6 and 20 characters.")
                    } else if password.count < 6 {
                        error("Too short — \(6 - password.count) more character(s) needed.")
                    } else if password.count > 20 {
                        error("Too long — remove \(password.count - 20) character(s).")
                    } else {
                        HStack {
                            valid("Strong enough.")
                            Spacer()
                            Text("\(password.count) / 20")
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.vertical, 4)

                // Confirm password
                VStack(alignment: .leading, spacing: 5) {
                    fieldLabel("Confirm password", icon: "lock.rotation")
                    SecureField("Repeat your password", text: $confirmPassword)
                        .textContentType(.newPassword)

                    if confirmPassword.isEmpty {
                        hint("Re-enter your password to confirm.")
                    } else if !passwordsMatch {
                        error("Passwords don't match — check and try again.")
                    } else {
                        valid("Passwords match.")
                    }
                }
                .padding(.vertical, 4)
            }

            // MARK: Firebase error
            if let serverError = authVM.errorMessage {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(serverError)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
            }

            // MARK: Submit
            Section {
                Button {
                    Task { await authVM.register(name: name, email: email, password: password) }
                } label: {
                    if authVM.isLoading {
                        ProgressView().tint(.white).frame(maxWidth: .infinity)
                    } else {
                        Text("Create Account")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!isFormValid || authVM.isLoading)
                .listRowBackground(isFormValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
            } footer: {
                Text("By creating an account you agree to the app's terms of use.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .navigationTitle("Register")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Reusable label helpers

    @ViewBuilder
    private func fieldLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private func error(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundColor(.red)
    }

    @ViewBuilder
    private func valid(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundColor(.green)
    }
}

#Preview {
    NavigationStack {
        RegistrationView()
            .environmentObject(AuthViewModel())
    }
}
