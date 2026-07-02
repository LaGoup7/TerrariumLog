import Foundation
import SwiftData

@Model
final class Plant {
    var name: String
    var species: String
    var addedDate: Date
    var lastWatered: Date?
    var status: PlantStatus
    var notes: String

    var terrarium: Terrarium?

    init(
        name: String,
        species: String = "",
        addedDate: Date = .now,
        lastWatered: Date? = nil,
        status: PlantStatus = .ok,
        notes: String = "",
        terrarium: Terrarium? = nil
    ) {
        self.name = name
        self.species = species
        self.addedDate = addedDate
        self.lastWatered = lastWatered
        self.status = status
        self.notes = notes
        self.terrarium = terrarium
    }
}

enum PlantStatus: String, Codable, CaseIterable, Sendable {
    case ok
    case dry
    case tooHumid
    case mold
    case pest

    var displayName: String {
        switch self {
        case .ok: return "OK"
        case .dry: return "Sec"
        case .tooHumid: return "Trop humide"
        case .mold: return "Moisissure"
        case .pest: return "Parasite"
        }
    }
}
