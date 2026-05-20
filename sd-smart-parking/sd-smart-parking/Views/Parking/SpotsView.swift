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
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var userRepo: UserRepository

    @State private var expandedFloors: Set<Int> = []
    @State private var pendingBulkFree          = false
    @State private var pendingBulkOccupy        = false
    @State private var showPreferencesSheet     = false
    @State private var showFloorMonitor         = false

    let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]

    var sortedFloors: [Int] {
        Dictionary(grouping: vm.spots, by: { $0.floor }).keys.sorted()
    }

    /// Personalized recommendation for the current driver. `nil` for managers
    /// or when no recommendation is possible (e.g. all spots full / suppressed tie).
    private var personalized: PersonalizedRecommendation? {
        guard !authVM.isGerente else { return nil }
        return vm.personalizedRecommendation(for: userRepo.currentUser?.preferences)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {

                    // MARK: - Offline Banner
                    if !networkMonitor.isConnected {
                        HStack(spacing: 8) {
                            Image(systemName: "wifi.slash")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Offline — Cached Spot Data")
                                    .font(.caption.weight(.semibold))
                                Text("Changes are queued and will sync when reconnected.")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.orange)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Recommendation banner (driver only)
                    if !authVM.isGerente,
                       userRepo.currentUser?.preferences == nil {
                        preferencesHeroBanner()
                    }

                    // Personalized recommendation banner (driver only).
                    // Includes a low-key "Edit preferences" pill at the bottom
                    // so a driver who already has preferences can tweak them.
                    if let rec = personalized {
                        recommendationBanner(rec)
                    }

                    ForEach(sortedFloors, id: \.self) { floor in
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Floor \(floor)")
                                    .font(.headline)
                                    .foregroundColor(.secondary)

                                if let rec = personalized, rec.floor == floor {
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
                ToolbarItem(placement: .navigationBarLeading) {
                    if !authVM.isGerente {
                        Button {
                            showFloorMonitor = true
                        } label: {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                        }
                    }
                }
            }
            .sheet(isPresented: $showFloorMonitor) {
                FloorMonitorView()
                    .environmentObject(vm)
                    .environmentObject(networkMonitor)
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
            .sheet(isPresented: $showPreferencesSheet) {
                EditProfileView()
            }
        }
    }

    // MARK: - Personalized banner

    @ViewBuilder
    private func recommendationBanner(_ rec: PersonalizedRecommendation) -> some View {
        let avail = vm.floorAvailability[rec.floor]?.available ?? 0
        let preview = vm.spots
            .filter { $0.floor == rec.floor && $0.isAvailable }
            .sorted { $0.number < $1.number }
            .prefix(3)
        let mobility = userRepo.currentUser?.preferences?.hasMobilityLimitation ?? false

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: bannerIcon(rec.reason, mobility: mobility))
                    .foregroundColor(bannerTint(rec.reason))
                Text(bannerTitle(rec))
                    .font(.headline)
                FloorBadge(isUrgent: avail <= 4)
                Spacer()
            }

            Text(bannerSubtitle(rec, available: avail, mobility: mobility))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(Array(preview)) { spot in
                    SpotCardView(spot: spot, isGerente: false)
                }
            }

            // Low-key "Edit preferences" pill — always visible inside the
            // recommendation banner so the driver can tweak prefs in-context.
            // Hidden only when the driver has no prefs yet (the prominent
            // standalone hero above is doing that job).
            if userRepo.currentUser?.preferences != nil {
                Button {
                    showPreferencesSheet = true
                } label: {
                    Label("Edit preferences", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(bannerTint(rec.reason).opacity(0.06))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    /// Standalone hero shown to drivers with no preferences set. Always renders
    /// when `currentUser?.preferences == nil`, regardless of whether a generic
    /// recommendation exists below it — the goal is to make personalization
    /// the first thing a fresh driver notices on the Spots tab.
    @ViewBuilder
    private func preferencesHeroBanner() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Personalize your spot")
                        .font(.title3.bold())
                    Text("Tell us your preferred floor or if you need a mobility-friendly spot — we'll tailor every recommendation to you.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                showPreferencesSheet = true
            } label: {
                Label("Set my parking preferences", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.14), Color.blue.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.blue.opacity(0.25), lineWidth: 1)
        )
        .cornerRadius(18)
        .padding(.horizontal)
    }

    private func bannerTitle(_ rec: PersonalizedRecommendation) -> String {
        switch rec.reason {
        case .mobility:
            return "Mobility-friendly: Floor \(rec.floor)"
        case .preferredFloor:
            return "Your preferred floor: Floor \(rec.floor)"
        case .preferredFloorFull:
            return "Best available: Floor \(rec.floor)"
        case .generic:
            return "Best floor: Floor \(rec.floor)"
        }
    }

    /// Subtitle text. When the driver has a mobility limitation we always
    /// surface the elevator-proximity note (the spot pick is always the
    /// lowest-numbered free spot, which is the closest to the elevator), so
    /// the message stays accurate whether we landed on the preferred floor,
    /// the lowest available floor, or the generic recommendation.
    private func bannerSubtitle(_ rec: PersonalizedRecommendation, available: Int, mobility: Bool) -> String {
        var parts = ["\(available) spot\(available == 1 ? "" : "s") available"]
        if mobility, let spot = rec.spot {
            parts.append("Spot \(spot.number) is closest to the elevator")
        }
        if case .preferredFloorFull(let fallback) = rec.reason {
            parts.append("Your preferred floor is full, recommending Floor \(fallback) instead")
        }
        return parts.joined(separator: " · ")
    }

    private func bannerIcon(_ reason: PersonalizedRecommendation.Reason, mobility: Bool) -> String {
        // When mobility is on but the chosen reason is preferred-floor, surface
        // a wheelchair glyph so the visual still signals accessibility.
        if mobility, case .preferredFloor = reason { return "figure.roll" }
        switch reason {
        case .mobility:           return "figure.roll"
        case .preferredFloor:     return "star.fill"
        case .preferredFloorFull: return "arrow.triangle.swap"
        case .generic:            return "sparkles"
        }
    }

    private func bannerTint(_ reason: PersonalizedRecommendation.Reason) -> Color {
        switch reason {
        case .mobility:           return .blue
        case .preferredFloor:     return .purple
        case .preferredFloorFull: return .orange
        case .generic:            return .green
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
