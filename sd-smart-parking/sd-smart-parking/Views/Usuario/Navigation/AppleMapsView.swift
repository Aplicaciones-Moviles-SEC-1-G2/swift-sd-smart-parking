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
        .onChange(of: navManager.route) { oldRoute, newRoute in
                    if newRoute != nil {
                        updateCamera() // Ahora sí, llamamos a la función que vive aquí
                    }
                }
                .onAppear {
                    // Enfocar cache inicial si existe
                    updateCamera()
                }
    }
    
    private func updateCamera() {
        // Intentamos obtener la polilínea real, y si no, la cacheada
        let polyline = navManager.route?.polyline ?? navManager.cachedPolyline
        
        guard let targetPolyline = polyline else {
            print("⚠️ No hay ruta real ni cacheada para enfocar")
            return
        }
        
        var rect = targetPolyline.boundingMapRect
        let paddingFactor = 1.2 // Aumenté un poco el padding para que respire más el mapa
        
        rect = rect.insetBy(
            dx: -rect.size.width * (paddingFactor - 1),
            dy: -rect.size.height * (paddingFactor - 1)
        )
        
        withAnimation(.easeInOut(duration: 0.8)) {
            cameraPosition = .rect(rect)
        }
    }
}
