import XCTest
@testable import TerrariumLog

final class WizCommandTests: XCTestCase {
    private func decodeParams(_ command: WizCommand) throws -> [String: AnyHashable] {
        let data = try WizCommandBuilder.encode(command)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let params = try XCTUnwrap(object?["params"] as? [String: Any])
        return params.compactMapValues { $0 as? AnyHashable }
    }

    func testPowerCommandSetsStateOnly() throws {
        let command = WizCommandBuilder.power(true)
        XCTAssertEqual(command.method, "setPilot")
        let params = try decodeParams(command)
        XCTAssertEqual(params["state"] as? Bool, true)
        XCTAssertNil(params["dimming"])
        XCTAssertNil(params["temp"])
    }

    func testBrightnessIsClampedToWizRange() {
        XCTAssertEqual(WizCommandBuilder.clampBrightness(5), 10)
        XCTAssertEqual(WizCommandBuilder.clampBrightness(150), 100)
        XCTAssertEqual(WizCommandBuilder.clampBrightness(50), 50)
    }

    func testColorTemperatureIsClampedToWizRange() {
        XCTAssertEqual(WizCommandBuilder.clampTemperature(1000), 2200)
        XCTAssertEqual(WizCommandBuilder.clampTemperature(9000), 6500)
        XCTAssertEqual(WizCommandBuilder.clampTemperature(4000), 4000)
    }

    func testBrightnessCommandEncodesClampedValue() throws {
        let command = WizCommandBuilder.brightness(5)
        let params = try decodeParams(command)
        XCTAssertEqual(params["dimming"] as? Int, 10)
    }

    func testColorCommandEncodesRGBComponentsOnly() throws {
        let command = WizCommandBuilder.color(red: 10, green: 20, blue: 30)
        let params = try decodeParams(command)
        XCTAssertEqual(params["r"] as? Int, 10)
        XCTAssertEqual(params["g"] as? Int, 20)
        XCTAssertEqual(params["b"] as? Int, 30)
        XCTAssertNil(params["state"])
        XCTAssertNil(params["sceneId"])
    }

    func testColorComponentsAreClampedToByteRange() throws {
        let command = WizCommandBuilder.color(red: -5, green: 300, blue: 128)
        let params = try decodeParams(command)
        XCTAssertEqual(params["r"] as? Int, 0)
        XCTAssertEqual(params["g"] as? Int, 255)
        XCTAssertEqual(params["b"] as? Int, 128)
    }

    func testEffectCommandEncodesSceneId() throws {
        let command = WizCommandBuilder.effect(.rainbow)
        let params = try decodeParams(command)
        XCTAssertEqual(params["sceneId"] as? Int, LightEffect.rainbow.wizSceneId)
        XCTAssertNil(params["speed"])
    }

    func testPulseBasedEffectEncodesSpeed() throws {
        let command = WizCommandBuilder.effect(.blink)
        let params = try decodeParams(command)
        XCTAssertEqual(params["sceneId"] as? Int, 31)
        XCTAssertEqual(params["speed"] as? Int, 190)
    }
}
