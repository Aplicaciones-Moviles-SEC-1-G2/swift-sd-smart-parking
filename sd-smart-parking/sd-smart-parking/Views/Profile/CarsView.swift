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
        ScrollView {
            // Check if user exists and has cars
            if let user = userRepo.currentUser, !user.cars.isEmpty {
                VStack(spacing: 16) {
                    ForEach(user.cars) { car in
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
        }
        .navigationTitle("My Vehicles")
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddCar = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.bold) // Optional: makes it pop more
                        .foregroundStyle(.blue) // This makes the button blue
                }
            }
        }
        // 3. Add the functionality to input a new car
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
                                userRepo.addCar(name: newName, plate: newPlate)
                                    
                                    // 2. Limpiamos la UI inmediatamente
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "car.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text(car.name)
                    .font(.headline)
                
                Spacer()
            }
            
            Divider()
            
            HStack {
                Text("PLATE")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                
                Text(car.plate.uppercased())
                    .font(.subheadline.monospaced())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1)) // Added a subtle tint
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
#Preview {
    // 1. Create the ViewModel instance
    let viewModel = AuthViewModel()
    
    // 2. Create mock data
    let sampleCars = [
        Car(id: UUID(), plate: "GTC-456", UserID: UUID(), name: "Commuter Sedan"),
        Car(id: UUID(), plate: "FAST-01", UserID: UUID(), name: "Weekend Cruiser")
    ]
    
    // 3. Inject the data into the ViewModel
    viewModel.currentUser = User(
        id: UUID(),
        name: "Alex",
        email: "alex@uniandes.edu.co",
        password: "password",
        cars: sampleCars
    )
    viewModel.isLoggedIn = true
    
    // 4. Return the view with the environment object attached
    return NavigationStack {
        CarsView()
            .environmentObject(viewModel)
    }
}

#Preview("Empty State") {
    let emptyVM = AuthViewModel()
    emptyVM.currentUser = User(id: UUID(), name: "New User", email: "test@test.com", password: "123", cars: [])
    
    return NavigationStack {
        CarsView()
            .environmentObject(emptyVM)
    }
}
