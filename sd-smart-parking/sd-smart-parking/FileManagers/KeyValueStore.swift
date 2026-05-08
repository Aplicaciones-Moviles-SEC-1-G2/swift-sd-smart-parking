//
//  KeyValueStore.swift
//  sd-smart-parking
//
//  Generic K/V store backed by a Swift Dictionary (O(1) hash lookup) with
//  scope-namespaced JSON persistence. Same row in the rubric as Mateo's
//  ArrayMap (also a k/v store) but a deliberately different implementation:
//
//    - ArrayMap: parallel sorted [keys] + [values] arrays, binary-search
//                lookups (O(log n)).
//    - KeyValueStore: Swift Dictionary, hash-based (O(1)).
//
//  Files live under Documents/diego.kv/<scope>.json so the namespace cannot
//  collide with anything Mateo or Juanes wrote.
//
//  NOTE: JSONEncoder requires `Key` to be String or Int when encoding a
//  Dictionary; that is the case for every consumer in this project (e.g.
//  ScanStats keys brands by lowercased String).
//

import Foundation

final class KeyValueStore<Key: Hashable & Codable, Value: Codable>: @unchecked Sendable {

    private var storage: [Key: Value]
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.diego.kvstore", attributes: .concurrent)

    init(scope: String, fileURL: URL? = nil) {
        let url = fileURL ?? Self.defaultURL(scope: scope)
        self.fileURL = url
        self.storage = Self.loadInitial(from: url)
    }

    private static func defaultURL(scope: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("diego.kv", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(scope).json")
    }

    private static func loadInitial(from url: URL) -> [Key: Value] {
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([Key: Value].self, from: data)
        else { return [:] }
        return dict
    }

    // MARK: - Public API

    subscript(key: Key) -> Value? {
        get { queue.sync { storage[key] } }
        set {
            queue.async(flags: .barrier) {
                if let v = newValue {
                    self.storage[key] = v
                } else {
                    self.storage.removeValue(forKey: key)
                }
                self.persist()
            }
        }
    }

    func put(_ value: Value, forKey key: Key) { self[key] = value }

    func remove(_ key: Key) { self[key] = nil }

    func snapshot() -> [Key: Value] { queue.sync { storage } }

    var count: Int { queue.sync { storage.count } }

    /// Drains every entry and rewrites the file to disk. Useful in tests.
    func clear() {
        queue.async(flags: .barrier) {
            self.storage.removeAll()
            self.persist()
        }
    }

    // MARK: - Internals

    private func persist() {
        guard let data = try? JSONEncoder().encode(storage) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
