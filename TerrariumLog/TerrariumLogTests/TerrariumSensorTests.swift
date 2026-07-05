import XCTest
@testable import TerrariumLog

final class TerrariumSensorTests: XCTestCase {
    func testParsesCanonicalKeys() throws {
        let json = #"{"temperature":24.5,"humidity":78,"soil":41,"lux":120}"#
        let reading = try XCTUnwrap(TerrariumSensorReading.fromJSON(Data(json.utf8)))
        XCTAssertEqual(reading.temperature, 24.5)
        XCTAssertEqual(reading.humidity, 78)
        XCTAssertEqual(reading.soilMoisture, 41)
        XCTAssertEqual(reading.luminosity, 120)
    }

    func testParsesShortKeysAndStrings() throws {
        let json = #"{"temp":"26.1","hum":65,"sol":30}"#
        let reading = try XCTUnwrap(TerrariumSensorReading.fromJSON(Data(json.utf8)))
        XCTAssertEqual(reading.temperature, 26.1)
        XCTAssertEqual(reading.humidity, 65)
        XCTAssertEqual(reading.soilMoisture, 30)
        XCTAssertNil(reading.luminosity)
    }

    func testPartialPayloadIsAccepted() throws {
        let json = #"{"humidity":55}"#
        let reading = try XCTUnwrap(TerrariumSensorReading.fromJSON(Data(json.utf8)))
        XCTAssertNil(reading.temperature)
        XCTAssertEqual(reading.humidity, 55)
    }

    func testEmptyOrInvalidPayloadReturnsNil() {
        XCTAssertNil(TerrariumSensorReading.fromJSON(Data(#"{"status":"ok"}"#.utf8)))
        XCTAssertNil(TerrariumSensorReading.fromJSON(Data("pas du json".utf8)))
    }
}
