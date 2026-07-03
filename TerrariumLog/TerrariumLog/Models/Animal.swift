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

    /// Décalage de recadrage de la photo principale (glisser-déposer sur la fiche animal),
    /// en points, appliqué avant le clip carré. (0, 0) = centré.
    var primaryPhotoOffsetX: Double = 0
    var primaryPhotoOffsetY: Double = 0

    /// Position dans le Dashboard, ajustable par glisser-déposer. Les nouveaux animaux
    /// reçoivent la valeur max+1 existante à la création (voir AnimalFormView).
    var dashboardSortOrder: Int = 0

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

    @Relationship(deleteRule: .cascade, inverse: \AnimalVideo.animal)
    var videos: [AnimalVideo] = []

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
        primaryPhotoOffsetX: Double = 0,
        primaryPhotoOffsetY: Double = 0,
        dashboardSortOrder: Int = 0,
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
        self.primaryPhotoOffsetX = primaryPhotoOffsetX
        self.primaryPhotoOffsetY = primaryPhotoOffsetY
        self.dashboardSortOrder = dashboardSortOrder
        self.estimatedWorkerCount = estimatedWorkerCount
        self.queenCount = queenCount
        self.broodPresent = broodPresent
        self.swarmingDateEstimate = swarmingDateEstimate
    }

    /// Résumé court des effectifs de colonie (ex: "12 ouvrières · 1 reine"), nil hors colonies de fourmis.
    var colonySummary: String? {
        guard type == .antColony else { return nil }
        var parts: [String] = []
        if let workers = estimatedWorkerCount {
            parts.append("\(workers) ouvrière\(workers > 1 ? "s" : "")")
        }
        if let queens = queenCount {
            parts.append("\(queens) reine\(queens > 1 ? "s" : "")")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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
    case gecko
    case dendrobate
    case insect
    case other

    var displayName: String {
        switch self {
        case .antColony:
            return "Colonie de fourmis"
        case .jumpingSpider:
            return "Araignée sauteuse"
        case .gecko:
            return "Gecko"
        case .dendrobate:
            return "Dendrobate"
        case .insect:
            return "Insecte"
        case .other:
            return "Autre"
        }
    }

    var symbolName: String {
        switch self {
        case .antColony:
            return "ant.fill"
        case .jumpingSpider:
            return "spider.fill"
        case .gecko:
            return "lizard.fill"
        case .dendrobate:
            return "leaf.fill"
        case .insect:
            return "ladybug.fill"
        case .other:
            return "pawprint.fill"
        }
    }

    /// Le suivi individuel des mues (exuvie, ancien/nouveau stade) n'a de sens que pour les
    /// animaux qui muent individuellement — pas pour une colonie de fourmis.
    var tracksMolting: Bool {
        switch self {
        case .jumpingSpider, .gecko, .insect:
            return true
        case .antColony, .dendrobate, .other:
            return false
        }
    }

    /// La diapause (dormance saisonnière) se suit au niveau de la colonie, pas de l'individu.
    var tracksDiapause: Bool {
        self == .antColony
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
        case .hibernation: return "Diapause"
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

    /// Filtre les statuts pertinents selon l'espèce : une colonie n'a pas de stade "Prémue"
    /// individuel, un animal suivi individuellement n'a pas de "Fondation"/"Croissance" de colonie.
    func isAvailable(for animalType: AnimalType) -> Bool {
        if animalType == .antColony {
            return self != .premolt && self != .molting
        }
        if self == .foundation || self == .growth {
            return false
        }
        if self == .premolt || self == .molting {
            return animalType.tracksMolting
        }
        return true
    }
}

enum AnimalAlertLevel: Equatable {
    case ok
    case warning
    case critical
}
