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

/// Affiche un flux vidéo live RTSP via VLCKit (iOS ne lit pas le RTSP nativement).
///
/// Conception volontairement simple et auto-réparante :
/// - options VLC minimales et éprouvées (RTP dans le TCP, sans audio, tampon court) ;
/// - le succès = une **image réellement décodée** (sortie vidéo + taille non nulle),
///   pas l'état « Lecture » de VLC qui peut mentir ;
/// - si aucune image n'arrive dans le délai imparti, le lecteur est détruit puis
///   relancé automatiquement (3 tentatives) — la C220/le Wi-Fi ratent souvent le
///   premier essai mais réussissent le suivant.
struct CameraStreamView: UIViewRepresentable {
    let url: URL
    var onStatusChange: (CameraStreamStatus, String) -> Void = { _, _ in }
    /// Journal technique compact (tentatives, états, erreurs).
    var onLog: (String) -> Void = { _ in }

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.backgroundColor = .black
        // Démarrage seulement quand la vue est affichée ET dimensionnée : VLCKit
        // a besoin d'une taille > 0 pour créer sa sortie vidéo.
        let coordinator = context.coordinator
        view.onReady = { [url] readyView in
            coordinator.start(url: url, on: readyView)
        }
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onStatusChange: onStatusChange, onLog: onLog)
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: Coordinator) {
        coordinator.stop()
    }

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

    final class Coordinator: NSObject, VLCMediaPlayerDelegate {
        // Réglages de la stratégie de reprise.
        private let maxAttempts = 3
        private let attemptTimeout: TimeInterval = 20
        private let retryDelay: TimeInterval = 2

        private var player: VLCMediaPlayer?
        private weak var drawable: UIView?
        private var url: URL?
        private var attempt = 0
        private var watchdog: Timer?
        private var successPoll: Timer?
        private var isStopped = false
        private var didSucceed = false

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

        // MARK: Cycle de vie

        func start(url: URL, on view: UIView) {
            self.url = url
            self.drawable = view
            attempt = 0
            isStopped = false
            didSucceed = false
            enableVLCLogging()
            log("Ouverture : \(Self.redactedURL(url))")
            launchAttempt()
        }

        func stop() {
            isStopped = true
            watchdog?.invalidate()
            successPoll?.invalidate()
            disableVLCLogging()
            teardownPlayer()
            log("Flux fermé")
        }

        /// Détruit proprement le lecteur courant (ferme la session RTSP côté caméra).
        private func teardownPlayer() {
            player?.delegate = nil
            player?.stop()
            player?.drawable = nil
            player?.media = nil
            player = nil
        }

        // MARK: Tentatives

        private func launchAttempt() {
            guard !isStopped, let url, let drawable else { return }
            attempt += 1
            log("Tentative \(attempt)/\(maxAttempts)")
            onStatusChange(.connecting, "Connexion (essai \(attempt)/\(maxAttempts))…")

            let player = VLCMediaPlayer()
            player.drawable = drawable
            player.delegate = self

            let media = VLCMedia(url: url)
            // RTP encapsulé dans la connexion TCP : seul transport dont les paquets
            // média arrivent jusqu'à l'iPhone sur ce réseau (l'UDP est bloqué).
            media.addOption(":rtsp-tcp")
            // Sans audio : évite ~15 s de négociation d'une piste inutile ici.
            media.addOption(":no-audio")
            // Tampon court + horloge libre : démarrage rapide d'un flux live.
            media.addOption(":network-caching=600")
            media.addOption(":clock-jitter=0")
            media.addOption(":clock-synchro=0")
            player.media = media
            player.play()
            self.player = player

            armWatchdog()
            armSuccessPoll()
        }

        /// Si aucune image décodée dans le délai imparti : on détruit et on retente.
        private func armWatchdog() {
            watchdog?.invalidate()
            watchdog = Timer.scheduledTimer(withTimeInterval: attemptTimeout, repeats: false) { [weak self] _ in
                self?.handleAttemptFailure(reason: "délai dépassé")
            }
        }

        /// Le vrai critère de succès : une sortie vidéo existe ET une taille
        /// d'image est connue (donc au moins une image décodée).
        private func armSuccessPoll() {
            successPoll?.invalidate()
            successPoll = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
                guard let self, let player = self.player else { timer.invalidate(); return }
                let size = player.videoSize
                if player.hasVideoOut && size.width > 0 {
                    timer.invalidate()
                    self.watchdog?.invalidate()
                    self.didSucceed = true
                    self.log("✅ Image décodée : \(Int(size.width))×\(Int(size.height))")
                    self.onStatusChange(.playing, "Lecture")
                }
            }
        }

        private func handleAttemptFailure(reason: String) {
            guard !isStopped, !didSucceed else { return }
            watchdog?.invalidate()
            successPoll?.invalidate()
            log("Échec (\(reason))")
            teardownPlayer()

            if attempt < maxAttempts {
                // Petit délai pour laisser la caméra libérer la session avant de retenter.
                DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                    self?.launchAttempt()
                }
            } else {
                onStatusChange(.error, "Flux indisponible après \(maxAttempts) essais. Vérifie le Wi-Fi, ou redémarre la caméra (sessions saturées).")
            }
        }

        // MARK: Délégué VLC

        func mediaPlayerStateChanged(_ aNotification: Notification) {
            guard let player, !didSucceed else { return }
            switch player.state {
            case .error:
                handleAttemptFailure(reason: "erreur lecteur")
            case .ended, .stopped:
                handleAttemptFailure(reason: "flux arrêté par la caméra")
            default:
                break
            }
        }

        // MARK: Log natif libvlc (filtré)

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

        /// Ne garde que l'essentiel du diagnostic RTSP/RTP, en excluant le bruit
        /// (dump de configuration au démarrage, messages répétitifs).
        private func forwardVLCLog(_ message: String) {
            guard vlcLogCount < 40 else { return }
            let lower = message.lowercased()
            guard !lower.hasPrefix("configured with") else { return }
            let keywords = ["rtsp", "rtp subsession", "live555", "no data", "cannot",
                            "error", "fail", "timeout", "unauthor", "401", "403",
                            "vout display", "using video decoder"]
            guard keywords.contains(where: { lower.contains($0) }) else { return }
            vlcLogCount += 1
            log("VLC: \(message.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        /// URL sans mot de passe, pour le journal.
        private static func redactedURL(_ url: URL) -> String {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.password = nil
            return components?.string ?? "rtsp://…"
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
