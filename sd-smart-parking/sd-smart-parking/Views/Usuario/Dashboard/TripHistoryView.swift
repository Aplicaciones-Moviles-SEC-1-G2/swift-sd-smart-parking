//
//  TripHistoryView.swift
//  sd-smart-parking
//
//  Read-only listing of trips the driver has previously exported to the
//  Calendar. Backed by SwiftData via the @Query property wrapper, so the
//  list updates the moment a new SavedTripPlan is inserted from the
//  TripPlannerSheetView.
//
//  This is the user-facing surface of the SwiftData layer (relational store)
//  and complements the other local-storage strategies Diego owns:
//  @AppStorage (UserDefaults), Keychain, Codable+JSON file, and the
//  hash-based KeyValueStore.
//

import SwiftUI
import SwiftData

struct TripHistoryView: View {
    @Query(sort: \SavedTripPlan.createdAt, order: .reverse) private var trips: [SavedTripPlan]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private static let arrivalFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    ContentUnavailableView(
                        "No saved trips yet",
                        systemImage: "calendar.badge.clock",
                        description: Text("Export a trip to Calendar and it will appear here.")
                    )
                } else {
                    List {
                        ForEach(trips) { trip in
                            tripRow(trip)
                        }
                        .onDelete(perform: deleteTrips)
                    }
                }
            }
            .navigationTitle("Trip History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func tripRow(_ trip: SavedTripPlan) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(trip.parkingName)
                    .font(.headline)
                Spacer()
                if trip.wasExportedToCalendar {
                    Image(systemName: "calendar.badge.checkmark")
                        .foregroundColor(.green)
                        .accessibilityLabel("Exported to Calendar")
                }
            }
            Text("Arrival: \(Self.arrivalFormatter.string(from: trip.arrivalDate))")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Leave: \(Self.arrivalFormatter.string(from: trip.leaveDate))")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("COP \(Int(trip.estimatedCostCOP))")
                .font(.caption.bold())
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }

    private func deleteTrips(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(trips[index])
        }
        try? modelContext.save()
    }
}

#Preview {
    TripHistoryView()
        .modelContainer(for: SavedTripPlan.self, inMemory: true)
}
