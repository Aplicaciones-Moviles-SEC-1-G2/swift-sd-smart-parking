//
//  PersonalizedRecommendationTests.swift
//  sd-smart-parkingTests
//

import Foundation
import Testing
@testable import sd_smart_parking

// MARK: - Helpers

/// Build N spots on a single floor where the first `available` spots (by index)
/// are free. Spot numbers follow the production scheme: floor*100 + index.
private func makeFloor(_ floor: Int, available: Int, total: Int) -> [ParkingSpot] {
    (1...total).map { idx in
        ParkingSpot(
            id: UUID(),
            number: floor * 100 + idx,
            floor: floor,
            isAvailable: idx <= available
        )
    }
}

/// Build a custom set of spots for a floor by passing the indices that should
/// be available. Used to verify "lowest-numbered available spot" picks.
private func makeFloor(_ floor: Int, total: Int, freeIndices: Set<Int>) -> [ParkingSpot] {
    (1...total).map { idx in
        ParkingSpot(
            id: UUID(),
            number: floor * 100 + idx,
            floor: floor,
            isAvailable: freeIndices.contains(idx)
        )
    }
}

private func vm(spots: [ParkingSpot]) -> ParkingViewModel {
    let vm = ParkingViewModel()
    vm.spots = spots
    return vm
}

// MARK: - PersonalizedRecommendation tests

@Suite("personalizedRecommendation")
struct PersonalizedRecommendationTests {

    // MARK: No preferences → generic path

    @Test func noPrefs_clearWinner_genericReason() {
        let v = vm(spots:
            makeFloor(1, available: 3, total: 20)
            + makeFloor(2, available: 10, total: 20)
            + makeFloor(3, available: 5, total: 20)
        )
        let rec = v.personalizedRecommendation(for: nil)
        #expect(rec?.floor == 2)
        #expect(rec?.reason == .generic)
        // Lowest-numbered free spot on F2 has index 1 → number = 201
        #expect(rec?.spot?.number == 201)
    }

    @Test func noPrefs_tie_returnsNil() {
        let v = vm(spots:
            makeFloor(1, available: 10, total: 20)
            + makeFloor(2, available: 9, total: 20)
        )
        #expect(v.personalizedRecommendation(for: nil) == nil)
    }

    // MARK: Mobility-aware path

    @Test func mobility_picksLowestFloorWithAvailability() {
        let prefs = UserPreferences(hasMobilityLimitation: true, preferredFloor: nil)
        let v = vm(spots:
            makeFloor(1, available: 2, total: 20)
            + makeFloor(2, available: 10, total: 20)
        )
        let rec = v.personalizedRecommendation(for: prefs)
        #expect(rec?.floor == 1)
        #expect(rec?.reason == .mobility)
        #expect(rec?.spot?.number == 101)
    }

    @Test func mobility_skipsFullLowerFloor() {
        let prefs = UserPreferences(hasMobilityLimitation: true, preferredFloor: nil)
        let v = vm(spots:
            makeFloor(1, available: 0, total: 20)
            + makeFloor(2, available: 5, total: 20)
            + makeFloor(3, available: 10, total: 20)
        )
        let rec = v.personalizedRecommendation(for: prefs)
        #expect(rec?.floor == 2)
        #expect(rec?.reason == .mobility)
    }

    @Test func mobility_allFull_returnsNil() {
        let prefs = UserPreferences(hasMobilityLimitation: true, preferredFloor: nil)
        let v = vm(spots:
            makeFloor(1, available: 0, total: 20)
            + makeFloor(2, available: 0, total: 20)
        )
        #expect(v.personalizedRecommendation(for: prefs) == nil)
    }

    @Test func mobility_pickIsLowestNumberedFreeSpot() {
        // Floor 1 has indices {3, 5} free → lowest free number = 103
        let prefs = UserPreferences(hasMobilityLimitation: true, preferredFloor: nil)
        let v = vm(spots: makeFloor(1, total: 10, freeIndices: [3, 5]))
        let rec = v.personalizedRecommendation(for: prefs)
        #expect(rec?.floor == 1)
        #expect(rec?.spot?.number == 103)
    }

    // MARK: Preferred-floor path

    @Test func preferredFloor_withAvailability_winsOverGeneric() {
        // Generic winner would be Floor 3 (most spots), but driver prefers Floor 2.
        let prefs = UserPreferences(hasMobilityLimitation: false, preferredFloor: 2)
        let v = vm(spots:
            makeFloor(1, available: 1, total: 20)
            + makeFloor(2, available: 4, total: 20)
            + makeFloor(3, available: 15, total: 20)
        )
        let rec = v.personalizedRecommendation(for: prefs)
        #expect(rec?.floor == 2)
        #expect(rec?.reason == .preferredFloor)
        #expect(rec?.spot?.number == 201)
    }

    @Test func preferredFloor_full_mobilityOff_fallsBackToGeneric() {
        let prefs = UserPreferences(hasMobilityLimitation: false, preferredFloor: 2)
        let v = vm(spots:
            makeFloor(1, available: 2, total: 20)
            + makeFloor(2, available: 0, total: 20)
            + makeFloor(3, available: 10, total: 20)
        )
        let rec = v.personalizedRecommendation(for: prefs)
        #expect(rec?.floor == 3)
        if case .preferredFloorFull(let fallback) = rec?.reason {
            #expect(fallback == 3)
        } else {
            Issue.record("Expected .preferredFloorFull reason, got \(String(describing: rec?.reason))")
        }
    }

    @Test func preferredFloor_full_mobilityOn_fallsBackToLowestAvailableFloor() {
        // Preferred floor full + mobility on → fall back to mobility logic
        // (lowest floor with availability), not the generic recommendation.
        let prefs = UserPreferences(hasMobilityLimitation: true, preferredFloor: 2)
        let v = vm(spots:
            makeFloor(1, available: 3, total: 20)
            + makeFloor(2, available: 0, total: 20)
            + makeFloor(3, available: 15, total: 20)
        )
        let rec = v.personalizedRecommendation(for: prefs)
        #expect(rec?.floor == 1)
        if case .preferredFloorFull(let fallback) = rec?.reason {
            #expect(fallback == 1)
        } else {
            Issue.record("Expected .preferredFloorFull(fallback: 1), got \(String(describing: rec?.reason))")
        }
        // Spot pick is the lowest-numbered free spot on the fallback floor.
        #expect(rec?.spot?.number == 101)
    }

    @Test func preferredFloor_full_mobilityOn_allOtherFloorsFull_returnsNil() {
        let prefs = UserPreferences(hasMobilityLimitation: true, preferredFloor: 2)
        let v = vm(spots:
            makeFloor(1, available: 0, total: 20)
            + makeFloor(2, available: 0, total: 20)
            + makeFloor(3, available: 0, total: 20)
        )
        #expect(v.personalizedRecommendation(for: prefs) == nil)
    }

    @Test func preferredFloor_full_andTieElsewhere_returnsNil() {
        // Preferred floor full, generic tie within threshold → no usable fallback.
        let prefs = UserPreferences(hasMobilityLimitation: false, preferredFloor: 2)
        let v = vm(spots:
            makeFloor(1, available: 10, total: 20)
            + makeFloor(2, available: 0, total: 20)
            + makeFloor(3, available: 9, total: 20)
        )
        #expect(v.personalizedRecommendation(for: prefs) == nil)
    }

    @Test func preferredFloor_outOfRange_treatedAsFallback() {
        // Floor 99 doesn't exist; algorithm should fall through to generic
        // (no `preferredFloorFull` hint since the floor was never present).
        let prefs = UserPreferences(hasMobilityLimitation: false, preferredFloor: 99)
        let v = vm(spots:
            makeFloor(1, available: 3, total: 20)
            + makeFloor(2, available: 10, total: 20)
        )
        let rec = v.personalizedRecommendation(for: prefs)
        #expect(rec?.floor == 2)
        #expect(rec?.reason == .generic)
    }

    // MARK: Preferred floor wins over mobility (university classroom rationale)

    @Test func preferredFloor_overridesMobility() {
        // Wheelchair user has class on Floor 3 — they should park on Floor 3
        // in the spot closest to the elevator, NOT on Floor 1 which would
        // force them to take the elevator to reach class.
        let prefs = UserPreferences(hasMobilityLimitation: true, preferredFloor: 3)
        let v = vm(spots:
            makeFloor(1, available: 5, total: 20)
            + makeFloor(2, available: 8, total: 20)
            + makeFloor(3, available: 10, total: 20)
        )
        let rec = v.personalizedRecommendation(for: prefs)
        #expect(rec?.floor == 3)
        #expect(rec?.reason == .preferredFloor)
        // Closest-to-elevator spot on F3 = lowest spot number on F3 = 301.
        #expect(rec?.spot?.number == 301)
    }

    // MARK: Generic spot pick is the lowest-numbered free spot

    @Test func generic_picksLowestNumberedSpotOnWinningFloor() {
        // Generic winner is Floor 1 with free spots at indices {5, 10, 12, 15};
        // Floor 2 has 0 free → gap = 4 > 2, so the tie-suppression rule does
        // NOT trigger. Lowest-numbered free spot on F1 is index 5 → number 105.
        let v = vm(spots:
            makeFloor(1, total: 20, freeIndices: [5, 10, 12, 15])
            + makeFloor(2, available: 0, total: 20)
        )
        let rec = v.personalizedRecommendation(for: nil)
        #expect(rec?.floor == 1)
        #expect(rec?.spot?.number == 105)
    }

    // MARK: Backward compatibility — UserPreferences default init

    @Test func defaultPreferences_haveNoEffect() {
        // Default UserPreferences == no mobility, no preferred floor → generic.
        let prefs = UserPreferences()
        let v = vm(spots:
            makeFloor(1, available: 2, total: 20)
            + makeFloor(2, available: 10, total: 20)
        )
        let rec = v.personalizedRecommendation(for: prefs)
        #expect(rec?.floor == 2)
        #expect(rec?.reason == .generic)
    }
}

// MARK: - UserPreferences (de)serialization

@Suite("UserPreferences serialization")
struct UserPreferencesSerializationTests {

    @Test func roundTrip_firestore_fullPayload() {
        let prefs = UserPreferences(hasMobilityLimitation: true, preferredFloor: 3)
        let dict = prefs.toFirestore()
        #expect(dict["hasMobilityLimitation"] as? Bool == true)
        #expect(dict["preferredFloor"] as? Int == 3)
        let decoded = UserPreferences(firestore: dict)
        #expect(decoded == prefs)
    }

    @Test func roundTrip_firestore_omitsNilFloor() {
        let prefs = UserPreferences(hasMobilityLimitation: false, preferredFloor: nil)
        let dict = prefs.toFirestore()
        #expect(dict["preferredFloor"] == nil)
        let decoded = UserPreferences(firestore: dict)
        #expect(decoded?.preferredFloor == nil)
        #expect(decoded?.hasMobilityLimitation == false)
    }

    @Test func nilFirestoreData_returnsNil() {
        #expect(UserPreferences(firestore: nil) == nil)
    }
}
