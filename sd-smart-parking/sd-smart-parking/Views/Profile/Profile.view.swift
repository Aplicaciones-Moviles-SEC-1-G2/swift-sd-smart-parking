//
//  Profile.view.swift
//  ParkingApp
//
//  Created by Mateo on 19/02/26.
//
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var isEditing = false
    
    var body: some View {
        NavigationStack {
            List {
                // 1. Dynamic Header with Real User Data
                Section {
                    if let user = authVM.currentUser {
                        HStack(spacing: 15) {
                            // Profile Image / Avatar
                            ZStack {
                                Circle()
                                    .fill(Color.blue.gradient)
                                    .frame(width: 60, height: 60)
                                
                                Text(user.name.prefix(1).uppercased())
                                    .font(.title.bold())
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text("No se encontró información del usuario")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // 2. Settings Section
                Section("Settings") {
                    Label("Notifications", systemImage: "bell.fill")
                    Label("Security", systemImage: "lock.fill")
                    
                    // Link to CarsView passing the real user object
                    if let user = authVM.currentUser {
                        NavigationLink(destination: CarsView()) {
                            HStack {
                                Label("My Cars", systemImage: "car.fill")
                                Spacer()
                                // Dynamic badge showing number of cars
                                Text("\(user.cars.count)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color(.systemGray5))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // 3. Logout
                Button(role: .destructive) {
                    authVM.signOut()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Log Out")
                    }
                }
            }
            .navigationTitle("My Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing){
                        Button("Edit") {
                                    isEditing = true
                                }
                            }
                        }
                        .sheet(isPresented: $isEditing) {
                            EditProfileView()
                        }
                    
        
        }
    }
}
#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
        .environmentObject(ParkingViewModel())
}
