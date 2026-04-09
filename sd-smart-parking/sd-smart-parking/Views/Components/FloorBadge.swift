//
//  FloorBadge.swift
//  sd-smart-parking
//

import SwiftUI

struct FloorBadge: View {
    let isUrgent: Bool

    var body: some View {
        Text(isUrgent ? "Last spots!" : "Recommended")
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundColor(isUrgent ? .orange : .green)
            .background((isUrgent ? Color.orange : Color.green).opacity(0.1))
            .clipShape(Capsule())
    }
}

#Preview("Recommended") {
    FloorBadge(isUrgent: false)
}

#Preview("Urgent") {
    FloorBadge(isUrgent: true)
}
