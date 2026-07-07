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

    // MARK: Cycle jour/nuit
    /// Mode de pilotage (rawValue de `LightScheduleMode`) : "manual" (aucun
    /// cycle), "fixed" (photopériode à horaires fixes) ou "biotope" (soleil réel
    /// de la région d'origine). Stocké en String pour rester robuste aux
    /// évolutions du schéma.
    var scheduleModeRawValue: String = LightScheduleMode.manual.rawValue
    /// Photopériode fixe : lever en minutes depuis minuit (ex. 540 = 9 h 00).
    var dayStartMinutes: Int = 540
    /// Photopériode fixe : coucher en minutes depuis minuit (ex. 1260 = 21 h 00).
    var dayEndMinutes: Int = 1260
    /// Intensité maximale du plateau de jour (10–100 %). La montée/descente
    /// aube/crépuscule est calculée automatiquement (courbe naturelle).
    var dayBrightness: Int = 100

    /// Biotope suivi par la lampe (id d'un `BiotopePreset`), ou nil.
    var biotopePresetID: String?
    /// true = la courbe du soleil du biotope est rejouée sur l'horaire local ;
    /// false = temps réel du biotope (décalage horaire vécu).
    var biotopeShiftedToLocal: Bool = true
    /// Reproduit la météo réelle de la veille du biotope (nuages → intensité).
    var biotopeWeatherEnabled: Bool = false
    /// Pluie réelle au biotope → lumière d'orage + son de pluie automatiques.
    var biotopeStormSyncEnabled: Bool = false
    /// Nuits de pleine lune → veilleuse bleutée très faible au lieu du noir.
    var biotopeMoonEnabled: Bool = false

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

    var scheduleMode: LightScheduleMode {
        get { LightScheduleMode(rawValue: scheduleModeRawValue) ?? .manual }
        set { scheduleModeRawValue = newValue.rawValue }
    }
}

/// Mode de pilotage du cycle jour/nuit d'une lampe.
enum LightScheduleMode: String, CaseIterable, Codable, Sendable {
    /// Aucun cycle : la lampe garde le dernier réglage manuel.
    case manual
    /// Photopériode à horaires fixes (standard en élevage) : aube et crépuscule
    /// progressifs autour d'un plateau de jour.
    case fixed
    /// Soleil réel de la région d'origine (élévation solaire → intensité/teinte).
    case biotope

    var displayName: String {
        switch self {
        case .manual: return "Manuel"
        case .fixed: return "Horaires fixes"
        case .biotope: return "Biotope"
        }
    }

    var symbolName: String {
        switch self {
        case .manual: return "hand.raised"
        case .fixed: return "clock"
        case .biotope: return "globe.americas.fill"
        }
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

/// Ambiances thématiques : des atmosphères complètes (Cuba, forêt tropicale,
/// orage…) plutôt que de simples effets. La plupart s'appuient sur des scènes
/// WiZ natives ; « Pluie » et « Orage » sont animées par l'app (séquences de
/// couleurs/éclairs) et ne tournent que tant que l'écran lampe est ouvert.
/// Chaque ambiance porte aussi une recherche Spotify pour l'ambiance sonore.
enum LightAmbiance: String, CaseIterable, Identifiable, Sendable {
    case cuba
    case rainforest
    case deepOcean
    case reef
    case sunset
    case campfire
    case night
    case rain
    case storm

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cuba: return "Cuba"
        case .rainforest: return "Forêt tropicale"
        case .deepOcean: return "Océan profond"
        case .reef: return "Récif"
        case .sunset: return "Coucher de soleil"
        case .campfire: return "Feu de camp"
        case .night: return "Nuit"
        case .rain: return "Pluie"
        case .storm: return "Orage"
        }
    }

    var symbolName: String {
        switch self {
        case .cuba: return "beach.umbrella.fill"
        case .rainforest: return "tree.fill"
        case .deepOcean: return "water.waves"
        case .reef: return "fish.fill"
        case .sunset: return "sun.horizon.fill"
        case .campfire: return "flame.fill"
        case .night: return "moon.stars.fill"
        case .rain: return "cloud.rain.fill"
        case .storm: return "cloud.bolt.rain.fill"
        }
    }

    /// Scène WiZ native correspondante, ou `nil` pour les ambiances animées
    /// par l'app (pluie, orage).
    var wizSceneId: Int? {
        switch self {
        case .cuba: return 25        // Mojito
        case .rainforest: return 24  // Jungle
        case .deepOcean: return 23   // Deep dive
        case .reef: return 1         // Ocean
        case .sunset: return 3       // Sunset
        case .campfire: return 5     // Fireplace
        case .night: return 14       // Night light
        case .rain, .storm: return nil
        }
    }

    /// Recherche lancée dans Spotify pour accompagner l'ambiance.
    var spotifySearch: String {
        switch self {
        case .cuba: return "cuban salsa ambiance"
        case .rainforest: return "rainforest sounds"
        case .deepOcean: return "deep ocean sounds"
        case .reef: return "coral reef ambience"
        case .sunset: return "sunset chill"
        case .campfire: return "campfire sounds"
        case .night: return "night nature sounds"
        case .rain: return "rain sounds"
        case .storm: return "thunderstorm sounds"
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

    /// Effets affichés dans la carte « Effets dynamiques » : les scènes
    /// d'atmosphère (océan, forêt, coucher de soleil, cosy, bougie) sont
    /// désormais couvertes par les Ambiances et ne sont plus listées ici.
    static let dynamicOnly: [LightEffect] = [.rainbow, .breathe, .blink, .plantGrowth]

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
