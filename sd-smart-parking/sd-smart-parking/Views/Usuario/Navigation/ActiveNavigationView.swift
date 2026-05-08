//
//  ActiveNavigationView.swift
//  ParkingApp
//
//  Created by Mateo on 26/02/26.
//
import SwiftUI
import MapKit

struct ActiveNavigationView: View {
    
    // MARK: - Environment & State
    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userRepo: UserRepository
    // Usamos el estado del Manager para la lógica, y solo dejamos
    // el estado de la cámara aquí por ser puramente visual.
    @State private var cameraPosition: MapCameraPosition = .userLocation(
        followsHeading: false,
        fallback: .automatic
    )
    
    var body: some View {
        let nav = navigationManager
        ZStack {
            // MARK: - MAP LAYER
            Map(position: $cameraPosition) {
                // Indicador de usuario personalizado
                UserAnnotation {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 42, height: 42)
                            .shadow(color: .black.opacity(0.2), radius: 4)
                        
                        Image(systemName: "location.north.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .foregroundColor(.blue)
                    }
                }
                
                // Destino: Edificio SD
                Marker("SD Building", systemImage: "car.2.fill",
                       coordinate: navigationManager.destination)
                    .tint(.blue)
                
                // Dibujar la ruta si existe
                if let route = nav.route {
                    MapPolyline(route.polyline)
                        .stroke(.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                }
                //ACA HAY PROTECCION DE VIEW
                else if let cachedPolyline = nav.cachedPolyline {
                        // Mostramos la ruta guardada en gris o azul tenue para indicar "Offline"
                        MapPolyline(cachedPolyline)
                        .stroke(.gray, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                    }
                
            }
            .mapStyle(.standard(elevation: .realistic, emphasis: .automatic, showsTraffic: true))
            .mapControls {
                // Solo mostramos controles si NO estamos navegando activamente
                if !navigationManager.isNavigating {
                    MapUserLocationButton()
                    MapCompass()
                    MapPitchToggle()
                }
            }
            .ignoresSafeArea()
            
            // MARK: - TOP CONTROLS (Close Button)
            VStack {
                HStack {
                    Button {
                        // Limpiamos navegación antes de salir
                        navigationManager.endNavigation()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4)
                    }
                    .padding(.top, 25)
                    .padding(.leading, 25)
                    Spacer()
                }
                Spacer()
                // --- INTEGRACIÓN DEL BANNER OFFLINE ---
                if userRepo.isOffline {
                                        OfflineBanner(lastUpdate: nav.lastUpdateDate)
                                            .padding(.top, 25)
                                            .padding(.trailing, 25)
                                    }
                Spacer()
            }
            
            // MARK: - BOTTOM INTERFACE CARD
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    // Indicador de arrastre (Estético)
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 40, height: 5)
                    
                    if navigationManager.isNavigating, let route = navigationManager.route {
                        // --- MODO: NAVEGACIÓN ACTIVA ---
                        Text("On your way to SD Building")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Arrival (ETA)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatTime(route.expectedTravelTime))
                                    .font(.title2).bold()
                            }
                            
                            Spacer()
                            Image(systemName: "bolt.car.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Distance")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatDistance(route.distance))
                                    .font(.title2).bold()
                            }
                        }
                        .padding(.horizontal)
                        
                        Button {
                            navigationManager.endNavigation()
                            dismiss() // Cerramos al terminar
                        } label: {
                            Text("End Trip")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.gradient)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                        
                    } else {
                        // --- MODO: PREVISTA (READY TO START) ---
                        Text("Ready to navigate")
                            .font(.headline)
                        
                        if let route = navigationManager.route {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Est. Time")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatTime(route.expectedTravelTime))
                                        .font(.title2).bold()
                                }
                                Spacer()
                                Image(systemName: "car.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Distance")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatDistance(route.distance))
                                        .font(.title2).bold()
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Button {
                            startNavigationAction()
                        } label: {
                            Label("Start Trip", systemImage: "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.gradient)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(28)
                .padding()
                .shadow(color: .black.opacity(0.15), radius: 15)
                // Escuchamos el cambio de estado del manager para animar la tarjeta
                .animation(.easeInOut(duration: 0.3), value: navigationManager.isNavigating)
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - HELPER FUNCTIONS
    
    private func startNavigationAction() {
        // 1. Cambiamos el estado global
        navigationManager.isNavigating = true
        
        // 2. Animación inicial: Centrar en usuario con rumbo
        withAnimation(.easeInOut(duration: 1.2)) {
            cameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
        }
        
        // 3. Si tenemos ubicación, inclinamos la cámara a 3D después del primer zoom
        if let userCoords = navigationManager.userLocation?.coordinate {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    cameraPosition = .camera(
                        MapCamera(
                            centerCoordinate: userCoords,
                            distance: 350,
                            heading: 0,
                            pitch: 65 // Efecto 3D
                        )
                    )
                }
            }
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        return minutes < 60 ? "\(minutes) min" : "\(minutes / 60)h \(minutes % 60)m"
    }
    
    private func formatDistance(_ meters: CLLocationDistance) -> String {
        return String(format: "%.1f km", meters / 1000)
    }
}

// En un archivo separado o dentro de ActiveNavigationView
struct OfflineBanner: View {
    var lastUpdate: Date?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption2.bold())
            
            VStack(alignment: .leading, spacing: 0) {
                Text("Offline Mode")
                    .font(.caption.bold())
                if let date = lastUpdate {
                    Text("Data from: \(date, style: .time)")
                        .font(.system(size: 8))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.orange.opacity(0.9))
        .foregroundColor(.white)
        .clipShape(Capsule())
        .shadow(radius: 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - PREVIEW
#Preview {
    ActiveNavigationView()
        .environmentObject(NavigationManager())
}
