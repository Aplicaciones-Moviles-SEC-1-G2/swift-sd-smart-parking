//
//  ParkingSpot.swift
//  ParkingApp
//
//  Created by Mateo on 19/02/26.
//

import Foundation

struct ParkingSpot: Identifiable, Codable, Equatable {
    let id: UUID
    let number: Int
    let floor: Int
    var isAvailable: Bool
    var reservedByEmail: String?

    var isOccupied: Bool { !isAvailable }
}
