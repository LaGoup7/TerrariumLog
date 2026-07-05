import Foundation

/// Météo horaire réelle de la veille sur le biotope, via Open-Meteo (gratuit,
/// sans clé). La journée d'hier est rejouée sur la journée en cours : à 14 h,
/// la lampe reflète le ciel qu'il faisait hier à 14 h là-bas.
/// Mise en cache par biotope et par jour (une seule requête quotidienne).
struct BiotopeHourlyWeather: Codable {
    /// Couverture nuageuse 0-100 % pour chacune des 24 h de la veille.
    let cloudCover: [Double]
    /// Précipitations (mm) pour chacune des 24 h.
    let precipitation: [Double]

    /// Facteur d'atténuation lumineuse pour une heure donnée (1 = plein soleil,
    /// ~0.45 = ciel totalement couvert).
    func lightFactor(hour: Int) -> Double {
        guard cloudCover.indices.contains(hour) else { return 1 }
        return 1 - 0.55 * (cloudCover[hour] / 100)
    }

    func isRaining(hour: Int) -> Bool {
        guard precipitation.indices.contains(hour) else { return false }
        return precipitation[hour] >= 0.3
    }

    var summary: String {
        let averageCloud = cloudCover.isEmpty ? 0 : cloudCover.reduce(0, +) / Double(cloudCover.count)
        let totalRain = precipitation.reduce(0, +)
        var parts: [String] = []
        switch averageCloud {
        case ..<25: parts.append("plutôt dégagé")
        case ..<60: parts.append("partiellement nuageux")
        default: parts.append("couvert")
        }
        if totalRain >= 1 {
            parts.append(String(format: "%.0f mm de pluie", totalRain))
        }
        return parts.joined(separator: ", ")
    }
}

final class BiotopeWeatherService {
    static let shared = BiotopeWeatherService()

    private var cache: [String: BiotopeHourlyWeather] = [:]

    /// Météo de la veille pour un biotope (cache mémoire + UserDefaults).
    func yesterdayWeather(for preset: BiotopePreset) async -> BiotopeHourlyWeather? {
        let dayStamp = Self.dayStamp(for: .now)
        let key = "biotopeWeather-\(preset.id)-\(dayStamp)"

        if let cached = cache[key] {
            return cached
        }
        if let data = UserDefaults.standard.data(forKey: key),
           let stored = try? JSONDecoder().decode(BiotopeHourlyWeather.self, from: data) {
            cache[key] = stored
            return stored
        }

        guard let fetched = await fetch(for: preset) else { return nil }
        cache[key] = fetched
        if let data = try? JSONEncoder().encode(fetched) {
            UserDefaults.standard.set(data, forKey: key)
        }
        return fetched
    }

    private func fetch(for preset: BiotopePreset) async -> BiotopeHourlyWeather? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(preset.latitude)),
            URLQueryItem(name: "longitude", value: String(preset.longitude)),
            URLQueryItem(name: "hourly", value: "cloud_cover,precipitation"),
            URLQueryItem(name: "past_days", value: "1"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: preset.timeZoneID)
        ]
        guard let url = components?.url else { return nil }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return Self.parse(data)
    }

    /// Extrait les 24 premières heures (la veille, grâce à past_days=1).
    static func parse(_ data: Data) -> BiotopeHourlyWeather? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hourly = object["hourly"] as? [String: Any],
              let clouds = hourly["cloud_cover"] as? [Any],
              let rain = hourly["precipitation"] as? [Any] else { return nil }

        func doubles(_ values: [Any], count: Int) -> [Double] {
            values.prefix(count).map { value in
                if let number = value as? Double { return number }
                if let number = value as? Int { return Double(number) }
                return 0
            }
        }

        let cloudCover = doubles(clouds, count: 24)
        let precipitation = doubles(rain, count: 24)
        guard !cloudCover.isEmpty else { return nil }
        return BiotopeHourlyWeather(cloudCover: cloudCover, precipitation: precipitation)
    }

    private static func dayStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
