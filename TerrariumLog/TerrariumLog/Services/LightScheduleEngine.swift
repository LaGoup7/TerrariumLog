import Foundation
import SwiftData

/// Résultat d'une synchronisation de lampe, pour l'affichage (icône + texte).
struct LightSyncOutcome: Equatable {
    let symbolName: String
    let statusText: String
    let isOn: Bool
}

/// Moteur UNIQUE du cycle jour/nuit des lampes : calcule la consigne du moment
/// (photopériode fixe ou biotope) et l'applique à la lampe. Utilisé par l'écran
/// lampe, par l'intent « Synchroniser les lampes » (Automatisations iOS) et par
/// le retour au premier plan de l'app — une seule implémentation, plus de
/// divergence entre l'écran et les raccourcis.
enum LightScheduleEngine {

    // MARK: Consigne photopériode fixe (pur, testable)

    /// Consigne pour une photopériode à horaires fixes. La journée suit une
    /// courbe naturelle (sinus) : aube chaude et faible, plateau autour de midi,
    /// crépuscule symétrique — pas d'allumage brutal, moins de stress.
    /// Gère les photopériodes à cheval sur minuit (start > end).
    static func fixedState(
        minutesSinceMidnight minutes: Int,
        dayStartMinutes start: Int,
        dayEndMinutes end: Int,
        dayBrightness: Int
    ) -> SunLightState {
        let dayLength: Int
        let elapsed: Int
        if start <= end {
            dayLength = end - start
            elapsed = minutes - start
        } else {
            // Photopériode inversée (à cheval sur minuit).
            dayLength = 24 * 60 - start + end
            elapsed = minutes >= start ? minutes - start : minutes + 24 * 60 - start
        }
        guard dayLength > 0, elapsed >= 0, elapsed <= dayLength else {
            return SunLightState(isDaylight: false, brightness: 0, colorTemperature: 2200, elevation: -10)
        }
        // Position dans la journée → élévation solaire virtuelle (0° → 60° → 0°),
        // puis réutilisation de la courbe intensité/teinte du soleil réel.
        let fraction = Double(elapsed) / Double(dayLength)
        let elevation = sin(fraction * .pi) * 60
        let state = SunCalculator.lightState(forElevation: elevation)
        let clampedDay = min(max(dayBrightness, 10), 100)
        return SunLightState(
            isDaylight: true,
            brightness: max(10, state.brightness * clampedDay / 100),
            colorTemperature: state.colorTemperature,
            elevation: elevation
        )
    }

    /// Consigne du moment pour une lampe selon son mode (nil = mode manuel :
    /// on ne touche pas à la lampe).
    static func targetState(for light: Light, at date: Date = .now) -> SunLightState? {
        switch light.scheduleMode {
        case .manual:
            return nil
        case .fixed:
            let calendar = Calendar.current
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            return fixedState(
                minutesSinceMidnight: minutes,
                dayStartMinutes: light.dayStartMinutes,
                dayEndMinutes: light.dayEndMinutes,
                dayBrightness: light.dayBrightness
            )
        case .biotope:
            guard let preset = BiotopePreset.preset(id: light.biotopePresetID) else { return nil }
            return SunCalculator.currentState(for: preset, shiftedToLocalClock: light.biotopeShiftedToLocal, at: date)
        }
    }

    // MARK: Application à la lampe

    /// Couleur de la lumière d'orage (pluie réelle sur le biotope).
    private static let stormColor = (red: 45, green: 65, blue: 105)
    /// Couleur de la veilleuse lunaire (nuits de pleine lune).
    private static let moonColor = (red: 70, green: 80, blue: 130)

    /// Calcule et applique la consigne du moment à une lampe configurée.
    /// Renvoie nil si la lampe est en mode manuel ou non configurée (on ne
    /// touche à rien), sinon le résultat pour l'affichage.
    /// `context` : les états `lastKnownOn`/`lastBrightness` sont mis à jour,
    /// à l'appelant de sauvegarder.
    @MainActor
    static func sync(_ light: Light, at date: Date = .now) async -> LightSyncOutcome? {
        guard let ip = light.ipAddress, !ip.isEmpty,
              light.scheduleMode != .manual,
              var state = targetState(for: light, at: date) else { return nil }

        let controller = LightControllerFactory.controller(for: light.brand)
        var isRainingNow = false
        var weatherNote = ""

        // Météo réelle de la veille (biotope uniquement) : les nuages modulent
        // l'intensité, la pluie peut déclencher la lumière d'orage.
        if light.scheduleMode == .biotope, light.biotopeWeatherEnabled, state.isDaylight,
           let preset = BiotopePreset.preset(id: light.biotopePresetID),
           let weather = await BiotopeWeatherService.shared.yesterdayWeather(for: preset) {
            var calendar = Calendar.current
            if !light.biotopeShiftedToLocal { calendar.timeZone = preset.timeZone }
            let hour = calendar.component(.hour, from: date)
            let factor = weather.lightFactor(hour: hour)
            isRainingNow = weather.isRaining(hour: hour)
            state = SunLightState(
                isDaylight: true,
                brightness: max(10, Int(Double(state.brightness) * factor)),
                colorTemperature: state.colorTemperature,
                elevation: state.elevation
            )
            weatherNote = isRainingNow ? " · pluie là-bas" : (factor < 0.75 ? " · nuageux" : "")
        }

        if state.isDaylight {
            if light.scheduleMode == .biotope, light.biotopeStormSyncEnabled, isRainingNow {
                // Pluie réelle sur le biotope : pénombre d'orage bleu-gris.
                try? await controller.setPower(true, ip: ip)
                try? await controller.setColor(red: stormColor.red, green: stormColor.green, blue: stormColor.blue, ip: ip)
                try? await controller.setBrightness(max(10, state.brightness / 2), ip: ip)
                light.lastKnownOn = true
                return LightSyncOutcome(
                    symbolName: "cloud.rain.fill",
                    statusText: "Pluie sur le biotope — lumière d'orage",
                    isOn: true
                )
            }
            try? await controller.setPower(true, ip: ip)
            try? await controller.setBrightness(state.brightness, ip: ip)
            try? await controller.setColorTemperature(state.colorTemperature, ip: ip)
            light.lastKnownOn = true
            light.lastBrightness = state.brightness
            let icon = state.elevation < 8 ? "sun.horizon.fill" : "sun.max.fill"
            let phase = light.scheduleMode == .biotope
                ? "Soleil à \(Int(state.elevation))°"
                : (state.elevation < 8 ? (isMorning(date: date, light: light) ? "Aube" : "Crépuscule") : "Jour")
            return LightSyncOutcome(
                symbolName: icon,
                statusText: "\(phase) → \(state.brightness) %\(weatherNote)",
                isOn: true
            )
        }

        // Nuit : veilleuse lunaire (optionnelle) ou extinction. Une lumière
        // nocturne quasi nulle et bleutée reste compatible avec les espèces
        // nocturnes ; sinon noir complet.
        let moonlight = MoonCalculator.illumination(at: date)
        if light.biotopeMoonEnabled, moonlight >= 0.55 {
            try? await controller.setPower(true, ip: ip)
            try? await controller.setColor(red: moonColor.red, green: moonColor.green, blue: moonColor.blue, ip: ip)
            try? await controller.setBrightness(10, ip: ip)
            light.lastKnownOn = true
            return LightSyncOutcome(
                symbolName: "moon.fill",
                statusText: "Nuit — lune à \(Int(moonlight * 100)) % : veilleuse lunaire",
                isOn: true
            )
        }
        try? await controller.setPower(false, ip: ip)
        light.lastKnownOn = false
        return LightSyncOutcome(
            symbolName: "moon.stars.fill",
            statusText: "Nuit — lampe éteinte",
            isOn: false
        )
    }

    /// Vrai si l'heure est dans la première moitié de la photopériode fixe
    /// (pour libeller « Aube » vs « Crépuscule »).
    private static func isMorning(date: Date, light: Light) -> Bool {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let start = light.dayStartMinutes
        let end = light.dayEndMinutes
        let dayLength = start <= end ? end - start : 24 * 60 - start + end
        let elapsed = minutes >= start ? minutes - start : minutes + 24 * 60 - start
        return elapsed <= dayLength / 2
    }

    /// Synchronise toutes les lampes qui ont un cycle actif (fixe ou biotope).
    /// Renvoie le nombre de lampes pilotées. Sauvegarde le contexte.
    @MainActor
    static func syncAll(context: ModelContext, at date: Date = .now) async -> Int {
        let lights = (try? context.fetch(FetchDescriptor<Light>())) ?? []
        var applied = 0
        for light in lights {
            if await sync(light, at: date) != nil {
                applied += 1
            }
        }
        try? context.save()
        return applied
    }

    // MARK: Migration de l'ancien champ Terrarium.wizLightIP

    /// Migre l'ancien système (IP WiZ saisie sur le terrarium) vers le modèle
    /// `Light` : pour chaque terrarium avec une IP héritée sans lampe
    /// correspondante, une lampe WiZ est créée puis le champ est vidé.
    /// Idempotente ; appelée au lancement et après un import de sauvegarde.
    /// (Pas d'isolation d'acteur : n'utilise que le contexte passé en paramètre.)
    static func migrateLegacyTerrariumLights(context: ModelContext) {
        let terrariums = (try? context.fetch(FetchDescriptor<Terrarium>())) ?? []
        let lights = (try? context.fetch(FetchDescriptor<Light>())) ?? []
        var knownIPs = Set(lights.compactMap { $0.ipAddress })
        var migrated = false

        for terrarium in terrariums {
            guard let ip = terrarium.wizLightIP, !ip.isEmpty else { continue }
            if !knownIPs.contains(ip) {
                let light = Light(
                    name: "Lampe \(terrarium.name)",
                    brand: .wiz,
                    ipAddress: ip,
                    terrarium: terrarium
                )
                context.insert(light)
                knownIPs.insert(ip)
            }
            terrarium.wizLightIP = nil
            migrated = true
        }
        if migrated {
            try? context.save()
        }
    }
}
