//
//  ParkingStatusBannerView.swift
//  sd-smart-parking
//

import SwiftUI

struct ParkingStatusBannerView: View {
    let demandLevel: DemandLevel
    var countdown: String? = nil
    /// Renders a trailing chevron when the banner is interactive (tappable).
    var showsDisclosure: Bool = false

    private var icon: String {
        switch demandLevel {
        case .peak:   return "flame.fill"
        case .valley: return "leaf.fill"
        case .normal: return "clock.fill"
        }
    }

    private var label: String {
        switch demandLevel {
        case .peak:   return "Peak Hours"
        case .valley: return "Off-Peak Hours"
        case .normal: return "Normal Hours"
        }
    }

    private var foregroundColor: Color {
        switch demandLevel {
        case .peak:   return Color(.sRGB, red: 0.8, green: 0.4, blue: 0.0)
        case .valley: return Color(.sRGB, red: 0.1, green: 0.55, blue: 0.15)
        case .normal: return Color(.sRGB, red: 0.55, green: 0.45, blue: 0.0)
        }
    }

    private var backgroundColor: Color {
        switch demandLevel {
        case .peak:   return Color.orange.opacity(0.15)
        case .valley: return Color.green.opacity(0.15)
        case .normal: return Color.yellow.opacity(0.2)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(foregroundColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(foregroundColor)
                if let countdown {
                    Text(countdown)
                        .font(.system(size: 12))
                        .foregroundColor(foregroundColor.opacity(0.7))
                }
            }
            Spacer()
            if showsDisclosure {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(foregroundColor.opacity(0.7))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(foregroundColor.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(backgroundColor)
        .cornerRadius(12)
    }
}

struct ClosingSoonBannerView: View {
    let minutesLeft: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text("Closes in \(minutesLeft) min — plan your exit")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.red)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview("Peak") {
    ParkingStatusBannerView(demandLevel: .peak, countdown: "1h 30m until normal hours")
        .padding()
}

#Preview("Valley") {
    ParkingStatusBannerView(demandLevel: .valley, countdown: "2h 0m until closing")
        .padding()
}

#Preview("Normal") {
    ParkingStatusBannerView(demandLevel: .normal, countdown: "45 min until peak hours")
        .padding()
}

#Preview("Closing Soon") {
    ClosingSoonBannerView(minutesLeft: 15)
        .padding()
}
