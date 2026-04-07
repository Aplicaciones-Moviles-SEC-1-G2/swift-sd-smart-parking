//
//  RecordDetailView.swift
//  ParkingApp
//
//  Created by Mateo on 2/03/26.
//
import SwiftUI
import FirebaseFirestore

struct RecordDetailView: View {
    let record: VehicleRecord
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vm: ParkingViewModel
    @State private var hasExited: Bool = false
    @State private var isLoadingStatus: Bool = true
    @State private var isInParking: Bool = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // --- SECCIÓN DE IMAGEN ---
                    ZStack {
                        if let photoURL = record.photoURL, let url = URL(string: photoURL) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray5))
                                .frame(height: 200)
                                .overlay {
                                    Image(systemName: "car.fill")
                                        .font(.system(size: 80))
                                        .foregroundColor(.gray.opacity(0.5))
                                }
                        }
                    }
                    .padding(.horizontal)

                    // --- PANEL DE INFORMACIÓN ---
                    VStack(spacing: 12) {
                        InfoRow(label: "Plate", value: record.plate, isHeader: true)
                        Divider()
                        
                        // Ubicación en el SD
                        if let floor = record.floor, let spot = record.spotNumber {
                            HStack {
                                Label("Floor \(floor)", systemImage: "p.square.fill")
                                Spacer()
                                Label("Spot \(spot)", systemImage: "parkingsign.circle.fill")
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.blue)
                            .padding(.vertical, 5)
                            Divider()
                        }

                        InfoRow(label: "Type", value: record.type == .entry ? "Entry" : "Exit")
                        InfoRow(label: "Time", value: record.timestamp.formatted(date: .abbreviated, time: .shortened))
                        InfoRow(label: "Status", value: record.isRegistered ? "Registered" : "Unregistered")
                        
                        if let email = record.ownerEmail {
                            InfoRow(label: "Owner", value: email)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)

                    // --- SECCIÓN DE ACCIÓN (EL BOTÓN DINÁMICO) ---
                    if record.type == .entry {
                        VStack {
                            if isLoadingStatus {
                                ProgressView("Checking status...")
                                    .padding()
                            } else if !isInParking {
                                // VEHÍCULO YA SALIÓ: BOTÓN VERDE ESTÁTICO
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Vehicle not in parking")
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .transition(.scale.combined(with: .opacity))
                            } else {
                                // VEHÍCULO ADENTRO: BOTÓN ROJO DE ACCIÓN
                                Button(action: {
                                    Task {
                                        await registerExit()
                                        // Actualizamos el estado local para cambiar el color
                                        withAnimation {
                                            isInParking = false
                                        }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.up.circle.fill")
                                        Text("Register Exit")
                                            .fontWeight(.bold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                    }

                    Spacer()
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Record Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            // Al abrir la vista, verificamos si el vehículo sigue en el parking
            isLoadingStatus = true
            isInParking = await vm.isVehicleInParking(plate: record.plate)
            isLoadingStatus = false
        }
    }

    private func registerExit() {
        // Creamos la copia exacta pero con datos de salida
        let exitRecord = VehicleRecord(
            id: nil, // IMPORTANTE: Dejamos que Firestore genere un ID nuevo para el registro de salida
            plate: record.plate,
            type: .exit, // Cambiamos a salida
            timestamp: Date(), // Hora actual del "espiche"
            floor: record.floor,
            spotNumber: record.spotNumber,
            photoURL: record.photoURL,
            isRegistered: record.isRegistered,
            ownerEmail: record.ownerEmail,
            ocrConfidence: 1.0, // Al ser manual, la confianza es total
            durationHours: calculateDuration(), // Opcional: calcular tiempo transcurrido
            hitDailyCap: false
        )
        
        // Guardamos en Firebase
        vm.addRecord(exitRecord)
        
        // Cerramos la vista de detalle
        dismiss()
    }

    // Función auxiliar para calcular cuánto tiempo estuvo (opcional)
    private func calculateDuration() -> Double {
        let durationSeconds = Date().timeIntervalSince(record.timestamp)
        return durationSeconds / 3600 // Convertir a horas
    }
    
    private func checkExitStatus() async {
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("vehicleRecords")
                .whereField("plate", isEqualTo: record.plate)
                .whereField("type", isEqualTo: RecordType.exit.rawValue)
                .whereField("timestamp", isGreaterThan: record.timestamp) // Solo salidas después de esta entrada
                .limit(to: 1)
                .getDocuments()
            
            await MainActor.run {
                self.hasExited = !snapshot.documents.isEmpty
                self.isLoadingStatus = false
            }
        } catch {
            print("Error verificando estatus: \(error)")
            await MainActor.run { self.isLoadingStatus = false }
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
