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
    @Published var lastUpdateDate: Date?
    @Published var userLocation: CLLocation?
    @Published var route: MKRoute?
    @Published var travelTime: String = "Calculating..."
    @Published var distance: String = "-- km"
    @Published var isNavigating: Bool = false
    @Published var cachedPolyline: MKPolyline?
    private var lastCalculationDate = Date()
    private let cacheFileName = "last_route_cache.json"
    
    private let locationManager = CLLocationManager()
    private var currentDirections: MKDirections?
    private var lastRouteCalculationLocation: CLLocation?  // ✅ Throttle
    
    // En NavigationManager
    @Published var isOffline: Bool = false
    private var networkCancellable: AnyCancellable?

    func observeNetwork(from userRepository: UserRepository) {
        networkCancellable = userRepository.$isOffline
            .receive(on: DispatchQueue.main)
            .assign(to: \.isOffline, on: self)
    }
    
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
        
        let timeSinceLastUpdate = Date().timeIntervalSince(lastCalculationDate)
        // ✅ Solo recalcula si el usuario se movió más de 50m o pasaron 5 minutos
        if let last = lastRouteCalculationLocation,
               location.distance(from: last) < 50 && timeSinceLastUpdate < 300 {
                return
            }
        lastCalculationDate = Date()
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
                self.lastUpdateDate = Date()
                self.savePreviewCache()
            }
        }
    }
    // MARK: - Guardar ruta en cache
    private func saveRouteToCache(route: MKRoute) {
        // Extraemos los puntos de la polilínea
        let count = route.polyline.pointCount
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: count)
        route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))
        
        let cachedCoords = coords.map { CachedNavigationData.Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
        
        let data = CachedNavigationData(
            coordinates: cachedCoords,
            expectedTravelTime: route.expectedTravelTime,
            distance: route.distance,
            destinationName: "SD Building",
            lastUpdated: Date()
        )
        
        DiskPersistenceManager.shared.save(data, to: cacheFileName)
    }
    
    func loadCachedRoute() {
        guard let cached: CachedNavigationData = DiskPersistenceManager.shared.load(filename: cacheFileName, type: CachedNavigationData.self) else { return }
        
        // Convertimos de vuelta a MKPolyline para mostrar en el mapa
        let points = cached.coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let polyline = MKPolyline(coordinates: points, count: points.count)
        
        // Aquí necesitamos una pequeña lógica para mostrar esta polilínea aunque no sea un MKRoute completo
        self.travelTime = "\(Int(cached.expectedTravelTime / 60)) min (Cached)"
        self.distance = String(format: "%.1f km", cached.distance / 1000)
        // Podrías crear una variable @Published var cachedPolyline: MKPolyline?
    }
    
    // MARK: - Terminar navegación
    
    func endNavigation() {
        isNavigating = false  // ✅ Solo detiene la navegación, no borra la ruta
    }
    
    // MARK: - Cache para preview
    func savePreviewCache() {
        UserDefaults.standard.set(self.travelTime, forKey: "cached_travel_time")
        UserDefaults.standard.set(self.distance, forKey: "cached_distance")
        UserDefaults.standard.set(Date(), forKey: "cached_date")
    }

    func loadPreviewCache() {
        self.travelTime = UserDefaults.standard.string(forKey: "cached_travel_time") ?? "-- min"
        self.distance = UserDefaults.standard.string(forKey: "cached_distance") ?? "-- km"
        self.lastUpdateDate = UserDefaults.standard.object(forKey: "cached_date") as? Date
    }
    
    
    func refreshRoute() {
        guard let location = userLocation else { return }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(location: location, address: nil)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
            request.destination = MKMapItem(location: destinationLocation, address: nil)
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        
        directions.calculate { [weak self] response, error in
            guard let self = self, let route = response?.routes.first else {
                if let error = error { print("❌ Error en ruta: \(error.localizedDescription)") }
                return
            }
            
            DispatchQueue.main.async {
                    // 1. Actualizamos los datos
                    self.route = route
                    self.travelTime = "\(Int(route.expectedTravelTime / 60)) min"
                    self.distance = String(format: "%.1f km", route.distance / 1000)
                    
                    // 2. Persistencia
                    self.savePreviewCache()
                    
                    print("✅ Ruta actualizada y cámara enfocada")
                }
        }
    }
}
