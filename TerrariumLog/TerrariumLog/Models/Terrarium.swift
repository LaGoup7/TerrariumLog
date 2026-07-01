import Foundation
import SwiftData

@Model
final class Terrarium {
    var name: String
    var type: TerrariumType
    var notes: String
    var dimensions: String
    var targetTemperatureMin: Double?
    var targetTemperatureMax: Double?
    var targetHumidityMin: Double?
    var targetHumidityMax: Double?

    @Relationship(deleteRule: .nullify, inverse: \Animal.terrarium)
    var animal: Animal?

    init(
        name: String,
        type: TerrariumType,
        notes: String = "",
        dimensions: String = "",
        targetTemperatureMin: Double? = nil,
        targetTemperatureMax: Double? = nil,
        targetHumidityMin: Double? = nil,
        targetHumidityMax: Double? = nil,
        animal: Animal? = nil
    ) {
        self.name = name
        self.type = type
        self.notes = notes
        self.dimensions = dimensions
        self.targetTemperatureMin = targetTemperatureMin
        self.targetTemperatureMax = targetTemperatureMax
        self.targetHumidityMin = targetHumidityMin
        self.targetHumidityMax = targetHumidityMax
        self.animal = animal
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
