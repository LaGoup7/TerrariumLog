import AppIntents
import Foundation
import SwiftData

/// Actions Habitat exposées à Siri, à l'app Raccourcis et aux Automatisations
/// iOS. C'est ce qui permet un vrai cycle jour/nuit : une Automatisation
/// personnelle (« tous les jours à 8 h ») exécute l'intent en arrière-plan,
/// sans ouvrir l'app.
@MainActor
enum HabitatIntentActions {
    /// Allume/éteint toutes les lampes configurées (modèle `Light` + IP WiZ
    /// héritée des terrariums), en dédupliquant les adresses.
    static func setAllLights(on: Bool) async -> Int {
        let context = PersistenceController.shared.container.mainContext
        var ips = Set<String>()

        let lights = (try? context.fetch(FetchDescriptor<Light>())) ?? []
        for light in lights {
            if let ip = light.ipAddress, !ip.isEmpty { ips.insert(ip) }
        }
        let terrariums = (try? context.fetch(FetchDescriptor<Terrarium>())) ?? []
        for terrarium in terrariums {
            if let ip = terrarium.wizLightIP, !ip.isEmpty { ips.insert(ip) }
        }

        for ip in ips {
            try? await WizLightService.shared.send(WizCommandBuilder.power(on), to: ip)
        }
        for light in lights where light.isConfigured {
            light.lastKnownOn = on
        }
        try? context.save()
        return ips.count
    }

    /// Applique la consigne « biotope » (soleil réel de la région d'origine,
    /// météo de la veille si activée) à toutes les lampes configurées.
    static func syncBiotopeLights() async -> Int {
        let context = PersistenceController.shared.container.mainContext
        let lights = (try? context.fetch(FetchDescriptor<Light>())) ?? []
        var applied = 0
        for light in lights {
            guard let preset = BiotopePreset.preset(id: light.biotopePresetID),
                  let ip = light.ipAddress, !ip.isEmpty else { continue }

            var state = SunCalculator.currentState(for: preset, shiftedToLocalClock: light.biotopeShiftedToLocal)
            if light.biotopeWeatherEnabled, state.isDaylight,
               let weather = await BiotopeWeatherService.shared.yesterdayWeather(for: preset) {
                var calendar = Calendar.current
                if !light.biotopeShiftedToLocal { calendar.timeZone = preset.timeZone }
                let hour = calendar.component(.hour, from: .now)
                let factor = weather.lightFactor(hour: hour)
                state = SunLightState(
                    isDaylight: true,
                    brightness: max(10, Int(Double(state.brightness) * factor)),
                    colorTemperature: state.colorTemperature,
                    elevation: state.elevation
                )
            }

            let service = WizLightService.shared
            if state.isDaylight {
                try? await service.send(WizCommandBuilder.power(true), to: ip)
                try? await service.send(WizCommandBuilder.brightness(state.brightness), to: ip)
                try? await service.send(WizCommandBuilder.colorTemperature(state.colorTemperature), to: ip)
                light.lastKnownOn = true
            } else {
                try? await service.send(WizCommandBuilder.power(false), to: ip)
                light.lastKnownOn = false
            }
            applied += 1
        }
        try? context.save()
        return applied
    }

    /// Déclenche la brumisation (`mist == true`) ou l'arrosage sur tous les
    /// terrariums équipés d'un module capteurs. Renvoie le nombre de succès.
    static func triggerSensorAction(mist: Bool) async -> Int {
        let context = PersistenceController.shared.container.mainContext
        let terrariums = (try? context.fetch(FetchDescriptor<Terrarium>())) ?? []
        var successes = 0
        for terrarium in terrariums {
            guard let ip = terrarium.sensorModuleIP, !ip.isEmpty else { continue }
            let client = TerrariumSensorClient(ip: ip)
            do {
                if mist {
                    try await client.triggerMist()
                } else {
                    try await client.triggerWater()
                }
                successes += 1
            } catch {
                continue
            }
        }
        return successes
    }
}

struct TurnTerrariumLightsOnIntent: AppIntent {
    static var title: LocalizedStringResource = "Allumer les lumières"
    static var description = IntentDescription("Allume toutes les lampes de terrarium configurées dans Habitat.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let count = await HabitatIntentActions.setAllLights(on: true)
        if count > 0 {
            return .result(dialog: "\(count) lampe(s) allumée(s).")
        }
        return .result(dialog: "Aucune lampe configurée dans Habitat.")
    }
}

struct TurnTerrariumLightsOffIntent: AppIntent {
    static var title: LocalizedStringResource = "Éteindre les lumières"
    static var description = IntentDescription("Éteint toutes les lampes de terrarium configurées dans Habitat.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let count = await HabitatIntentActions.setAllLights(on: false)
        if count > 0 {
            return .result(dialog: "\(count) lampe(s) éteinte(s).")
        }
        return .result(dialog: "Aucune lampe configurée dans Habitat.")
    }
}

struct MistTerrariumIntent: AppIntent {
    static var title: LocalizedStringResource = "Brumiser le terrarium"
    static var description = IntentDescription("Déclenche la brumisation sur les terrariums équipés d'un module capteurs.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let count = await HabitatIntentActions.triggerSensorAction(mist: true)
        if count > 0 {
            return .result(dialog: "Brumisation déclenchée (\(count) terrarium(s)).")
        }
        return .result(dialog: "Aucun module capteurs joignable.")
    }
}

struct WaterTerrariumIntent: AppIntent {
    static var title: LocalizedStringResource = "Arroser les plantes"
    static var description = IntentDescription("Déclenche l'arrosage sur les terrariums équipés d'un module capteurs.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let count = await HabitatIntentActions.triggerSensorAction(mist: false)
        if count > 0 {
            return .result(dialog: "Arrosage déclenché (\(count) terrarium(s)).")
        }
        return .result(dialog: "Aucun module capteurs joignable.")
    }
}

struct SyncBiotopeIntent: AppIntent {
    static var title: LocalizedStringResource = "Synchroniser le biotope"
    static var description = IntentDescription("Aligne les lampes sur le soleil réel de la région d'origine (et la météo de la veille si activée).")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let count = await HabitatIntentActions.syncBiotopeLights()
        if count > 0 {
            return .result(dialog: "Biotope synchronisé (\(count) lampe(s)).")
        }
        return .result(dialog: "Aucune lampe avec un biotope configuré.")
    }
}

/// Phrases Siri et raccourcis proposés d'office dans l'app Raccourcis.
struct HabitatShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TurnTerrariumLightsOnIntent(),
            phrases: ["Allume le terrarium avec \(.applicationName)"],
            shortTitle: "Allumer",
            systemImageName: "lightbulb.fill"
        )
        AppShortcut(
            intent: TurnTerrariumLightsOffIntent(),
            phrases: ["Éteins le terrarium avec \(.applicationName)"],
            shortTitle: "Éteindre",
            systemImageName: "lightbulb"
        )
        AppShortcut(
            intent: MistTerrariumIntent(),
            phrases: ["Brumise le terrarium avec \(.applicationName)"],
            shortTitle: "Brumiser",
            systemImageName: "cloud.fog.fill"
        )
        AppShortcut(
            intent: SyncBiotopeIntent(),
            phrases: ["Synchronise le biotope avec \(.applicationName)"],
            shortTitle: "Biotope",
            systemImageName: "globe.americas.fill"
        )
        AppShortcut(
            intent: WaterTerrariumIntent(),
            phrases: ["Arrose le terrarium avec \(.applicationName)"],
            shortTitle: "Arroser",
            systemImageName: "drop.fill"
        )
    }
}
