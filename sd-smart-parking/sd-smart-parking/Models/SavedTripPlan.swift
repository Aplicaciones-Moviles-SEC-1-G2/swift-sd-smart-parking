//
//  SavedTripPlan.swift
//  sd-smart-parking
//
//  SwiftData model that records a Trip Planner export so the user can review
//  past planned trips offline. Lives in its own SwiftData store — independent
//  from Mateo's DiskPersistanceManager (Codable+JSON) and from any Firestore
//  schema, so it counts as a distinct local-storage strategy for the rubric.
//
//  Insertion happens ONLY from the SwiftUI view (MainActor by default).
//  TripPlannerViewModel never instantiates this @Model directly; it exposes
//  a plain `TripExportSnapshot` struct so we never cross actor boundaries
//  with a SwiftData entity.
//

import Foundation
import SwiftData

@Model
final class SavedTripPlan {
    @Attribute(.unique) var id: UUID
    var arrivalDate: Date
    var leaveDate: Date
    var parkingName: String
    var estimatedCostCOP: Double
    var createdAt: Date
    var wasExportedToCalendar: Bool

    init(
        id: UUID = UUID(),
        arrivalDate: Date,
        leaveDate: Date,
        parkingName: String,
        estimatedCostCOP: Double,
        createdAt: Date = Date(),
        wasExportedToCalendar: Bool = false
    ) {
        self.id = id
        self.arrivalDate = arrivalDate
        self.leaveDate = leaveDate
        self.parkingName = parkingName
        self.estimatedCostCOP = estimatedCostCOP
        self.createdAt = createdAt
        self.wasExportedToCalendar = wasExportedToCalendar
    }
}
