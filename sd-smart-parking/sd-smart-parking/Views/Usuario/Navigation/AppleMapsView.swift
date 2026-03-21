//
//  AppleMapsView.swift
//  ParkingApp
//
//  Created by Mateo on 26/02/26.
//
import SwiftUI
import MapKit


struct AppleMapsView: View {
    
    @ObservedObject var navManager: NavigationManager
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasSetInitialCamera = false  // ✅ Solo centrar una vez
    
    var body: some View {
        Map(position: $cameraPosition) {
            
            // Usuario
            UserAnnotation()  // ✅ Más eficiente que un Marker con userLocation
            
            // Destino
            Marker("SD Building", coordinate: navManager.destination)
                .tint(.blue)
            
            // Ruta
            if let route = navManager.route {
                MapPolyline(route.polyline)
                    .stroke(.blue, lineWidth: 6)
            }
        }
        .mapStyle(.standard)
        .onChange(of: navManager.route) {
            // ✅ Solo mover la cámara la primera vez que llega la ruta
            guard !hasSetInitialCamera else { return }
            hasSetInitialCamera = true
            updateCamera()
        }
    }
    
    private func updateCamera() {
        guard let route = navManager.route else { return }
        
        var rect = route.polyline.boundingMapRect
        let paddingFactor = 1.1
        rect = rect.insetBy(
            dx: -rect.size.width * (paddingFactor - 1),
            dy: -rect.size.height * (paddingFactor - 1)
        )
        
        withAnimation(.easeInOut(duration: 0.8)) {  // ✅ Animación suave
            cameraPosition = .rect(rect)
        }
    }
}
