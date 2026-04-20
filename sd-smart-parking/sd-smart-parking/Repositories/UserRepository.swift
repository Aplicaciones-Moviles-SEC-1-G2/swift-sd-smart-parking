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

class UserRepository: ObservableObject {
    @Published var currentUser: User?
    @Published var isOffline: Bool = false
    
    private let db = Firestore.firestore()
    private let diskManager = DiskPersistenceManager.shared
    private let networkMonitor = NetworkMonitor.shared
    
    private let profileFileName = "user_profile_cache.json"
    private let queueFileName = "pending_sync.json"
    private var cancellables = Set<AnyCancellable>()

    init() {
            loadUser()
            setupNetworkObserver()
        }
        
        private func setupNetworkObserver() {
            networkMonitor.$isConnected
                .receive(on: DispatchQueue.main)
                .sink { [weak self] connected in
                    self?.isOffline = !connected
                    if connected {
                        self?.syncPendingActions()
                    }
                }
                .store(in: &cancellables)
        }

        func loadUser() {
            if let cachedUser = diskManager.load(filename: profileFileName, type: User.self) {
                self.currentUser = cachedUser
            }
        }

    // MÉTODO: AGREGAR CARRO (Llamado desde el ViewModel)
    func addCar(name: String, plate: String) {
            guard var user = currentUser else { return }
            
            let newCar = Car(id: UUID(), plate: plate, UserID: user.id, name: name)
            let key = newCar.normalizedPlate // Nuestra clave para la búsqueda binaria
            
            DispatchQueue.main.async {
                // Usamos 'put' de ArrayMap en lugar de 'append' de Array
                user.cars.put(newCar, for: key)
                
                self.currentUser = user
                self.saveUserLocally()
            }
            
            Task {
                await self.uploadCarToFirestore(newCar)
            }
        }

    // MÉTODO: ACTUALIZAR PERFIL (Llamado desde el ViewModel)
    func updateProfile(newName: String, newEmail: String) {
        guard var user = currentUser else { return }
        user = User(id: user.id, name: newName, email: newEmail, password: "", cars: user.cars)
        
        // 1. Local
        self.currentUser = user
        diskManager.save(user, to: profileFileName)

        // 2. Sincronización
        if !isOffline {
            Task { await uploadProfileToFirebase(newName: newName, newEmail: newEmail) }
        } else {
            // Aquí podrías crear un struct "ProfileUpdate" para el payload
            saveActionToQueue(action: .updateProfile, data: ["name": newName, "email": newEmail])
        }
    }

    // --- LÓGICA PRIVADA DE FIREBASE ---

    private func uploadCarToFirestore(_ car: Car) async {
        // 1. Usamos el UID directo de Firebase Auth en lugar del id del modelo local
        guard let firebaseUID = Auth.auth().currentUser?.uid else {
            print("⚠️ No hay una sesión de Firebase activa")
            return
        }
        
        // 2. Preparamos los datos (el ID del carro sí puede ser el UUID que generaste)
        let carData: [String: Any] = [
            //"id": car.id.uuidString,
            "name": car.name,
            "plate": car.plate,
            //"UserID": firebaseUID
        ]
        
        do {
            // 3. Apuntamos al documento que tiene el UID de Firebase
            try await db.collection("users").document(firebaseUID).setData([
                "cars": FieldValue.arrayUnion([carData])
            ], merge: true)
            
            print("✅ Carro guardado en el documento correcto: \(firebaseUID)")
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            self.saveActionToQueue(action: .addCar, data: car)
        }
    }
    private func uploadProfileToFirebase(newName: String, newEmail: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try? await db.collection("users").document(uid).updateData([
            "name": newName,
            "email": newEmail
        ])
    }

    // --- MOTOR DE SINCRONIZACIÓN ---

    func syncPendingActions() {
        guard var pendingActions = diskManager.load(filename: queueFileName, type: [PendingAction].self),
              !pendingActions.isEmpty else { return }

        Task {
            for action in pendingActions {
                let success = await processAction(action)
                if success {
                    pendingActions.removeAll(where: { $0.id == action.id })
                    diskManager.save(pendingActions, to: queueFileName)
                }
            }
        }
    }

    private func processAction(_ action: PendingAction) async -> Bool {
        switch action.type {
        case .addCar:
            if let car = try? JSONDecoder().decode(Car.self, from: action.payload) {
                await uploadCarToFirestore(car) // <-- Cambiado: pasamos el car decodificado
                return true
            }
        case .updateProfile:
            if let data = try? JSONDecoder().decode([String: String].self, from: action.payload) {
                await uploadProfileToFirebase(newName: data["name"] ?? "", newEmail: data["email"] ?? "")
                return true
            }
        default: return true
        }
        return false
    }

    private func saveActionToQueue<T: Codable>(action: ActionType, data: T) {
        var queue = diskManager.load(filename: queueFileName, type: [PendingAction].self) ?? []
        let newAction = PendingAction(type: action, data: data)
        queue.append(newAction)
        diskManager.save(queue, to: queueFileName)
        print("📦 Acción guardada en cola: \(action)")
    }
    
    private func saveUserLocally() {
        guard let user = currentUser else { return }
        diskManager.save(user, to: profileFileName)
    }
    
    
    func clearUserData() {
        // 1. Limpiamos la memoria
        self.currentUser = nil
        
        // 2. Accedemos al primer elemento de la lista de URLs
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ No se pudo encontrar la carpeta de documentos")
            return
        }
        
        let fileURL = documentsDirectory.appendingPathComponent("user_profile_cache.json")
        
        // 3. Borramos el archivo físico
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                print("🗑️ Memoria y JSON local eliminados con éxito.")
            }
        } catch {
            print("❌ Error al borrar el archivo: \(error.localizedDescription)")
        }
    }
    
    
}
