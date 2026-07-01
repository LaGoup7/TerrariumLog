import Foundation
import SwiftData

@Model
final class Animal {
    var name: String
    var species: String
    var type: AnimalType
    var origin: AnimalOrigin
    var arrivalDate: Date
    var currentStage: String
    var status: AnimalStatus
    var notes: String
    var primaryPhotoPath: String?

    @Relationship(deleteRule: .cascade, inverse: \ObservationEntry.animal)
    var journalEntries: [ObservationEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \Reminder.animal)
    var reminders: [Reminder] = []

    @Relationship(deleteRule: .cascade, inverse: \MeasurementEntry.animal)
    var measurements: [MeasurementEntry] = []

    @Relationship(deleteRule: .nullify)
    var terrarium: Terrarium?

    init(
        name: String,
        species: String,
        type: AnimalType,
        origin: AnimalOrigin,
        arrivalDate: Date,
        currentStage: String,
        status: AnimalStatus,
        notes: String,
        primaryPhotoPath: String? = nil
    ) {
        self.name = name
        self.species = species
        self.type = type
        self.origin = origin
        self.arrivalDate = arrivalDate
        self.currentStage = currentStage
        self.status = status
        self.notes = notes
        self.primaryPhotoPath = primaryPhotoPath
    }
}

enum AnimalType: String, Codable, CaseIterable, Sendable {
    case antColony = "ant_colony"
    case jumpingSpider = "jumping_spider"

    var displayName: String {
        switch self {
        case .antColony:
            return "Colonie de fourmis"
        case .jumpingSpider:
            return "Araignée sauteuse"
        }
    }

    var symbolName: String {
        switch self {
        case .antColony:
            return "ant.fill"
        case .jumpingSpider:
            return "spider.fill"
        }
    }
}

enum AnimalOrigin: String, Codable, CaseIterable, Sendable {
    case captured
    case purchased
    case adopted

    var displayName: String {
        switch self {
        case .captured: return "Capturée"
        case .purchased: return "Achetée"
        case .adopted: return "Adoptée"
        }
    }
}

enum AnimalStatus: String, Codable, CaseIterable, Sendable {
    case foundation
    case growth
    case adult
    case hibernation
    case pause
    case deceased

    var displayName: String {
        switch self {
        case .foundation: return "Fondation"
        case .growth: return "Croissance"
        case .adult: return "Adulte"
        case .hibernation: return "Hivernation"
        case .pause: return "Pause"
        case .deceased: return "Décédé"
        }
    }
}
