import Foundation

enum ActionType: String, Codable {
    case addCar
    case occupySpace
    case updateProfile
    case updatePreferences
}

struct QueuedAction: Identifiable, Codable {
    let id: UUID
    let type: ActionType
    let payload: Data
    let createdAt: Date

    init<T: Codable>(type: ActionType, data: T) {
        self.id = UUID()
        self.type = type
        self.createdAt = Date()
        self.payload = (try? JSONEncoder().encode(data)) ?? Data()
    }
}
