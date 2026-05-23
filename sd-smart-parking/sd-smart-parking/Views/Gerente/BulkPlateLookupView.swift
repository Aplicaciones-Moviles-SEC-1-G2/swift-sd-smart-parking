//
//  BulkPlateLookupView.swift
//  sd-smart-parking
//
//  Sprint 4 / Diego — multi-threading feature.
//
//  Gerente pastes/types several plates (newline, comma or whitespace
//  separated). Tapping "Search all" fans out one concurrent Firestore query
//  per plate via `BulkPlateLookupViewModel.search` (which uses
//  `withTaskGroup`). Result cards stream in incrementally as each child
//  task finishes.
//

import SwiftUI

struct BulkPlateLookupView: View {
    @EnvironmentObject private var parkingVM: ParkingViewModel
    @EnvironmentObject private var network: NetworkMonitor
    @StateObject private var vm = BulkPlateLookupViewModel()
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                if !network.isConnected {
                    OfflineNoticeBadge(
                        message: "Offline — searching the in-memory snapshot"
                    )
                    .padding(.horizontal)
                }

                if !vm.recentTerms.isEmpty {
                    recentSearchesCard
                }

                inputCard

                if let err = vm.lastError {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                if vm.servedFromLocalSnapshot && !vm.resultsByPlate.isEmpty {
                    Text("Showing cached snapshot (offline)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                resultsList
            }
            .padding(.top, 12)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Bulk Plate Lookup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") { vm.clear() }
                        .disabled(vm.rawInput.isEmpty && vm.resultsByPlate.isEmpty)
                }
            }
        }
    }

    // MARK: - Sub-views

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plates")
                .font(.subheadline.weight(.semibold))
            TextEditor(text: $vm.rawInput)
                .focused($inputFocused)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .frame(minHeight: 90, maxHeight: 140)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text("Separate by line, comma, or space. e.g. ABC123 DEF456")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button {
                    inputFocused = false
                    Task {
                        await vm.search(
                            isOnline: network.isConnected,
                            localFallback: parkingVM.vehicleRecords
                        )
                    }
                } label: {
                    Label("Search all", systemImage: "magnifyingglass.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(vm.rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }

    private var resultsList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(orderedPlates, id: \.self) { plate in
                    PlateResultCard(
                        plate: plate,
                        records: vm.resultsByPlate[plate] ?? [],
                        isLoading: vm.inFlight.contains(plate),
                        servedFromCache: vm.cachedPlates.contains(plate)
                    )
                }

                if vm.resultsByPlate.isEmpty && vm.inFlight.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private var recentSearchesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Recent searches", systemImage: "clock.arrow.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear", role: .destructive) { vm.clearRecentTerms() }
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.recentTerms, id: \.self) { term in
                        Button {
                            inputFocused = false
                            Task {
                                await vm.rerun(
                                    term: term,
                                    isOnline: network.isConnected,
                                    localFallback: parkingVM.vehicleRecords
                                )
                            }
                        } label: {
                            Text(displayLabel(for: term))
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.12))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func displayLabel(for term: String) -> String {
        let plates = vm.parsePlates(term)
        if plates.count <= 2 { return plates.joined(separator: ", ") }
        return "\(plates[0]), \(plates[1]) +\(plates.count - 2)"
    }

    private var orderedPlates: [String] {
        // Keep the plates in the order the Gerente typed them so the cards
        // don't jump around as TaskGroup children resolve out of order.
        let typed = vm.parsePlates(vm.rawInput)
        let extras = vm.resultsByPlate.keys.filter { !typed.contains($0) }
        return typed + extras.sorted()
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Enter plates above and tap Search all")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

// MARK: - Result card

private struct PlateResultCard: View {
    let plate: String
    let records: [VehicleRecord]
    let isLoading: Bool
    let servedFromCache: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(plate)
                    .font(.headline)
                if servedFromCache {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Served from cache")
                }
                Spacer()
                if isLoading {
                    ProgressView().scaleEffect(0.75)
                } else {
                    Text("\(records.count) record\(records.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !isLoading {
                if records.isEmpty {
                    Text("No records for this plate.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(records.prefix(5)) { rec in
                        HStack(spacing: 6) {
                            Image(systemName: rec.type.icon)
                                .foregroundStyle(rec.type.color)
                                .font(.caption)
                            Text(rec.type.label).font(.caption)
                            Spacer()
                            if let floor = rec.floor {
                                Text("Floor \(floor)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(rec.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if records.count > 5 {
                        Text("+ \(records.count - 5) more")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    BulkPlateLookupView()
        .environmentObject(ParkingViewModel())
        .environmentObject(NetworkMonitor.shared)
}
