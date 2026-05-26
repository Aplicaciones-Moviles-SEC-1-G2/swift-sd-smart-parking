//
//  MyHistoryView.swift
//  sd-smart-parking
//
// ─────────────────────────────────────────────────────────────────────────
// SPRINT 4 — NEW VIEW + EVENTUAL CONNECTIVITY + CACHING
// File: Views/Usuario/ActiveInfo/MyHistoryView.swift
//
// Session history grouped by calendar month with filter picker (All/Week/
// Month/Year). Checks `networkMonitor.isConnected` on open: offline →
// loads from NSCache/disk (orange banner); online → builds fresh via actor.
// ─────────────────────────────────────────────────────────────────────────
import SwiftUI

struct MyHistoryView: View {
    @EnvironmentObject var vm:             ParkingViewModel
    @EnvironmentObject var authVM:         AuthViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @StateObject private var historyVM = ParkingHistoryViewModel()
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
                    if historyVM.isLoading {
                        loadingCard
                    } else if historyVM.allSessions.isEmpty {
                        emptyState
                    } else {
                        summaryCard
                        filterPicker
                        sessionGroups
                        if historyVM.isOfflineCopy, let ts = historyVM.lastUpdated {
                            Label("Cached \(ts, style: .date)", systemImage: "archivebox")
                                .font(.caption).foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
                .padding()
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await historyVM.load(records: vm.userHistoryRecords,
                                                    userPlates: userPlates) }
                    } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(historyVM.isLoading)
                }
            }
            .task {
                if !networkMonitor.isConnected {
                    historyVM.loadCachedIfOffline(userPlates: userPlates)
                } else {
                    await historyVM.load(records: vm.userHistoryRecords, userPlates: userPlates)
                }
            }
        }
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        let sessions = historyVM.filteredSessions
        let total    = sessions.count
        let hours    = sessions.reduce(0) { $0 + $1.durationHours }
        let spent    = sessions.reduce(0) { $0 + $1.costCOP }
        return HStack(spacing: 0) {
            statItem(value: "\(total)",          label: "Sessions")
            Divider().frame(height: 36)
            statItem(value: formatHours(hours),  label: "Total Time")
            Divider().frame(height: 36)
            statItem(value: formatCOP(spent),    label: "Total Paid")
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .bold))
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter picker

    private var filterPicker: some View {
        Picker("Filter", selection: $historyVM.filter) {
            ForEach(HistoryFilter.allCases) { f in
                Text(f.rawValue).tag(f)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Session groups

    @ViewBuilder
    private var sessionGroups: some View {
        if historyVM.filteredSessions.isEmpty {
            Text("No sessions in this period.")
                .font(.subheadline).foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 32)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(historyVM.sessionsByMonth, id: \.0) { month, sessions in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(month)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        ForEach(sessions) { session in
                            sessionRow(session)
                        }
                    }
                }
            }
        }
    }

    private func sessionRow(_ session: ParkingSession) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 44, height: 44)
                VStack(spacing: 0) {
                    Text("\(session.floor)")
                        .font(.headline.bold()).foregroundColor(.blue)
                    Text("F").font(.caption2).foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.plate)
                        .font(.subheadline.weight(.semibold).monospaced())
                    if session.hitCap {
                        Text("CAP")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.orange.opacity(0.18))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                }
                HStack(spacing: 4) {
                    Text(session.date, style: .date)
                    Text("·")
                    Text(session.date, style: .time)
                }
                .font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(formatHours(session.durationHours))
                    .font(.subheadline.weight(.semibold))
                Text(formatCOP(session.costCOP))
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    // MARK: - Offline banner

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
            VStack(alignment: .leading, spacing: 2) {
                Text("Showing cached history — live updates paused")
                    .font(.caption.weight(.medium))
                if let ts = historyVM.lastUpdated {
                    Text("Last updated \(ts, style: .relative) ago")
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

    // MARK: - Loading / empty

    private var loadingCard: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading history…")
                .font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(48)
        .background(Color.white)
        .cornerRadius(16)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.fill")
                .font(.system(size: 52)).foregroundColor(.gray.opacity(0.3))
            Text("No parking history yet")
                .font(.headline).foregroundColor(.secondary)
            Text("Your sessions will appear here once you start parking.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(48)
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
        let t = v / 1000
        let r = v % 1000
        return r > 0 ? "$\(t).\(String(format: "%03d", r))" : "$\(t).000"
    }
}

#Preview {
    MyHistoryView()
        .environmentObject(ParkingViewModel())
        .environmentObject(AuthViewModel())
        .environmentObject(NetworkMonitor.shared)
}
