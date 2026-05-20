import SwiftUI

struct CostBreakdownView: View {
    @EnvironmentObject var vm:             ParkingViewModel
    @EnvironmentObject var authVM:         AuthViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @StateObject private var costVM = CostBreakdownViewModel()
    @Environment(\.dismiss) private var dismiss

    private var userPlates: Set<String> {
        guard let cars = authVM.currentUser?.cars.allValues() else { return [] }
        return Set(cars.map { $0.plate.uppercased() })
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if !networkMonitor.isConnected { offlineBanner }
                    if costVM.isLoading {
                        loadingCard
                    } else if let snap = costVM.snapshot {
                        kpiRow(snap)
                        monthlyChart(snap)
                        floorCostCard(snap)
                        if costVM.isOfflineCopy { cacheFooter(snap) }
                    } else {
                        emptyState
                    }
                }
                .padding()
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Cost Breakdown")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await costVM.load(records: vm.vehicleRecords,
                                                 userPlates: userPlates) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(costVM.isLoading)
                }
            }
            .task {
                if !networkMonitor.isConnected {
                    costVM.loadCachedIfOffline(userPlates: userPlates)
                } else {
                    await costVM.load(records: vm.vehicleRecords, userPlates: userPlates)
                }
            }
        }
    }

    // MARK: - Offline banner

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            VStack(alignment: .leading, spacing: 2) {
                Text("Offline — Showing cached breakdown")
                    .font(.caption.weight(.semibold))
                if let saved = costVM.snapshot?.savedAt {
                    Text("Last updated \(saved, style: .relative) ago")
                        .font(.caption2).foregroundColor(.white.opacity(0.85))
                }
            }
            Spacer()
        }
        .foregroundColor(.white)
        .padding(12)
        .background(Color.orange)
        .cornerRadius(10)
    }

    // MARK: - KPI row

    private func kpiRow(_ snap: CostBreakdownSnapshot) -> some View {
        HStack(spacing: 12) {
            kpiCard(value: formatCOP(snap.totalAllTime),
                    label: "All-time Spent",
                    icon: "coloncurrencysign.circle.fill", color: .green)
            kpiCard(value: formatCOP(snap.avgPerSession),
                    label: "Avg / Session",
                    icon: "chart.bar.fill", color: .blue)
            kpiCard(value: String(format: "%.0f%%", snap.capHitPct),
                    label: "Hit Daily Cap",
                    icon: "exclamationmark.circle.fill",
                    color: snap.capHitPct > 20 ? .orange : .green)
        }
    }

    private func kpiCard(value: String, label: String,
                          icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title3).foregroundColor(color)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .minimumScaleFactor(0.55).lineLimit(1)
            Text(label)
                .font(.caption2).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - Monthly spending chart

    @ViewBuilder
    private func monthlyChart(_ snap: CostBreakdownSnapshot) -> some View {
        if !snap.monthlyPoints.isEmpty {
            let maxCost = snap.monthlyPoints.map(\.totalCOP).max() ?? 1.0
            VStack(alignment: .leading, spacing: 14) {
                Text("Monthly Spending")
                    .font(.headline)
                ForEach(snap.monthlyPoints) { point in
                    HStack(spacing: 10) {
                        Text(point.month)
                            .font(.caption.weight(.semibold))
                            .frame(width: 68, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.green.opacity(0.12))
                                    .frame(height: 22)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.green)
                                    .frame(
                                        width: geo.size.width * CGFloat(point.totalCOP / maxCost),
                                        height: 22
                                    )
                            }
                        }
                        .frame(height: 22)
                        Text(formatCOP(point.totalCOP))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                            .frame(width: 52, alignment: .trailing)
                    }
                }
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - Cost by floor

    @ViewBuilder
    private func floorCostCard(_ snap: CostBreakdownSnapshot) -> some View {
        let sorted = snap.costPerFloor.sorted { $0.value > $1.value }
        if !sorted.isEmpty {
            let maxCost = sorted.first?.value ?? 1.0
            VStack(alignment: .leading, spacing: 14) {
                Text("Avg Cost by Floor")
                    .font(.headline)
                ForEach(sorted, id: \.key) { floor, avg in
                    HStack(spacing: 10) {
                        Text(floor)
                            .font(.caption.weight(.semibold))
                            .frame(width: 56, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.indigo.opacity(0.12))
                                    .frame(height: 22)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.indigo)
                                    .frame(
                                        width: geo.size.width * CGFloat(avg / maxCost),
                                        height: 22
                                    )
                            }
                        }
                        .frame(height: 22)
                        Text(formatCOP(avg))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                            .frame(width: 52, alignment: .trailing)
                    }
                }
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - Loading / empty / footer

    private var loadingCard: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Computing cost breakdown…")
                .font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(48)
        .background(Color.white)
        .cornerRadius(16)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "coloncurrencysign.circle")
                .font(.system(size: 52)).foregroundColor(.gray.opacity(0.3))
            Text("No spending data yet")
                .font(.headline).foregroundColor(.secondary)
            Text("Cost breakdown will appear once you have completed parking sessions.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(48)
    }

    private func cacheFooter(_ snap: CostBreakdownSnapshot) -> some View {
        Label("Cached \(snap.savedAt, style: .date)", systemImage: "archivebox")
            .font(.caption).foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func formatCOP(_ v: Double) -> String {
        let i = Int(v)
        if i >= 1_000_000 { return "$\(i / 1_000_000)M" }
        if i >= 1_000     { return "$\(i / 1_000)K" }
        return "$\(i)"
    }
}

#Preview {
    CostBreakdownView()
        .environmentObject(ParkingViewModel())
        .environmentObject(AuthViewModel())
        .environmentObject(NetworkMonitor.shared)
}
