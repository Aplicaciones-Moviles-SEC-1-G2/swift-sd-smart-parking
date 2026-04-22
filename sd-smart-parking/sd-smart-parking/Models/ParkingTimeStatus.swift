//
//  ParkingTimeStatus.swift
//  sd-smart-parking
//

import Foundation

// MARK: - Demand Level

enum DemandLevel: String, Equatable {
    case peak
    case valley
    case normal
}

// MARK: - Operating Status

enum ParkingOperatingStatus: Equatable {
    case closed(opensAt: Int)
    case closingSoon(minutesLeft: Int)
    case open
}

// MARK: - Peak Hours Schedule

/// Temporal classification of the current hour. When a
/// `HistoricDemandSchedule` is supplied (computed from Firestore entries) it
/// takes priority for the matching weekday/weekend bucket. The hardcoded
/// weekday/weekend ranges remain as a cold-start fallback for when there are
/// not enough historic records yet.
struct PeakHoursSchedule {

    // Fallback weekday schedule (Mon–Fri)
    static let weekdayPeakRanges: [(start: Int, end: Int)] = [(6, 9)]
    static let weekdayValleyRanges: [(start: Int, end: Int)] = [(12, 15)]

    // Fallback weekend schedule (Sat–Sun)
    static let weekendPeakRanges: [(start: Int, end: Int)] = []
    static let weekendValleyRanges: [(start: Int, end: Int)] = [(6, 22)]

    static func isWeekend(at date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    static func demandLevel(
        at date: Date,
        using schedule: HistoricDemandSchedule? = nil
    ) -> DemandLevel {
        let hour = Calendar.current.component(.hour, from: date)
        let weekend = isWeekend(at: date)
        let (peaks, valleys) = effectiveRanges(weekend: weekend, schedule: schedule)

        for range in peaks {
            if hour >= range.start && hour < range.end { return .peak }
        }

        for range in valleys {
            if hour >= range.start && hour < range.end { return .valley }
        }

        return .normal
    }

    static func operatingStatus(at date: Date, openingHour: Int, closingHour: Int) -> ParkingOperatingStatus {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        if hour < openingHour || hour >= closingHour {
            return .closed(opensAt: openingHour)
        }

        let minutesUntilClosing = (closingHour - hour) * 60 - minute

        if minutesUntilClosing <= 30 {
            return .closingSoon(minutesLeft: minutesUntilClosing)
        }

        return .open
    }

    static func transitionCountdown(
        at date: Date,
        openingHour: Int,
        closingHour: Int,
        using schedule: HistoricDemandSchedule? = nil
    ) -> String? {
        let status = operatingStatus(at: date, openingHour: openingHour, closingHour: closingHour)
        guard case .open = status else { return nil }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let currentMinutes = hour * 60 + minute
        let closingMinutes = closingHour * 60
        let weekend = isWeekend(at: date)

        let (peaks, valleys) = effectiveRanges(weekend: weekend, schedule: schedule)
        let level = demandLevel(at: date, using: schedule)

        switch level {
        case .peak:
            if let range = peaks.first(where: { hour >= $0.start && hour < $0.end }) {
                let endMinutes = range.end * 60
                if endMinutes >= closingMinutes {
                    return formatCountdown(closingMinutes - currentMinutes, suffix: "until closing")
                }
                return formatCountdown(endMinutes - currentMinutes, suffix: "until normal hours")
            }
        case .valley:
            if let range = valleys.first(where: { hour >= $0.start && hour < $0.end }) {
                let endMinutes = range.end * 60
                if endMinutes >= closingMinutes {
                    return formatCountdown(closingMinutes - currentMinutes, suffix: "until closing")
                }
                return formatCountdown(endMinutes - currentMinutes, suffix: "until normal hours")
            }
        case .normal:
            var nextEvents: [(minuteMark: Int, label: String)] = []
            for range in peaks { nextEvents.append((range.start * 60, "peak hours")) }
            for range in valleys { nextEvents.append((range.start * 60, "off-peak hours")) }
            nextEvents.append((closingMinutes, "closing"))

            if let next = nextEvents
                .filter({ $0.minuteMark > currentMinutes })
                .min(by: { $0.minuteMark < $1.minuteMark }) {
                return formatCountdown(next.minuteMark - currentMinutes, suffix: "until \(next.label)")
            }
        }
        return nil
    }

    /// Prefer the historic schedule's ranges for the current bucket
    /// (weekday/weekend) when it classified anything there; otherwise use the
    /// hardcoded fallback so drivers still get meaningful banners on days with
    /// no history yet.
    private static func effectiveRanges(
        weekend: Bool,
        schedule: HistoricDemandSchedule?
    ) -> (peaks: [(start: Int, end: Int)], valleys: [(start: Int, end: Int)]) {
        if let schedule {
            let historicPeaks = weekend ? schedule.weekendPeakRanges : schedule.weekdayPeakRanges
            let historicValleys = weekend ? schedule.weekendValleyRanges : schedule.weekdayValleyRanges
            if !historicPeaks.isEmpty || !historicValleys.isEmpty {
                return (
                    historicPeaks.map { (start: $0.start, end: $0.end) },
                    historicValleys.map { (start: $0.start, end: $0.end) }
                )
            }
        }
        let peaks = weekend ? weekendPeakRanges : weekdayPeakRanges
        let valleys = weekend ? weekendValleyRanges : weekdayValleyRanges
        return (peaks, valleys)
    }

    private static func formatCountdown(_ totalMinutes: Int, suffix: String) -> String {
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h > 0 {
            return "\(h)h \(m)m \(suffix)"
        }
        return "\(m) min \(suffix)"
    }
}
