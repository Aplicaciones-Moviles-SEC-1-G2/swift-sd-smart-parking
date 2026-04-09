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
            // MARK: - MAP
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
                
                Marker("SD Building", systemImage: "car.2.fill",
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
            
            // MARK: - CLOSE BUTTON (Fix problem 2)
            VStack {
                HStack {
                    //Spacer()
                    Button {
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
                    .padding(.top, 25) // Evita el notch
                    .padding(.leading, 25)
                    Spacer()
                }
                Spacer()
            }
            
            // MARK: - BOTTOM CARD (Fix problem 1: English Translation)
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 40, height: 5)
                    
                    if isNavigating, let route = navigationManager.route {
                        // --- Active Navigation Mode ---
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
                            dismiss()
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
                        // --- Preview Mode ---
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
                            startNavigation()
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
                .animation(.easeInOut(duration: 0.3), value: isNavigating)
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - LOGIC & FORMATTERS
    
    private func startNavigation() {
        isNavigating = true
        withAnimation(.easeInOut(duration: 1.2)) {
            cameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            // Nota: Aquí podrías necesitar inyectar el LocationManager para obtener la coordenada real
            withAnimation(.easeInOut(duration: 0.8)) {
                cameraPosition = .camera(
                    MapCamera(
                        centerCoordinate: CLLocationCoordinate2D(latitude: 4.6767, longitude: -74.0483), // Ejemplo
                        distance: 300,
                        heading: 0,
                        pitch: 65
                    )
                )
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
#Preview {
    ActiveNavigationView()
        .environmentObject(NavigationManager())
}

#Preview {
    ActiveNavigationView()
        .environmentObject(NavigationManager())
}
