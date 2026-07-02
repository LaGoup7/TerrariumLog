import Foundation
import SwiftData

@Model
final class Animal {
    var name: String
    var species: String
    var scientificName: String?
    var type: AnimalType
    var sex: AnimalSex
    var origin: AnimalOrigin
    var locality: String?
    var breeder: String?
    var purchasePrice: Double?
    var arrivalDate: Date
    var currentStage: String
    var status: AnimalStatus
    var notes: String
    var primaryPhotoPath: String?

    // Champs colonie (fourmis), utilisés seulement si type == .antColony
    var estimatedWorkerCount: Int?
    var queenCount: Int?
    var broodPresent: Bool = false
    var swarmingDateEstimate: Date?

    var terrarium: Terrarium?

    @Relationship(deleteRule: .cascade, inverse: \ObservationEntry.animal)
    var journalEntries: [ObservationEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \Reminder.animal)
    var reminders: [Reminder] = []

    @Relationship(deleteRule: .cascade, inverse: \MeasurementEntry.animal)
    var measurements: [MeasurementEntry] = []

    init(
        name: String,
        species: String,
        scientificName: String? = nil,
        type: AnimalType,
        sex: AnimalSex = .unknown,
        origin: AnimalOrigin,
        locality: String? = nil,
        breeder: String? = nil,
        purchasePrice: Double? = nil,
        arrivalDate: Date,
        currentStage: String,
        status: AnimalStatus,
        notes: String,
        primaryPhotoPath: String? = nil,
        estimatedWorkerCount: Int? = nil,
        queenCount: Int? = nil,
        broodPresent: Bool = false,
        swarmingDateEstimate: Date? = nil
    ) {
        self.name = name
        self.species = species
        self.scientificName = scientificName
        self.type = type
        self.sex = sex
        self.origin = origin
        self.locality = locality
        self.breeder = breeder
        self.purchasePrice = purchasePrice
        self.arrivalDate = arrivalDate
        self.currentStage = currentStage
        self.status = status
        self.notes = notes
        self.primaryPhotoPath = primaryPhotoPath
        self.estimatedWorkerCount = estimatedWorkerCount
        self.queenCount = queenCount
        self.broodPresent = broodPresent
        self.swarmingDateEstimate = swarmingDateEstimate
    }
}

enum AnimalSex: String, Codable, CaseIterable, Sendable {
    case unknown
    case male
    case female

    var displayName: String {
        switch self {
        case .unknown: return "Inconnu"
        case .male: return "Mâle"
        case .female: return "Femelle"
        }
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
    case normal
    case foundation
    case growth
    case adult
    case premolt
    case molting
    case hibernation
    case stressed
    case sick
    case pause
    case deceased

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .foundation: return "Fondation"
        case .growth: return "Croissance"
        case .adult: return "Adulte"
        case .premolt: return "Prémue"
        case .molting: return "Mue"
        case .hibernation: return "Hivernation"
        case .stressed: return "Stress"
        case .sick: return "Malade"
        case .pause: return "Pause"
        case .deceased: return "Décédé"
        }
    }

    var alertLevel: AnimalAlertLevel {
        switch self {
        case .sick, .deceased:
            return .critical
        case .premolt, .stressed, .pause:
            return .warning
        default:
            return .ok
        }
    }
}

enum AnimalAlertLevel {
    case ok
    case warning
    case critical
}
