import Foundation
import SwiftData

@Model
final class MeasurementEntry {
    var date: Date
    var temperature: Double?
    var humidity: Double?
    var luminosity: Double?
    var waterLevel: Double?
    var note: String

    @Relationship(deleteRule: .nullify, inverse: \Animal.measurements)
    var animal: Animal?

    init(
        date: Date,
        temperature: Double? = nil,
        humidity: Double? = nil,
        luminosity: Double? = nil,
        waterLevel: Double? = nil,
        note: String = "",
        animal: Animal? = nil
    ) {
        self.date = date
        self.temperature = temperature
        self.humidity = humidity
        self.luminosity = luminosity
        self.waterLevel = waterLevel
        self.note = note
        self.animal = animal
    }
}
