import Foundation

struct WizPilotParams: Encodable {
    var state: Bool? = nil
    var dimming: Int? = nil
    var temp: Int? = nil
    var r: Int? = nil
    var g: Int? = nil
    var b: Int? = nil
    var sceneId: Int? = nil
    var speed: Int? = nil
}

struct WizCommand: Encodable {
    let method: String
    let params: WizPilotParams
}

enum WizCommandBuilder {
    static func power(_ isOn: Bool) -> WizCommand {
        WizCommand(method: "setPilot", params: WizPilotParams(state: isOn))
    }

    static func brightness(_ percent: Int) -> WizCommand {
        WizCommand(method: "setPilot", params: WizPilotParams(dimming: clampBrightness(percent)))
    }

    static func colorTemperature(_ kelvin: Int) -> WizCommand {
        WizCommand(method: "setPilot", params: WizPilotParams(temp: clampTemperature(kelvin)))
    }

    static func color(red: Int, green: Int, blue: Int) -> WizCommand {
        WizCommand(method: "setPilot", params: WizPilotParams(r: clampByte(red), g: clampByte(green), b: clampByte(blue)))
    }

    static func effect(_ effect: LightEffect) -> WizCommand {
        WizCommand(method: "setPilot", params: WizPilotParams(sceneId: effect.wizSceneId, speed: effect.wizSpeed.map(clampSpeed)))
    }

    /// Scène WiZ arbitraire (utilisée par les ambiances thématiques).
    static func scene(id: Int, speed: Int? = nil) -> WizCommand {
        WizCommand(method: "setPilot", params: WizPilotParams(sceneId: id, speed: speed.map(clampSpeed)))
    }

    static func clampBrightness(_ percent: Int) -> Int {
        min(max(percent, 10), 100)
    }

    static func clampTemperature(_ kelvin: Int) -> Int {
        min(max(kelvin, 2200), 6500)
    }

    static func clampByte(_ value: Int) -> Int {
        min(max(value, 0), 255)
    }

    static func clampSpeed(_ speed: Int) -> Int {
        min(max(speed, 10), 200)
    }

    static func encode(_ command: WizCommand) throws -> Data {
        try JSONEncoder().encode(command)
    }
}
