//
//  LoginView.swift
//  ParkingApp
//
//  Created by Mateo on 19/02/26.
//
import SwiftUI

import SwiftUI
import GoogleSignInSwift

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                // MARK: - Logo/Header
                VStack(spacing: 10) {
                    Image(systemName: "car.side.lock.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    Text("SD parking")
                        .font(.largeTitle.bold())
                }
                
                // MARK: - Formulario
                VStack(spacing: 20) {
                    // Email
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
                    
                    // Password
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
                
                // MARK: - Botón Login
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
                }
                .disabled(authVM.isLoading || email.isEmpty || password.count < 4)
                .padding(.horizontal, 24)

                // MARK: - Separador
                HStack {
                    Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3))
                    Text("or").font(.caption).foregroundColor(.secondary)
                    Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3))
                }
                .padding(.horizontal, 24)

                // MARK: - Botón Google
                Button {
                    Task {
                        await authVM.signInWithGoogle()
                    }
                } label: {
                    HStack(spacing: 12) { // Changed to HStack for a standard look
                        Image("Google_Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20) // Slightly smaller icon for HStack
                        
                        Text("Continue with Google")
                            .font(.body) // Slightly larger font for better readability
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemBackground)) // Adapts better to Light/Dark mode
                    .cornerRadius(12) // Slightly tighter corners
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2) // Subtle lift
                }
                .contentShape(Rectangle()) // Ensures the whole button is tappable
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
            }
            .navigationBarHidden(true)
        }
        
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
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
