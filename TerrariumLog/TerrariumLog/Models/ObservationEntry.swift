import Foundation
import SwiftData

@Model
final class ObservationEntry {
    var date: Date
    var eventType: String
    var note: String
    var photoPaths: [String] = []

    // Champs repas, utilisés seulement si eventType == .feeding
    var preyType: String?
    var preySize: String?
    var preyQuantity: Int?
    var eatenStatus: String?
    var captureTimeMinutes: Double?

    // Champs mue, utilisés seulement si eventType == .molt
    var previousStage: String?
    var newStage: String?
    var moltSuspectedStartDate: Date?

    var animal: Animal?

    init(
        date: Date,
        eventType: String,
        note: String,
        photoPaths: [String] = [],
        preyType: String? = nil,
        preySize: String? = nil,
        preyQuantity: Int? = nil,
        eatenStatus: String? = nil,
        captureTimeMinutes: Double? = nil,
        previousStage: String? = nil,
        newStage: String? = nil,
        moltSuspectedStartDate: Date? = nil,
        animal: Animal? = nil
    ) {
        self.date = date
        self.eventType = eventType
        self.note = note
        self.photoPaths = photoPaths
        self.preyType = preyType
        self.preySize = preySize
        self.preyQuantity = preyQuantity
        self.eatenStatus = eatenStatus
        self.captureTimeMinutes = captureTimeMinutes
        self.previousStage = previousStage
        self.newStage = newStage
        self.moltSuspectedStartDate = moltSuspectedStartDate
        self.animal = animal
    }
}

enum PreyType: String, CaseIterable, Codable, Sendable {
    case drosophile
    case fly
    case microCricket
    case cricket
    case roach
    case worm
    case sugarWater
    case protein
    case seeds
    case other

    var displayName: String {
        switch self {
        case .drosophile: return "Drosophile"
        case .fly: return "Mouche"
        case .microCricket: return "Micro-grillon"
        case .cricket: return "Grillon"
        case .roach: return "Blatte"
        case .worm: return "Vers"
        case .sugarWater: return "Eau miellée"
        case .protein: return "Protéines"
        case .seeds: return "Graines"
        case .other: return "Autre"
        }
    }
}

enum EatenStatus: String, CaseIterable, Codable, Sendable {
    case yes
    case no
    case partial

    var displayName: String {
        switch self {
        case .yes: return "Mangé"
        case .no: return "Refusé"
        case .partial: return "Partiel"
        }
    }
}

enum ObservationEventType: String, CaseIterable, Codable, Sendable {
    case capture
    case laying
    case eggs
    case larvae
    case cocoons
    case firstWorkers
    case feeding
    case humidifying
    case relocation
    case hibernationStart
    case hibernationEnd
    case death
    case arrival
    case foodRefusal
    case molt
    case behavior
    case webBuilding
    case cleaning
    case photo
    case other

    var displayName: String {
        switch self {
        case .capture: return "Capture"
        case .laying: return "Ponte"
        case .eggs: return "Œufs"
        case .larvae: return "Larves"
        case .cocoons: return "Cocons"
        case .firstWorkers: return "Premières ouvrières"
        case .feeding: return "Nourrissage"
        case .humidifying: return "Humidification"
        case .relocation: return "Déménagement"
        case .hibernationStart: return "Début d’hivernation"
        case .hibernationEnd: return "Fin d’hivernation"
        case .death: return "Décès"
        case .arrival: return "Arrivée"
        case .foodRefusal: return "Refus de nourriture"
        case .molt: return "Mue"
        case .behavior: return "Comportement"
        case .webBuilding: return "Construction de toile"
        case .cleaning: return "Nettoyage"
        case .photo: return "Photo"
        case .other: return "Autre"
        }
    }

    func isAvailable(for animalType: AnimalType) -> Bool {
        switch animalType {
        case .antColony:
            return [.capture, .laying, .eggs, .larvae, .cocoons, .firstWorkers, .feeding, .humidifying, .relocation, .hibernationStart, .hibernationEnd, .death, .photo, .other].contains(self)
        case .jumpingSpider:
            return [.arrival, .feeding, .foodRefusal, .molt, .behavior, .webBuilding, .humidifying, .cleaning, .death, .photo, .other].contains(self)
        case .gecko:
            return [.arrival, .feeding, .foodRefusal, .molt, .behavior, .humidifying, .cleaning, .death, .photo, .other].contains(self)
        case .dendrobate:
            return [.arrival, .feeding, .foodRefusal, .laying, .eggs, .behavior, .humidifying, .cleaning, .death, .photo, .other].contains(self)
        case .insect, .other:
            return [.arrival, .capture, .feeding, .foodRefusal, .molt, .laying, .eggs, .behavior, .humidifying, .cleaning, .death, .photo, .other].contains(self)
        }
    }
}
