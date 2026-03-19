//
//  GerenteSummaryView.swift
//  ParkingApp
//
//  Created by Mateo on 27/02/26.
//
import SwiftUI

struct GerenteSummaryView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Panel Gerente")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Ingresos del día
            HStack(spacing: 16) {
                GerenteStatCard(
                    icon: "dollarsign.circle.fill",
                    title: "Ingresos hoy",
                    value: "$45.000",
                    color: .green
                )
                GerenteStatCard(
                    icon: "car.fill",
                    title: "Vehículos hoy",
                    value: "34",
                    color: .blue
                )
            }
            
            // Alertas OCR
            VStack(alignment: .leading, spacing: 10) {
                Text("Alertas OCR")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                AlertaOCRRow(placa: "ABC123", mensaje: "Lectura con baja confianza", hora: "10:32 AM")
                AlertaOCRRow(placa: "XYZ789", mensaje: "Vehículo no registrado", hora: "11:15 AM")
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
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
