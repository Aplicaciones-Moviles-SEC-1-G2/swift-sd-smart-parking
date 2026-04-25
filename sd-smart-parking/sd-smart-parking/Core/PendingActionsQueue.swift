import Foundation

// Persists offline parking actions to the Documents directory as JSON.
// On reconnection, ParkingViewModel drains the queue and retries each action.
struct PendingAction: Codable, Identifiable {
    let id: UUID
    let actionType: String      // "entry" | "exit" | "spotUpdate"
    let plate: String
    let timestamp: Date
    let floor: Int?
    let spotNumber: Int?
    let userEmail: String?
    var retryCount: Int

    init(actionType: String, plate: String, floor: Int? = nil,
         spotNumber: Int? = nil, userEmail: String? = nil) {
        self.id = UUID()
        self.actionType = actionType
        self.plate = plate
        self.timestamp = Date()
        self.floor = floor
        self.spotNumber = spotNumber
        self.userEmail = userEmail
        self.retryCount = 0
    }
}

final class PendingActionsQueue {
    static let shared = PendingActionsQueue()

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("pending_actions.json")
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {}

    var all: [PendingAction] {
        guard let data = try? Data(contentsOf: fileURL),
              let actions = try? decoder.decode([PendingAction].self, from: data)
        else { return [] }
        return actions
    }

    var isEmpty: Bool { all.isEmpty }

    func enqueue(_ action: PendingAction) {
        var current = all
        current.append(action)
        persist(current)
    }

    func remove(id: UUID) {
        persist(all.filter { $0.id != id })
    }

    func clear() {
        persist([])
    }

    private func persist(_ actions: [PendingAction]) {
        guard let data = try? encoder.encode(actions) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
