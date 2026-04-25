//
//  ContentView.swift
//  sd-smart-parking
//
//  Created by Mateo on 19/03/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var parkingVM = ParkingViewModel()
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @State private var selectedTab: Int = 0
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) { // ZStack para permitir el banner flotante
            Group {
                if authVM.requiresBiometricUnlock {
                    BiometricLockView()
                } else if authVM.isLoggedIn {
                    if authVM.isGerente {
                        GerenteTabView()
                    } else {
                        UsuarioTabView(selectedTab: $selectedTab, scrollOffset: $scrollOffset)
                    }
                } else {
                    LoginView()
                }
            }
            
            // EL BANNER GLOBAL: Solo se muestra si isLoggedIn Y userRepo detecta offline
            if authVM.isLoggedIn && userRepo.isOffline {
                ConnectionBannerView()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1) // Asegura que esté por encima de todo
            }
        }
        .animation(.spring(), value: userRepo.isOffline) // Animación suave al aparecer/desaparecer
        .environmentObject(authVM)
        .environmentObject(parkingVM)
        .environmentObject(userRepo) // Inyectamos el repo para que cualquier vista acceda a los carros
        .task {
            await parkingVM.generateSpotsIfEmpty()
            await parkingVM.loadInitialDataParallel()
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            if isConnected { parkingVM.syncPendingActions() }
        }
    }
}

struct ConnectionBannerView: View {
    var body: some View {
        Text("Offline Mode")
            .font(.caption)
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color.orange)
            .foregroundColor(.white)
    }
}
#Preview {
    ContentView()
}
