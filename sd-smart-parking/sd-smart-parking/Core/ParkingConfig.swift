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
 
    private let db = Firestore.firestore()
    private let docRef: DocumentReference
 
    init() {
        docRef = db.collection("config").document("parking")
        Task { await fetch() }
    }
 
    // MARK: - Fee Calculation
    static func calculateFee(hours: Double, currentDayTotal: Double) -> Double {
        let fee = hours * 2000
        let remaining = max(0, dailyCap - currentDayTotal)
        return min(fee, remaining)
    }
 
    // MARK: - Fetch from Firestore
    func fetch() async {
        do {
            let doc = try await docRef.getDocument()
            guard let data = doc.data() else {
                // Si no existe, lo creamos con los valores por defecto
                await save()
                return
            }
            await MainActor.run {
                self.parkingName           = data["parkingName"] as? String ?? self.parkingName
                self.numberOfFloors        = data["numberOfFloors"] as? Int ?? self.numberOfFloors
                self.spotsPerFloor         = data["spotsPerFloor"] as? Int ?? self.spotsPerFloor
                self.hourlyRate            = data["hourlyRate"] as? Double ?? self.hourlyRate
                self.ocrConfidenceThreshold = data["ocrConfidenceThreshold"] as? Double ?? self.ocrConfidenceThreshold
                self.openingHour           = data["openingHour"] as? Int ?? self.openingHour
                self.closingHour           = data["closingHour"] as? Int ?? self.closingHour
            }
        } catch {
            print("Error fetching config: \(error.localizedDescription)")
        }
    }
 
    // MARK: - Save to Firestore
    func save() async {
        do {
            try await docRef.setData([
                "parkingName":            parkingName,
                "numberOfFloors":         numberOfFloors,
                "spotsPerFloor":          spotsPerFloor,
                "hourlyRate":             hourlyRate,
                "ocrConfidenceThreshold": ocrConfidenceThreshold,
                "openingHour":            openingHour,
                "closingHour":            closingHour
            ])
        } catch {
            print("Error saving config: \(error.localizedDescription)")
        }
    }
}
