//
//  CarsView.swift
//  ParkingApp
//
//  Created by Mateo on 24/02/26.
//
import SwiftUI

struct CarsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var userRepo: UserRepository
    @State private var showingAddCar = false
    @State private var newName = ""
    @State private var newPlate = ""
    
    var body: some View {
        // Diagnóstico inicial al entrar al body
        
        
        ScrollView {
            // Check if user exists and has cars
            if let user = userRepo.currentUser {
                let allCars = user.cars.allValues()
                
                
                if !allCars.isEmpty {
                    VStack(spacing: 16) {
                        ForEach(allCars) { car in
                            
                            CarCard(car: car)
                        }
                    }
                    .padding()
                } else {
                    
                    // Professional empty state using native SwiftUI (iOS 17+)
                    ContentUnavailableView {
                        Label("No Vehicles Yet", systemImage: "car.2.fill")
                    } description: {
                        Text("Tap the plus button to add your first car.")
                    }
                    .padding(.top, 100)
                }
            } else {
                
                // Fallback en caso de que el usuario sea nulo
                ContentUnavailableView {
                    Label("Session Error", systemImage: "person.crop.circle.badge.exclamationmark")
                } description: {
                    Text("Please log in again.")
                }
                .padding(.top, 100)
            }
        }
        .navigationTitle("My Vehicles")
        .onAppear {
            userRepo.refreshPendingStatus()
        }
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddCar = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                }
            }
        }
        .sheet(isPresented: $showingAddCar) {
            NavigationStack {
                Form {
                    Section("Vehicle Information") {
                        TextField("Name (e.g., My Truck)", text: $newName)
                        TextField("Plate Number", text: $newPlate)
                    }
                }
                .navigationTitle("New Car")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            Task {
                                let _ = print("🚀 Intentando agregar carro: \(newName) - \(newPlate)")
                                userRepo.addCar(name: newName, plate: newPlate)
                                
                                newName = ""
                                newPlate = ""
                                showingAddCar = false
                            }
                        }
                        .disabled(newName.isEmpty || newPlate.isEmpty)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingAddCar = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}
/// A card component that displays a vehicle's name and license plate.
struct CarCard: View {
    let car: Car
    @EnvironmentObject var userRepo: UserRepository
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "car.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading) {
                    Text(car.name)
                        .font(.headline)
                    Text(car.plate.uppercased())
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // --- INDICADOR DE ESTADO PENDIENTE ---
                if userRepo.pendingPlates.contains(car.plate) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("PENDING SYNC")
                                .font(.system(size: 9, weight: .black))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .transition(.scale.combined(with: .opacity)) // Animación de entrada/salida
                    }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

/// El "reloj cuadrado" que indica que la sincronización está pendiente
struct SyncIndicator: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(.orange.opacity(0.2))
                .frame(width: 20, height: 20)
            
            Image(systemName: "clock.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.orange)
        }
        .transition(.scale.combined(with: .opacity))
    }
}



