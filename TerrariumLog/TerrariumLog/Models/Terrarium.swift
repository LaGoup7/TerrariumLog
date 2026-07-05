import Foundation
import SwiftData

@Model
final class Terrarium {
    var name: String
    var type: TerrariumType
    var notes: String
    var dimensions: String
    var substrate: String
    var decor: String
    var createdAt: Date
    var mainPhotoPath: String?
    /// Décalage de recadrage de la photo principale (glisser-déposer sur la fiche terrarium),
    /// en points, appliqué avant le clip carré. (0, 0) = centré.
    var mainPhotoOffsetX: Double = 0
    var mainPhotoOffsetY: Double = 0
    var wizLightIP: String?
    /// IP locale du module capteurs/actionneurs (ESP32) : température, humidité,
    /// sol, brumisation et arrosage. Voir docs/capteurs-terrarium.md.
    var sensorModuleIP: String?
    var targetTemperatureMin: Double?
    var targetTemperatureMax: Double?
    var targetHumidityMin: Double?
    var targetHumidityMax: Double?

    @Relationship(deleteRule: .nullify, inverse: \Animal.terrarium)
    var animals: [Animal] = []

    @Relationship(deleteRule: .cascade, inverse: \Plant.terrarium)
    var plants: [Plant] = []

    @Relationship(deleteRule: .cascade, inverse: \Camera.terrarium)
    var cameras: [Camera] = []

    @Relationship(deleteRule: .cascade, inverse: \Light.terrarium)
    var lights: [Light] = []

    init(
        name: String,
        type: TerrariumType,
        notes: String = "",
        dimensions: String = "",
        substrate: String = "",
        decor: String = "",
        createdAt: Date = .now,
        mainPhotoPath: String? = nil,
        mainPhotoOffsetX: Double = 0,
        mainPhotoOffsetY: Double = 0,
        wizLightIP: String? = nil,
        sensorModuleIP: String? = nil,
        targetTemperatureMin: Double? = nil,
        targetTemperatureMax: Double? = nil,
        targetHumidityMin: Double? = nil,
        targetHumidityMax: Double? = nil
    ) {
        self.name = name
        self.type = type
        self.notes = notes
        self.dimensions = dimensions
        self.substrate = substrate
        self.decor = decor
        self.createdAt = createdAt
        self.mainPhotoPath = mainPhotoPath
        self.mainPhotoOffsetX = mainPhotoOffsetX
        self.mainPhotoOffsetY = mainPhotoOffsetY
        self.wizLightIP = wizLightIP
        self.sensorModuleIP = sensorModuleIP
        self.targetTemperatureMin = targetTemperatureMin
        self.targetTemperatureMax = targetTemperatureMax
        self.targetHumidityMin = targetHumidityMin
        self.targetHumidityMax = targetHumidityMax
    }
}

/// Position d'une mesure par rapport aux plages cibles du terrarium.
enum EnvironmentStatus: Equatable {
    case inRange
    case belowRange
    case aboveRange
    /// Aucune plage cible définie pour cette grandeur.
    case noTarget
}

extension Terrarium {
    func temperatureStatus(for value: Double) -> EnvironmentStatus {
        Self.status(value, min: targetTemperatureMin, max: targetTemperatureMax)
    }

    func humidityStatus(for value: Double) -> EnvironmentStatus {
        Self.status(value, min: targetHumidityMin, max: targetHumidityMax)
    }

    /// Libellé compact de la plage cible, ex. « 24–28 » ou « ≥ 60 ».
    static func targetLabel(min: Double?, max: Double?) -> String? {
        switch (min, max) {
        case (nil, nil): return nil
        case (let min?, nil): return "≥ \(Self.trim(min))"
        case (nil, let max?): return "≤ \(Self.trim(max))"
        case (let min?, let max?): return "\(Self.trim(min))–\(Self.trim(max))"
        }
    }

    static func status(_ value: Double, min: Double?, max: Double?) -> EnvironmentStatus {
        if min == nil && max == nil { return .noTarget }
        if let min, value < min { return .belowRange }
        if let max, value > max { return .aboveRange }
        return .inRange
    }

    private static func trim(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}

enum TerrariumType: String, CaseIterable, Codable, Sendable {
    case tube
    case nest
    case huntingArea = "hunting_area"
    case terrarium
    case breedingBox = "breeding_box"

    var displayName: String {
        switch self {
        case .tube: return "Tube"
        case .nest: return "Nid"
        case .huntingArea: return "Aire de chasse"
        case .terrarium: return "Terrarium"
        case .breedingBox: return "Boîte d’élevage"
        }
    }
}
