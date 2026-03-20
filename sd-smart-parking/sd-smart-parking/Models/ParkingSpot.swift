//
//  ParkingSpot.swift
//  ParkingApp
//
//  Created by Mateo on 19/02/26.
//

import Foundation

struct ParkingSpot: Identifiable, Codable {
    let id: UUID
    let number: Int
    let floor: Int
    var isAvailable: Bool
    
    // Propiedad útil para cálculos rápidos en la interfaz
    var isOccupied: Bool {
        !isAvailable
    }
}
