//
//  User.swift
//  ParkingApp
//
//  Created by Mateo on 19/02/26.
//
import Foundation

struct User: Identifiable, Codable{
    let id: UUID
    let name: String
    let email: String
    let password: String

    //var cars: [Car]
    var cars: ArrayMap<String, Car>

    //var cars: [Car]

    var preferences: UserPreferences?


    // Extrae todas las placas del usuario para la consulta
        var allPlates: [String] {
            //cars.map { $0.normalizedPlate }
            cars.allValues().map { $0.normalizedPlate }
        }


}
