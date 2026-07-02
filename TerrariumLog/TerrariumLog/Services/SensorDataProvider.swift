import Foundation

protocol SensorDataProvider {
    func currentValues(for animal: Animal) -> SensorSnapshot
}

struct SensorSnapshot: Equatable {
    let temperature: Double
    let humidity: Double
    let luminosity: Double
    let waterLevel: Double
}

struct MockSensorDataProvider: SensorDataProvider {
    func currentValues(for animal: Animal) -> SensorSnapshot {
        switch animal.type {
        case .antColony:
            return SensorSnapshot(temperature: 25.0, humidity: 60.0, luminosity: 120.0, waterLevel: 70.0)
        case .jumpingSpider:
            return SensorSnapshot(temperature: 27.0, humidity: 65.0, luminosity: 90.0, waterLevel: 50.0)
        case .gecko, .dendrobate:
            return SensorSnapshot(temperature: 26.0, humidity: 75.0, luminosity: 100.0, waterLevel: 60.0)
        case .insect, .other:
            return SensorSnapshot(temperature: 24.0, humidity: 55.0, luminosity: 100.0, waterLevel: 50.0)
        }
    }
}
