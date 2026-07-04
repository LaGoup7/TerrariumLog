import Foundation
import SwiftData

/// Une lampe connectée rattachée (optionnellement) à un terrarium.
///
/// Le modèle est volontairement agnostique de la marque : `brand` détermine
/// quel `LightController` pilote la lampe (voir `Services/LightController.swift`),
/// ce qui permet d'ajouter d'autres marques que WiZ sans toucher aux vues.
/// L'app ne peut pas interroger l'état réel de la lampe (protocole local à sens
/// unique), on mémorise donc le dernier état envoyé pour l'affichage.
@Model
final class Light {
    var name: String
    var brand: LightBrand
    var ipAddress: String?
    var notes: String
    var createdAt: Date
    var lastKnownOn: Bool = false
    var lastBrightness: Int = 100

    var terrarium: Terrarium?

    init(
        name: String,
        brand: LightBrand = .wiz,
        ipAddress: String? = nil,
        notes: String = "",
        createdAt: Date = .now,
        lastKnownOn: Bool = false,
        lastBrightness: Int = 100,
        terrarium: Terrarium? = nil
    ) {
        self.name = name
        self.brand = brand
        self.ipAddress = ipAddress
        self.notes = notes
        self.createdAt = createdAt
        self.lastKnownOn = lastKnownOn
        self.lastBrightness = lastBrightness
        self.terrarium = terrarium
    }

    var isConfigured: Bool {
        !(ipAddress ?? "").isEmpty
    }
}

enum LightBrand: String, Codable, CaseIterable, Sendable {
    case wiz
    case other

    var displayName: String {
        switch self {
        case .wiz: return "WiZ"
        case .other: return "Autre marque"
        }
    }

    /// Toutes les marques n'exposent pas les mêmes capacités ; les vues masquent
    /// les contrôles non pris en charge en s'appuyant sur ces indicateurs.
    var supportsColor: Bool {
        switch self {
        case .wiz: return true
        case .other: return false
        }
    }

    var supportsEffects: Bool {
        switch self {
        case .wiz: return true
        case .other: return false
        }
    }
}

/// Effets dynamiques proposés à l'utilisateur. Chaque effet est mappé sur un
/// identifiant de scène WiZ (`sceneId`) ; certaines animations (respiration,
/// clignotement) réutilisent la scène « Pulse » à des vitesses différentes.
enum LightEffect: String, CaseIterable, Identifiable, Sendable {
    case rainbow
    case breathe
    case blink
    case ocean
    case forest
    case sunset
    case cozy
    case plantGrowth
    case candle

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rainbow: return "Arc-en-ciel"
        case .breathe: return "Respiration"
        case .blink: return "Clignotement"
        case .ocean: return "Océan"
        case .forest: return "Forêt"
        case .sunset: return "Coucher de soleil"
        case .cozy: return "Cosy"
        case .plantGrowth: return "Croissance"
        case .candle: return "Bougie"
        }
    }

    var symbolName: String {
        switch self {
        case .rainbow: return "rainbow"
        case .breathe: return "wind"
        case .blink: return "sparkles"
        case .ocean: return "water.waves"
        case .forest: return "tree"
        case .sunset: return "sun.horizon"
        case .cozy: return "flame"
        case .plantGrowth: return "leaf"
        case .candle: return "flame.fill"
        }
    }

    /// Identifiant de scène WiZ (API locale). Voir la documentation communautaire
    /// des scènes WiZ pour la correspondance complète.
    var wizSceneId: Int {
        switch self {
        case .rainbow: return 4      // Party — cycle rapide de couleurs vives
        case .breathe: return 31     // Pulse
        case .blink: return 31       // Pulse rapide
        case .ocean: return 1
        case .forest: return 7
        case .sunset: return 3
        case .cozy: return 6
        case .plantGrowth: return 19 // Plantgrowth
        case .candle: return 29      // Candlelight
        }
    }

    /// Vitesse d'animation (10–200) pour les scènes qui l'exploitent.
    var wizSpeed: Int? {
        switch self {
        case .breathe: return 40
        case .blink: return 190
        default: return nil
        }
    }
}
