//
//  TripExportSnapshot.swift
//  sd-smart-parking
//
//  DTO seam between TripPlannerViewModel and the SwiftUI layer that owns the
//  SwiftData @Model (SavedTripPlan). Keeps SwiftData types — which are
//  MainActor-bound by virtue of `@Model` — out of the VM surface. This is an
//  architectural boundary, NOT a fix for actor crossing: the VM is itself
//  MainActor-isolated under SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor. The
//  seam exists so the VM stays oblivious to the persistence layer and tests
//  can exercise export logic without standing up a ModelContainer.
//

import Foundation

struct TripExportSnapshot: Sendable {
    let arrivalDate: Date
    let leaveDate: Date
    let parkingName: String
    let estimatedCostCOP: Double
    let wasExportedToCalendar: Bool
}
