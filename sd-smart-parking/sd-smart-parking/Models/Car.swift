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
    let UserID: UUID
    let name: String


}
