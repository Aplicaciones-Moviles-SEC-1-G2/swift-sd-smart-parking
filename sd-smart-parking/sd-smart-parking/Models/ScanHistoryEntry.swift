//
//  ScanHistoryEntry.swift
//  sd-smart-parking
//
//  Local-only history entry for AI vehicle scans. Codable so it round-trips
//  through ScanHistoryStore (a separate FileManager-backed JSON store, not
//  Mateo's DiskPersistanceManager).
//

import Foundation

struct ScanHistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let identification: VehicleIdentification
    let scannedAt: Date
    let imageHashHex: String

    init(
        id: UUID = UUID(),
        identification: VehicleIdentification,
        scannedAt: Date = Date(),
        imageHashHex: String
    ) {
        self.id = id
        self.identification = identification
        self.scannedAt = scannedAt
        self.imageHashHex = imageHashHex
    }
}
