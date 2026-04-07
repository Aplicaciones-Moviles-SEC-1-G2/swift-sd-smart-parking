//
//  User.swift
//  ParkingApp
//
//  Created by Mateo on 19/02/26.
//
import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    let name: String
    let email: String
    let password: String
    let cars: [Car]
    
    // Extrae todas las placas del usuario para la consulta
        var allPlates: [String] {
            cars.map { $0.normalizedPlate }
        }
    
    
}
