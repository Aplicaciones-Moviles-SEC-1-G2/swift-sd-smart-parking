//
//  StaticHeader.swift
//  ParkingApp
//
//  Created by Mateo on 19/02/26.
//

import SwiftUI

struct StaticHeader: View {
    let title: String
    let subtitle: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // El contenedor del header
            VStack(alignment: .leading, spacing: 4) {
                Spacer() // Empuja el texto hacia abajo del notch
                
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .bottomLeading)
            .frame(height: 120) // Altura fija total (incluyendo safe area)
            .background(Color.blue)
        }
        .ignoresSafeArea(edges: .top) // Esto hace que el azul rellene hasta arriba
    }
}

#Preview {
    StaticHeader(title: "Prueba", subtitle: "xxx")
}
