//
//  UserPreferences.swift
//  sd-smart-parking
//

import Foundation

/// Driver-declared context that personalizes the floor recommendation.
struct UserPreferences: Codable, Equatable {
    var hasMobilityLimitation: Bool
    var preferredFloor: Int?

    init(hasMobilityLimitation: Bool = false, preferredFloor: Int? = nil) {
        self.hasMobilityLimitation = hasMobilityLimitation
        self.preferredFloor = preferredFloor
    }

    func toFirestore() -> [String: Any] {
        var dict: [String: Any] = [
            "hasMobilityLimitation": hasMobilityLimitation
        ]
        if let preferredFloor { dict["preferredFloor"] = preferredFloor }
        return dict
    }

    init?(firestore data: [String: Any]?) {
        guard let data else { return nil }
        self.hasMobilityLimitation = data["hasMobilityLimitation"] as? Bool ?? false
        self.preferredFloor = data["preferredFloor"] as? Int
    }
}
