//
//  UserRepository.swift
//  sd-smart-parking
//
//  Created by Mateo on 16/04/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine
import Firebase

import SwiftUI

class UserRepository: ObservableObject {
    @Published var currentUser: User?
    @Published var isOffline: Bool = false
    @Published var pendingPlates: Set<String> = []
    
    private let db = Firestore.firestore()
    private let diskManager = DiskPersistenceManager.shared
    private let networkMonitor = NetworkMonitor.shared
    
    private let profileFileName = "user_profile_cache.json"
    private let queueFileName = "pending_sync.json"
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadUser()
        setupNetworkObserver()
        refreshPendingStatus()
    }
    
    private func setupNetworkObserver() {
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.isOffline = !connected
                if connected {
                    self?.syncQueuedActions()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Local Persistence
    func loadUser() {
        if let cachedUser = diskManager.load(filename: profileFileName, type: User.self) {
            self.currentUser = cachedUser
        }
    }

    private func saveUserLocally() {
        guard let user = currentUser else { return }
        diskManager.save(user, to: profileFileName)
    }

    // MARK: - Core Actions
    func addCar(name: String, plate: String) {
        guard let firebaseUID = Auth.auth().currentUser?.uid else { return }
        
        let newCar = Car(id: UUID(), plate: plate, UserID: firebaseUID, name: name)
        
        // Actualizamos localmente el modelo
        self.currentUser?.cars.put(newCar, for: newCar.normalizedPlate)
        saveUserLocally()
        
        // IMPORTANTE: Agregamos a pendientes SIEMPRE al inicio de la acción
        addToPending(plate)
        
        if isOffline {
            saveActionToQueue(action: .addCar, data: newCar)
        } else {
            Task {
                await uploadCarToFirestore(newCar)
            }
        }
    }
    
    // Crea estas dos funciones de ayuda en UserRepository para no repetir código:

    private func addToPending(_ plate: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            withAnimation(.spring()) {
                _ = self.pendingPlates.insert(plate) // El '_' ayuda a veces si el compilador espera un retorno
            }
        }
    }

    private func removeFromPending(_ plate: String) {
        DispatchQueue.main.async {
            self.pendingPlates.remove(plate)
        }
    }
    func isCarPending(plate: String) -> Bool {
        // Cargamos la cola actual
        guard let queue = diskManager.load(filename: queueFileName, type: [QueuedAction].self) else { return false }
        
        // Buscamos si hay alguna acción de tipo addCar que contenga esa placa en su payload
        return queue.contains { action in
            guard action.type == .addCar else { return false }
            // Intentamos decodificar el carro del payload para comparar la placa
            if let car = try? JSONDecoder().decode(Car.self, from: action.payload) {
                return car.plate == plate
            }
            return false
        }
    }

    func refreshPendingStatus() {
        // 1. Cargamos la cola del disco
        guard let queue = diskManager.load(filename: queueFileName, type: [QueuedAction].self) else {
            DispatchQueue.main.async { self.pendingPlates = [] }
            return
        }
        
        // 2. Extraemos solo las placas de las acciones tipo .addCar
        let plates = queue.compactMap { action -> String? in
            guard action.type == .addCar else { return nil }
            let car = try? JSONDecoder().decode(Car.self, from: action.payload)
            return car?.plate
        }
        
        // 3. Actualizamos la UI en el hilo principal con una pequeña animación
        DispatchQueue.main.async {
            withAnimation(.spring()) {
                self.pendingPlates = Set(plates)
            }
        }
    }
    func updateProfile(newName: String, newEmail: String) {
        guard var user = currentUser else { return }
        user = User(id: user.id, name: newName, email: newEmail, password: "", cars: user.cars, preferences: user.preferences)

        self.currentUser = user
        saveUserLocally()

        if isOffline {
            saveActionToQueue(action: .updateProfile, data: ["name": newName, "email": newEmail])
        } else {
            Task { await uploadProfileToFirebase(newName: newName, newEmail: newEmail) }
        }
    }

    func updatePreferences(_ preferences: UserPreferences) {
        currentUser?.preferences = preferences
        saveUserLocally()

        if isOffline {
            saveActionToQueue(action: .updatePreferences, data: preferences)
        } else {
            Task { await uploadPreferencesToFirebase(preferences) }
        }
    }

    // MARK: - Firebase Internal Logic
    private func uploadCarToFirestore(_ car: Car) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let carData: [String: Any] = ["name": car.name, "plate": car.plate]
        
        do {
            try await db.collection("users").document(uid).setData([
                "cars": FieldValue.arrayUnion([carData])
            ], merge: true)
            removeFromPending(car.plate)
            print("✅ Carro sincronizado: \(car.plate)")
        } catch {
            print("❌ Fallo subida, encolando...")
            saveActionToQueue(action: .addCar, data: car)
        }
    }

    private func uploadProfileToFirebase(newName: String, newEmail: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try? await db.collection("users").document(uid).updateData([
            "name": newName, "email": newEmail
        ])
    }

    private func uploadPreferencesToFirebase(_ preferences: UserPreferences) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try? await db.collection("users").document(uid).setData(
            ["preferences": preferences.toFirestore()], merge: true
        )
    }

    // MARK: - Sync Engine
    func syncQueuedActions() {
        guard var queue = diskManager.load(filename: queueFileName, type: [QueuedAction].self), !queue.isEmpty else { return }

        Task {
            print("📦 Procesando \(queue.count) acciones pendientes...")
            var remainingActions = queue
            
            for action in queue {
                let success = await processAction(action)
                if success {
                    remainingActions.removeAll(where: { $0.id == action.id })
                    diskManager.save(remainingActions, to: queueFileName)
                }
            }
        }
    }

    private func processAction(_ action: QueuedAction) async -> Bool {
        switch action.type {
        case .addCar:
            if let car = try? JSONDecoder().decode(Car.self, from: action.payload) {
                await uploadCarToFirestore(car)
                return true
            }
        case .updateProfile:
            if let data = try? JSONDecoder().decode([String: String].self, from: action.payload) {
                await uploadProfileToFirebase(newName: data["name"] ?? "", newEmail: data["email"] ?? "")
                return true
            }
        case .updatePreferences:
            if let prefs = try? JSONDecoder().decode(UserPreferences.self, from: action.payload) {
                await uploadPreferencesToFirebase(prefs)
                return true
            }
        default: return true
        }
        return false
    }

    private func saveActionToQueue<T: Codable>(action: ActionType, data: T) {
        var queue = diskManager.load(filename: queueFileName, type: [QueuedAction].self) ?? []
        queue.append(QueuedAction(type: action, data: data))
        diskManager.save(queue, to: queueFileName)
    }
    
    func clearUserData() {
        self.currentUser = nil
        diskManager.delete(filename: profileFileName)
        diskManager.delete(filename: queueFileName)
        print("🗑️ Datos locales eliminados.")
    }
}
