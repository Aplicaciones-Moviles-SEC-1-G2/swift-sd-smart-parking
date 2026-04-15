//
//  SpotsView.swift
//  ParkingApp
//
//  Created by Mateo on 19/02/26.
//

import SwiftUI

struct SpotsView: View {
    @EnvironmentObject var vm: ParkingViewModel
    @EnvironmentObject var authVM: AuthViewModel

    @State private var expandedFloors: Set<Int> = []
    @State private var pendingBulkFree          = false
    @State private var pendingBulkOccupy        = false

    let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]

    var sortedFloors: [Int] {
        Dictionary(grouping: vm.spots, by: { $0.floor }).keys.sorted()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    // Recommendation banner (driver only)
                    if !authVM.isGerente,
                       let recommended = vm.recommendedFloor {
                        let avail = vm.floorAvailability[recommended]?.available ?? 0
                        let floorSpots = vm.spots
                            .filter { $0.floor == recommended && $0.isAvailable }
                            .sorted { $0.number < $1.number }
                            .prefix(3)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.green)
                                Text("Best floor: Floor \(recommended)")
                                    .font(.headline)
                                FloorBadge(isUrgent: avail <= 4)
                                Spacer()
                            }

                            Text("\(avail) spots available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            LazyVGrid(columns: columns, spacing: 15) {
                                ForEach(Array(floorSpots)) { spot in
                                    SpotCardView(spot: spot, isGerente: false)
                                }
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.05))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }

                    ForEach(sortedFloors, id: \.self) { floor in // <- usar aquí
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Floor \(floor)")
                                    .font(.headline)
                                    .foregroundColor(.secondary)

                                if !authVM.isGerente,
                                   let recommended = vm.recommendedFloor,
                                   recommended == floor {
                                    let avail = vm.floorAvailability[floor]?.available ?? 0
                                    FloorBadge(isUrgent: avail <= 4)
                                }
                            }
                            .padding(.horizontal)
                            
                            LazyVGrid(columns: columns, spacing: 15) {
                                ForEach(vm.spots.filter { $0.floor == floor }.sorted(by: { $0.number < $1.number })) { spot in
                                    SpotCardView(spot: spot, isGerente: authVM.isGerente)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(authVM.isGerente ? "Spot Management" : "Availability")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { syncExpandedFloors() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear { syncExpandedFloors() }
            .onChange(of: vm.totalAvailable) { _, _ in syncExpandedFloors() }
            .onChange(of: vm.spots.count)    { _, _ in syncExpandedFloors() }
            .alert("Free all spots?", isPresented: $pendingBulkFree) {
                Button("Free All", role: .destructive) { vm.freeAllSpots() }
                Button("Cancel", role: .cancel) { }
            } message: { Text("All reservations will be cleared.") }
            .alert("Occupy all spots?", isPresented: $pendingBulkOccupy) {
                Button("Occupy All", role: .destructive) { vm.occupyAllSpots() }
                Button("Cancel", role: .cancel) { }
            } message: { Text("All spots will be marked as occupied.") }
        }
    }

    // MARK: - Floor expand/collapse sync

    private func syncExpandedFloors() {
        for floor in sortedFloors {
            let hasAvailable = vm.spots.filter { $0.floor == floor }.contains { $0.isAvailable }
            if hasAvailable { expandedFloors.insert(floor) }
            else            { expandedFloors.remove(floor) }
        }
    }

    // MARK: - All Occupied (passenger, no active spot)

    private var allOccupiedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "parkingsign.circle.fill")
                .font(.system(size: 88))
                .foregroundStyle(.red.opacity(0.75))

            VStack(spacing: 8) {
                Text("Parking Full")
                    .font(.title.bold())
                Text("All spots are currently occupied.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let mins = estimatedMinutesUntilFree {
                Label("Est. next spot free in ~\(mins) min", systemImage: "clock.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
            }

            Text("Wait in the external queue or check back shortly.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var estimatedMinutesUntilFree: Int? {
        let durations = vm.vehicleRecords
            .filter { $0.type == .exit }
            .compactMap { $0.durationHours }
        guard !durations.isEmpty else { return nil }
        let avgHours = durations.reduce(0, +) / Double(durations.count)

        guard let oldest = vm.vehicleRecords
            .filter({ $0.type == .entry })
            .min(by: { $0.timestamp < $1.timestamp }) else { return nil }

        let parkedHours = Date().timeIntervalSince(oldest.timestamp) / 3600
        let remaining   = max(0.083, avgHours - parkedHours)
        return Int(remaining * 60)
    }

    // MARK: - Blocking view (user already has a spot)

    @ViewBuilder
    private func activeSpotBlockView(spot: ParkingSpot) -> some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            VStack(spacing: 8) {
                Text("Spot \(spot.number) — Floor \(spot.floor)")
                    .font(.title2.bold())
                Text("You currently have this spot reserved.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Text("Free your spot first to browse or reserve a different one.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Button {
                withAnimation(.spring()) { vm.releaseSpot(spot) }
            } label: {
                Label("Free My Spot", systemImage: "lock.open.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: 260)
                    .background(Color.orange)
                    .cornerRadius(16)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Normal spots grid

    private var spotsScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Admin bulk controls (reserved for future use)

                // Duplicate reservations warning (admin only)
                if authVM.isGerente {
                    let dupes = vm.duplicateSpotGroups
                    if !dupes.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                                Text("Duplicate Reservations").font(.headline)
                            }
                            ForEach(dupes, id: \.email) { group in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(group.email).font(.caption.bold())
                                    Text("→ Spots \(group.spots.map { "\($0.number)" }.joined(separator: ", "))")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(14)
                        .padding(.horizontal)
                    }
                }

                // Best floor recommendation (driver only)
                if !authVM.isGerente, let recommended = vm.recommendedFloor {
                    let avail      = vm.floorAvailability[recommended]?.available ?? 0
                    let floorSpots = vm.spots
                        .filter { $0.floor == recommended && $0.isAvailable }
                        .sorted { $0.number < $1.number }
                        .prefix(3)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles").foregroundColor(.green)
                            Text("Best floor: Floor \(recommended)").font(.headline)
                            FloorBadge(isUrgent: avail <= 4)
                            Spacer()
                        }
                        Text("\(avail) spots available").font(.subheadline).foregroundColor(.secondary)
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(Array(floorSpots)) { spot in
                                SpotCardView(spot: spot, isGerente: false)
                            }
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }

                // Per-floor collapsible sections
                ForEach(sortedFloors, id: \.self) { floor in
                    floorSection(floor: floor)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Collapsible floor section

    @ViewBuilder
    private func floorSection(floor: Int) -> some View {
        let floorSpots      = vm.spots.filter { $0.floor == floor }.sorted { $0.number < $1.number }
        let available       = floorSpots.filter { $0.isAvailable }.count
        let isExpanded      = expandedFloors.contains(floor)
        let isFullyOccupied = available == 0

        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    if isExpanded { expandedFloors.remove(floor) }
                    else          { expandedFloors.insert(floor) }
                }
            } label: {
                HStack {
                    Text("Floor \(floor)")
                        .font(.headline)
                        .foregroundColor(isFullyOccupied ? .secondary : .primary)
                    if !authVM.isGerente,
                       let recommended = vm.recommendedFloor,
                       recommended == floor {
                        FloorBadge(isUrgent: available <= 4)
                    }
                    Spacer()
                    if isFullyOccupied {
                        Text("Full")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(6)
                    } else {
                        Text("\(available) free")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(floorSpots) { spot in
                        SpotCardView(spot: spot, isGerente: authVM.isGerente)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 15)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

#Preview("Usuario Normal") {
    SpotsView()
        .environmentObject(ParkingViewModel())
        .environmentObject(AuthViewModel())
}

#Preview("Gerente") {
    let auth = AuthViewModel()
    auth.isGerente = true
    return SpotsView()
        .environmentObject(ParkingViewModel())
        .environmentObject(auth)
}
