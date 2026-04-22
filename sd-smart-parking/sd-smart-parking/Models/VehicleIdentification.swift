//
//  VehicleIdentification.swift
//  sd-smart-parking
//
//  Result of the Gemini-based vehicle scan.
//

import Foundation

struct VehicleIdentification: Codable, Equatable {
    let plate: String?
    let plateVisible: Bool
    let color: String
    let brand: String
    let model: String

    var hasPlate: Bool {
        plateVisible && !(plate?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
    }
}
