import Foundation

/// Relevé instantané renvoyé par le module capteurs du terrarium (ESP32).
struct TerrariumSensorReading: Equatable {
    var temperature: Double?
    var humidity: Double?
    /// Humidité du sol en % (capteur capacitif).
    var soilMoisture: Double?
    var luminosity: Double?

    var isEmpty: Bool {
        temperature == nil && humidity == nil && soilMoisture == nil && luminosity == nil
    }

    /// Décode le JSON du module en tolérant plusieurs noms de clés, pour rester
    /// compatible avec les sketchs maison (`temp` ou `temperature`, `hum` ou
    /// `humidity`, `soil`/`sol`, `lux`/`luminosity`).
    static func fromJSON(_ data: Data) -> TerrariumSensorReading? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        func number(_ keys: [String]) -> Double? {
            for key in keys {
                if let value = object[key] as? Double { return value }
                if let value = object[key] as? Int { return Double(value) }
                if let value = object[key] as? String, let parsed = Double(value) { return parsed }
            }
            return nil
        }
        let reading = TerrariumSensorReading(
            temperature: number(["temperature", "temp", "t"]),
            humidity: number(["humidity", "hum", "h"]),
            soilMoisture: number(["soil", "sol", "soil_moisture", "soilMoisture"]),
            luminosity: number(["luminosity", "lux", "light"])
        )
        return reading.isEmpty ? nil : reading
    }
}

/// Client HTTP du module capteurs/actionneurs (ESP32) d'un terrarium.
/// Même philosophie que les lampes WiZ et les caméras : IP locale, zéro cloud.
/// API attendue côté module (voir docs/capteurs-terrarium.md) :
///   GET  /sensors → {"temperature":24.5,"humidity":78,"soil":41,"lux":120}
///   POST /mist    → déclenche le brumisateur quelques secondes
///   POST /water   → déclenche la pompe d'arrosage quelques secondes
struct TerrariumSensorClient {
    let ip: String
    var port: Int = 80
    var timeout: TimeInterval = 6

    enum SensorError: LocalizedError {
        case badURL
        case http(Int)
        case badPayload

        var errorDescription: String? {
            switch self {
            case .badURL: return "Adresse IP du module invalide"
            case .http(let code): return "Le module a répondu HTTP \(code)"
            case .badPayload: return "Réponse du module illisible (JSON attendu)"
            }
        }
    }

    /// Lit les valeurs actuelles des capteurs.
    func fetchReading() async throws -> TerrariumSensorReading {
        let data = try await request(path: "/sensors", method: "GET")
        guard let reading = TerrariumSensorReading.fromJSON(data) else {
            throw SensorError.badPayload
        }
        return reading
    }

    /// Déclenche le brumisateur (durée gérée côté module).
    func triggerMist() async throws {
        _ = try await request(path: "/mist", method: "POST")
    }

    /// Déclenche la pompe d'arrosage (durée gérée côté module).
    func triggerWater() async throws {
        _ = try await request(path: "/water", method: "POST")
    }

    private func request(path: String, method: String) async throws -> Data {
        let trimmed = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: "http://\(trimmed):\(port)\(path)") else {
            throw SensorError.badURL
        }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw SensorError.http(status)
        }
        return data
    }
}
