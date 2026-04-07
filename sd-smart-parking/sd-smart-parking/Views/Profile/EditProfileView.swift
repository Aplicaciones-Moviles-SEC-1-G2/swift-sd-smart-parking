//
//  EditProfileView.swift
//  ParkingApp
//
//  Created by Mateo on 25/02/26.
//
import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var email: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Personal information") {
                    TextField("Name", text: $name)
                    TextField("E-mail", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Edit Profile")
            .onAppear {
                // Populate fields with current data
                if let user = authVM.currentUser {
                    name = user.name
                    email = user.email
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await authVM.updateProfile(newName: name, newEmail: email)
                        }
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
