//
//  VehicleRecord.swift
//  ParkingApp
//
//  Created by Mateo on 27/02/26.
//
import Foundation
import SwiftUI
import FirebaseFirestore

struct VehicleRecord: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let plate: String
    let type: RecordType
    let timestamp: Date
    let floor: Int?
    let spotNumber: Int?
    let photoURL: String?
    let isRegistered: Bool
    let ownerEmail: String?
    var ocrConfidence: Double // 0.0 a 1.0
    var needsReview: Bool { ocrConfidence < 0.75 }
    var durationHours: Double?      // <- agregar
    var hitDailyCap: Bool = false
}

enum RecordType: String, Codable {
    case entry = "entry"
    case exit = "exit"
    
    var label: String {
        self == .entry ? "Entrada" : "Salida"
    }
    
    var icon: String {
        self == .entry ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
    }
    
    var color: Color {
        self == .entry ? .green : .red
    }
}
