//
//  Car.swift
//  ParkingApp
//
//  Created by Mateo on 25/02/26.
//
import Foundation

struct Car: Identifiable, Codable {
    let id: UUID
    let plate: String
    let UserID: String
    let name: String
    //var isSynced: Bool = true

    var normalizedPlate: String {
            plate.uppercased().replacingOccurrences(of: " ", with: "")
        }

}
