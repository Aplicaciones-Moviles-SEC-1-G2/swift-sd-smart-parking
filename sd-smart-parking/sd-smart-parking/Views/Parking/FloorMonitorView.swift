import SwiftUI

struct FloorMonitorView: View {
    @EnvironmentObject var vm:             ParkingViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @StateObject private var monitorVM =   FloorMonitorViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // Offline banner
                    if !networkMonitor.isConnected {
                        offlineBanner
                    }

                    // Last refreshed / loading indicator
                    refreshHeader

                    // Watched floors section
                    if !monitorVM.watchedSnapshots.isEmpty {
                        floorSection(
                            title:    "Watched Floors",
                            icon:     "star.fill",
                            color:    .orange,
                            snaps:    monitorVM.watchedSnapshots
                        )
                    }

                    // All floors section
                    floorSection(
                        title:  monitorVM.watchedSnapshots.isEmpty ? "All Floors" : "Other Floors",
                        icon:   "building.2",
                        color:  .blue,
                        snaps:  monitorVM.watchedSnapshots.isEmpty
                                    ? monitorVM.sortedSnapshots
                                    : monitorVM.unwatchedSnapshots
                    )
                }
                .padding()
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Floor Monitor")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await monitorVM.refresh(spots: vm.spots,
                                                       records: vm.vehicleRecords) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(monitorVM.isRefreshing)
                }
            }
            // Initial load + background refresh every 30 s for the view lifetime
            .task {
                await monitorVM.refresh(spots: vm.spots, records: vm.vehicleRecords)
                repeat {
                    try? await Task.sleep(for: .seconds(30))
                    guard !Task.isCancelled else { break }
                    await monitorVM.refresh(spots: vm.spots, records: vm.vehicleRecords)
                } while !Task.isCancelled
            }
            // Re-run concurrent refresh whenever live Firestore data changes
            .onChange(of: vm.spots.count) { _, _ in
                Task { await monitorVM.refresh(spots: vm.spots, records: vm.vehicleRecords) }
            }
        }
    }

    // MARK: - Refresh header

    private var refreshHeader: some View {
        HStack {
            if monitorVM.isRefreshing {
                ProgressView().scaleEffect(0.8)
                Text("Updating floors…")
                    .font(.caption).foregroundColor(.secondary)
            } else if let ts = monitorVM.lastRefreshed {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                Text("Updated \(ts, style: .relative) ago")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text("\(monitorVM.floorSnapshots.count) floors")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Offline banner

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text("Offline — showing last snapshot")
                .font(.caption.weight(.semibold))
            Spacer()
        }
        .foregroundColor(.white)
        .padding(12)
        .background(Color.orange)
        .cornerRadius(10)
    }

    // MARK: - Floor section

    private func floorSection(title: String, icon: String,
                               color: Color, snaps: [FloorSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(color)

            ForEach(snaps) { snap in
                floorCard(snap)
            }
        }
    }

    // MARK: - Floor card

    private func floorCard(_ snap: FloorSnapshot) -> some View {
        HStack(spacing: 16) {

            // Floor label
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(availabilityColor(snap).opacity(0.12))
                    .frame(width: 52, height: 52)
                VStack(spacing: 0) {
                    Text("\(snap.floor)")
                        .font(.title2.bold())
                        .foregroundColor(availabilityColor(snap))
                    Text("F")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }

            // Stats
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(snap.available) / \(snap.total) free")
                        .font(.subheadline.weight(.semibold))
                    trendIcon(snap.trend)
                }
                occupancyBar(snap)
                if snap.avgStayHours > 0 {
                    Text(String(format: "Avg stay: %.1f h", snap.avgStayHours))
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            Spacer()

            // Watch toggle
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    monitorVM.toggleWatch(floor: snap.floor)
                }
            } label: {
                Image(systemName: monitorVM.watchedFloors.contains(snap.floor)
                      ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundColor(monitorVM.watchedFloors.contains(snap.floor)
                                     ? .orange : .gray.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - Sub-components

    private func trendIcon(_ trend: FloorSnapshot.Trend) -> some View {
        Group {
            switch trend {
            case .up:
                Image(systemName: "arrow.up.circle.fill").foregroundColor(.green)
            case .down:
                Image(systemName: "arrow.down.circle.fill").foregroundColor(.red)
            case .same:
                Image(systemName: "minus.circle.fill").foregroundColor(.secondary)
            }
        }
        .font(.caption)
    }

    private func occupancyBar(_ snap: FloorSnapshot) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(Color(.systemGray5))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 3)
                    .fill(availabilityColor(snap))
                    .frame(width: geo.size.width * CGFloat(1 - snap.occupancyPct), height: 6)
            }
        }
        .frame(height: 6)
    }

    private func availabilityColor(_ snap: FloorSnapshot) -> Color {
        let pct = snap.total > 0 ? Double(snap.available) / Double(snap.total) : 0
        if pct > 0.5 { return .green }
        if pct > 0.2 { return .orange }
        return .red
    }
}

#Preview {
    FloorMonitorView()
        .environmentObject(ParkingViewModel())
        .environmentObject(NetworkMonitor.shared)
}
