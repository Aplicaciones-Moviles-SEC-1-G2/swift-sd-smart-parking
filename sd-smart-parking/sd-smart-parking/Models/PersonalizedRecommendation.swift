//
//  PersonalizedRecommendation.swift
//  sd-smart-parking
//

import Foundation

/// Result returned by `ParkingViewModel.personalizedRecommendation(for:)`.
/// Carries the floor pick, an optional spot to highlight, and the reason
/// the recommendation was chosen so the UI can explain itself.
struct PersonalizedRecommendation {
    enum Reason: Equatable {
        /// Driver has a mobility limitation — pick the lowest floor with availability.
        case mobility
        /// Driver picked this floor and it has availability.
        case preferredFloor
        /// Driver picked a floor but it's full; we recommend `fallback` instead.
        case preferredFloorFull(fallback: Int)
        /// No preferences set; behaves like the original recommendation engine.
        case generic
    }

    let floor: Int
    let spot: ParkingSpot?
    let reason: Reason
}
