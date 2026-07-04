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

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        context.coordinator.start(url: url, username: username, password: password, on: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onStatusChange: onStatusChange)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, VLCMediaPlayerDelegate {
        private var player: VLCMediaPlayer?
        private let onStatusChange: (CameraStreamStatus, String) -> Void

        init(onStatusChange: @escaping (CameraStreamStatus, String) -> Void) {
            self.onStatusChange = onStatusChange
        }

        func start(url: URL, username: String?, password: String?, on view: UIView) {
            let player = VLCMediaPlayer()
            player.drawable = view
            player.delegate = self

            let media = VLCMedia(url: url)
            // RTSP sur TCP (plus fiable que l'UDP derrière un NAT).
            media.addOption(":rtsp-tcp")
            // Un buffer trop court fait échouer les flux RTSP (2K/keyframes lentes) :
            // 1,5 s est un bon compromis latence/robustesse.
            media.addOption(":network-caching=1500")
            media.addOption(":rtsp-caching=1500")
            // Authentification aussi via options (secours quand l'URL ne suffit pas).
            if let username, !username.isEmpty {
                media.addOption(":rtsp-user=\(username)")
                if let password, !password.isEmpty {
                    media.addOption(":rtsp-pwd=\(password)")
                }
            }
            player.media = media
            player.play()
            self.player = player
            onStatusChange(.connecting, "Ouverture…")
        }

        /// Vrai dès que le flux a réellement joué : permet de distinguer un arrêt
        /// normal (fin de flux) d'un rejet immédiat à l'ouverture (auth/URL).
        private var hasPlayed = false

        func stop() {
            // On coupe le délégué d'abord pour ne pas remonter le `.stopped` du teardown.
            player?.delegate = nil
            player?.stop()
            player?.drawable = nil
            player = nil
        }

        func mediaPlayerStateChanged(_ aNotification: Notification) {
            guard let player else { return }
            let name = Self.stateName(player.state)
            switch player.state {
            case .playing:
                hasPlayed = true
                onStatusChange(.playing, name)
            case .error:
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
