import Foundation
import SwiftData

@Model
final class ObservationEntry {
    var date: Date
    var eventType: String
    var note: String
    var photoPaths: [String] = []

    var animal: Animal?

    init(date: Date, eventType: String, note: String, photoPaths: [String] = [], animal: Animal? = nil) {
        self.date = date
        self.eventType = eventType
        self.note = note
        self.photoPaths = photoPaths
        self.animal = animal
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
        case .other: return "Autre"
        }
    }

    func isAvailable(for animalType: AnimalType) -> Bool {
        switch animalType {
        case .antColony:
            return [.capture, .laying, .eggs, .larvae, .cocoons, .firstWorkers, .feeding, .humidifying, .relocation, .hibernationStart, .hibernationEnd, .death, .other].contains(self)
        case .jumpingSpider:
            return [.arrival, .feeding, .foodRefusal, .molt, .behavior, .webBuilding, .humidifying, .cleaning, .death, .other].contains(self)
        }
    }
}
