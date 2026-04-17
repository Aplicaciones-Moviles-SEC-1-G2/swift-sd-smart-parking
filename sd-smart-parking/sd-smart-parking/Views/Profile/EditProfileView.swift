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
                // 2. Cargamos los datos desde el repositorio
                if let user = userRepo.currentUser {
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
                        // 3. Llamada al Repositorio (maneja lógica offline/online)
                        userRepo.updateProfile(newName: name, newEmail: email)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
