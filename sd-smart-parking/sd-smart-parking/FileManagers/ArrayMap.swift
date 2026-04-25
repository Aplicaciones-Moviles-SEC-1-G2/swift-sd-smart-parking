//
//  ArrayMap.swift
//  sd-smart-parking
//
//  Created by Mateo on 20/04/26.
//
struct ArrayMap<K: Comparable & Codable, V: Codable>: Codable {
    private var keys: [K] = []
    private var values: [V] = []

    // Requisito para el DiskManager: que sea Codable (ya lo es por conformación)

    // Método para insertar (Mantiene los arrays sincronizados y ordenados)
    mutating func put(_ value: V, for key: K) {
        if let index = binarySearch(for: key) {
            values[index] = value
        } else {
            // Buscamos la posición donde debe ir para mantener el orden
            let insertionIndex = keys.firstIndex(where: { $0 > key }) ?? keys.count
            keys.insert(key, at: insertionIndex)
            values.insert(value, at: insertionIndex)
        }
    }

    // Método de búsqueda rápida para tu lógica de negocio
    func get(_ key: K) -> V? {
        guard let index = binarySearch(for: key) else { return nil }
        return values[index]
    }

    // Expone los valores para la propiedad allPlates de User
    func allValues() -> [V] {
        return values
    }

    // Lógica interna de búsqueda binaria
    private func binarySearch(for key: K) -> Int? {
        var low = 0
        var high = keys.count - 1
        
        while low <= high {
            let mid = (low + high) / 2
            if keys[mid] == key { return mid }
            if keys[mid] < key { low = mid + 1 }
            else { high = mid - 1 }
        }
        return nil
    }
    
    func isEmpty() -> Bool {
            return keys.isEmpty
        }
    func count() -> Int {
            return keys.count
        }
    
    
}
