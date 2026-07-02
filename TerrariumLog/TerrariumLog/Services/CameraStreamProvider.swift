import Foundation

/// Point d'extension pour la lecture vidéo réelle. AVPlayer ne lit pas nativement le RTSP :
/// une future implémentation pourra convertir/transcoder (ex: via une librairie comme VLCKit,
/// ou un relai RTSP→HLS) sans changer les vues qui consomment ce protocole.
protocol CameraStreamProvider {
    func playableURL(for camera: Camera) -> URL?
}

/// Implémentation V1 : renvoie l'URL du flux telle quelle, sans transcodage.
/// Suffisant pour stocker/valider la configuration ; un vrai lecteur RTSP sera branché plus tard.
struct RTSPPassthroughProvider: CameraStreamProvider {
    func playableURL(for camera: Camera) -> URL? {
        guard let streamURL = camera.streamURL, !streamURL.isEmpty else { return nil }
        return URL(string: streamURL)
    }
}
