import Foundation

/// Abstraction de pilotage d'une lampe, indépendante de la marque.
///
/// Chaque marque fournit son implémentation ; `LightControllerFactory` choisit
/// la bonne selon `Light.brand`. Ajouter une marque = ajouter un `case` à
/// `LightBrand`, une implémentation ici, et l'enregistrer dans la factory —
/// sans toucher aux vues.
protocol LightController {
    var supportsColor: Bool { get }
    var supportsEffects: Bool { get }

    func setPower(_ isOn: Bool, ip: String) async throws
    func setBrightness(_ percent: Int, ip: String) async throws
    func setColor(red: Int, green: Int, blue: Int, ip: String) async throws
    func setColorTemperature(_ kelvin: Int, ip: String) async throws
    func setEffect(_ effect: LightEffect, ip: String) async throws
}

enum LightControllerFactory {
    static func controller(for brand: LightBrand) -> LightController {
        switch brand {
        case .wiz: return WizLightController()
        case .other: return UnsupportedLightController()
        }
    }
}

/// Pilote une lampe WiZ via son API locale UDP (voir `WizLightService`).
struct WizLightController: LightController {
    let supportsColor = true
    let supportsEffects = true

    private var service: WizLightService { WizLightService.shared }

    func setPower(_ isOn: Bool, ip: String) async throws {
        try await service.send(WizCommandBuilder.power(isOn), to: ip)
    }

    func setBrightness(_ percent: Int, ip: String) async throws {
        try await service.send(WizCommandBuilder.brightness(percent), to: ip)
    }

    func setColor(red: Int, green: Int, blue: Int, ip: String) async throws {
        try await service.send(WizCommandBuilder.color(red: red, green: green, blue: blue), to: ip)
    }

    func setColorTemperature(_ kelvin: Int, ip: String) async throws {
        try await service.send(WizCommandBuilder.colorTemperature(kelvin), to: ip)
    }

    func setEffect(_ effect: LightEffect, ip: String) async throws {
        try await service.send(WizCommandBuilder.effect(effect), to: ip)
    }
}

/// Marque déclarée mais pas encore prise en charge : renvoie une erreur claire
/// plutôt que d'échouer silencieusement, tant qu'aucun pilote n'est écrit.
struct UnsupportedLightController: LightController {
    let supportsColor = false
    let supportsEffects = false

    struct NotSupported: LocalizedError {
        var errorDescription: String? { "Cette marque de lampe n'est pas encore prise en charge." }
    }

    func setPower(_ isOn: Bool, ip: String) async throws { throw NotSupported() }
    func setBrightness(_ percent: Int, ip: String) async throws { throw NotSupported() }
    func setColor(red: Int, green: Int, blue: Int, ip: String) async throws { throw NotSupported() }
    func setColorTemperature(_ kelvin: Int, ip: String) async throws { throw NotSupported() }
    func setEffect(_ effect: LightEffect, ip: String) async throws { throw NotSupported() }
}
