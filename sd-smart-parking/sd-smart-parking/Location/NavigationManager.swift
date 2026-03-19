//
//  NavigationManager.swift
//  ParkingApp
//
//  Created by Mateo on 26/02/26.
//

import Foundation
import CoreLocation
import MapKit
import Combine

class NavigationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    @Published var userLocation: CLLocation?
    @Published var route: MKRoute?
    @Published var travelTime: String = "Calculating..."
    @Published var distance: String = "-- km"
    @Published var isNavigating: Bool = false
    
    private let locationManager = CLLocationManager()
    private var currentDirections: MKDirections?
    private var lastRouteCalculationLocation: CLLocation?  // ✅ Throttle
    
    let destination = CLLocationCoordinate2D(latitude: 4.6014, longitude: -74.0649)
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // ✅ Ignorar lecturas imprecisas o muy viejas
        guard location.horizontalAccuracy < 50,
              location.timestamp.timeIntervalSinceNow > -10 else { return }
        
        userLocation = location
        calculateRoute(from: location)
    }
    
    // MARK: - Calcular ETA desde un punto fijo (para preview/simulación)
    
    private let edificioSD = CLLocation(latitude: 4.6014, longitude: -74.0649)
    
    func calculateETA(from startLocation: CLLocation) {
        let request = MKDirections.Request()
        request.source = MKMapItem(location: startLocation, address: nil)
        request.destination = MKMapItem(location: edificioSD, address: nil)
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let route = response?.routes.first else { return }
            
            DispatchQueue.main.async {
                self?.route = route
                self?.travelTime = "\(Int(route.expectedTravelTime / 60)) min"
                self?.distance = String(format: "%.1f km", route.distance / 1000)
            }
        }
    }
    
    // MARK: - Calcular ruta desde ubicación real del GPS
    
    private func calculateRoute(from location: CLLocation) {
        
        // ✅ Solo recalcula si el usuario se movió más de 50m
        if let last = lastRouteCalculationLocation,
           location.distance(from: last) < 50 { return }
        
        lastRouteCalculationLocation = location
        currentDirections?.cancel()
        
        let request = MKDirections.Request()
        request.source = MKMapItem(location: location, address: nil)
        
        let destLocation = CLLocation(latitude: destination.latitude,
                                      longitude: destination.longitude)
        let destinationItem = MKMapItem(location: destLocation, address: nil)
        destinationItem.name = "SD Building"
        
        request.destination = destinationItem
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        currentDirections = directions
        
        directions.calculate { [weak self] response, error in
            guard let self = self else { return }
            guard let route = response?.routes.first else { return }
            
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute]
            formatter.unitsStyle = .abbreviated
            
            DispatchQueue.main.async {
                self.route = route
                self.travelTime = formatter.string(from: route.expectedTravelTime) ?? "--"
                self.distance = String(format: "%.1f km", route.distance / 1000)
            }
        }
    }
    
    // MARK: - Terminar navegación
    
    func endNavigation() {
        isNavigating = false  // ✅ Solo detiene la navegación, no borra la ruta
    }
}
