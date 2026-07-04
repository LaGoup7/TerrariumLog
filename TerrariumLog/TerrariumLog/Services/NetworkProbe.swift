import Foundation
import Network

/// Test de joignabilité TCP simple, utilisé pour diagnostiquer l'accès à une
/// caméra (port RTSP 554) indépendamment de VLC. Distingue les causes probables
/// d'échec (port fermé, injoignable/permission, échec réseau) plutôt que de ne
/// renvoyer qu'un booléen.
enum NetworkProbe {
    /// Résultat détaillé d'un test de connexion.
    struct Outcome {
        let reachable: Bool
        /// Explication lisible de la cause probable, prête à afficher.
        let detail: String
    }

    static func probe(host: String, port: UInt16, timeout: TimeInterval = 6) async -> Outcome {
        guard !host.isEmpty, let nwPort = NWEndpoint.Port(rawValue: port) else {
            return Outcome(reachable: false, detail: "Hôte ou port invalide.")
        }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)

        return await withCheckedContinuation { (continuation: CheckedContinuation<Outcome, Never>) in
            let lock = NSLock()
            var resumed = false
            var lastWaitingReason: String?

            let finish: (Outcome) -> Void = { outcome in
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                connection.cancel()
                continuation.resume(returning: outcome)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(Outcome(reachable: true, detail: "Port \(port) ouvert : la caméra répond."))
                case .waiting(let error):
                    // `.waiting` = échec transitoire que le système ré-essaie. Sur un
                    // refus explicite, inutile d'attendre : le port est fermé.
                    if Self.isConnectionRefused(error) {
                        finish(Outcome(
                            reachable: false,
                            detail: "Connexion refusée : l'IP répond mais le port \(port) est fermé. Le RTSP est probablement désactivé sur la caméra."
                        ))
                    } else {
                        lock.lock()
                        lastWaitingReason = error.localizedDescription
                        lock.unlock()
                    }
                case .failed(let error):
                    finish(Outcome(reachable: false, detail: "Échec réseau : \(error.localizedDescription)."))
                default:
                    break
                }
            }
            connection.start(queue: .global())

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                lock.lock()
                let waiting = lastWaitingReason
                lock.unlock()
                var detail = "Délai dépassé : aucune réponse de \(host):\(port). Vérifie que l'IP est exacte, que l'iPhone est sur le même Wi-Fi que la caméra, et que la permission « réseau local » a bien été autorisée pour l'app."
                if let waiting {
                    detail += "\n(Réseau : \(waiting))"
                }
                finish(Outcome(reachable: false, detail: detail))
            }
        }
    }

    private static func isConnectionRefused(_ error: NWError) -> Bool {
        if case let .posix(code) = error { return code == .ECONNREFUSED }
        return false
    }

    /// Conservé pour compatibilité : renvoie uniquement la joignabilité.
    static func canConnect(host: String, port: UInt16, timeout: TimeInterval = 6) async -> Bool {
        await probe(host: host, port: port, timeout: timeout).reachable
    }
}
