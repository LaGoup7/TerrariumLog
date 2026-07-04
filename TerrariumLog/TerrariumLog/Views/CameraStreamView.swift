import SwiftUI
import UIKit
import VLCKitSPM

/// État simplifié du flux, exposé aux vues SwiftUI sans qu'elles aient à
/// connaître VLCKit.
enum CameraStreamStatus: Equatable {
    case connecting
    case playing
    case ended
    case error
}

/// Affiche un flux vidéo live (RTSP, etc.) via VLCKit — iOS ne lit pas le RTSP
/// nativement. On branche un `VLCMediaPlayer` sur une `UIView` (drawable).
/// Réutilise l'`URL` fournie par `CameraStreamProvider` sans transcodage.
///
/// `onStatusChange` remonte l'état simplifié **et** un libellé lisible de l'état
/// VLC réel (Ouverture / Tampon / Erreur…) pour le diagnostic à l'écran.
struct CameraStreamView: UIViewRepresentable {
    let url: URL
    /// Identifiants passés aussi en options VLC (en plus de l'URL) : certains flux
    /// RTSP n'acceptent l'authentification que par ce biais.
    var username: String? = nil
    var password: String? = nil
    var onStatusChange: (CameraStreamStatus, String) -> Void = { _, _ in }
    /// Journal technique : chaque étape du cycle de vie du lecteur (ouverture,
    /// états, codec détecté, erreurs) pour diagnostiquer sans supposition.
    var onLog: (String) -> Void = { _ in }

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.backgroundColor = .black
        // On démarre la lecture seulement quand la vue est dans la fenêtre ET
        // dimensionnée : VLCKit a besoin d'une taille > 0 pour créer la sortie
        // vidéo, sinon il s'arrête aussitôt (écran noir « Arrêté »).
        let coordinator = context.coordinator
        view.onReady = { [url, username, password] readyView in
            coordinator.start(url: url, username: username, password: password, on: readyView)
        }
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {}

    /// UIView qui signale une seule fois quand elle est réellement affichée et
    /// dimensionnée, pour démarrer VLC au bon moment.
    final class PlayerContainerView: UIView {
        var onReady: ((UIView) -> Void)?
        private var didStart = false

        override func layoutSubviews() {
            super.layoutSubviews()
            guard !didStart, window != nil, bounds.width > 0, bounds.height > 0 else { return }
            didStart = true
            onReady?(self)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onStatusChange: onStatusChange, onLog: onLog)
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, VLCMediaPlayerDelegate {
        private var player: VLCMediaPlayer?
        private let onStatusChange: (CameraStreamStatus, String) -> Void
        private let onLog: (String) -> Void

        init(onStatusChange: @escaping (CameraStreamStatus, String) -> Void,
             onLog: @escaping (String) -> Void) {
            self.onStatusChange = onStatusChange
            self.onLog = onLog
        }

        private func log(_ message: String) {
            let forward = onLog
            DispatchQueue.main.async { forward(message) }
        }

        func start(url: URL, username: String?, password: String?, on view: UIView) {
            log("Lecteur créé (MobileVLCKit)")
            log("Ouverture RTSP : \(Self.redactedURL(url))")
            log("Vue \(Int(view.bounds.width))×\(Int(view.bounds.height)) — buffer 1500 ms, décodage matériel")

            let player = VLCMediaPlayer()
            player.drawable = view
            player.delegate = self

            let media = VLCMedia(url: url)
            // Configuration calquée sur VLC desktop : identifiants portés par
            // l'URL, transport par défaut (pas de RTSP-sur-TCP forcé). On garde
            // le décodage matériel (rapide) ; sur mobile on privilégie le flux
            // SD (voir StreamQuality) qui se décode sans peine, le HD 2K H.265
            // étant trop lourd pour l'iPhone en temps réel.
            media.addOption(":network-caching=1500")
            player.media = media
            player.play()
            self.player = player
            onStatusChange(.connecting, "Ouverture…")
        }

        /// Vrai dès que le flux a réellement joué : permet de distinguer un arrêt
        /// normal (fin de flux) d'un rejet immédiat à l'ouverture (auth/URL).
        private var hasPlayed = false
        /// Évite de journaliser le codec en boucle à chaque changement d'état.
        private var didLogTracks = false

        func stop() {
            log("Fermeture du flux")
            // On coupe le délégué d'abord pour ne pas remonter le `.stopped` du teardown.
            player?.delegate = nil
            player?.stop()
            player?.drawable = nil
            player = nil
        }

        func mediaPlayerStateChanged(_ aNotification: Notification) {
            guard let player else { return }
            let name = Self.stateName(player.state)
            log("État VLC → \(name)")
            logTracksIfAvailable()
            switch player.state {
            case .playing:
                hasPlayed = true
                onStatusChange(.playing, name)
            case .error:
                log("⚠️ Erreur lecteur")
                onStatusChange(.error, "Refusé par la caméra — vérifie le compte caméra (nom + mot de passe RTSP), le chemin et que le RTSP est activé.")
            case .ended, .stopped:
                if hasPlayed {
                    onStatusChange(.ended, name)
                } else {
                    // Arrêt sans avoir jamais joué = flux rejeté à l'ouverture,
                    // quasi toujours un problème d'identifiants du compte caméra.
                    onStatusChange(.error, "Arrêté dès l'ouverture — identifiants du compte caméra probablement incorrects, ou RTSP non activé sur la caméra.")
                }
            default:
                onStatusChange(.connecting, name)
            }
        }

        /// Lit le codec réellement négocié par VLC (le point décisif : H.264 vs
        /// H.265) et la résolution, dès que l'info est disponible.
        private func logTracksIfAvailable() {
            guard !didLogTracks,
                  let tracks = player?.media?.tracksInformation as? [[String: Any]],
                  !tracks.isEmpty else { return }
            didLogTracks = true
            for track in tracks {
                let type = track[VLCMediaTracksInformationType] as? String
                let codec = (track[VLCMediaTracksInformationCodec] as? NSNumber)?.uint32Value ?? 0
                let codecName = Self.fourCC(codec)
                if type == VLCMediaTracksInformationTypeVideo {
                    let width = (track[VLCMediaTracksInformationVideoWidth] as? NSNumber)?.intValue ?? 0
                    let height = (track[VLCMediaTracksInformationVideoHeight] as? NSNumber)?.intValue ?? 0
                    log("🎥 Vidéo : \(codecName) \(width)×\(height)")
                } else if type == VLCMediaTracksInformationTypeAudio {
                    log("🔊 Audio : \(codecName)")
                }
            }
        }

        /// Convertit un FourCC VLC (ex. 0x63766568) en texte lisible (« hevc »).
        private static func fourCC(_ value: UInt32) -> String {
            guard value != 0 else { return "?" }
            let bytes = [
                UInt8(value & 0xFF),
                UInt8((value >> 8) & 0xFF),
                UInt8((value >> 16) & 0xFF),
                UInt8((value >> 24) & 0xFF)
            ]
            let string = String(bytes: bytes, encoding: .ascii) ?? ""
            let cleaned = string.trimmingCharacters(in: CharacterSet(charactersIn: " \0"))
            return cleaned.isEmpty ? "?" : cleaned
        }

        /// URL sans mot de passe, pour le journal.
        private static func redactedURL(_ url: URL) -> String {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.password = nil
            return components?.string ?? "rtsp://…"
        }

        private static func stateName(_ state: VLCMediaPlayerState) -> String {
            switch state {
            case .stopped: return "Arrêté"
            case .opening: return "Ouverture…"
            case .buffering: return "Mise en mémoire tampon…"
            case .playing: return "Lecture"
            case .paused: return "En pause"
            case .ended: return "Terminé"
            case .error: return "Erreur (flux/identifiants/URL)"
            case .esAdded: return "Flux détecté…"
            @unknown default: return "…"
            }
        }
    }
}
