import Foundation

/// Lieu de référence d'un biotope : la lampe peut suivre le soleil réel de la
/// région d'origine de l'animal (élévation solaire → intensité + teinte).
struct BiotopePreset: Identifiable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let timeZoneID: String

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneID) ?? .current
    }

    /// Régions couvrant les origines des espèces du catalogue.
    static let all: [BiotopePreset] = [
        BiotopePreset(id: "soroa", name: "Soroa, Cuba", latitude: 22.79, longitude: -83.01, timeZoneID: "America/Havana"),
        BiotopePreset(id: "guyane", name: "Guyane (plateau des Guyanes)", latitude: 4.92, longitude: -52.31, timeZoneID: "America/Cayenne"),
        BiotopePreset(id: "queensland", name: "Queensland, Australie", latitude: -16.92, longitude: 145.77, timeZoneID: "Australia/Brisbane"),
        BiotopePreset(id: "lucon", name: "Luçon, Philippines", latitude: 14.60, longitude: 121.00, timeZoneID: "Asia/Manila"),
        BiotopePreset(id: "thailande", name: "Thaïlande", latitude: 13.75, longitude: 100.50, timeZoneID: "Asia/Bangkok"),
        BiotopePreset(id: "madagascar", name: "Madagascar", latitude: -18.91, longitude: 47.54, timeZoneID: "Indian/Antananarivo"),
        BiotopePreset(id: "afriquecentrale", name: "Afrique équatoriale", latitude: 0.39, longitude: 9.45, timeZoneID: "Africa/Libreville"),
        BiotopePreset(id: "pakistan", name: "Pakistan (zones arides)", latitude: 30.20, longitude: 67.00, timeZoneID: "Asia/Karachi"),
        BiotopePreset(id: "mediterranee", name: "Bassin méditerranéen", latitude: 39.57, longitude: 2.65, timeZoneID: "Europe/Madrid"),
        BiotopePreset(id: "texas", name: "Sud des États-Unis", latitude: 29.42, longitude: -98.49, timeZoneID: "America/Chicago")
    ]

    static func preset(id: String?) -> BiotopePreset? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }
}

/// Consigne lampe dérivée du soleil : allumée ou non, intensité, teinte.
struct SunLightState: Equatable {
    let isDaylight: Bool
    /// 10–100 (%）quand allumée.
    let brightness: Int
    /// Température de couleur en kelvins (2200 aube/crépuscule → 6000 midi).
    let colorTemperature: Int
    /// Élévation solaire en degrés (pour l'affichage).
    let elevation: Double
}

/// Position du soleil (algorithme NOAA simplifié — précision largement
/// suffisante pour piloter une lampe) et consigne lumineuse associée.
enum SunCalculator {
    /// Élévation solaire (degrés) pour une horloge murale donnée à un lieu
    /// donné. `utcOffsetHours` est le décalage UTC de cette horloge murale.
    static func solarElevation(
        latitude: Double,
        longitude: Double,
        year: Int, month: Int, day: Int,
        hour: Int, minute: Int,
        utcOffsetHours: Double
    ) -> Double {
        let dayOfYear = Self.dayOfYear(year: year, month: month, day: day)
        let fractionalHour = Double(hour) + Double(minute) / 60

        // Angle fractionnaire de l'année (radians).
        let gamma = 2 * Double.pi / 365 * (Double(dayOfYear) - 1 + (fractionalHour - 12) / 24)

        // Équation du temps (minutes) et déclinaison solaire (radians) — NOAA.
        let eqTime = 229.18 * (0.000075
            + 0.001868 * cos(gamma) - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))
        let decl = 0.006918
            - 0.399912 * cos(gamma) + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)

        let timeOffset = eqTime + 4 * longitude - 60 * utcOffsetHours
        let trueSolarTime = fractionalHour * 60 + timeOffset
        let hourAngle = (trueSolarTime / 4 - 180) * Double.pi / 180

        let latRad = latitude * Double.pi / 180
        let cosZenith = sin(latRad) * sin(decl) + cos(latRad) * cos(decl) * cos(hourAngle)
        let zenith = acos(min(max(cosZenith, -1), 1))
        return 90 - zenith * 180 / Double.pi
    }

    /// Élévation actuelle du soleil sur le biotope.
    /// - `shiftedToLocalClock: false` → temps réel du biotope (décalage horaire
    ///   vécu : il fait nuit chez toi quand il fait jour là-bas).
    /// - `true` → la courbe du biotope est rejouée sur l'horloge locale
    ///   (le lever de soleil de là-bas arrive à la même heure « murale » ici).
    static func currentElevation(for preset: BiotopePreset, shiftedToLocalClock: Bool, at date: Date = .now) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = shiftedToLocalClock ? .current : preset.timeZone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let offsetHours = Double(preset.timeZone.secondsFromGMT(for: date)) / 3600
        return solarElevation(
            latitude: preset.latitude,
            longitude: preset.longitude,
            year: parts.year ?? 2026, month: parts.month ?? 1, day: parts.day ?? 1,
            hour: parts.hour ?? 12, minute: parts.minute ?? 0,
            utcOffsetHours: offsetHours
        )
    }

    /// Convertit une élévation solaire en consigne lampe : nuit sous -6°
    /// (crépuscule civil), puis montée en intensité et en blancheur.
    static func lightState(forElevation elevation: Double) -> SunLightState {
        guard elevation > -6 else {
            return SunLightState(isDaylight: false, brightness: 0, colorTemperature: 2200, elevation: elevation)
        }
        let brightness: Int
        let temperature: Int
        switch elevation {
        case ..<0:
            // Aube / crépuscule : lueur chaude.
            let progress = (elevation + 6) / 6
            brightness = 10 + Int(progress * 15)
            temperature = 2200
        case ..<10:
            let progress = elevation / 10
            brightness = 25 + Int(progress * 30)
            temperature = 2400 + Int(progress * 600)
        case ..<30:
            let progress = (elevation - 10) / 20
            brightness = 55 + Int(progress * 35)
            temperature = 3000 + Int(progress * 1800)
        default:
            let progress = min((elevation - 30) / 40, 1)
            brightness = 90 + Int(progress * 10)
            temperature = 4800 + Int(progress * 1200)
        }
        return SunLightState(
            isDaylight: true,
            brightness: min(brightness, 100),
            colorTemperature: min(temperature, 6000),
            elevation: elevation
        )
    }

    /// Consigne actuelle pour un biotope.
    static func currentState(for preset: BiotopePreset, shiftedToLocalClock: Bool, at date: Date = .now) -> SunLightState {
        lightState(forElevation: currentElevation(for: preset, shiftedToLocalClock: shiftedToLocalClock, at: date))
    }

    /// Durée du jour (heures) à une latitude donnée — formule analytique du
    /// coucher/lever (déclinaison solaire). Sert à la suggestion de diapause.
    static func dayLengthHours(latitude: Double, date: Date = .now) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let gamma = 2 * Double.pi / 365 * (Double(dayOfYear) - 1)
        let decl = 0.006918
            - 0.399912 * cos(gamma) + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)
        let latRad = latitude * Double.pi / 180
        let cosHourAngle = -tan(latRad) * tan(decl)
        if cosHourAngle <= -1 { return 24 } // jour polaire
        if cosHourAngle >= 1 { return 0 }   // nuit polaire
        return acos(cosHourAngle) * 24 / Double.pi
    }

    private static func dayOfYear(year: Int, month: Int, day: Int) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else { return 1 }
        return calendar.ordinality(of: .day, in: .year, for: date) ?? 1
    }
}

/// Phase lunaire approchée (cycle synodique moyen) — largement suffisante pour
/// décider d'une veilleuse de pleine lune.
enum MoonCalculator {
    static let synodicMonth = 29.530588853

    /// Fraction éclairée de la lune (0 = nouvelle lune, 1 = pleine lune).
    static func illumination(at date: Date = .now) -> Double {
        // Nouvelle lune de référence : 6 janvier 2000, 18:14 UTC.
        let reference = Date(timeIntervalSince1970: 947_182_440)
        let days = date.timeIntervalSince(reference) / 86400
        var phase = days.truncatingRemainder(dividingBy: synodicMonth) / synodicMonth
        if phase < 0 { phase += 1 }
        return (1 - cos(2 * Double.pi * phase)) / 2
    }
}
