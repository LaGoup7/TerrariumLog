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
        self.targetTemperatureMin = targetTemperatureMin
        self.targetTemperatureMax = targetTemperatureMax
        self.targetHumidityMin = targetHumidityMin
        self.targetHumidityMax = targetHumidityMax
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
