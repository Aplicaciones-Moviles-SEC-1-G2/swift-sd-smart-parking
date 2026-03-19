//
//  ActiveNavigationView.swift
//  ParkingApp
//
//  Created by Mateo on 26/02/26.
//
import SwiftUI
import MapKit


struct ActiveNavigationView: View {
    
    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var isNavigating: Bool = false
    @State private var cameraPosition: MapCameraPosition = .userLocation(
        followsHeading: false,
        fallback: .automatic
    )
    
    var body: some View {
        ZStack {
            // MARK: - MAPA
            Map(position: $cameraPosition) {
                
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
                
                Marker("Edificio SD", systemImage: "car.2.fill",
                       coordinate: CLLocationCoordinate2D(latitude: 4.6014, longitude: -74.0649))
                    .tint(.blue)
                
                if let route = navigationManager.route {
                    MapPolyline(route.polyline)
                        .stroke(.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                }
            }
            .mapStyle(.standard(elevation: .realistic, emphasis: .automatic, showsTraffic: true))
            .mapControls {
                if !isNavigating {
                    MapUserLocationButton()
                    MapCompass()
                    MapPitchToggle()
                }
            }
            .ignoresSafeArea()
            
            // MARK: - CARD INFERIOR
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 40, height: 5)
                    
                    if isNavigating, let route = navigationManager.route {
                        // --- Modo navegación activa ---
                        Text("En camino al Edificio SD")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Llegada (ETA)")
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
                                Text("Distancia")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatDistance(route.distance))
                                    .font(.title2).bold()
                            }
                        }
                        .padding(.horizontal)
                        
                        Button {
                            navigationManager.endNavigation()
                            dismiss()
                        } label: {
                            Text("Terminar Viaje")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                        
                    } else {
                        // --- Modo vista previa ---
                        Text("Listo para navegar")
                            .font(.headline)
                        
                        if let route = navigationManager.route {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Tiempo estimado")
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
                                    Text("Distancia")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatDistance(route.distance))
                                        .font(.title2).bold()
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Button {
                            startNavigation()
                        } label: {
                            Label("Iniciar Viaje", systemImage: "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
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
                .animation(.easeInOut(duration: 0.3), value: isNavigating)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            //navigationManager.calculateETA(from: //CLLocation(latitude: 4.6767, //longitude: -74.0483))
        }
    }
    
    // MARK: - INICIAR NAVEGACIÓN
    private func startNavigation() {
        isNavigating = true
        
        // Bajamos la cámara a nivel del usuario con pitch 3D y heading activo
        withAnimation(.easeInOut(duration: 1.2)) {
            cameraPosition = .userLocation(
                followsHeading: true,
                fallback: .automatic
            )
        }
        
        // Tras la animación, aplicamos el pitch 3D
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if let userLocation = CLLocationManager().location {
                withAnimation(.easeInOut(duration: 0.8)) {
                    cameraPosition = .camera(
                        MapCamera(
                            centerCoordinate: userLocation.coordinate,
                            distance: 300,       // Muy cerca del suelo
                            heading: userLocation.course >= 0 ? userLocation.course : 0,
                            pitch: 65            // Inclinación tipo Waze
                        )
                    )
                }
            }
        }
    }
    
    // MARK: - FORMATTERS
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        return minutes < 60 ? "\(minutes) min" : "\(minutes / 60)h \(minutes % 60)m"
    }
    
    private func formatDistance(_ meters: CLLocationDistance) -> String {
        return String(format: "%.1f km", meters / 1000)
    }
}

#Preview {
    ActiveNavigationView()
        .environmentObject(NavigationManager())
}

#Preview {
    ActiveNavigationView()
        .environmentObject(NavigationManager())
}
