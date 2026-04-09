//
//  SpotsView.swift
//  ParkingApp
//
//  Created by Mateo on 19/02/26.
//


import SwiftUI

struct SpotsView: View {
    @EnvironmentObject var vm: ParkingViewModel
    @EnvironmentObject var authVM: AuthViewModel
    
    let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    // <- sacar aquí
    var sortedFloors: [Int] {
        Dictionary(grouping: vm.spots, by: { $0.floor }).keys.sorted()
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    // Recommendation banner (driver only)
                    if !authVM.isGerente,
                       let recommended = vm.recommendedFloor {
                        let avail = vm.floorAvailability[recommended]?.available ?? 0
                        let floorSpots = vm.spots
                            .filter { $0.floor == recommended && $0.isAvailable }
                            .sorted { $0.number < $1.number }
                            .prefix(3)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.green)
                                Text("Best floor: Floor \(recommended)")
                                    .font(.headline)
                                FloorBadge(isUrgent: avail <= 4)
                                Spacer()
                            }

                            Text("\(avail) spots available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            LazyVGrid(columns: columns, spacing: 15) {
                                ForEach(Array(floorSpots)) { spot in
                                    SpotCardView(spot: spot, isGerente: false)
                                }
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.05))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }

                    ForEach(sortedFloors, id: \.self) { floor in // <- usar aquí
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Floor \(floor)")
                                    .font(.headline)
                                    .foregroundColor(.secondary)

                                if !authVM.isGerente,
                                   let recommended = vm.recommendedFloor,
                                   recommended == floor {
                                    let avail = vm.floorAvailability[floor]?.available ?? 0
                                    FloorBadge(isUrgent: avail <= 4)
                                }
                            }
                            .padding(.horizontal)
                            
                            LazyVGrid(columns: columns, spacing: 15) {
                                ForEach(vm.spots.filter { $0.floor == floor }.sorted(by: { $0.number < $1.number })) { spot in
                                    SpotCardView(spot: spot, isGerente: authVM.isGerente)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(authVM.isGerente ? "Gestión de Espacios" : "Availability")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}


#Preview("Usuario Normal") {
    SpotsView()
        .environmentObject(ParkingViewModel())
        .environmentObject(AuthViewModel())
}

#Preview("Gerente") {
    let auth = AuthViewModel()
    auth.isGerente = true
    return SpotsView()
        .environmentObject(ParkingViewModel())
        .environmentObject(auth)
}
