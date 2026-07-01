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
        }
    }
}
