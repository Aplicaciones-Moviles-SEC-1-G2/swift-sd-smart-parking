//
//  GerenteTabView.swift
//  ParkingApp
//
//  Created by Mateo on 27/02/26.
//
// GerenteTabView.swift — nuevo
// GerenteTabView.swift
import SwiftUI

struct GerenteTabView: View {
    @State private var selectedTab: Int = 0
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(selectedTab: $selectedTab, scrollOffset: $scrollOffset)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            
            SpotsView()
                .tabItem { Label("Spots", systemImage: "square.grid.3x3.fill") }
                .tag(1)
            
            RegistroVehiculosView()
                .tabItem { Label("Vehicles", systemImage: "car.fill") }
                .tag(2)
            
            ReportsView()
                .tabItem { Label("Reports", systemImage: "chart.bar.fill") }
                .tag(3)
            
            ConfigurationView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .accentColor(.blue)
    }
}

#Preview {
    let auth = AuthViewModel()
    auth.isGerente = true
    return GerenteTabView()
        .environmentObject(auth)
        .environmentObject(ParkingViewModel())
}
