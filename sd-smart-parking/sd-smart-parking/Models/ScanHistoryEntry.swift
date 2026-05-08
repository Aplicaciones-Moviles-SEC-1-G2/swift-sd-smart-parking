//
//  ScanHistoryEntry.swift
//  sd-smart-parking
//
//  Local-only history entry for AI vehicle scans. Codable so it round-trips
//  through ScanHistoryStore (a separate FileManager-backed JSON store, not
//  Mateo's DiskPersistanceManager).
//

import Foundation

/// Codable evolution rule: any new field MUST be optional or have a Codable
/// default. Otherwise decoding historical entries fails, `ScanHistoryStore`
/// falls back to `[]`, and the user's local scan history is silently wiped on
/// the next launch after a schema change.
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
