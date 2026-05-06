//
//  SavedTripPlanTests.swift
//  sd-smart-parkingTests
//
//  In-memory SwiftData container exercising insert / fetch / sort / delete
//  on the SavedTripPlan @Model. Uses the public ModelContainer API rather
//  than touching the file system, so tests stay hermetic and parallelizable.
//

import Foundation
import SwiftData
import Testing
@testable import sd_smart_parking

@MainActor
private func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema([SavedTripPlan.self])
    let config = ModelConfiguration("test", schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}

@Suite("SavedTripPlan")
@MainActor
struct SavedTripPlanTests {

    @Test func insertAndFetchSingleTrip() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let arrival = Date(timeIntervalSince1970: 1_700_000_000)
        let leave = arrival.addingTimeInterval(3600)
        let trip = SavedTripPlan(
            arrivalDate: arrival,
            leaveDate: leave,
            parkingName: "SD Building Parking",
            estimatedCostCOP: 5000,
            wasExportedToCalendar: true
        )
        context.insert(trip)
        try context.save()

        let results = try context.fetch(FetchDescriptor<SavedTripPlan>())
        #expect(results.count == 1)
        #expect(results.first?.parkingName == "SD Building Parking")
        #expect(results.first?.estimatedCostCOP == 5000)
        #expect(results.first?.wasExportedToCalendar == true)
    }

    @Test func multipleTripsSortedByCreatedAtDescending() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let older = SavedTripPlan(
            arrivalDate: now,
            leaveDate: now.addingTimeInterval(3600),
            parkingName: "Old",
            estimatedCostCOP: 1000,
            createdAt: now
        )
        let newer = SavedTripPlan(
            arrivalDate: now.addingTimeInterval(7200),
            leaveDate: now.addingTimeInterval(10_800),
            parkingName: "New",
            estimatedCostCOP: 4000,
            createdAt: now.addingTimeInterval(60)
        )
        context.insert(older)
        context.insert(newer)
        try context.save()

        var descriptor = FetchDescriptor<SavedTripPlan>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 10
        let results = try context.fetch(descriptor)

        #expect(results.count == 2)
        #expect(results.first?.parkingName == "New")
        #expect(results.last?.parkingName == "Old")
    }

    @Test func deletingTripRemovesItFromStore() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let trip = SavedTripPlan(
            arrivalDate: Date(),
            leaveDate: Date().addingTimeInterval(3600),
            parkingName: "Temp",
            estimatedCostCOP: 2000
        )
        context.insert(trip)
        try context.save()

        context.delete(trip)
        try context.save()

        let results = try context.fetch(FetchDescriptor<SavedTripPlan>())
        #expect(results.isEmpty)
    }

    @Test func defaultsAreApplied() async throws {
        let trip = SavedTripPlan(
            arrivalDate: Date(),
            leaveDate: Date().addingTimeInterval(1800),
            parkingName: "Defaults",
            estimatedCostCOP: 1500
        )
        #expect(trip.wasExportedToCalendar == false)
        #expect(trip.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }
}

@Suite("TripExportSnapshot")
struct TripExportSnapshotTests {

    @Test func snapshotPropagatesAllFields() async throws {
        let arrival = Date(timeIntervalSince1970: 1_700_000_000)
        let leave = arrival.addingTimeInterval(7200)
        let snapshot = TripExportSnapshot(
            arrivalDate: arrival,
            leaveDate: leave,
            parkingName: "SD",
            estimatedCostCOP: 6000,
            wasExportedToCalendar: true
        )
        #expect(snapshot.arrivalDate == arrival)
        #expect(snapshot.leaveDate == leave)
        #expect(snapshot.parkingName == "SD")
        #expect(snapshot.estimatedCostCOP == 6000)
        #expect(snapshot.wasExportedToCalendar)
    }
}
