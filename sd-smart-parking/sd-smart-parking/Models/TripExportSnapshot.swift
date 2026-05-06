//
//  TripExportSnapshot.swift
//  sd-smart-parking
//
//  Plain value type the TripPlannerViewModel uses to hand off trip data to
//  the SwiftUI layer without ever touching the SwiftData @Model class.
//  Keeps the @Model entity isolated to MainActor (the view), avoiding data
//  races that would arise if the non-MainActor VM constructed a SavedTripPlan
//  and passed it across actor boundaries.
//

import Foundation

struct TripExportSnapshot {
    let arrivalDate: Date
    let leaveDate: Date
    let parkingName: String
    let estimatedCostCOP: Double
    let wasExportedToCalendar: Bool
}
