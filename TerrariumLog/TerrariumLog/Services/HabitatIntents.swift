import AppIntents
import Foundation
import SwiftData

/// Actions Habitat exposées à Siri, à l'app Raccourcis et aux Automatisations
/// iOS. C'est ce qui permet un vrai cycle jour/nuit : une Automatisation
/// personnelle (« tous les jours à 8 h ») exécute l'intent en arrière-plan,
/// sans ouvrir l'app.
@MainActor
enum HabitatIntentActions {
    /// Allume/éteint toutes les lampes configurées, via le contrôleur de la
    /// marque de chaque lampe. L'ancienne IP WiZ des terrariums est migrée en
    /// `Light` au préalable (voir `LightScheduleEngine`).
    static func setAllLights(on: Bool) async -> Int {
        let context = PersistenceController.shared.container.mainContext
        LightScheduleEngine.migrateLegacyTerrariumLights(context: context)

        let lights = (try? context.fetch(FetchDescriptor<Light>())) ?? []
        var count = 0
        for light in lights {
            guard let ip = light.ipAddress, !ip.isEmpty else { continue }
            let controller = LightControllerFactory.controller(for: light.brand)
            try? await controller.setPower(on, ip: ip)
            light.lastKnownOn = on
            count += 1
        }
        try? context.save()
        return count
    }

    /// Applique le cycle jour/nuit du moment (photopériode fixe ou biotope) à
    /// toutes les lampes qui en ont un — même logique que l'écran lampe, via le
    /// `LightScheduleEngine`.
    static func syncScheduledLights() async -> Int {
        let context = PersistenceController.shared.container.mainContext
        LightScheduleEngine.migrateLegacyTerrariumLights(context: context)
        return await LightScheduleEngine.syncAll(context: context)
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
    static var title: LocalizedStringResource = "Synchroniser les lampes"
    static var description = IntentDescription("Applique le cycle jour/nuit du moment à toutes les lampes (photopériode fixe ou soleil réel du biotope, avec météo si activée).")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let count = await HabitatIntentActions.syncScheduledLights()
        if count > 0 {
            return .result(dialog: "\(count) lampe(s) synchronisée(s).")
        }
        return .result(dialog: "Aucune lampe avec un cycle jour/nuit configuré.")
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
            phrases: ["Synchronise le biotope avec \(.applicationName)", "Synchronise les lampes avec \(.applicationName)"],
            shortTitle: "Synchroniser",
            systemImageName: "sun.max.fill"
        )
        AppShortcut(
            intent: WaterTerrariumIntent(),
            phrases: ["Arrose le terrarium avec \(.applicationName)"],
            shortTitle: "Arroser",
            systemImageName: "drop.fill"
        )
    }
}
