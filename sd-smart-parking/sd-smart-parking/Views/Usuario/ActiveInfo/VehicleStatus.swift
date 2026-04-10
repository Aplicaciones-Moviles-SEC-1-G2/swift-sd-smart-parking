//
//  VehicleStatus.swift
//  sd-smart-parking
//
//  Created by Mateo on 7/04/26.
//
import SwiftUI
import EventKit

struct VehicleStatusCard: View {
    let record: VehicleRecord
    let now: Date // Para el timer
    @StateObject private var calendarVM = CalendarExportViewModel()
    @EnvironmentObject var config: ParkingConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Header: Placa y Status
            HStack {
                Text(record.plate)
                    .font(.system(.title2, design: .rounded)).bold()
                
                Spacer()
                
                Capsule()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 100, height: 30)
                    .overlay(
                        HStack(spacing: 5) {
                            Circle().fill(.green).frame(width: 6, height: 6)
                            Text("On site").font(.caption.bold()).foregroundColor(.green)
                        }
                    )
            }
            
            Divider()
            
            // Body: Ubicación y Tiempo
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Location").font(.caption).foregroundColor(.secondary)
                    Text("Floor \(record.floor ?? 0), Spot \(record.spotNumber ?? 0)")
                        .font(.headline)
                }
                
                Divider().frame(height: 30)
                
                VStack(alignment: .leading) {
                    Text("TIME").font(.caption).foregroundColor(.secondary)
                    Text(timeElapsed)
                        .font(.headline)
                }
            }
            
            // Footer: El Pago (Destacado)
            HStack {
                VStack(alignment: .leading) {
                    Text("ESTIMATED TOTAL").font(.caption).foregroundColor(.secondary)
                    Text("$\(currentFee)")
                        .font(.title.bold())
                        .foregroundColor(.blue)
                }
                Spacer()
                Button {
                    Task {
                        await calendarVM.exportEvent(
                            record: record,
                            parkingName: config.parkingName,
                            closingHour: config.closingHour
                        )
                    }
                } label: {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                Image(systemName: "creditcard.fill")
                    .font(.title2)
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .alert(calendarVM.alertTitle, isPresented: $calendarVM.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(calendarVM.alertMessage)
        }
    }
    
    // Propiedades calculadas
    private var timeElapsed: String {
        let diff = Calendar.current.dateComponents([.hour, .minute], from: record.timestamp, to: now)
        return "\(diff.hour ?? 0)h \(diff.minute ?? 0)m"
    }
    
    private var currentFee: Int {
        let hours = now.timeIntervalSince(record.timestamp) / 3600
        return Int(ParkingConfig.calculateFee(hours: hours, currentDayTotal: 0))
    }
}


