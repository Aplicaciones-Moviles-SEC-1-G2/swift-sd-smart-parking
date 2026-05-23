//
//  PinnedPlatesView.swift
//  sd-smart-parking
//
//  Sprint 4 / Diego — local-storage feature.
//
//  Lists the plates the Gerente has bookmarked. Reads from
//  PinnedPlatesViewModel which is backed by KeyValueStore on disk. Tapping
//  a row jumps into the matching record via the existing RecordDetailView;
//  if no record exists yet the row shows "no records" and acts purely as
//  the pinned bookmark.
//

import SwiftUI

struct PinnedPlatesView: View {
    @EnvironmentObject private var parkingVM: ParkingViewModel
    @StateObject private var vm = PinnedPlatesViewModel()
    @State private var selectedRecord: VehicleRecord? = nil
    @State private var noteDraftFor: PinnedPlate? = nil
    @State private var noteDraftText: String = ""

    var body: some View {
        NavigationStack {
            Group {
                if vm.pinned.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(vm.pinned) { entry in
                            row(entry)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        vm.unpin(entry.plate)
                                    } label: {
                                        Label("Unpin", systemImage: "star.slash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        noteDraftFor = entry
                                        noteDraftText = entry.note ?? ""
                                    } label: {
                                        Label("Note", systemImage: "square.and.pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Pinned Plates")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedRecord) { record in
                RecordDetailView(record: record)
                    .environmentObject(parkingVM)
            }
            .sheet(item: $noteDraftFor) { entry in
                noteEditor(for: entry)
            }
        }
    }

    // MARK: - Row

    private func row(_ entry: PinnedPlate) -> some View {
        Button {
            if let rec = mostRecentRecord(for: entry.plate) {
                selectedRecord = rec
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.plate)
                        .font(.headline)
                    if let note = entry.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Text("Pinned \(entry.pinnedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if let rec = mostRecentRecord(for: entry.plate) {
                    VStack(alignment: .trailing) {
                        Image(systemName: rec.type.icon)
                            .foregroundStyle(rec.type.color)
                        Text(rec.timestamp.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No records")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func mostRecentRecord(for plate: String) -> VehicleRecord? {
        parkingVM.vehicleRecords
            .filter { $0.plate.uppercased() == plate }
            .sorted { $0.timestamp > $1.timestamp }
            .first
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "star")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text("No pinned plates yet")
                .font(.headline)
            Text("Pin a plate from the vehicle registry to keep it one tap away here.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Note editor

    private func noteEditor(for entry: PinnedPlate) -> some View {
        NavigationStack {
            Form {
                Section("Note for \(entry.plate)") {
                    TextField("Optional note", text: $noteDraftText, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { noteDraftFor = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.updateNote(entry.plate, note: noteDraftText)
                        noteDraftFor = nil
                    }
                }
            }
        }
    }
}

#Preview {
    PinnedPlatesView()
        .environmentObject(ParkingViewModel())
}
