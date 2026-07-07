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
    /// Taille du corps après la mue (mm) — alimente la courbe de croissance.
    var moltSizeMM: Double?

    // MARK: Snapshot d'environnement (best-effort au moment de l'observation)
    /// Valeurs relevées depuis le module capteurs / les mesures du terrarium au
    /// moment de l'observation. Optionnelles : nil si aucun capteur disponible.
    /// Elles restent figées et documentent le contexte de l'événement.
    var snapshotTemperature: Double?
    var snapshotHumidity: Double?
    var snapshotSoilMoisture: Double?
    var snapshotLuminosity: Double?

    /// Poids relevé (g) — renseigné par les événements de pesée, alimente la
    /// courbe d'évolution du poids (voir JournalInsights).
    var weightGrams: Double?

    /// Étiquettes libres saisies sur les notes manuelles, pour filtrer/regrouper.
    var tags: [String] = []

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
        moltSizeMM: Double? = nil,
        snapshotTemperature: Double? = nil,
        snapshotHumidity: Double? = nil,
        snapshotSoilMoisture: Double? = nil,
        snapshotLuminosity: Double? = nil,
        weightGrams: Double? = nil,
        tags: [String] = [],
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
        self.moltSizeMM = moltSizeMM
        self.snapshotTemperature = snapshotTemperature
        self.snapshotHumidity = snapshotHumidity
        self.snapshotSoilMoisture = snapshotSoilMoisture
        self.snapshotLuminosity = snapshotLuminosity
        self.weightGrams = weightGrams
        self.tags = tags
        self.animal = animal
    }
}

extension ObservationEntry {
    /// Entrée créée uniquement pour ajouter une ou des photos à la galerie
    /// (type `.photo`, sans note). Ce n'est pas un vrai événement : elle ne doit
    /// pas apparaître dans la timeline, le journal, ni comme « dernier
    /// événement ». Ses photos restent visibles et gérables dans la galerie.
    var isPhotoOnly: Bool {
        eventType == ObservationEventType.photo.rawValue
    }

    /// Type d'événement décodé (nil si valeur inconnue/personnalisée).
    var resolvedEventType: ObservationEventType? {
        ObservationEventType(rawValue: eventType)
    }

    /// Catégorie de l'événement (Nourrissage, Mue, Comportement, Santé,
    /// Maintenance, Environnement, Note). Défaut : `.note`.
    var category: ObservationCategory {
        resolvedEventType?.category ?? .note
    }

    /// Vrai si l'entrée porte au moins une valeur de snapshot environnemental.
    var hasEnvironmentSnapshot: Bool {
        snapshotTemperature != nil || snapshotHumidity != nil
            || snapshotSoilMoisture != nil || snapshotLuminosity != nil
    }

    /// Résumé compact du snapshot, ex. « 25°C · 68% · sol 40% ».
    var environmentSnapshotSummary: String? {
        var parts: [String] = []
        if let t = snapshotTemperature { parts.append("\(Self.trim(t))°C") }
        if let h = snapshotHumidity { parts.append("\(Self.trim(h))%") }
        if let s = snapshotSoilMoisture { parts.append("sol \(Self.trim(s))%") }
        if let l = snapshotLuminosity { parts.append("\(Self.trim(l)) lux") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func trim(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
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

    /// Filtre les types de proies pertinents selon l'espèce (une colonie de fourmis ne mange
    /// pas de grillon, une araignée prédatrice ne mange pas d'eau miellée).
    func isAvailable(for animalType: AnimalType) -> Bool {
        switch animalType {
        case .antColony:
            return [.sugarWater, .protein, .seeds, .drosophile, .other].contains(self)
        case .dendrobate:
            return [.drosophile, .microCricket, .other].contains(self)
        case .jumpingSpider, .gecko, .insect, .other:
            return [.drosophile, .fly, .microCricket, .cricket, .roach, .worm, .other].contains(self)
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

/// Grande famille d'un événement de journal. Porte la couleur (jeton Brand) et
/// l'icône par défaut affichées dans la timeline « premium ». L'ajout d'un type
/// d'événement se rattache toujours à l'une de ces catégories.
enum ObservationCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case feeding
    case molting
    case behavior
    case health
    case maintenance
    case environment
    case lifecycle
    case note

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .feeding: return "Nourrissage"
        case .molting: return "Mue"
        case .behavior: return "Comportement"
        case .health: return "Santé"
        case .maintenance: return "Maintenance"
        case .environment: return "Environnement"
        case .lifecycle: return "Cycle de vie"
        case .note: return "Note"
        }
    }

    var symbolName: String {
        switch self {
        case .feeding: return "fork.knife"
        case .molting: return "arrow.triangle.2.circlepath"
        case .behavior: return "eye"
        case .health: return "cross.case"
        case .maintenance: return "wrench.and.screwdriver"
        case .environment: return "sensor"
        case .lifecycle: return "sparkles"
        case .note: return "note.text"
        }
    }

    /// Clé de couleur résolue en jeton `Brand.*` côté vue (le modèle ne dépend
    /// pas de SwiftUI). Voir `Brand.color(for:)`.
    var colorKey: String { rawValue }
}

enum ObservationEventType: String, CaseIterable, Codable, Sendable {
    // Cycle de vie
    case arrival
    case capture
    case death
    // Nourrissage
    case feeding
    case foodRefusal
    // Mue
    case premoltStart
    case molt
    case moltFailed
    // Comportement
    case behavior
    case webBuilding
    case hammockBuilt
    case hammockDestroyed
    case exploring
    case inactive
    case veryActive
    case aggressive
    case hiding
    case burrowing
    case courtship
    case mating
    case eggSac
    // Reproduction / colonie
    case laying
    case eggs
    case larvae
    case cocoons
    case firstWorkers
    case workersAppeared
    case queenLaidEggs
    case firstLarvae
    case firstPupa
    // Santé
    case injury
    case limbLoss
    case limbRegen
    case parasites
    case vetVisit
    case medication
    case recovery
    case weighing
    case measurement
    // Maintenance
    case humidifying
    case cleaning
    case relocation
    case waterRefill
    case plantsWatered
    case substrateChange
    case decorChange
    case plantAdded
    case hideAdded
    case humidityAdjust
    case temperatureAdjust
    case lightingChange
    // Environnement / matériel
    case newLamp
    case cameraInstalled
    case cameraDisconnected
    case sensorCalibrated
    case firmwareUpdate
    case automationAdded
    case weatherChange
    // Diapause
    case hibernationStart
    case hibernationEnd
    // Divers
    case photo
    case other

    var displayName: String {
        switch self {
        case .arrival: return "Arrivée"
        case .capture: return "Capture"
        case .death: return "Décès"
        case .feeding: return "Nourrissage"
        case .foodRefusal: return "Refus de nourriture"
        case .premoltStart: return "Prémue"
        case .molt: return "Mue"
        case .moltFailed: return "Mue ratée"
        case .behavior: return "Comportement"
        case .webBuilding: return "Construction de toile"
        case .hammockBuilt: return "Hamac construit"
        case .hammockDestroyed: return "Hamac détruit"
        case .exploring: return "Exploration"
        case .inactive: return "Inactif"
        case .veryActive: return "Très actif"
        case .aggressive: return "Agressif"
        case .hiding: return "Caché"
        case .burrowing: return "Fouissage"
        case .courtship: return "Parade"
        case .mating: return "Accouplement"
        case .eggSac: return "Cocon d'œufs"
        case .laying: return "Ponte"
        case .eggs: return "Œufs"
        case .larvae: return "Larves"
        case .cocoons: return "Cocons"
        case .firstWorkers: return "Premières ouvrières"
        case .workersAppeared: return "Apparition d'ouvrières"
        case .queenLaidEggs: return "Ponte de la reine"
        case .firstLarvae: return "Premières larves"
        case .firstPupa: return "Première nymphe"
        case .injury: return "Blessure"
        case .limbLoss: return "Perte d'un membre"
        case .limbRegen: return "Membre régénéré"
        case .parasites: return "Parasites"
        case .vetVisit: return "Visite vétérinaire"
        case .medication: return "Médication"
        case .recovery: return "Guérison"
        case .weighing: return "Pesée"
        case .measurement: return "Mesure"
        case .humidifying: return "Humidification"
        case .cleaning: return "Nettoyage"
        case .relocation: return "Déménagement"
        case .waterRefill: return "Recharge d'eau"
        case .plantsWatered: return "Arrosage des plantes"
        case .substrateChange: return "Substrat remplacé"
        case .decorChange: return "Décor modifié"
        case .plantAdded: return "Plante ajoutée"
        case .hideAdded: return "Cachette ajoutée"
        case .humidityAdjust: return "Réglage d'humidité"
        case .temperatureAdjust: return "Réglage de température"
        case .lightingChange: return "Éclairage modifié"
        case .newLamp: return "Nouvelle lampe"
        case .cameraInstalled: return "Caméra installée"
        case .cameraDisconnected: return "Caméra déconnectée"
        case .sensorCalibrated: return "Capteur calibré"
        case .firmwareUpdate: return "Firmware mis à jour"
        case .automationAdded: return "Automatisation ajoutée"
        case .weatherChange: return "Simulation météo modifiée"
        case .hibernationStart: return "Début de diapause"
        case .hibernationEnd: return "Fin de diapause"
        case .photo: return "Photo"
        case .other: return "Autre"
        }
    }

    /// Catégorie de l'événement (couleur/icône, regroupement dans la saisie).
    var category: ObservationCategory {
        switch self {
        case .arrival, .capture, .death:
            return .lifecycle
        case .feeding, .foodRefusal:
            return .feeding
        case .premoltStart, .molt, .moltFailed:
            return .molting
        case .behavior, .webBuilding, .hammockBuilt, .hammockDestroyed, .exploring,
             .inactive, .veryActive, .aggressive, .hiding, .burrowing, .courtship,
             .mating, .eggSac, .laying, .eggs, .larvae, .cocoons, .firstWorkers,
             .workersAppeared, .queenLaidEggs, .firstLarvae, .firstPupa:
            return .behavior
        case .injury, .limbLoss, .limbRegen, .parasites, .vetVisit, .medication,
             .recovery, .weighing, .measurement:
            return .health
        case .humidifying, .cleaning, .relocation, .waterRefill, .plantsWatered,
             .substrateChange, .decorChange, .plantAdded, .hideAdded, .humidityAdjust,
             .temperatureAdjust, .lightingChange:
            return .maintenance
        case .newLamp, .cameraInstalled, .cameraDisconnected, .sensorCalibrated,
             .firmwareUpdate, .automationAdded, .weatherChange:
            return .environment
        case .hibernationStart, .hibernationEnd:
            return .lifecycle
        case .photo, .other:
            return .note
        }
    }

    /// Événements de « santé », « maintenance », « environnement » et « note »
    /// concernent toute espèce ; les autres sont filtrés plus finement ci-dessous.
    func isAvailable(for animalType: AnimalType) -> Bool {
        // Universelles : pertinentes quelle que soit l'espèce.
        let universal: Set<ObservationEventType> = [
            .arrival, .death, .feeding, .foodRefusal, .behavior, .exploring,
            .inactive, .veryActive, .aggressive, .hiding, .photo, .other,
            // Santé
            .injury, .parasites, .vetVisit, .medication, .recovery, .weighing, .measurement,
            // Maintenance
            .humidifying, .cleaning, .relocation, .waterRefill, .plantsWatered,
            .substrateChange, .decorChange, .plantAdded, .hideAdded, .humidityAdjust,
            .temperatureAdjust, .lightingChange,
            // Environnement / matériel
            .newLamp, .cameraInstalled, .cameraDisconnected, .sensorCalibrated,
            .firmwareUpdate, .automationAdded, .weatherChange
        ]
        if universal.contains(self) { return true }

        switch self {
        case .premoltStart, .molt, .moltFailed:
            // Le suivi de mue vaut pour les animaux qui muent (et le type « autre »,
            // catch-all d'exotiques).
            return animalType.tracksMolting || animalType == .other
        case .limbLoss, .limbRegen:
            return animalType.tracksMolting || animalType == .other
        case .webBuilding, .hammockBuilt, .hammockDestroyed, .eggSac:
            return animalType == .jumpingSpider
        case .burrowing:
            return [.gecko, .insect, .other].contains(animalType)
        case .courtship, .mating:
            return animalType != .antColony
        case .capture:
            return [.antColony, .insect, .other].contains(animalType)
        case .laying, .eggs:
            return [.antColony, .dendrobate, .insect, .other].contains(animalType)
        case .larvae, .cocoons, .firstWorkers, .workersAppeared, .queenLaidEggs,
             .firstLarvae, .firstPupa:
            return animalType == .antColony
        case .hibernationStart, .hibernationEnd:
            return animalType.tracksDiapause
        default:
            return false
        }
    }

    /// Icône : spécifique si pertinent, sinon celle de la catégorie.
    var symbolName: String {
        switch self {
        case .feeding: return "fork.knife"
        case .foodRefusal: return "xmark.circle"
        case .premoltStart: return "hourglass"
        case .molt: return "arrow.triangle.2.circlepath"
        case .moltFailed: return "exclamationmark.triangle"
        case .arrival, .capture: return "sparkles"
        case .death: return "heart.slash"
        case .humidifying: return "drop"
        case .cleaning: return "sparkle"
        case .webBuilding, .eggSac: return "circle.hexagongrid"
        case .hammockBuilt, .hammockDestroyed: return "bed.double"
        case .exploring: return "figure.walk"
        case .inactive: return "zzz"
        case .veryActive: return "bolt.fill"
        case .aggressive: return "flame"
        case .hiding: return "eye.slash"
        case .burrowing: return "arrow.down.to.line"
        case .courtship: return "heart"
        case .mating: return "heart.circle"
        case .laying, .eggs: return "circle.grid.2x2"
        case .larvae, .cocoons, .firstWorkers, .workersAppeared, .queenLaidEggs,
             .firstLarvae, .firstPupa: return "ant"
        case .injury: return "bandage"
        case .limbLoss: return "scissors"
        case .limbRegen: return "arrow.clockwise.heart"
        case .parasites: return "ladybug"
        case .vetVisit: return "cross.case"
        case .medication: return "pills"
        case .recovery: return "heart.text.square"
        case .weighing: return "scalemass"
        case .measurement: return "ruler"
        case .relocation: return "arrow.left.arrow.right"
        case .waterRefill: return "drop.fill"
        case .plantsWatered: return "leaf"
        case .substrateChange: return "square.stack.3d.up"
        case .decorChange: return "cube"
        case .plantAdded: return "leaf.circle"
        case .hideAdded: return "house"
        case .humidityAdjust: return "humidity"
        case .temperatureAdjust: return "thermometer.medium"
        case .lightingChange: return "lightbulb"
        case .newLamp: return "lightbulb.led"
        case .cameraInstalled: return "video"
        case .cameraDisconnected: return "video.slash"
        case .sensorCalibrated: return "sensor"
        case .firmwareUpdate: return "arrow.down.circle"
        case .automationAdded: return "gearshape.2"
        case .weatherChange: return "cloud.sun"
        case .hibernationStart, .hibernationEnd: return "moon.zzz"
        case .photo: return "photo"
        case .other: return "note.text"
        }
    }
}
