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
    /// Fréquence d'arrosage souhaitée en jours (nil = pas de suivi d'arrosage).
    /// L'échéance est calculée depuis le dernier arrosage (voir `wateringDueDate`).
    var wateringIntervalDays: Int?
    /// Photo de la plante (fichier géré par `PhotoStorage`).
    var photoPath: String?

    var terrarium: Terrarium?

    init(
        name: String,
        species: String = "",
        addedDate: Date = .now,
        lastWatered: Date? = nil,
        status: PlantStatus = .ok,
        notes: String = "",
        wateringIntervalDays: Int? = nil,
        photoPath: String? = nil,
        terrarium: Terrarium? = nil
    ) {
        self.name = name
        self.species = species
        self.addedDate = addedDate
        self.lastWatered = lastWatered
        self.status = status
        self.notes = notes
        self.wateringIntervalDays = wateringIntervalDays
        self.photoPath = photoPath
        self.terrarium = terrarium
    }
}

extension Plant {
    /// Prochaine échéance d'arrosage : dernier arrosage + intervalle. Une plante
    /// jamais arrosée compte depuis sa date d'ajout. Nil si pas de suivi.
    var wateringDueDate: Date? {
        guard let interval = wateringIntervalDays, interval > 0 else { return nil }
        let reference = lastWatered ?? addedDate
        return Calendar.current.date(byAdding: .day, value: interval, to: reference)
    }

    /// Vrai quand l'échéance d'arrosage est atteinte ou dépassée.
    var isWateringDue: Bool {
        guard let due = wateringDueDate else { return false }
        return due <= .now
    }

    /// Marque la plante comme arrosée maintenant.
    func markWatered(at date: Date = .now) {
        lastWatered = date
    }

    /// Libellé compact du dernier arrosage, ex. « il y a 3 j » ou « jamais ».
    var lastWateredLabel: String {
        guard let lastWatered else { return "jamais arrosée" }
        let days = Calendar.current.dateComponents([.day], from: lastWatered, to: .now).day ?? 0
        switch days {
        case 0: return "arrosée aujourd'hui"
        case 1: return "arrosée hier"
        default: return "arrosée il y a \(days) j"
        }
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

    /// Conseil d'entretien affiché sur la fiche plante quand le statut n'est
    /// pas « OK » — pour que le statut débouche sur une action.
    var advice: String? {
        switch self {
        case .ok:
            return nil
        case .dry:
            return "Arrose plus souvent ou rapproche la plante de la zone brumisée. Vérifie que le substrat retient l'eau (ajoute de la sphaigne si besoin)."
        case .tooHumid:
            return "Espace les arrosages et améliore la ventilation. Un substrat détrempé en permanence favorise la pourriture des racines."
        case .mold:
            return "Retire les parties atteintes et aère davantage. Les collemboles (nettoyeurs) aident à contenir les moisissures dans un bac bioactif."
        case .pest:
            return "Isole la plante si possible et identifie l'intrus (pucerons, sciarides…). Évite tout traitement chimique : dangereux pour les animaux du bac."
        }
    }
}
