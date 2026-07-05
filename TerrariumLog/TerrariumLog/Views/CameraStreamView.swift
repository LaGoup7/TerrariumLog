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
    /// Incrémenter cette valeur déclenche la capture de l'image affichée
    /// (photo instantanée depuis le flux, sans requête réseau supplémentaire).
    var snapshotTrigger: Int = 0
    var onSnapshot: (UIImage?) -> Void = { _ in }
    /// Enregistrement vidéo du flux en cours (REC pendant la lecture).
    var isRecording: Bool = false
    /// Chemin du fichier vidéo produit quand l'enregistrement s'arrête
    /// (`nil` si l'enregistrement a échoué).
    var onRecordingFinished: (String?) -> Void = { _ in }
    var onStatusChange: (CameraStreamStatus, String) -> Void = { _, _ in }
    /// Journal technique compact (tentatives, états, erreurs).
    var onLog: (String) -> Void = { _ in }
    /// Active le log natif de libvlc (diagnostic RTSP/RTP détaillé).
    /// Coûteux : à réserver au débogage.
    var verboseVLCLogging: Bool = false

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

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        context.coordinator.recordingFinished = onRecordingFinished
        if snapshotTrigger != context.coordinator.handledSnapshotTrigger {
            context.coordinator.handledSnapshotTrigger = snapshotTrigger
            if snapshotTrigger > 0 {
                context.coordinator.captureSnapshot(completion: onSnapshot)
            }
        }
        if isRecording != context.coordinator.requestedRecording {
            context.coordinator.setRecording(isRecording)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onStatusChange: onStatusChange, onLog: onLog, verbose: verboseVLCLogging)
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
        // Réglages de la stratégie de reprise. Le délai par tentative doit couvrir
        // une négociation RTSP LENTE : sur ce réseau, chaque échange prend ~10 s
        // (retransmissions Wi-Fi) et la première image est arrivée à ~35 s lors du
        // cas réussi. Un délai trop court tue des connexions sur le point d'aboutir
        // (bug observé : "successfully opened" 1 s après le couperet à 20 s).
        private let maxAttempts = 2
        private let attemptTimeout: TimeInterval = 50
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
        private let verbose: Bool

        init(onStatusChange: @escaping (CameraStreamStatus, String) -> Void,
             onLog: @escaping (String) -> Void,
             verbose: Bool = false) {
            self.onStatusChange = onStatusChange
            self.onLog = onLog
            self.verbose = verbose
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
            // Log natif de libvlc uniquement en mode diagnostic (coûteux).
            if verbose {
                enableVLCLogging()
            }
            log("Ouverture : \(Self.redactedURL(url))")
            launchAttempt()
        }

        func stop() {
            isStopped = true
            watchdog?.invalidate()
            successPoll?.invalidate()
            stallTimer?.invalidate()
            disableVLCLogging()
            teardownPlayer()
            log("Flux fermé")
        }

        // MARK: Enregistrement vidéo du flux

        private(set) var requestedRecording = false
        var recordingFinished: ((String?) -> Void)?
        private var recordingDirectory: String?

        /// Démarre/arrête l'enregistrement du flux en cours dans un dossier
        /// temporaire ; le chemin final est remonté par le délégué VLC.
        func setRecording(_ on: Bool) {
            requestedRecording = on
            guard let player else {
                if on { recordingFinished?(nil) }
                return
            }
            if on {
                let directory = NSTemporaryDirectory() + "habitat-rec-\(UUID().uuidString)"
                try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
                recordingDirectory = directory
                if player.startRecording(atPath: directory) {
                    log("⏺ Enregistrement démarré")
                } else {
                    log("⏺ Enregistrement impossible (flux pas encore prêt ?)")
                    requestedRecording = false
                    recordingFinished?(nil)
                }
            } else {
                _ = player.stopRecording()
                log("⏹ Arrêt de l'enregistrement demandé")
            }
        }

        func mediaPlayer(_ player: VLCMediaPlayer, recordingStoppedAtPath path: String) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.log("⏹ Enregistrement terminé : \(URL(fileURLWithPath: path).lastPathComponent)")
                self.requestedRecording = false
                self.recordingFinished?(path)
            }
        }

        // MARK: Capture d'image depuis le flux

        var handledSnapshotTrigger = 0
        private var snapshotCompletion: ((UIImage?) -> Void)?
        private var snapshotPath: String?

        /// Enregistre l'image actuellement affichée (VLC l'extrait du flux en
        /// cours de lecture) et la renvoie via `completion`.
        func captureSnapshot(completion: @escaping (UIImage?) -> Void) {
            guard let player, player.hasVideoOut else {
                log("Capture impossible : aucune image en cours de lecture")
                completion(nil)
                return
            }
            let path = NSTemporaryDirectory() + "habitat-snapshot-\(UUID().uuidString).png"
            snapshotCompletion = completion
            snapshotPath = path
            player.saveVideoSnapshot(at: path, withWidth: 0, andHeight: 0)
            // Filet de sécurité si le délégué ne confirme pas la capture.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.finishSnapshot()
            }
        }

        func mediaPlayerSnapshot(_ aNotification: Notification) {
            DispatchQueue.main.async { [weak self] in
                self?.finishSnapshot()
            }
        }

        private func finishSnapshot() {
            guard let completion = snapshotCompletion else { return }
            snapshotCompletion = nil
            var image: UIImage?
            if let path = snapshotPath {
                image = UIImage(contentsOfFile: path)
                try? FileManager.default.removeItem(atPath: path)
            }
            snapshotPath = nil
            if let image {
                log("📸 Image capturée \(Int(image.size.width))×\(Int(image.size.height))")
            } else {
                log("Capture échouée (pas de fichier produit)")
            }
            completion(image)
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
            log("Tentative \(attempt)/\(maxAttempts) (délai \(Int(attemptTimeout)) s)")
            onStatusChange(.connecting, "Connexion \(attempt)/\(maxAttempts) — peut prendre ~1 min…")

            let player = VLCMediaPlayer()
            player.drawable = drawable
            player.delegate = self

            let media = VLCMedia(url: url)
            // RTP encapsulé dans la connexion TCP : seul transport dont les paquets
            // média arrivent jusqu'à l'iPhone sur ce réseau (l'UDP est bloqué).
            media.addOption(":rtsp-tcp")
            // Sans audio : évite ~15 s de négociation d'une piste inutile ici.
            media.addOption(":no-audio")
            // Tampon 1,5 s : absorbe les pertes du Wi-Fi (un tampon trop court
            // fige l'image à la moindre coupure) ; horloge libre pour le live.
            media.addOption(":network-caching=1500")
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
                    self.startStallMonitor()
                }
            }
        }

        // MARK: Détection de gel + reconnexion automatique

        /// Sur un Wi-Fi qui perd des paquets, le flux peut se figer sans erreur :
        /// VLC garde la dernière image et attend indéfiniment. On surveille
        /// l'avancement du temps de lecture ; s'il stagne (ou tampon permanent),
        /// on relance la connexion automatiquement, sans action de l'utilisateur.
        private var stallTimer: Timer?
        private var lastTimeValue: Int32 = 0
        private var stallTicks = 0
        private var bufferingTicks = 0
        private var autoReconnects = 0
        private let maxAutoReconnects = 3

        private func startStallMonitor() {
            stallTimer?.invalidate()
            lastTimeValue = player?.time.intValue ?? 0
            stallTicks = 0
            bufferingTicks = 0
            stallTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
                guard let self, let player = self.player, !self.isStopped else { timer.invalidate(); return }

                if player.state == .buffering || player.state == .opening {
                    self.bufferingTicks += 1
                } else {
                    self.bufferingTicks = 0
                }

                let time = player.time.intValue
                if time != self.lastTimeValue {
                    self.lastTimeValue = time
                    self.stallTicks = 0
                    // La lecture avance : la connexion s'est stabilisée.
                    self.autoReconnects = 0
                } else {
                    self.stallTicks += 1
                }

                // Figé : temps immobile ~12 s, ou mise en tampon continue ~12 s.
                if self.stallTicks >= 6 || self.bufferingTicks >= 6 {
                    timer.invalidate()
                    self.handleStall()
                }
            }
        }

        private func handleStall() {
            guard !isStopped else { return }
            autoReconnects += 1
            guard autoReconnects <= maxAutoReconnects else {
                log("Flux figé — reconnexions automatiques épuisées")
                onStatusChange(.error, "Connexion trop instable. Rapproche l'iPhone ou la caméra du routeur, puis appuie sur Live.")
                return
            }
            log("Flux figé — reconnexion automatique (\(autoReconnects)/\(maxAutoReconnects))")
            didSucceed = false
            teardownPlayer()
            onStatusChange(.connecting, "Flux figé — reconnexion \(autoReconnects)/\(maxAutoReconnects)…")
            attempt = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                self?.launchAttempt()
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
