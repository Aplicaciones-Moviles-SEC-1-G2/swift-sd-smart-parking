//
//  SpotCard.swift
//  ParkingApp
//
//  Created by Mateo on 19/02/26.
//
import SwiftUI
struct SpotCardView: View {
    let spot: ParkingSpot
    var isGerente: Bool = false  // <- agregar
    @EnvironmentObject var vm: ParkingViewModel
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(spot.isAvailable ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .frame(width: 45, height: 45)
                
                Image(systemName: "car.fill")
                    .font(.system(size: 22))
                    .foregroundColor(spot.isAvailable ? .green : .red)
            }
            
            VStack(spacing: 2) {
                Text("\(spot.number)")
                    .font(.system(size: 14, weight: .bold))
                
                Text(spot.isAvailable ? "Available" : "Occupied")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // El gerente ve un indicador de que puede editar
            if isGerente {
                Text("Toca para cambiar")
                    .font(.system(size: 9))
                    .foregroundColor(.blue.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 3)
        .overlay(
            // Borde azul sutil para indicar que es editable
            RoundedRectangle(cornerRadius: 18)
                .stroke(isGerente ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            guard isGerente else { return } // <- usuario normal no puede tocar
            withAnimation(.spring()) {
                vm.reserveSpot(spot)
            }
        }
    }
}
