// ─────────────────────────────────────────────────────────────────────────
// SPRINT 4 — NEW VIEW + EVENTUAL CONNECTIVITY
// File: Views/Usuario/ActiveInfo/PersonalStatsView.swift
//
// Displays personal KPIs + weekday bar chart. On open, checks
// `networkMonitor.isConnected`: offline → serves NSCache/disk snapshot
// with orange banner; online → computes fresh via 5 concurrent async let.
// ─────────────────────────────────────────────────────────────────────────
import SwiftUI

struct PersonalStatsView: View {
    @EnvironmentObject var vm:             ParkingViewModel
    @EnvironmentObject var authVM:         AuthViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @StateObject private var statsVM =     PersonalStatsViewModel()
    @Environment(\.dismiss) private var dismiss

    private var userPlates: Set<String> {
        guard let cars = authVM.currentUser?.cars.allValues() else { return [] }
        return Set(cars.map { $0.plate.uppercased() })
    }

    private let weekdayOrder = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if !networkMonitor.isConnected {
                        offlineBanner
                    }
                    if statsVM.isLoading {
                        loadingCard
                    } else if let snap = statsVM.snapshot {
                        summaryRow(snap)
                        avgDurationCard(snap)
                        insightRow(snap)
                        weekdayChart(snap)
                        if statsVM.isOfflineCopy {
                            cacheFooter(snap)
                        }
                    } else {
                        emptyState
                    }
                }
                .padding()
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My Parking Stats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await statsVM.load(records: vm.userHistoryRecords,
                                                  userPlates: userPlates) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(statsVM.isLoading)
                }
            }
            .task {
                if !networkMonitor.isConnected {
                    statsVM.loadCachedIfOffline(userPlates: userPlates)
                } else {
                    await statsVM.load(records: vm.userHistoryRecords, userPlates: userPlates)
                }
            }
        }
    }

    // MARK: - Offline banner

    private var offlineBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
            VStack(alignment: .leading, spacing: 2) {
                Text("Offline — Showing cached stats")
                    .font(.caption.weight(.semibold))
                if let saved = statsVM.snapshot?.savedAt {
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

    // MARK: - Summary row

    private func summaryRow(_ snap: PersonalStatsSnapshot) -> some View {
        HStack(spacing: 12) {
            statCard(value: "\(snap.totalSessions)",
                     label: "Sessions", icon: "car.fill", color: .blue)
            statCard(value: formatHours(snap.totalHours),
                     label: "Total Time", icon: "clock.fill", color: .purple)
            statCard(value: formatCOP(snap.totalCostCOP),
                     label: "Total Paid", icon: "coloncurrencysign.circle.fill", color: .green)
        }
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title3).foregroundColor(color)
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - Avg duration card

    private func avgDurationCard(_ snap: PersonalStatsSnapshot) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Average Session")
                    .font(.caption).foregroundColor(.secondary)
                Text(formatHours(snap.avgDurationHours))
                    .font(.system(size: 28, weight: .bold)).foregroundColor(.blue)
            }
            Spacer()
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 44)).foregroundColor(.blue.opacity(0.2))
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - Insight row

    private func insightRow(_ snap: PersonalStatsSnapshot) -> some View {
        HStack(spacing: 12) {
            insightCard(
                title:    snap.busiestDayName ?? "—",
                subtitle: snap.busiestDayCount > 0 ? "\(snap.busiestDayCount) sessions" : "No data",
                icon:     "calendar", label: "Busiest Day", color: .orange)
            insightCard(
                title:    snap.mostUsedFloor.map { "Floor \($0)" } ?? "—",
                subtitle: snap.mostUsedFloorCount > 0 ? "\(snap.mostUsedFloorCount) visits" : "No data",
                icon:     "building.2.fill", label: "Favourite Floor", color: .indigo)
        }
    }

    private func insightCard(title: String, subtitle: String,
                              icon: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon).foregroundColor(color)
                Text(label).font(.caption).foregroundColor(.secondary)
            }
            Text(title).font(.title3.bold())
            Text(subtitle).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - Weekday chart

    @ViewBuilder
    private func weekdayChart(_ snap: PersonalStatsSnapshot) -> some View {
        let ordered = weekdayOrder.compactMap { day -> (String, Double)? in
            guard let avg = snap.weekdayAvgDurations[day], avg > 0 else { return nil }
            return (day, avg)
        }
        if !ordered.isEmpty {
            let maxVal = ordered.map(\.1).max() ?? 1.0
            VStack(alignment: .leading, spacing: 14) {
                Text("Avg Duration by Day of Week")
                    .font(.headline)
                ForEach(ordered, id: \.0) { day, avg in
                    HStack(spacing: 10) {
                        Text(day)
                            .font(.caption.weight(.semibold))
                            .frame(width: 30, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(height: 22)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue)
                                    .frame(width: geo.size.width * CGFloat(avg / maxVal),
                                           height: 22)
                            }
                        }
                        .frame(height: 22)
                        Text(String(format: "%.1fh", avg))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                            .frame(width: 38, alignment: .trailing)
                    }
                }
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - Loading / empty / cache footer

    private var loadingCard: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Computing your stats…")
                .font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(48)
        .background(Color.white)
        .cornerRadius(16)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 52)).foregroundColor(.gray.opacity(0.3))
            Text("No parking history yet")
                .font(.headline).foregroundColor(.secondary)
            Text("Stats will appear here once you have completed parking sessions.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(48)
    }

    private func cacheFooter(_ snap: PersonalStatsSnapshot) -> some View {
        Label("Cached \(snap.savedAt, style: .date)", systemImage: "archivebox")
            .font(.caption).foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Formatters

    private func formatHours(_ h: Double) -> String {
        guard h > 0 else { return "0m" }
        let whole = Int(h)
        let mins  = Int((h - Double(whole)) * 60)
        if whole == 0 { return "\(mins)m" }
        return mins > 0 ? "\(whole)h \(mins)m" : "\(whole)h"
    }

    private func formatCOP(_ amount: Double) -> String {
        let v = Int(amount)
        guard v >= 1000 else { return "$\(v)" }
        return "$\(v / 1000)K"
    }
}

#Preview {
    PersonalStatsView()
        .environmentObject(ParkingViewModel())
        .environmentObject(AuthViewModel())
        .environmentObject(NetworkMonitor.shared)
}
