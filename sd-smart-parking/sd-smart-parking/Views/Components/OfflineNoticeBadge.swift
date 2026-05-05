//
//  OfflineNoticeBadge.swift
//  sd-smart-parking
//
//  Pill informativo que Diego usa en sus vistas para indicar estado offline.
//  Estilo deliberadamente distinto al banner naranja de Juanes
//  (Capsule pequeño azul-claro vs banner full-width naranja) para que
//  git blame deje autoría visualmente clara.
//

import SwiftUI

struct OfflineNoticeBadge: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.12))
        .foregroundColor(.blue)
        .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 12) {
        OfflineNoticeBadge(message: "Sin conexión — modo limitado")
        OfflineNoticeBadge(message: "Sin conexión — usaremos OCR local")
    }
    .padding()
}
