//
//  RecordDetailView.swift
//  ParkingApp
//
//  Created by Mateo on 2/03/26.
//
import SwiftUI

struct RecordDetailView: View {
    let record: VehicleRecord
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Foto del carro (Placeholder en 2D)
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray5))
                            .frame(height: 200)
                        
                        Image(systemName: "car.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .padding(.horizontal)
                    
                    // Info Panel
                    VStack(spacing: 12) {
                        InfoRow(label: "Plate", value: record.plate, isHeader: true)
                        Divider()
                        InfoRow(label: "Type", value: record.type == .entry ? "Entry" : "Exit")
                        InfoRow(label: "Time", value: record.timestamp.formatted(date: .abbreviated, time: .shortened))
                        InfoRow(label: "Status", value: record.isRegistered ? "Registered" : "Unregistered")
                        
                        if let email = record.ownerEmail {
                            InfoRow(label: "Owner", value: email)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Record Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var isHeader: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(isHeader ? .title3 : .body)
                .fontWeight(isHeader ? .bold : .regular)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(isHeader ? .title3 : .body)
                .fontWeight(isHeader ? .bold : .medium)
        }
    }
}
