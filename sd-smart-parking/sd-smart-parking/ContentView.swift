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
    @State private var selectedTab: Int = 0
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
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
        .environmentObject(authVM)
        .environmentObject(parkingVM)
        .task {
            await parkingVM.generateSpotsIfEmpty()
        }
    }
}
#Preview {
    ContentView()
}
