//
//  NetworkMonitor.swift
//  sd-smart-parking
//
//  Created by Mateo on 16/04/26.
//
import Foundation

enum ActionType: String, Codable {
    case addCar
    case occupySpace
    case updateProfile
    case updatePreferences
}

struct PendingAction: Identifiable, Codable {
    let id: UUID
    let type: ActionType
    let payload: Data // Aquí guardaremos el Carro o el Registro convertido a bytes
    let createdAt: Date
    
    init<T: Codable>(type: ActionType, data: T) {
        self.id = UUID()
        self.type = type
        self.createdAt = Date()
        // Convertimos cualquier objeto (Car, User, etc) a Data para guardarlo genéricamente
        self.payload = (try? JSONEncoder().encode(data)) ?? Data()
    }
}




