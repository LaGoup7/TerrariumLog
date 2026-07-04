import Foundation
import Network

/// Test de joignabilité TCP simple, utilisé pour diagnostiquer l'accès à une
/// caméra (port RTSP 554) indépendamment de VLC : distingue « hôte/port
/// injoignable » (réseau, IP, RTSP désactivé) de « joignable mais lecture qui
/// échoue » (URL/chemin/identifiants/codec).
enum NetworkProbe {
    static func canConnect(host: String, port: UInt16, timeout: TimeInterval = 6) async -> Bool {
        guard !host.isEmpty, let nwPort = NWEndpoint.Port(rawValue: port) else { return false }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)

        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            var resumed = false
            let finish: (Bool) -> Void = { result in
                guard !resumed else { return }
                resumed = true
                connection.cancel()
                continuation.resume(returning: result)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(true)
                case .failed, .cancelled:
                    finish(false)
                default:
                    break
                }
            }
            connection.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish(false) }
        }
    }
}
