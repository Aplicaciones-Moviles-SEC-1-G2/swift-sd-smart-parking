//
//  DiskPersistanceManager.swift
//  sd-smart-parking
//
//  Created by Mateo on 16/04/26.
//
import Foundation

class DiskPersistenceManager {
    static let shared = DiskPersistenceManager() // Singleton para usarlo en toda la app
    private let fileManager = FileManager.default

    // Obtiene la ruta de la carpeta "Documents" del iPhone
    private func getDocumentsDirectory() -> URL {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    // GUARDA cualquier objeto Codable (User, Car, [PendingAction])
    func save<T: Codable>(_ object: T, to filename: String) {
        // Aquí usamos la función que acabamos de corregir
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        
        do {
            let data = try JSONEncoder().encode(object)
            try data.write(to: url, options: [.atomicWrite])
        } catch {
            print("Error al guardar: \(error.localizedDescription)")
        }
    }

    // CARGA cualquier objeto Codable
    func load<T: Codable>(filename: String, type: T.Type) -> T? {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Error al cargar de disco: \(error.localizedDescription)")
            return nil
        }
    }

    // BORRA un archivo (ej: al cerrar sesión)
    func delete(filename: String) {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        try? fileManager.removeItem(at: url)
    }
}
