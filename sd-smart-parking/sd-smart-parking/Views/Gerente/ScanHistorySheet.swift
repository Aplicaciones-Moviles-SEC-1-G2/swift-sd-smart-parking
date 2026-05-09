//
//  ScanHistorySheet.swift
//  sd-smart-parking
//
//  Lists the most recent AI vehicle scans persisted by ScanHistoryStore.
//

import SwiftUI

struct ScanHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [ScanHistoryEntry] = []

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("No scans saved yet.")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.identification.plate ?? "—")
                                    .font(.system(.body, design: .monospaced).bold())
                                Spacer()
                                Text(Self.dateFormatter.string(from: entry.scannedAt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text("\(entry.identification.brand.capitalized) · \(entry.identification.model.capitalized) · \(entry.identification.color.capitalized)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Scan History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                entries = ScanHistoryStore.shared.loadAll()
            }
        }
    }
}
