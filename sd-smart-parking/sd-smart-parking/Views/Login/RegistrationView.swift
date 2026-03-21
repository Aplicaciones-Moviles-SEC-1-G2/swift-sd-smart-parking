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
    
    var body: some View {
        Form {
            // Section 1: The Header
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    Text("User info")
                        .font(.largeTitle.bold())
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear) // Makes the header look seamless
            }
            
            // Section 2: Info
            Section(header: Text("Personal info")) {
                TextField("Name", text: $name)
                TextField("e-mail", text: $email)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
            }
            
            // Section 3: Security
            Section(header: Text("Security")) {
                SecureField("password", text: $password)
                SecureField("Confirm", text: $confirmPassword)
            }
            
            // Section 4: The Button
            Section {
                Button {
                    Task { await authVM.register(name: name, email: email, password: password) }
                } label: {
                    if authVM.isLoading {
                        ProgressView().tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create Account")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!isFormValid || authVM.isLoading)
                .listRowBackground(isFormValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
            }
        }
        .navigationTitle("Register")
        .navigationBarTitleDisplayMode(.large)
    }
    
    var isFormValid: Bool {
        !name.isEmpty && email.contains("@") && password == confirmPassword && password.count >= 6
    }
}

#Preview {
    NavigationStack {
        RegistrationView()
            .environmentObject(AuthViewModel())
    }
}

