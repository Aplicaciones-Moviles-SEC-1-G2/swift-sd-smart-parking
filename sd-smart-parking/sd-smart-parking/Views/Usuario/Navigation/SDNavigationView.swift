//
//  SDNavigationView.swift
//  ParkingApp
//
//  Created by Mateo on 26/02/26.
//

import SwiftUI

struct SDNavigationView: View {

    @StateObject private var navManager = NavigationManager()
    @StateObject private var weatherVM  = WeatherViewModel()
    @State private var showNavigation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                // LIVE CAPACITY CARD
                LiveCapacityCard(available: 40, total: 120, queue: 3)

                // MAP VIEW WITH OVERLAYS
                ZStack(alignment: .bottomTrailing) {
                    AppleMapsView(navManager: navManager)
                        .frame(maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20))

                    // Weather overlay — top leading
                    Group {
                        if let weather = weatherVM.weather {
                            HStack(spacing: 6) {
                                Image(systemName: weather.symbolName)
                                    .foregroundColor(weather.symbolColor)
                                Text("\(Int(weather.temperature))°C")
                                    .font(.subheadline.bold())
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                        } else if weatherVM.isLoading {
                            ProgressView()
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    // Route info — bottom trailing
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("Route to SD Building")
                            .font(.caption.bold())

                        HStack(spacing: 16) {
                            Label(navManager.travelTime, systemImage: "clock.fill")
                            Label(navManager.distance, systemImage: "road.lanes")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(10)
                }
                
                // ✅ Botón justo debajo del mapa, sin Spacer
                Button {
                    showNavigation = true
                } label: {
                    Label("Start Navigation", systemImage: "paperplane.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .fullScreenCover(isPresented: $showNavigation) {
                    ActiveNavigationView()
                        .environmentObject(navManager)
                }
            }
            .padding()
            .padding(.bottom, 8) // ✅ Espacio extra sobre la tab bar
            .background(Color(.systemGray6).opacity(0.5))
            .navigationTitle("Navigation")
        }
    }
}

// MARK: - Live Capacity Card

struct LiveCapacityCard: View {
    @EnvironmentObject var vm: ParkingViewModel
    var available: Int
    var total: Int
    var queue: Int
    
    
    var statusInfo: (text: String, color: Color) {
        
        if vm.totalAvailable == 0 {
            return ("Full Capacity", .red)
        } else if vm.totalAvailable <= 10 {
            return ("Limited Availability", .orange)
        } else {
            return ("Good Availability", .green)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Live Capacity")
                .font(.title3.bold())
            
            HStack {
                Text("Available Spots")
                    .foregroundColor(.secondary)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(vm.totalAvailable)")
                        .font(.title2.bold())
                    Text("/ \(vm.spots.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(statusInfo.text)
                .font(.subheadline.bold())
                .foregroundColor(statusInfo.color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(statusInfo.color.opacity(0.1))
                .cornerRadius(10)
                .animation(.default, value: available)
            
            Divider()
            
            HStack {
                Label("Queue Length", systemImage: "car.fill")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(queue) cars")
                    .bold()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    SDNavigationView()
        .environmentObject(ParkingViewModel())
}
