import XCTest
@testable import TerrariumLog

final class MeasurementStatsTests: XCTestCase {
    func testComputeWithNoMeasurementsReturnsNils() {
        let stats = MeasurementStats.compute(from: [])
        XCTAssertNil(stats.minTemperature)
        XCTAssertNil(stats.maxTemperature)
        XCTAssertNil(stats.avgTemperature)
        XCTAssertNil(stats.minHumidity)
        XCTAssertNil(stats.maxHumidity)
        XCTAssertNil(stats.avgHumidity)
    }

    func testComputeReturnsMinMaxAverage() {
        let measurements = [
            MeasurementEntry(date: .now, temperature: 20, humidity: 50),
            MeasurementEntry(date: .now, temperature: 26, humidity: 70),
            MeasurementEntry(date: .now, temperature: 23, humidity: 60)
        ]

        let stats = MeasurementStats.compute(from: measurements)

        XCTAssertEqual(stats.minTemperature, 20)
        XCTAssertEqual(stats.maxTemperature, 26)
        XCTAssertEqual(stats.avgTemperature ?? 0, 23, accuracy: 0.01)
        XCTAssertEqual(stats.minHumidity, 50)
        XCTAssertEqual(stats.maxHumidity, 70)
        XCTAssertEqual(stats.avgHumidity ?? 0, 60, accuracy: 0.01)
    }

    func testComputeIgnoresMissingValues() {
        let measurements = [
            MeasurementEntry(date: .now, temperature: 22, humidity: nil),
            MeasurementEntry(date: .now, temperature: nil, humidity: 65)
        ]

        let stats = MeasurementStats.compute(from: measurements)

        XCTAssertEqual(stats.avgTemperature, 22)
        XCTAssertEqual(stats.avgHumidity, 65)
    }
}
