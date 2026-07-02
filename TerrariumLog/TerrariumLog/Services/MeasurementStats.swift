import Foundation

struct MeasurementStats {
    let minTemperature: Double?
    let maxTemperature: Double?
    let avgTemperature: Double?
    let minHumidity: Double?
    let maxHumidity: Double?
    let avgHumidity: Double?

    static func compute(from measurements: [MeasurementEntry]) -> MeasurementStats {
        let temperatures = measurements.compactMap(\.temperature)
        let humidities = measurements.compactMap(\.humidity)

        return MeasurementStats(
            minTemperature: temperatures.min(),
            maxTemperature: temperatures.max(),
            avgTemperature: average(temperatures),
            minHumidity: humidities.min(),
            maxHumidity: humidities.max(),
            avgHumidity: average(humidities)
        )
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
