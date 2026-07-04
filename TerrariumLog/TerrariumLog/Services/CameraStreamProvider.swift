import Foundation

/// Point d'extension pour la lecture vidéo réelle. AVPlayer ne lit pas nativement le RTSP :
/// la lecture passe par VLCKit (voir `CameraStreamView`), à qui l'on fournit l'URL construite ici.
protocol CameraStreamProvider {
    /// URL réellement jouable, identifiants inclus.
    /// - Parameter streamPathOverride: si fourni (ex. `"stream2"`), remplace le
    ///   chemin du flux — utile pour basculer HD/SD sur les Tapo.
    func playableURL(for camera: Camera, streamPathOverride: String?) -> URL?
    /// Même URL, mais mot de passe masqué — pour l'affichage à l'écran.
    func redactedURLString(for camera: Camera, streamPathOverride: String?) -> String?
}

extension CameraStreamProvider {
    func playableURL(for camera: Camera) -> URL? {
        playableURL(for: camera, streamPathOverride: nil)
    }

    func redactedURLString(for camera: Camera) -> String? {
        redactedURLString(for: camera, streamPathOverride: nil)
    }
}

/// Construit l'URL RTSP à partir de la configuration de la caméra :
/// - part de `streamURL` si renseignée, sinon fabrique une URL Tapo par défaut
///   depuis l'IP (`rtsp://<ip>:554/stream1`) ;
/// - injecte les identifiants du **compte caméra** dans l'URL s'ils n'y sont pas
///   déjà — indispensable pour les Tapo (sinon 401 → écran noir).
struct RTSPPassthroughProvider: CameraStreamProvider {
    func playableURL(for camera: Camera, streamPathOverride: String?) -> URL? {
        resolvedComponents(for: camera, streamPathOverride: streamPathOverride)?.url
    }

    func redactedURLString(for camera: Camera, streamPathOverride: String?) -> String? {
        guard let components = resolvedComponents(for: camera, streamPathOverride: streamPathOverride) else { return nil }
        // Reconstruction manuelle pour un rendu lisible : `components.string`
        // encoderait le masque en %E2%80%A2… (bullets). On masque proprement.
        let scheme = components.scheme ?? "rtsp"
        var auth = ""
        if let user = components.user, !user.isEmpty {
            auth = components.password != nil ? "\(user):••••@" : "\(user)@"
        }
        let host = components.host ?? ""
        let port = components.port.map { ":\($0)" } ?? ""
        return "\(scheme)://\(auth)\(host)\(port)\(components.path)"
    }

    private func resolvedComponents(for camera: Camera, streamPathOverride: String?) -> URLComponents? {
        let raw = (camera.streamURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let base: String
        if !raw.isEmpty {
            base = raw
        } else {
            // Pas d'URL explicite : on tente l'URL RTSP Tapo standard depuis l'IP.
            let ip = (camera.ipAddress ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ip.isEmpty else { return nil }
            base = "rtsp://\(ip):554/stream1"
        }

        guard var components = URLComponents(string: base) else { return nil }

        // Bascule éventuelle du chemin (HD/SD) sans toucher à la config stockée.
        if let override = streamPathOverride, !override.isEmpty {
            components.path = override.hasPrefix("/") ? override : "/\(override)"
        }

        // Injecte les identifiants seulement si l'URL n'en porte pas déjà.
        // `URLComponents` gère l'encodage des caractères spéciaux du mot de passe,
        // ce qui évite les URL cassées quand l'utilisateur les tape à la main.
        if (components.user ?? "").isEmpty {
            let user = (camera.username ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !user.isEmpty {
                components.user = user
                let password = camera.password ?? ""
                if !password.isEmpty {
                    components.password = password
                }
            }
        }

        return components
    }
}
