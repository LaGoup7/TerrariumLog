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
            log("Vue \(Int(view.bounds.width))×\(Int(view.bounds.height)) — RTP sur TCP, sans audio, buffer 1000 ms")

            // Active le log natif de libvlc pour capturer la raison exacte (RTSP/RTP).
            enableVLCLogging()

            let player = VLCMediaPlayer()
            player.drawable = view
            player.delegate = self

            let media = VLCMedia(url: url)
            // Le log natif l'a prouvé : le contrôle RTSP passe (SDP reçu) mais le RTP
            // en UDP n'arrive jamais (live555 timeout 15 s puis se détruit). On force
            // le RTP entrelacé DANS la connexion TCP déjà ouverte pour contourner le
            // blocage des ports UDP entre la caméra et l'iPhone.
            media.addOption(":rtsp-tcp")
            // Sans audio : la négociation de la piste audio (PCMA) ajoutait ~15 s au
            // démarrage (VLC attend TOUTES les pistes avant d'afficher). Inutile ici.
            media.addOption(":no-audio")
            // Buffer réduit : moins de latence au démarrage (le transport TCP est fiable).
            media.addOption(":network-caching=1000")
            player.media = media
            player.play()
            self.player = player
            onStatusChange(.connecting, "Ouverture…")
            startProbe()
        }

        // MARK: Log natif libvlc
        private var logRelay: VLCLogRelay?
        private var vlcLogCount = 0

        private func enableVLCLogging() {
            vlcLogCount = 0
            let relay = VLCLogRelay { [weak self] message, _ in
                self?.forwardVLCLog(message)
            }
            logRelay = relay
            let library = VLCLibrary.shared()
            library.debugLogging = true
            library.debugLoggingLevel = 2
            library.debugLoggingTarget = relay
        }

        private func disableVLCLogging() {
            let library = VLCLibrary.shared()
            library.debugLoggingTarget = nil
            library.debugLogging = false
            logRelay = nil
        }

        /// Ne garde que les messages libvlc utiles au diagnostic RTSP/RTP, et
        /// plafonne le volume pour ne pas noyer le journal.
        private func forwardVLCLog(_ message: String) {
            guard vlcLogCount < 60 else { return }
            let lower = message.lowercased()
            let keywords = ["rtsp", "rtp", "live555", "sdp", "no data", "cannot",
                            "error", "fail", "timeout", "unauthor", "401", "403",
                            "hevc", "h264", "vout", "decoder", "demux", "access",
                            "prebuffer", "discontinu", "satip"]
            guard keywords.contains(where: { lower.contains($0) }) else { return }
            vlcLogCount += 1
            log("VLC: \(message.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        /// Vrai dès que le flux a réellement joué : permet de distinguer un arrêt
        /// normal (fin de flux) d'un rejet immédiat à l'ouverture (auth/URL).
        private var hasPlayed = false
        /// Évite de journaliser le codec en boucle à chaque changement d'état.
        private var didLogTracks = false
        /// Sonde runtime : vérifie si la lecture progresse réellement.
        private var probeTimer: Timer?
        private var probeTicks = 0

        /// Journalise toutes les 2 s l'avancement du temps de lecture, la taille
        /// vidéo décodée et la présence d'une sortie vidéo : distingue « images
        /// qui ne circulent pas » de « images décodées mais non affichées ».
        private func startProbe() {
            probeTimer?.invalidate()
            probeTicks = 0
            probeTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
                guard let self, let player = self.player else { timer.invalidate(); return }
                self.probeTicks += 1
                if self.probeTicks > 12 { timer.invalidate(); return }
                let ms = player.time.intValue
                let size = player.videoSize
                self.log("t=\(ms)ms  vidéo=\(Int(size.width))×\(Int(size.height))  sortie=\(player.hasVideoOut ? "oui" : "non")")
            }
        }

        func stop() {
            log("Fermeture du flux")
            probeTimer?.invalidate()
            probeTimer = nil
            disableVLCLogging()
            // On coupe le délégué d'abord pour ne pas remonter le `.stopped` du teardown.
            player?.delegate = nil
            player?.stop()
            player?.drawable = nil
            // On libère explicitement le média pour fermer la session RTSP côté
            // caméra (la C220 limite le nombre de flux simultanés).
            player?.media = nil
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

/// Relais des messages bruts de libvlc vers une closure Swift, pour afficher les
/// vrais logs RTSP/RTP du moteur dans le journal technique.
final class VLCLogRelay: NSObject, VLCLibraryLogReceiverProtocol {
    private let onMessage: (String, Int32) -> Void

    init(onMessage: @escaping (String, Int32) -> Void) {
        self.onMessage = onMessage
        super.init()
    }

    func handleMessage(_ message: String, debugLevel level: Int32) {
        onMessage(message, level)
    }
}
