//
//  ScanHistoryStore.swift
//  sd-smart-parking
//
//  Ring-buffer JSON store of the most recent AI vehicle scans. Uses
//  FileManager + JSONEncoder/JSONDecoder directly, not Mateo's generic
//  DiskPersistanceManager — separate codepath, separate file
//  (`Documents/diego.scan_history.json`), separate concurrency model.
//

import Foundation

final class ScanHistoryStore: @unchecked Sendable {
    static let shared = ScanHistoryStore()

    private let fileURL: URL
    private let maxEntries: Int
    /// Concurrent reader queue with barrier writes — multiple loadAll() calls
    /// stay parallel; mutations serialize.
    private let queue = DispatchQueue(label: "com.diego.scanhistory", attributes: .concurrent)

    init(fileURL: URL? = nil, maxEntries: Int = 50) {
        self.fileURL = fileURL ?? Self.defaultURL()
        self.maxEntries = maxEntries
    }

    private static func defaultURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("diego.scan_history.json")
    }

    /// Returns the persisted entries, newest first. Empty on miss or corruption.
    func loadAll() -> [ScanHistoryEntry] {
        queue.sync {
            decode()
        }
    }

    /// Inserts the entry at the front and trims the tail if over capacity.
    /// Atomic write so a crash mid-save can't half-overwrite the file.
    func append(_ entry: ScanHistoryEntry) {
        queue.async(flags: .barrier) {
            var current = self.decode()
            current.insert(entry, at: 0)
            if current.count > self.maxEntries {
                current = Array(current.prefix(self.maxEntries))
            }
            self.persist(current)
        }
    }

    func clear() {
        queue.async(flags: .barrier) {
            try? FileManager.default.removeItem(at: self.fileURL)
        }
    }

    // MARK: - Internals

    private func decode() -> [ScanHistoryEntry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([ScanHistoryEntry].self, from: data)) ?? []
    }

    private func persist(_ entries: [ScanHistoryEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
