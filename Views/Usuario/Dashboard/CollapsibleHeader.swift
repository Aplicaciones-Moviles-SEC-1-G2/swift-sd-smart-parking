//
//  CollapsibleHeaderView.swift
//  ParkingApp
//
//  Created by Mateo on 19/02/26.
//
import SwiftUI

struct CollapsibleHeader: View {
    let offset: CGFloat
    
    private let maxHeight: CGFloat = 110
    private let minHeight: CGFloat = 70
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Fondo azul que rellena el notch
            Color.blue
                .frame(height: max(minHeight, maxHeight - offset))
                .ignoresSafeArea(edges: .top)
            
            // Contenedor del texto
            VStack(alignment: .leading, spacing: 2) {
                Spacer() // Empuja el contenido hacia abajo del azul
                
                Text("SD Building Parking")
                    .font(.system(size: calculateFontSize(), weight: .bold))
                    .foregroundColor(.white)
                
                if offset < 15 {
                    Text("Universidad de los Andes")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 15) // Un padding normal y sano
            // 💡 ESTE ES EL TRUCO:
            // Elevamos el texto para que no choque con el scroll
            // y se mantenga centrado en la franja azul
            .frame(height: max(minHeight, maxHeight - offset))
        }
        .frame(maxWidth: .infinity)
        // Eliminamos cualquier offset externo que esté causando el error
    }
    
    private func calculateFontSize() -> CGFloat {
        let size = 22 - (offset / 15)
        return max(18, size)
    }
}

struct HeaderPreviewHelper: View {
    @State private var offset: CGFloat = 0
    
    var body: some View {
        VStack {
            // El Header reaccionando al State
            CollapsibleHeader(offset: offset)
            
            Spacer()
            
            // Control para simular el scroll manualmente
            VStack {
                Text("Simulador de Scroll: \(Int(offset))px")
                    .font(.caption)
                Slider(value: $offset, in: 0...150)
                    .padding()
            }
            .background(Color.white)
            .cornerRadius(15)
            .padding()
            .shadow(radius: 5)
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
    }
}

#Preview("Simulador Interactivo") {
    HeaderPreviewHelper()
}
