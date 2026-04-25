//
//  MyHistoryView.swift
//  sd-smart-parking
//

import SwiftUI

struct MyHistoryView: View {
    @EnvironmentObject var vm: ParkingViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @Environment(\.dismiss) private var dismiss

    private var userPlates: Set<String> {
        // Si el usuario es nil, devolvemos un Set vacío.
        // Si existe, usamos allValues() para obtener el array de Car.
        guard let cars = authVM.currentUser?.cars.allValues() else { return [] }
        return Set(cars.map { $0.plate.uppercased() })
    }

    private var userRecords: [VehicleRecord] {
        vm.vehicleRecords
            .filter { userPlates.contains($0.plate.uppercased()) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var completedSessions: [VehicleRecord] {
        userRecords.filter { $0.type == .exit }
    }

    private var totalHours: Double {
        completedSessions.compactMap { $0.durationHours }.reduce(0, +)
    }

    private var totalSpent: Double {
        completedSessions.compactMap { $0.durationHours }.reduce(0) {
            $0 + ParkingConfig.calculateFee(hours: $1, currentDayTotal: 0)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if !networkMonitor.isConnected {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("Showing cached history — live updates paused")
                                .font(.caption.weight(.medium))
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.orange)
                        .cornerRadius(10)
                    }
                    summaryCard
                    if userRecords.isEmpty {
                        emptyState
                    } else {
                        recordsList
                    }
                }
                .padding()
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        HStack(spacing: 0) {
            statItem(value: "\(completedSessions.count)", label: "Sessions")
            Divider().frame(height: 36)
            statItem(value: formatHours(totalHours), label: "Total Time")
            Divider().frame(height: 36)
            statItem(value: formatCOP(totalSpent), label: "Total Paid")
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Records list

    private var recordsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .padding(.horizontal, 4)

            ForEach(userRecords) { record in
                recordRow(record)
            }
        }
    }

    private func recordRow(_ record: VehicleRecord) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(record.type == .entry
                          ? Color.green.opacity(0.12)
                          : Color.blue.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: record.type == .entry
                      ? "arrow.down.circle.fill"
                      : "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(record.type == .entry ? .green : .blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.type == .entry ? "Entered" : "Exited")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(record.timestamp, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 6) {
                    if let floor = record.floor, let spot = record.spotNumber {
                        Label("F\(floor) · \(spot)", systemImage: "parkingsign")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(record.plate)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                    Text(record.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if record.type == .exit, let duration = record.durationHours {
                    let fee = ParkingConfig.calculateFee(hours: duration, currentDayTotal: 0)
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                        Text(formatHours(duration))
                        Text("·")
                        Text(formatCOP(fee))
                            .foregroundColor(.green)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.fill")
                .font(.system(size: 52))
                .foregroundColor(.gray.opacity(0.3))
            Text("No parking history yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Your sessions will appear here once you start parking.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(48)
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
}
