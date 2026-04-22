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
    @Published var activeUserRecords: [VehicleRecord] = []
    /// Peak/valley ranges derived from the latest `vehicleRecords` snapshot.
    /// Nil when there aren't enough historic entries yet — callers fall back
    /// to `PeakHoursSchedule`'s hardcoded ranges.
    @Published var historicSchedule: HistoricDemandSchedule?
     
    let db = Firestore.firestore()
    private var spotsListener: ListenerRegistration?
    private var recordsListener: ListenerRegistration?
    private var configCancellable: AnyCancellable?

    // MARK: - Computed Properties
 
    var totalAvailable: Int { spots.filter { $0.isAvailable }.count }
    var totalOccupied: Int  { spots.filter { !$0.isAvailable }.count }
 
    var occupancyProgress: Double {
        guard !spots.isEmpty else { return 0 }
        return Double(totalOccupied) / Double(spots.count)
    }

    /// Per-floor availability counts, keyed by floor number.
    var floorAvailability: [Int: (available: Int, total: Int)] {
        let grouped = Dictionary(grouping: spots, by: { $0.floor })
        return grouped.mapValues { floorSpots in
            let available = floorSpots.filter { $0.isAvailable }.count
            return (available: available, total: floorSpots.count)
        }
    }

    /// The floor with the most available spots, or `nil` when no clear winner.
    var recommendedFloor: Int? {
        let avail = floorAvailability
        guard !avail.isEmpty else { return nil }

        let sorted = avail.sorted { $0.value.available > $1.value.available }
        let best = sorted[0]

        // No spots available on the best floor
        guard best.value.available > 0 else { return nil }

        // Tie: if a second floor is within 2 spots, suppress recommendation
        if sorted.count >= 2 {
            let second = sorted[1]
            if best.value.available - second.value.available <= 2 {
                return nil
            }
        }

        return best.key
    }

    // MARK: - Personalized recommendation

    /// Lowest-numbered available spot on a given floor (closest to elevator/stairs).
    private func lowestAvailableSpot(onFloor floor: Int) -> ParkingSpot? {
        spots
            .filter { $0.floor == floor && $0.isAvailable }
            .min { $0.number < $1.number }
    }

    /// Floor with availability that is closest to the building entrance —
    /// modeled here as the lowest floor number that has any free spot.
    /// Used for the mobility-aware path.
    private var lowestFloorWithAvailability: Int? {
        floorAvailability
            .filter { $0.value.available > 0 }
            .keys
            .min()
    }

    /// Personalized floor + spot recommendation that respects user-declared
    /// mobility limitations and a preferred floor.
    ///
    /// Priority order (preferred floor wins over mobility — rationale: this is
    /// a university building where the preferred floor is usually the floor of
    /// the user's class, so parking elsewhere defeats the point even for a
    /// driver with a mobility limitation. The closest-to-elevator spot on the
    /// preferred floor is still picked):
    ///   1. Preferred floor with availability → that floor + closest-to-elevator spot
    ///   2. Mobility limitation → lowest floor with availability + closest-to-elevator spot
    ///      (used when no preferred floor is set, or when preferred floor is full)
    ///   3. Generic `recommendedFloor` as final fallback
    ///   4. `nil` when no recommendation is possible (all full / suppressed tie)
    ///
    /// Spot selection inside the chosen floor is always the lowest-numbered
    /// available spot, which corresponds to the spot closest to the
    /// elevator/stairs core in the production numbering scheme.
    func personalizedRecommendation(for prefs: UserPreferences?) -> PersonalizedRecommendation? {
        // 1. Preferred floor wins when it has availability.
        if let preferred = prefs?.preferredFloor,
           let avail = floorAvailability[preferred],
           avail.available > 0 {
            return PersonalizedRecommendation(
                floor: preferred,
                spot: lowestAvailableSpot(onFloor: preferred),
                reason: .preferredFloor
            )
        }

        // Preferred floor was set but has no availability — flag it for the UI
        // copy so the fallback can be explained.
        let preferredIsFull = prefs?.preferredFloor.flatMap { floorAvailability[$0]?.available } == 0

        // 2. Mobility path (no preferred match): lowest floor with availability.
        if prefs?.hasMobilityLimitation == true {
            guard let floor = lowestFloorWithAvailability else { return nil }
            return PersonalizedRecommendation(
                floor: floor,
                spot: lowestAvailableSpot(onFloor: floor),
                reason: preferredIsFull ? .preferredFloorFull(fallback: floor) : .mobility
            )
        }

        // 3. Generic recommendation (with optional "preferred floor full" hint).
        guard let generic = recommendedFloor else { return nil }
        return PersonalizedRecommendation(
            floor: generic,
            spot: lowestAvailableSpot(onFloor: generic),
            reason: preferredIsFull ? .preferredFloorFull(fallback: generic) : .generic
        )
    }

    // MARK: - Init
 
    init() {
        listenToSpots()
        listenToRecords()
        // ParkingConfig is a nested ObservableObject. SwiftUI views that observe
        // ParkingViewModel won't re-render when config's @Published properties change
        // unless we forward its objectWillChange up to ours.
        configCancellable = config.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
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

                let allSpots: [ParkingSpot] = docs.compactMap { doc in
                    let data = doc.data()
                    guard let number = data["number"] as? Int,
                          let floor  = data["floor"]  as? Int else { return nil }
                    return ParkingSpot(
                        id: UUID(uuidString: doc.documentID) ?? UUID(),
                        number: number,
                        floor: floor,
                        isAvailable: data["isAvailable"] as? Bool ?? true,
                        reservedByEmail: data["reservedByEmail"] as? String
                    )
                }

                // Deduplicate by spot number. When two docs share the same number,
                // keep the occupied/reserved one and delete the extra from Firestore.
                var keeperByNumber = [Int: ParkingSpot]()
                for spot in allSpots {
                    if let existing = keeperByNumber[spot.number] {
                        let keepIncoming = !spot.isAvailable && existing.isAvailable
                        let docToDelete  = keepIncoming ? existing : spot
                        self.db.collection("parkingSpots")
                            .document(docToDelete.id.uuidString)
                            .delete()
                        if keepIncoming { keeperByNumber[spot.number] = spot }
                    } else {
                        keeperByNumber[spot.number] = spot
                    }
                }

                self.spots = keeperByNumber.values.sorted {
                    $0.floor == $1.floor ? $0.number < $1.number : $0.floor < $1.floor
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
                        id: doc.documentID,
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
                self.historicSchedule = HistoricDemandSchedule.build(from: self.vehicleRecords)
            }
    }
 
    // MARK: - Add Record
 
    // MARK: - Add Record (CORREGIDO)
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

            if record.type == .exit {
                // Lógica de salida: Valida, guarda y libera cupo
                Task { await calculateAndSaveExit(record: record, data: data) }
            } else {
                // Lógica de entrada: Guarda y ocupa cupo
                if let recordId = record.id {
                    db.collection("vehicleRecords").document(recordId).setData(data)
                } else {
                    db.collection("vehicleRecords").addDocument(data: data)
                }
                
                // Si tiene ubicación, ocupamos el spot en tiempo real
                if let floor = record.floor, let spotNumber = record.spotNumber {
                    Task { await updateSpotAvailability(floor: floor, spotNumber: spotNumber, available: false) }
                }
            }
        }
 
// MARK: - Calculate exit fee & Spot Release (UNIFICADO)
    func calculateAndSaveExit(record: VehicleRecord, data: [String: Any]) async {
        do {
            let lastRecordQuery = try await db.collection("vehicleRecords")
                .whereField("plate", isEqualTo: record.plate)
                .order(by: "timestamp", descending: true)
                .limit(to: 1)
                .getDocuments()

            if let lastDoc = lastRecordQuery.documents.first {
                let lastType = lastDoc.data()["type"] as? String
                if lastType == RecordType.exit.rawValue {
                    print("⚠️ Vehicle already exited")
                    return
                }
            }

            // Guardar la salida
            try await db.collection("vehicleRecords").addDocument(data: data)
            print("✅ Salida registrada.")

            // LIBERAR EL CUPO (De origin/develop)
            if let floor = record.floor, let spotNumber = record.spotNumber {
                await updateSpotAvailability(floor: floor, spotNumber: spotNumber, available: true)
            }

        } catch {
            print("Error en proceso de salida: \(error.localizedDescription)")
        }
    }

    // MARK: - Update spot availability (Lógica de Develop)
        func updateSpotAvailability(floor: Int, spotNumber: Int, available: Bool) async {
            let targetNumber = (floor * 100) + spotNumber
            do {
                let snapshot = try await db.collection("parkingSpots")
                    .whereField("floor", isEqualTo: floor)
                    .whereField("number", isEqualTo: targetNumber)
                    .limit(to: 1)
                    .getDocuments()
                if let ref = snapshot.documents.first?.reference {
                    try await ref.updateData(["isAvailable": available])
                }
            } catch {
                print("Error actualizando spot: \(error.localizedDescription)")
            }
        }
    
    // MARK: -- Delete Record
    func deleteRecord(_ record: VehicleRecord) {
        guard let id = record.id else { return }
        db.collection("vehicleRecords").document(id).delete() { error in
            if let error = error {
                print("Error eliminando: \(error.localizedDescription)")
            }
        }
    }
    // MARK: - Is vehicle in parking
    func isVehicleInParking(plate: String) async -> Bool {
        let db = Firestore.firestore()
        
        do {
            // Buscamos el registro MÁS RECIENTE de esta placa
            let snapshot = try await db.collection("vehicleRecords")
                .whereField("plate", isEqualTo: plate)
                .order(by: "timestamp", descending: true)
                .limit(to: 1)
                .getDocuments()
            
            guard let lastDoc = snapshot.documents.first else {
                return false // Si no hay registros, no está en el parking
            }
            
            let typeRaw = lastDoc.data()["type"] as? String ?? ""
            // Si el último registro es una entrada, el carro está en el parking
            return typeRaw == RecordType.entry.rawValue
            
        } catch {
            print("❌ Error verificando estado: \(error.localizedDescription)")
            return false
        }
    }
    // MARK: - Reserve / Toggle Spot

    /// Admin toggle — also clears reservation email when freeing a spot.
    func reserveSpot(_ spot: ParkingSpot) {
        var data: [String: Any] = ["isAvailable": !spot.isAvailable]
        if !spot.isAvailable {
            // Spot is being freed by admin — clear owner
            data["reservedByEmail"] = FieldValue.delete()
        }
        db.collection("parkingSpots").document(spot.id.uuidString).updateData(data)
    }

    /// Driver QR reservation — marks spot unavailable and records the user.
    func reserveSpotForUser(_ spot: ParkingSpot, userEmail: String) {
        db.collection("parkingSpots").document(spot.id.uuidString).updateData([
            "isAvailable": false,
            "reservedByEmail": userEmail
        ])
    }

    /// Driver releases their own spot.
    func releaseSpot(_ spot: ParkingSpot) {
        db.collection("parkingSpots").document(spot.id.uuidString).updateData([
            "isAvailable": true,
            "reservedByEmail": FieldValue.delete()
        ])
    }

    /// Admin — marks every spot as available and clears all reservations.
    func freeAllSpots() {
        let batch = db.batch()
        for spot in spots {
            let ref = db.collection("parkingSpots").document(spot.id.uuidString)
            var data: [String: Any] = ["isAvailable": true]
            if spot.reservedByEmail != nil { data["reservedByEmail"] = FieldValue.delete() }
            batch.updateData(data, forDocument: ref)
        }
        Task { try? await batch.commit() }
    }

    /// Admin — marks every spot as occupied.
    func occupyAllSpots() {
        let batch = db.batch()
        for spot in spots {
            let ref = db.collection("parkingSpots").document(spot.id.uuidString)
            batch.updateData(["isAvailable": false], forDocument: ref)
        }
        Task { try? await batch.commit() }
    }

    // MARK: - User active spot

    /// Returns the spot currently reserved by this user, or nil if none.
    func userActiveSpot(for email: String) -> ParkingSpot? {
        guard !email.isEmpty else { return nil }
        return spots.first { !$0.isAvailable && $0.reservedByEmail == email }
    }

    // MARK: - Duplicate detection (admin)

    /// Groups of spots where the same user email has reserved more than one spot.
    var duplicateSpotGroups: [(email: String, spots: [ParkingSpot])] {
        let occupied = spots.filter {
            !$0.isAvailable && !($0.reservedByEmail ?? "").isEmpty
        }
        let grouped = Dictionary(grouping: occupied, by: { $0.reservedByEmail! })
        return grouped
            .filter { $0.value.count > 1 }
            .map { (email: $0.key, spots: $0.value) }
            .sorted { $0.email < $1.email }
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
    func peakHour(for period: ReportsView.ReportPeriod) -> String {
        let now = Date()
        let calendar = Calendar.current
        
        // 1. Filtrar registros por fecha (Período) y tipo (Entrada)
        let filteredEntries = vehicleRecords.filter { record in
            // Primero, solo entradas
            guard record.type == .entry else { return false }
            
            // Segundo, validar que el registro esté dentro del rango de tiempo
            switch period {
            case .today: // Ajusta este nombre según tu Enum (ej: .day o .daily)
                return calendar.isDateInToday(record.timestamp)
            case .week:
                guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return false }
                return record.timestamp >= sevenDaysAgo
            case .month:
                guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) else { return false }
                return record.timestamp >= thirtyDaysAgo
            }
        }
        
        // 2. Agrupar por hora (0...23)
        let hourGroups = Dictionary(grouping: filteredEntries) { record -> Int in
            let components = calendar.dateComponents([.hour], from: record.timestamp)
            return components.hour ?? 0
        }
        
        // 3. Encontrar la hora con el conteo más alto
        guard let maxHour = hourGroups.max(by: { $0.value.count < $1.value.count }) else {
            return "N/A"
        }
        
        // 4. Formatear el resultado (Ejemplo: "2:00 PM")
        var components = DateComponents()
        components.hour = maxHour.key
        // Usamos el calendario para crear una fecha válida y formatearla
        if let date = calendar.date(from: components) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        }
        
        return "\(maxHour.key):00"
    }
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


extension ParkingViewModel {
    
    // Esta función filtra los registros de los carros del usuario
    func listenToUserCars(for user: User) {
        // 1. Extraemos las placas usando allValues() del ArrayMap
        let plates = user.cars.allValues().map { $0.plate.uppercased() }
        
        print("DEBUG: Buscando estas placas: \(plates)")
        
        guard !plates.isEmpty else {
            print("DEBUG: El usuario no tiene placas registradas.")
            // Limpiamos los registros si el usuario ya no tiene carros
            DispatchQueue.main.async { self.activeUserRecords = [] }
            return
        }
        
        db.collection("vehicleRecords")
            .whereField("plate", in: plates) // Firestore permite hasta 30 elementos en 'in'
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                
                if let error = error {
                    print("❌ ERROR DE FIREBASE: \(error.localizedDescription)")
                    return
                }
                
                let count = snapshot?.documents.count ?? 0
                print("DEBUG: Documentos recibidos de Firestore: \(count)")
                
                guard let self = self, let docs = snapshot?.documents else { return }
                
                // Mapeamos los documentos a objetos de dominio
                let records = docs.compactMap { self.mapDocumentToRecord($0) }
                print("DEBUG: Registros mapeados con éxito: \(records.count)")
                
                // 2. Lógica para obtener solo el último estado por placa
                // (Como vienen ordenados por timestamp desc, el primero que encontremos es el actual)
                var latestStatus: [String: VehicleRecord] = [:]
                for record in records {
                    if latestStatus[record.plate] == nil {
                        latestStatus[record.plate] = record
                    }
                }
                
                DispatchQueue.main.async {
                    // Filtramos solo aquellos cuyo último movimiento fue una 'entrada' (están en el parking)
                    self.activeUserRecords = Array(latestStatus.values).filter { $0.type == .entry }
                    print("DEBUG: Registros finales en pantalla: \(self.activeUserRecords.count)")
                }
            }
    }
    
    // MARK: - Mapeo con Codable
    func mapDocumentToRecord(_ doc: QueryDocumentSnapshot) -> VehicleRecord? {
        do {
            // Opción A: Si usas FirebaseFirestoreSwift
            return try doc.data(as: VehicleRecord.self)
        } catch {
            print("❌ ERROR DE MAPEO en placa \(doc.get("plate") ?? "desconocida"): \(error)")
            return nil
        }
    }
}

