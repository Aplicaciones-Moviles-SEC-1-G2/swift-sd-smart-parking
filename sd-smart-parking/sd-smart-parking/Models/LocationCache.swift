//
//  LocationCache.swift
//  sd-smart-parking
//
//  Created by Mateo on 2/05/26.
//
import Foundation

struct CachedNavigationData: Codable {
    let coordinates: [Coordinate]
    let expectedTravelTime: TimeInterval
    let distance: Double
    let destinationName: String
    let lastUpdated: Date
    
    struct Coordinate: Codable {
        let latitude: Double
        let longitude: Double
    }
}
