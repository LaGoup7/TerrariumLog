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

    func testDayLengthSeasons() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let june = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21))!
        let december = calendar.date(from: DateComponents(year: 2026, month: 12, day: 21))!

        let parisSummer = SunCalculator.dayLengthHours(latitude: 48.85, date: june)
        let parisWinter = SunCalculator.dayLengthHours(latitude: 48.85, date: december)
        XCTAssertGreaterThan(parisSummer, 15)
        XCTAssertLessThan(parisWinter, 9.5)

        // Aux tropiques, la durée du jour varie peu.
        let cubaSummer = SunCalculator.dayLengthHours(latitude: 22.79, date: june)
        let cubaWinter = SunCalculator.dayLengthHours(latitude: 22.79, date: december)
        XCTAssertLessThan(abs(cubaSummer - cubaWinter), 3.5)
    }

    func testMoonIlluminationCycle() {
        // Nouvelle lune de référence (6 janvier 2000, 18:14 UTC) : ~0.
        let newMoon = Date(timeIntervalSince1970: 947_182_440)
        XCTAssertLessThan(MoonCalculator.illumination(at: newMoon), 0.02)
        // Une demi-lunaison plus tard : pleine lune (~1).
        let fullMoon = newMoon.addingTimeInterval(MoonCalculator.synodicMonth / 2 * 86400)
        XCTAssertGreaterThan(MoonCalculator.illumination(at: fullMoon), 0.98)
        // Toujours borné à [0, 1].
        let anyDate = Date(timeIntervalSince1970: 1_780_000_000)
        let value = MoonCalculator.illumination(at: anyDate)
        XCTAssertTrue((0...1).contains(value))
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
