import Foundation

/// Point d'extension pour la lecture vidéo réelle. AVPlayer ne lit pas nativement le RTSP :
/// la lecture passe par VLCKit (voir `CameraStreamView`), à qui l'on fournit l'URL construite ici.
protocol CameraStreamProvider {
    /// URL réellement jouable, identifiants inclus.
    func playableURL(for camera: Camera) -> URL?
    /// Même URL, mais mot de passe masqué — pour l'affichage à l'écran.
    func redactedURLString(for camera: Camera) -> String?
}

/// Construit l'URL RTSP à partir de la configuration de la caméra :
/// - part de `streamURL` si renseignée, sinon fabrique une URL Tapo par défaut
///   depuis l'IP (`rtsp://<ip>:554/stream1`) ;
/// - injecte les identifiants du **compte caméra** dans l'URL s'ils n'y sont pas
///   déjà — indispensable pour les Tapo (sinon 401 → écran noir).
struct RTSPPassthroughProvider: CameraStreamProvider {
    func playableURL(for camera: Camera) -> URL? {
        resolvedComponents(for: camera)?.url
    }

    func redactedURLString(for camera: Camera) -> String? {
        guard var components = resolvedComponents(for: camera) else { return nil }
        if components.password != nil {
            components.password = "••••"
        }
        return components.string
    }

    private func resolvedComponents(for camera: Camera) -> URLComponents? {
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
