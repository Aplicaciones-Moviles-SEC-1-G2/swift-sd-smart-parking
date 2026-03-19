//
//  ParkingViewModel.swift
//  ParkingApp
//
//  Created by Mateo on 19/02/26.
//

import SwiftUI
import Combine
import FirebaseFirestore
 
class ParkingViewModel: ObservableObject {
    @Published var config = ParkingConfig()
    @Published var spots: [ParkingSpot] = []
    @Published var vehicleRecords: [VehicleRecord] = []
    @Published var hourlyRate: Double = 2000
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
 
    private let db = Firestore.firestore()
    private var spotsListener: ListenerRegistration?
    private var recordsListener: ListenerRegistration?
 
    // MARK: - Computed Properties
 
    var totalAvailable: Int { spots.filter { $0.isAvailable }.count }
    var totalOccupied: Int  { spots.filter { !$0.isAvailable }.count }
 
    var occupancyProgress: Double {
        guard !spots.isEmpty else { return 0 }
        return Double(totalOccupied) / Double(spots.count)
    }
 
    // MARK: - Init
 
    init() {
        listenToSpots()
        listenToRecords()
    }
 
    deinit {
        spotsListener?.remove()
        recordsListener?.remove()
    }
 
    // MARK: - Real-time listeners
 
    func listenToSpots() {
        spotsListener = db.collection("parkingSpots")
            .order(by: "floor")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let docs = snapshot?.documents else { return }
                self.spots = docs.compactMap { doc in
                    let data = doc.data()
                    guard let number = data["number"] as? Int,
                          let floor  = data["floor"]  as? Int else { return nil }
                    return ParkingSpot(
                        id: UUID(uuidString: doc.documentID) ?? UUID(),
                        number: number,
                        floor: floor,
                        isAvailable: data["isAvailable"] as? Bool ?? true
                    )
                }
            }
    }
 
    func listenToRecords() {
        recordsListener = db.collection("vehicleRecords")
            .order(by: "timestamp", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let docs = snapshot?.documents else { return }
                self.vehicleRecords = docs.compactMap { doc in
                    let data = doc.data()
                    guard let plate     = data["plate"]     as? String,
                          let typeRaw   = data["type"]      as? String,
                          let type      = RecordType(rawValue: typeRaw),
                          let timestamp = (data["timestamp"] as? Timestamp)?.dateValue()
                    else { return nil }
 
                    return VehicleRecord(
                        id: UUID(uuidString: doc.documentID) ?? UUID(),
                        plate: plate,
                        type: type,
                        timestamp: timestamp,
                        floor: data["floor"] as? Int,
                        spotNumber: data["spotNumber"] as? Int,
                        photoURL: data["photoURL"] as? String,
                        isRegistered: data["isRegistered"] as? Bool ?? false,
                        ownerEmail: data["ownerEmail"] as? String,
                        ocrConfidence: data["ocrConfidence"] as? Double ?? 1.0,
                        durationHours: data["durationHours"] as? Double,
                        hitDailyCap: data["hitDailyCap"] as? Bool ?? false
                    )
                }
            }
    }
 
    // MARK: - Add Record
 
    func addRecord(_ record: VehicleRecord) {
        var data: [String: Any] = [
            "plate":         record.plate,
            "type":          record.type.rawValue,
            "timestamp":     Timestamp(date: record.timestamp),
            "isRegistered":  record.isRegistered,
            "ocrConfidence": record.ocrConfidence,
            "hitDailyCap":   record.hitDailyCap
        ]
 
        if let floor       = record.floor       { data["floor"]         = floor }
        if let spotNumber  = record.spotNumber  { data["spotNumber"]    = spotNumber }
        if let photoURL    = record.photoURL    { data["photoURL"]      = photoURL }
        if let ownerEmail  = record.ownerEmail  { data["ownerEmail"]    = ownerEmail }
        if let duration    = record.durationHours { data["durationHours"] = duration }
 
        // Si es una salida, calculamos duración y tarifa
        if record.type == .exit {
            Task { await calculateAndSaveExit(record: record, data: data) }
        } else {
            db.collection("vehicleRecords").document(record.id.uuidString).setData(data) { error in
                if let error { print("Error saving record: \(error.localizedDescription)") }
            }
        }
    }
 
    // MARK: - Calculate exit fee
 
    private func calculateAndSaveExit(record: VehicleRecord, data: [String: Any]) async {
        var data = data
 
        // Buscar el entry correspondiente a esta placa
        do {
            let snapshot = try await db.collection("vehicleRecords")
                .whereField("plate", isEqualTo: record.plate)
                .whereField("type", isEqualTo: RecordType.entry.rawValue)
                .order(by: "timestamp", descending: true)
                .limit(to: 1)
                .getDocuments()
 
            if let entryDoc = snapshot.documents.first,
               let entryTimestamp = (entryDoc.data()["timestamp"] as? Timestamp)?.dateValue() {
                let durationHours = record.timestamp.timeIntervalSince(entryTimestamp) / 3600
                let totalFee = ParkingConfig.calculateFee(hours: durationHours, currentDayTotal: 0)
                let hitCap = totalFee >= ParkingConfig.dailyCap
 
                data["durationHours"] = durationHours
                data["totalFee"]      = totalFee
                data["hitDailyCap"]   = hitCap
            }
 
            try await db.collection("vehicleRecords")
                .document(record.id.uuidString)
                .setData(data)
 
        } catch {
            print("Error saving exit record: \(error.localizedDescription)")
        }
    }
 
    // MARK: - Reserve / Toggle Spot
 
    func reserveSpot(_ spot: ParkingSpot) {
        db.collection("parkingSpots").document(spot.id.uuidString).updateData([
            "isAvailable": !spot.isAvailable
        ])
    }
 
    // MARK: - Generate spots (usar solo una vez para poblar Firestore)
 
    func generateSpotsIfEmpty() async {
        do {
            let snapshot = try await db.collection("parkingSpots").limit(to: 1).getDocuments()
            guard snapshot.documents.isEmpty else { return } // Ya existen spots
 
            let batch = db.batch()
            for floor in 1...config.numberOfFloors {
                for index in 1...config.spotsPerFloor {
                    let id = UUID()
                    let ref = db.collection("parkingSpots").document(id.uuidString)
                    batch.setData([
                        "number":      (floor * 100) + index,
                        "floor":       floor,
                        "isAvailable": true,
                        "currentPlate": ""
                    ], forDocument: ref)
                }
            }
            try await batch.commit()
        } catch {
            print("Error generating spots: \(error.localizedDescription)")
        }
    }
 
    // MARK: - Reports helpers
 
    func totalRevenue(for period: ReportsView.ReportPeriod) -> Double {
        recordsFor(period)
            .filter { $0.type == .exit }
            .compactMap { $0.durationHours }
            .reduce(0.0) { $0 + ParkingConfig.calculateFee(hours: $1, currentDayTotal: 0) }
    }
 
    func avgRevenuePerVehicle(for period: ReportsView.ReportPeriod) -> Double {
        let records = recordsFor(period)
        guard !records.isEmpty else { return 0 }
        return totalRevenue(for: period) / Double(records.count)
    }
 
    func vehiclesAtCap(for period: ReportsView.ReportPeriod) -> Int {
        recordsFor(period).filter { $0.hitDailyCap }.count
    }
 
    func totalEntries(for period: ReportsView.ReportPeriod) -> Int {
        recordsFor(period).filter { $0.type == .entry }.count
    }
 
    func totalExits(for period: ReportsView.ReportPeriod) -> Int {
        recordsFor(period).filter { $0.type == .exit }.count
    }
 
    func registeredVehicles(for period: ReportsView.ReportPeriod) -> Int {
        recordsFor(period).filter { $0.isRegistered }.count
    }
 
    func unregisteredVehicles(for period: ReportsView.ReportPeriod) -> Int {
        recordsFor(period).filter { !$0.isRegistered }.count
    }
 
    func avgOccupancy(for period: ReportsView.ReportPeriod) -> Double { 0.65 }
    func peakHour(for period: ReportsView.ReportPeriod) -> String { "10:00 AM" }
 
    func revenueChartData(for period: ReportsView.ReportPeriod) -> [ChartDataPoint] {
        switch period {
        case .today:
            return (6...22).map { ChartDataPoint(label: "\($0)h", value: Double.random(in: 0...16000)) }
        case .week:
            return ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"].map { ChartDataPoint(label: $0, value: Double.random(in: 0...200000)) }
        case .month:
            return (1...30).map { ChartDataPoint(label: "\($0)", value: Double.random(in: 0...200000)) }
        }
    }
 
    func occupancyChartData(for period: ReportsView.ReportPeriod) -> [ChartDataPoint] {
        (6...22).map { ChartDataPoint(label: "\($0)h", value: Double.random(in: 0...100)) }
    }
 
    func vehiclesChartData(for period: ReportsView.ReportPeriod) -> [ChartDataPoint] {
        switch period {
        case .today:
            return (6...22).map { ChartDataPoint(label: "\($0)h", value: Double.random(in: 0...20)) }
        case .week:
            return ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"].map { ChartDataPoint(label: $0, value: Double.random(in: 0...100)) }
        case .month:
            return (1...30).map { ChartDataPoint(label: "\($0)", value: Double.random(in: 0...100)) }
        }
    }
 
    private func recordsFor(_ period: ReportsView.ReportPeriod) -> [VehicleRecord] {
        let calendar = Calendar.current
        let now = Date()
        return vehicleRecords.filter { record in
            switch period {
            case .today: return calendar.isDateInToday(record.timestamp)
            case .week:  return calendar.isDate(record.timestamp, equalTo: now, toGranularity: .weekOfYear)
            case .month: return calendar.isDate(record.timestamp, equalTo: now, toGranularity: .month)
            }
        }
    }
}
