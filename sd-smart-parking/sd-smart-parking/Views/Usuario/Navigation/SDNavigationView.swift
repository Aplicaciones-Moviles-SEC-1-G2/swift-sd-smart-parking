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
            ScrollView { // Usamos ScrollView para evitar que los elementos se corten
                VStack(spacing: 20) {
                    
                    // 1. IA RECOMMENDATION CARD (Prioridad visual)
                    AIRecommendationCard()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 5)
                    
                    // 2. LIVE CAPACITY CARD
                    //LiveCapacityCard(available: 40, total: 120, queue: 3)
                    
                    // 3. MAP CONTAINER
                    ZStack(alignment: .bottomTrailing) {
                        AppleMapsView(navManager: navManager)
                            .frame(height: 300) // Altura fija para el mapa
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                        
                        // Weather Overlay (Arriba Izquierda)
                        weatherOverlay
                        
                        // Route Info Overlay (Abajo Derecha)
                        routeInfoOverlay
                    }
                    
                    // 4. ACTION BUTTON
                    Button {
                        showNavigation = true
                    } label: {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Start Navigation")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue.gradient) // Gradiente sutil
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal)
            }
            .background(Color(.systemGray6))
            .navigationTitle("Navigation")
            .fullScreenCover(isPresented: $showNavigation) {
                ActiveNavigationView()
                    .environmentObject(navManager)
            }
        }
    }
    
    // MARK: - Overlays pulidos
    
    private var weatherOverlay: some View {
        VStack {
            HStack {
                if let weather = weatherVM.weather {
                    HStack(spacing: 6) {
                        Image(systemName: weather.symbolName)
                            .foregroundColor(weather.symbolColor)
                        Text("\(Int(weather.temperature))°C")
                            .font(.system(.subheadline, design: .rounded).bold())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
                Spacer()
            }
            Spacer()
        }
        .padding(12)
    }
    
    private var routeInfoOverlay: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("SD Building")
                .font(.caption.bold())
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                Label(navManager.travelTime, systemImage: "clock.fill")
                Label(navManager.distance, systemImage: "road.lanes")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .padding(12)
    }
}

// MARK: - Live Capacity Card Pulida

struct LiveCapacityCard: View {
    @EnvironmentObject var vm: ParkingViewModel
    var available: Int
    var total: Int
    var queue: Int
    
    var statusInfo: (text: String, color: Color) {
        if vm.totalAvailable == 0 { return ("Full Capacity", .red) }
        else if vm.totalAvailable <= 10 { return ("Limited", .orange) }
        else { return ("Available", .green) }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Capacity")
                        .font(.headline)
                    Text("SD Building • Floor \(vm.spots.first?.floor ?? 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // Badge de estado
                Text(statusInfo.text)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusInfo.color.opacity(0.15))
                    .foregroundColor(statusInfo.color)
                    .clipShape(Capsule())
            }
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading) {
                    Text("\(vm.totalAvailable)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Spots left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Barra de progreso minimalista
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5)).frame(width: 120, height: 8)
                    Capsule()
                        .fill(statusInfo.color.gradient)
                        .frame(width: 120 * CGFloat(vm.occupancyProgress), height: 8)
                }
            }
            
            Divider()
            
            HStack {
                Label("Queue: \(queue) cars", systemImage: "car.2.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .padding(20)
        .background(Color(.white))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
    }
}

    #Preview {
        SDNavigationView()
            .environmentObject(ParkingViewModel()) // El del edificio SD
            .environmentObject(NavigationManager()) // Si lo usas como global
    }
