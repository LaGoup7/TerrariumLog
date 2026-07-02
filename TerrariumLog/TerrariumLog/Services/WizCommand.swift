import Foundation

struct WizPilotParams: Encodable {
    var state: Bool?
    var dimming: Int?
    var temp: Int?
}

struct WizCommand: Encodable {
    let method: String
    let params: WizPilotParams
}

enum WizCommandBuilder {
    static func power(_ isOn: Bool) -> WizCommand {
        WizCommand(method: "setPilot", params: WizPilotParams(state: isOn, dimming: nil, temp: nil))
    }

    static func brightness(_ percent: Int) -> WizCommand {
        WizCommand(method: "setPilot", params: WizPilotParams(state: nil, dimming: clampBrightness(percent), temp: nil))
    }

    static func colorTemperature(_ kelvin: Int) -> WizCommand {
        WizCommand(method: "setPilot", params: WizPilotParams(state: nil, dimming: nil, temp: clampTemperature(kelvin)))
    }

    static func clampBrightness(_ percent: Int) -> Int {
        min(max(percent, 10), 100)
    }

    static func clampTemperature(_ kelvin: Int) -> Int {
        min(max(kelvin, 2200), 6500)
    }

    static func encode(_ command: WizCommand) throws -> Data {
        try JSONEncoder().encode(command)
    }
}
