import XCTest
@testable import TerrariumLog

final class SunCalculatorTests: XCTestCase {
    // La Havane / Soroa : UTC-5 (hiver) ou UTC-4 (été, DST cubain).
    func testNoonIsDaylightInHavanaSummer() {
        let elevation = SunCalculator.solarElevation(
            latitude: 22.79, longitude: -83.01,
            year: 2026, month: 7, day: 5,
            hour: 13, minute: 0,
            utcOffsetHours: -4
        )
        XCTAssertGreaterThan(elevation, 60, "Midi solaire d'été aux tropiques : soleil très haut")
    }

    func testMidnightIsNightInHavana() {
        let elevation = SunCalculator.solarElevation(
            latitude: 22.79, longitude: -83.01,
            year: 2026, month: 7, day: 5,
            hour: 1, minute: 0,
            utcOffsetHours: -4
        )
        XCTAssertLessThan(elevation, -10)
    }

    func testWinterNoonIsLowerThanSummerNoon() {
        let summer = SunCalculator.solarElevation(
            latitude: 48.85, longitude: 2.35,
            year: 2026, month: 6, day: 21, hour: 13, minute: 50, utcOffsetHours: 2
        )
        let winter = SunCalculator.solarElevation(
            latitude: 48.85, longitude: 2.35,
            year: 2026, month: 12, day: 21, hour: 12, minute: 50, utcOffsetHours: 1
        )
        XCTAssertGreaterThan(summer, winter + 30, "L'écart été/hiver à Paris dépasse 40°")
    }

    func testLightStateMapping() {
        XCTAssertFalse(SunCalculator.lightState(forElevation: -10).isDaylight)
        let dawn = SunCalculator.lightState(forElevation: -3)
        XCTAssertTrue(dawn.isDaylight)
        XCTAssertEqual(dawn.colorTemperature, 2200)
        XCTAssertLessThan(dawn.brightness, 30)
        let noon = SunCalculator.lightState(forElevation: 70)
        XCTAssertEqual(noon.brightness, 100)
        XCTAssertGreaterThanOrEqual(noon.colorTemperature, 5500)
    }

    func testWeatherParsing() throws {
        let json = """
        {"hourly": {"cloud_cover": [10, 80, 100], "precipitation": [0, 0.5, 2.1]}}
        """
        let weather = try XCTUnwrap(BiotopeWeatherService.parse(Data(json.utf8)))
        XCTAssertEqual(weather.lightFactor(hour: 0), 1 - 0.55 * 0.10, accuracy: 0.001)
        XCTAssertFalse(weather.isRaining(hour: 0))
        XCTAssertTrue(weather.isRaining(hour: 1))
        XCTAssertTrue(weather.isRaining(hour: 2))
        // Heure hors bornes : neutre.
        XCTAssertEqual(weather.lightFactor(hour: 23), 1)
    }
}
