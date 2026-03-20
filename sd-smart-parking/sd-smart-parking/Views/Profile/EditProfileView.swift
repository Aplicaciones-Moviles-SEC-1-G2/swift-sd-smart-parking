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
                Section("Información Personal") {
                    TextField("Nombre", text: $name)
                    TextField("Correo", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Editar Perfil")
            .onAppear {
                // Populate fields with current data
                if let user = authVM.currentUser {
                    name = user.name
                    email = user.email
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
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
