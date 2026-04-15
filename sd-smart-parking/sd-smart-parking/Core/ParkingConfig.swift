//
//  ParkingConfig.swift
//  ParkingApp
//
//  Created by Mateo on 27/02/26.
//
import Foundation
import Combine
import FirebaseFirestore

class ParkingConfig: ObservableObject {

    // Parking
    @Published var parkingName: String = "SD Building Parking"
    @Published var numberOfFloors: Int = 3
    @Published var spotsPerFloor: Int = 20

    // Pricing
    @Published var hourlyRate: Double = 2000
    static let dailyCap: Double = 16000

    // OCR
    @Published var ocrConfidenceThreshold: Double = 0.75

    // Operating Hours
    @Published var openingHour: Int = 6
    @Published var closingHour: Int = 22

    // Queue
    @Published var queueLength: Int = 0

    private let db = Firestore.firestore()
    private let docRef: DocumentReference
    private var configListener: ListenerRegistration?

    init() {
        docRef = db.collection("config").document("parking")
        startListening()
    }

    deinit {
        configListener?.remove()
    }

    // MARK: - Real-time listener (replaces one-shot fetch)

    private func startListening() {
        configListener = docRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }

            guard let data = snapshot?.data() else {
                // Document doesn't exist yet — seed with defaults
                Task { await self.save() }
                return
            }

            DispatchQueue.main.async {
                self.parkingName            = data["parkingName"]            as? String ?? self.parkingName
                self.numberOfFloors         = data["numberOfFloors"]         as? Int    ?? self.numberOfFloors
                self.spotsPerFloor          = data["spotsPerFloor"]          as? Int    ?? self.spotsPerFloor
                self.hourlyRate             = data["hourlyRate"]             as? Double ?? self.hourlyRate
                self.ocrConfidenceThreshold = data["ocrConfidenceThreshold"] as? Double ?? self.ocrConfidenceThreshold
                self.openingHour            = data["openingHour"]            as? Int    ?? self.openingHour
                self.closingHour            = data["closingHour"]            as? Int    ?? self.closingHour
                self.queueLength            = data["queueLength"]            as? Int    ?? 0
            }
        }
    }

    // MARK: - Fee Calculation

    static func calculateFee(hours: Double, currentDayTotal: Double) -> Double {
        let fee = hours * 2000
        let remaining = max(0, dailyCap - currentDayTotal)
        return min(fee, remaining)
    }

    // MARK: - Queue update (manager only — writes a single field, no full save needed)

    func updateQueueLength(_ count: Int) {
        let clamped = max(0, count)
        queueLength = clamped
        docRef.updateData(["queueLength": clamped]) { error in
            if let error = error {
                print("Error updating queue: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Full save (from ConfigurationView)

    func save() async {
        do {
            try await docRef.setData([
                "parkingName":            parkingName,
                "numberOfFloors":         numberOfFloors,
                "spotsPerFloor":          spotsPerFloor,
                "hourlyRate":             hourlyRate,
                "ocrConfidenceThreshold": ocrConfidenceThreshold,
                "openingHour":            openingHour,
                "closingHour":            closingHour,
                "queueLength":            queueLength
            ])
        } catch {
            print("Error saving config: \(error.localizedDescription)")
        }
    }

    // fetch() kept for any call sites that still use it
    func fetch() async { /* now handled by the real-time listener */ }
}
