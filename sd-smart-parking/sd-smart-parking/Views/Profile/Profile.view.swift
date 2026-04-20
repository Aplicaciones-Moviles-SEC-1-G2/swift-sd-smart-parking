//
//  Profile.view.swift
//  ParkingApp
//
//  Created by Mateo on 19/02/26.
//
import SwiftUI
import Foundation
import Combine
import FirebaseFirestoreInternal

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var isEditing = false
    @EnvironmentObject var parkingVM: ParkingViewModel
    @EnvironmentObject var userRepo: UserRepository
    //let user: User
    @State private var now = Date()
        
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
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
                if !parkingVM.activeUserRecords.isEmpty {
                    Section("Current Status") {
                        ForEach(parkingVM.activeUserRecords) { record in
                            VehicleStatusCard(record: record, now: now)
                                .listRowInsets(EdgeInsets()) // Para que la tarjeta use todo el ancho
                                .background(Color.clear)
                        }
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
                                Text("\(user.cars.count())")
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
                    authVM.signOut(userRepo: userRepo  )
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
                    
        
        }.onAppear {
            print("🚀 PROBANDO CONEXIÓN EN PROFILEVIEW")
            
            // Forzamos una lectura manual sin importar el usuario
            parkingVM.db.collection("vehicleRecords").limit(to: 1).getDocuments { snap, _ in
                print("📡 CONEXIÓN FIREBASE: Llegaron \(snap?.documents.count ?? 0) documentos")
            }

            if let user = authVM.currentUser {
                print("👤 USUARIO ENCONTRADO: \(user.name) con \(user.cars.count) carros")
                parkingVM.listenToUserCars(for: user)
            } else {
                print("❌ ERROR: authVM.currentUser es NIL")
            }
        }
    }
    
}

