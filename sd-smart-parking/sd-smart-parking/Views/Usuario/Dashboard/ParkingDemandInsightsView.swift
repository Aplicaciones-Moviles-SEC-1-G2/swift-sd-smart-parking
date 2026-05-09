//
//  ParkingDemandInsightsView.swift
//  sd-smart-parking
//

import SwiftUI
import Charts

/// Sheet opened from the dashboard banner. Shows hourly entry/exit patterns
/// pulled from Firestore and surfaces the quietest arrival and departure
/// windows so drivers can plan around the crowd.
struct ParkingDemandInsightsView: View {
    let records: [VehicleRecord]
    let openingHour: Int
    let closingHour: Int
    /// Day type the sheet should open on — defaults to the one matching today.
    let initialBucket: Bucket
    /// Timestamp of the most recent record at presentation time. Used to
    /// surface freshness info when the device is offline. Optional to keep
    /// existing call sites backward-compatible.
    let lastSyncedAt: Date?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @State private var bucket: Bucket

    /// Read-side mirror of the EditProfile toggle that the user owns. When off
    /// the sheet collapses to a `ContentUnavailableView` so the dashboard's
    /// banner trigger remains intact (Mateo's territory) without breaking
    /// the user's stated preference.
    @AppStorage("diego.profile.showDemandBadgeOnDashboard")
    private var showDemandBadge: Bool = true

    enum Bucket: String, CaseIterable, Identifiable {
        case weekday = "Weekdays"
        case weekend = "Weekends"
        var id: String { rawValue }
        var isWeekend: Bool { self == .weekend }
    }

    init(
        records: [VehicleRecord],
        openingHour: Int,
        closingHour: Int,
        initialBucket: Bucket = Self.defaultBucket(for: Date()),
        lastSyncedAt: Date? = nil
    ) {
        self.records = records
        self.openingHour = openingHour
        self.closingHour = closingHour
        self.initialBucket = initialBucket
        self.lastSyncedAt = lastSyncedAt
        self._bucket = State(initialValue: initialBucket)
    }

    private static let lastSyncedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    private static func defaultBucket(for date: Date) -> Bucket {
        let weekday = Calendar.current.component(.weekday, from: date)
        return (weekday == 1 || weekday == 7) ? .weekend : .weekday
    }

    private var insights: ParkingDemandInsights {
        ParkingDemandInsights.build(from: records)
    }

    private var entryCounts: [ParkingDemandInsights.HourlyCount] {
        let all = bucket.isWeekend ? insights.weekendEntryCounts : insights.weekdayEntryCounts
        return all.filter { (openingHour..<closingHour).contains($0.hour) }
    }

    private var exitCounts: [ParkingDemandInsights.HourlyCount] {
        let all = bucket.isWeekend ? insights.weekendExitCounts : insights.weekdayExitCounts
        return all.filter { (openingHour..<closingHour).contains($0.hour) }
    }

    private var bucketTotals: (entries: Int, exits: Int) {
        insights.totalForBucket(weekend: bucket.isWeekend)
    }

    private var bestEntryHours: [ParkingDemandInsights.HourlyCount] {
        insights.bestEntryHours(
            weekend: bucket.isWeekend,
            openingHour: openingHour,
            closingHour: closingHour
        )
    }

    private var bestExitHours: [ParkingDemandInsights.HourlyCount] {
        insights.bestExitHours(
            weekend: bucket.isWeekend,
            openingHour: openingHour,
            closingHour: closingHour
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if showDemandBadge {
                    insightsScroll
                } else {
                    ContentUnavailableView(
                        "Insights hidden",
                        systemImage: "eye.slash",
                        description: Text("Re-enable from Profile → Edit Profile.")
                    )
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Parking Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var insightsScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Day type", selection: $bucket) {
                    ForEach(Bucket.allCases) { b in Text(b.rawValue).tag(b) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                sampleSizeCaption

                chartCard(
                    title: "Arrivals per hour",
                    caption: "How many cars enter each hour historically",
                    data: entryCounts,
                    color: .blue
                )

                chartCard(
                    title: "Departures per hour",
                    caption: "How many cars leave each hour historically",
                    data: exitCounts,
                    color: .purple
                )

                recommendationCard(
                    title: "Best times to arrive",
                    subtitle: "Hours with the fewest recorded arrivals — easiest to find a spot",
                    icon: "arrow.down.circle.fill",
                    tint: .green,
                    hours: bestEntryHours
                )

                recommendationCard(
                    title: "Best times to leave",
                    subtitle: "Hours with the fewest recorded departures — avoid the exit rush",
                    icon: "arrow.up.circle.fill",
                    tint: .indigo,
                    hours: bestExitHours
                )
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var sampleSizeCaption: some View {
        let totals = bucketTotals
        let captionText = totals.entries + totals.exits == 0
            ? "No historic records for \(bucket.rawValue.lowercased()) yet. Come back after a few days of activity."
            : "Based on \(totals.entries) arrivals and \(totals.exits) departures recorded on \(bucket.rawValue.lowercased())."
        VStack(alignment: .leading, spacing: 6) {
            // TODO: replace `lastSyncedAt` source with a dedicated
            // `ParkingViewModel.lastFetchedAt: Date?`. Today the dashboard call
            // site passes `vehicleRecords.first?.timestamp`, which only works
            // while that array is sorted DESC and non-empty.
            if !networkMonitor.isConnected && lastSyncedAt == nil {
                OfflineNoticeBadge(message: "Offline — no synced data")
            } else if !networkMonitor.isConnected, let synced = lastSyncedAt {
                Text("Offline — showing data as of \(Self.lastSyncedFormatter.string(from: synced)).")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.orange)
            }
            Text(captionText)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
    }

    private func chartCard(
        title: String,
        caption: String,
        data: [ParkingDemandInsights.HourlyCount],
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(caption).font(.caption).foregroundColor(.secondary)

            if data.contains(where: { $0.count > 0 }) {
                Chart(data) { point in
                    BarMark(
                        x: .value("Hour", point.label),
                        y: .value("Cars", point.count)
                    )
                    .foregroundStyle(color.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisValueLabel { if let s = value.as(String.self) { Text(s) } }
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            } else {
                emptyChartPlaceholder
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    private var emptyChartPlaceholder: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("Nothing recorded in this window yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .frame(height: 180)
    }

    private func recommendationCard(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        hours: [ParkingDemandInsights.HourlyCount]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                }
            }

            if hours.isEmpty {
                Text("Not enough history yet to recommend an hour. Needs at least \(ParkingDemandInsights.minSampleForRecommendation) records in this bucket.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 10) {
                    ForEach(hours) { hour in
                        VStack(spacing: 4) {
                            Text(hour.label)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(tint)
                            Text("\(hour.count) car\(hour.count == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(tint.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
}

#Preview("With data") {
    let now = Date()
    let cal = Calendar.current
    let records: [VehicleRecord] = (0..<60).map { i in
        let hour = [7, 8, 8, 9, 13, 14, 16, 17, 17, 18][i % 10]
        let type: RecordType = i.isMultiple(of: 3) ? .exit : .entry
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour
        let date = cal.date(from: comps) ?? now
        return VehicleRecord(
            id: UUID().uuidString,
            plate: "ABC\(i)",
            type: type,
            timestamp: date,
            floor: nil,
            spotNumber: nil,
            photoURL: nil,
            isRegistered: false,
            ownerEmail: nil,
            ocrConfidence: 1.0,
            durationHours: nil,
            hitDailyCap: false
        )
    }
    return ParkingDemandInsightsView(records: records, openingHour: 6, closingHour: 22)
        .environmentObject(NetworkMonitor())
}

#Preview("Empty") {
    ParkingDemandInsightsView(records: [], openingHour: 6, closingHour: 22)
        .environmentObject(NetworkMonitor())
}
