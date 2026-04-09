//
//  ParkingViewModelTests.swift
//  sd-smart-parkingTests
//

import Foundation
import Testing
@testable import sd_smart_parking

// MARK: - Helpers

private func makeSpot(floor: Int, index: Int, available: Bool) -> ParkingSpot {
    ParkingSpot(
        id: UUID(),
        number: floor * 100 + index,
        floor: floor,
        isAvailable: available
    )
}

private func makeFloor(_ floor: Int, available: Int, total: Int) -> [ParkingSpot] {
    (1...total).map { i in
        makeSpot(floor: floor, index: i, available: i <= available)
    }
}

// MARK: - floorAvailability tests

@Suite("floorAvailability")
struct FloorAvailabilityTests {

    @Test func emptySpots() {
        let vm = ParkingViewModel()
        vm.spots = []
        #expect(vm.floorAvailability.isEmpty)
    }

    @Test func singleFloorAllAvailable() {
        let vm = ParkingViewModel()
        vm.spots = makeFloor(1, available: 5, total: 5)
        let fa = vm.floorAvailability
        #expect(fa[1]?.available == 5)
        #expect(fa[1]?.total == 5)
    }

    @Test func twoFloorsMixed() {
        let vm = ParkingViewModel()
        vm.spots = makeFloor(1, available: 3, total: 5) + makeFloor(2, available: 1, total: 5)
        let fa = vm.floorAvailability
        #expect(fa[1]?.available == 3)
        #expect(fa[1]?.total == 5)
        #expect(fa[2]?.available == 1)
        #expect(fa[2]?.total == 5)
    }
}

// MARK: - recommendedFloor tests

@Suite("recommendedFloor")
struct RecommendedFloorTests {

    @Test func clearWinner() {
        let vm = ParkingViewModel()
        vm.spots = makeFloor(1, available: 10, total: 20)
                 + makeFloor(2, available: 3, total: 20)
                 + makeFloor(3, available: 5, total: 20)
        #expect(vm.recommendedFloor == 1)
    }

    @Test func tieWithinThreshold() {
        let vm = ParkingViewModel()
        vm.spots = makeFloor(1, available: 10, total: 20)
                 + makeFloor(2, available: 9, total: 20)
        #expect(vm.recommendedFloor == nil)
    }

    @Test func tieExactlyAtThreshold() {
        let vm = ParkingViewModel()
        vm.spots = makeFloor(1, available: 10, total: 20)
                 + makeFloor(2, available: 7, total: 20)
        #expect(vm.recommendedFloor == 1)
    }

    @Test func allFull() {
        let vm = ParkingViewModel()
        vm.spots = makeFloor(1, available: 0, total: 20)
                 + makeFloor(2, available: 0, total: 20)
        #expect(vm.recommendedFloor == nil)
    }

    @Test func allEqualAvailability() {
        let vm = ParkingViewModel()
        vm.spots = makeFloor(1, available: 10, total: 20)
                 + makeFloor(2, available: 10, total: 20)
                 + makeFloor(3, available: 10, total: 20)
        #expect(vm.recommendedFloor == nil)
    }

    @Test func singleFloor() {
        let vm = ParkingViewModel()
        vm.spots = makeFloor(1, available: 5, total: 20)
        #expect(vm.recommendedFloor == 1)
    }

    @Test func emptySpots() {
        let vm = ParkingViewModel()
        vm.spots = []
        #expect(vm.recommendedFloor == nil)
    }
}

// MARK: - Urgency threshold tests

@Suite("urgency")
struct UrgencyTests {

    @Test func urgentAt4Spots() {
        let vm = ParkingViewModel()
        vm.spots = makeFloor(1, available: 4, total: 20)
                 + makeFloor(2, available: 0, total: 20)
        let avail = vm.floorAvailability[1]?.available ?? 0
        #expect(avail <= 4)
    }

    @Test func notUrgentAt5Spots() {
        let vm = ParkingViewModel()
        vm.spots = makeFloor(1, available: 5, total: 20)
                 + makeFloor(2, available: 0, total: 20)
        let avail = vm.floorAvailability[1]?.available ?? 0
        #expect(avail > 4)
    }
}
