//
//  GoogleMapsView.swift
//  ParkingApp
//
//  Created by Mateo on 26/02/26.
//
import SwiftUI
import GoogleMaps


struct GoogleMapsView: UIViewRepresentable {
    let latitude: Double = 4.6014
    let longitude: Double = -74.0649
    
    func makeUIView(context: Context) -> GMSMapView {
        // 1. Create the camera as usual
        let camera = GMSCameraPosition.camera(withLatitude: latitude,
                                            longitude: longitude,
                                            zoom: 16.0)
        
        // 2. NEW for iOS 26: Create an Options object
        let options = GMSMapViewOptions()
        options.camera = camera
        options.frame = .zero // SwiftUI handles the actual sizing
        
        // 3. Initialize with the Options object
        let mapView = GMSMapView(options: options)
        
        // Add marker
        let marker = GMSMarker()
        marker.position = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        marker.title = "SD Building"
        marker.map = mapView
        
        return mapView
    }
    
    func updateUIView(_ uiView: GMSMapView, context: Context) {
        // Handle updates here
    }
}
