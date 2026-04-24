//
//  GerenteSummaryView.swift
//  ParkingApp
//
//  Created by Mateo on 27/02/26.
//
import SwiftUI
import GoogleGenerativeAI

struct GerenteSummaryView: View {
    @EnvironmentObject var vm: ParkingViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor

    @State private var briefing: String = ""
    @State private var isLoadingBrief = false
    @State private var briefingLoaded = false

    private let model: GenerativeModel

    init() {
        let safety = [
            SafetySetting(harmCategory: .harassment,       threshold: .blockNone),
            SafetySetting(harmCategory: .hateSpeech,       threshold: .blockNone),
            SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockNone),
            SafetySetting(harmCategory: .dangerousContent, threshold: .blockNone)
        ]
        self.model = GenerativeModel(
            name: "gemini-2.5-flash-lite",
            apiKey: "AIzaSyD_te2nJttAzp07IHJOb8KFuBbzWuWVqyw",
            safetySettings: safety
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Manager Panel")
                .font(.headline)
                .foregroundColor(.primary)

            // MARK: - Stats row (real data)
            HStack(spacing: 16) {
                GerenteStatCard(
                    icon: "dollarsign.circle.fill",
                    title: "Today's Revenue",
                    value: formatCOP(vm.totalRevenue(for: .today)),
                    color: .green
                )
                GerenteStatCard(
                    icon: "car.fill",
                    title: "Vehicles Today",
                    value: "\(vm.totalEntries(for: .today))",
                    color: .blue
                )
            }

            // MARK: - AI Briefing
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: networkMonitor.isConnected ? "sparkles" : "sparkles.slash")
                        .font(.caption.bold())
                        .foregroundColor(networkMonitor.isConnected ? .blue : .orange)
                    Text("AI Briefing")
                        .font(.subheadline.weight(.semibold))
                    if !networkMonitor.isConnected {
                        Text("OFFLINE")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    if isLoadingBrief {
                        ProgressView().scaleEffect(0.75)
                    } else if networkMonitor.isConnected {
                        Button { generateBriefing() } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Text(briefing.isEmpty ? "Loading today's briefing…" : briefing)
                    .font(.subheadline)
                    .foregroundColor(briefing.isEmpty ? .secondary : .primary.opacity(0.85))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(Color(.systemGray6))
            .cornerRadius(14)
            .onAppear {
                guard !briefingLoaded else { return }
                briefingLoaded = true
                generateBriefing()
            }
            // Retry once Firestore data arrives (spots start empty on cold launch)
            .onChange(of: vm.spots.count) { _, _ in
                guard !isLoadingBrief, briefing.isEmpty || briefing == computedSummary() else { return }
                generateBriefing()
            }

            // MARK: - Queue control
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "car.2.fill")
                        .foregroundColor(.orange)
                    Text("External Queue")
                        .font(.subheadline.weight(.semibold))
                }

                HStack(spacing: 0) {
                    // Minus
                    Button {
                        vm.config.updateQueueLength(vm.config.queueLength - 1)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(vm.config.queueLength > 0 ? .red.opacity(0.85) : .gray.opacity(0.3))
                    }
                    .disabled(vm.config.queueLength == 0)

                    // Count + label
                    VStack(spacing: 2) {
                        Text("\(vm.config.queueLength)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                        Text("cars waiting outside")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    // Plus
                    Button {
                        vm.config.updateQueueLength(vm.config.queueLength + 1)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 8)

                // Estimated wait for context
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(vm.config.queueLength == 0
                         ? "No estimated wait — parking is free."
                         : "Passengers see ~\(vm.config.queueLength * 5) min estimated wait.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(16)

            // OCR Alerts
            VStack(alignment: .leading, spacing: 10) {
                Text("OCR Alerts")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                AlertaOCRRow(placa: "ABC123", mensaje: "Low confidence reading", hora: "10:32 AM")
                AlertaOCRRow(placa: "XYZ789", mensaje: "Unregistered vehicle", hora: "11:15 AM")
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }

    // MARK: - Gemini briefing

    private func generateBriefing() {
        guard !isLoadingBrief else { return }

        // When offline: skip the Gemini API call and serve the local computed summary
        guard networkMonitor.isConnected else {
            briefing = "[Offline] " + computedSummary()
            return
        }

        let entries   = vm.totalEntries(for: .today)
        let exits     = vm.totalExits(for: .today)
        let revenue   = Int(vm.totalRevenue(for: .today))
        let available = vm.totalAvailable
        let total     = vm.spots.count
        let queue     = vm.config.queueLength

        guard total > 0 else {
            briefing = computedSummary()
            return
        }

        isLoadingBrief = true

        let prompt = """
        Write a 2-sentence operations briefing for a parking manager at Universidad de los Andes in Bogotá.
        Today's data: \(entries) vehicle entries, \(exits) exits, $\(revenue) COP revenue, \
        \(available)/\(total) spots currently free, \(queue) cars in external queue.
        Be direct and factual. No greetings, no markdown, no asterisks.
        """

        Task {
            do {
                let response = try await model.generateContent(prompt)
                await MainActor.run {
                    briefing = response.text?.trimmingCharacters(in: .whitespacesAndNewlines)
                               ?? computedSummary()
                    isLoadingBrief = false
                }
            } catch {
                print("⚠️ Gemini briefing error: \(error)")
                await MainActor.run {
                    briefing = computedSummary()
                    isLoadingBrief = false
                }
            }
        }
    }

    /// Always-valid summary built from live numbers — used as fallback when Gemini fails
    /// or when there is no activity yet today.
    private func computedSummary() -> String {
        let entries = vm.totalEntries(for: .today)
        let exits   = vm.totalExits(for: .today)
        let revenue = vm.totalRevenue(for: .today)
        let avail   = vm.totalAvailable
        let total   = vm.spots.count
        let queue   = vm.config.queueLength
        let pct     = total > 0 ? Int(Double(total - avail) / Double(total) * 100) : 0

        if total == 0 {
            return "Syncing facility data…"
        }
        if entries == 0 && exits == 0 {
            return "No vehicle activity recorded today yet. " +
                   "The facility has \(avail)/\(total) spots free" +
                   (queue > 0 ? " and \(queue) car\(queue == 1 ? "" : "s") waiting outside." : ".")
        }
        return "\(entries) entr\(entries == 1 ? "y" : "ies") and \(exits) " +
               "exit\(exits == 1 ? "" : "s") logged today — \(formatCOP(revenue)) revenue. " +
               "Occupancy at \(pct)% (\(avail)/\(total) free)" +
               (queue > 0 ? ", \(queue) in external queue." : ".")
    }

    // MARK: - Helpers

    private func formatCOP(_ amount: Double) -> String {
        let v = Int(amount)
        guard v >= 1000 else { return "$\(v)" }
        let t = v / 1000
        let r = v % 1000
        return r > 0 ? "$\(t).\(String(format: "%03d", r))" : "$\(t).000"
    }
}

struct GerenteStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 20, weight: .bold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }
}

struct AlertaOCRRow: View {
    let placa: String
    let mensaje: String
    let hora: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(placa)
                    .font(.system(size: 14, weight: .bold))
                Text(mensaje)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            Spacer()
            Text(hora)
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
    }
}
