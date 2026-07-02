import Foundation
import SwiftData

@Model
final class Camera {
    var name: String
    var brand: CameraBrand
    var model: String
    var connectionType: CameraConnectionType
    var streamURL: String?
    var ipAddress: String?
    var username: String?
    var password: String?
    var notes: String
    var createdAt: Date

    var terrarium: Terrarium?

    init(
        name: String,
        brand: CameraBrand = .tapo,
        model: String = "",
        connectionType: CameraConnectionType = .unconfigured,
        streamURL: String? = nil,
        ipAddress: String? = nil,
        username: String? = nil,
        password: String? = nil,
        notes: String = "",
        createdAt: Date = .now,
        terrarium: Terrarium? = nil
    ) {
        self.name = name
        self.brand = brand
        self.model = model
        self.connectionType = connectionType
        self.streamURL = streamURL
        self.ipAddress = ipAddress
        self.username = username
        self.password = password
        self.notes = notes
        self.createdAt = createdAt
        self.terrarium = terrarium
    }

    var isConfigured: Bool {
        connectionType != .unconfigured && !(streamURL ?? "").isEmpty
    }
}

enum CameraBrand: String, Codable, CaseIterable, Sendable {
    case tapo
    case reolink
    case esp32cam
    case other

    var displayName: String {
        switch self {
        case .tapo: return "TP-Link Tapo"
        case .reolink: return "Reolink"
        case .esp32cam: return "ESP32-CAM"
        case .other: return "Autre"
        }
    }
}

enum CameraConnectionType: String, Codable, CaseIterable, Sendable {
    case unconfigured
    case rtsp
    case http
    case cloud

    var displayName: String {
        switch self {
        case .unconfigured: return "Non configuré"
        case .rtsp: return "RTSP (réseau local)"
        case .http: return "HTTP (snapshot/MJPEG)"
        case .cloud: return "Cloud fabricant"
        }
    }
}
