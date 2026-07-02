import Foundation
import Network

final class WizLightService {
    static let shared = WizLightService()

    private static let port: UInt16 = 38899
    private static let timeoutSeconds: TimeInterval = 3

    enum WizError: Error {
        case invalidAddress
        case timeout
        case sendFailed(Error)
    }

    func send(_ command: WizCommand, to ip: String) async throws {
        guard !ip.isEmpty, let port = NWEndpoint.Port(rawValue: Self.port) else {
            throw WizError.invalidAddress
        }
        let data = try WizCommandBuilder.encode(command)
        let connection = NWConnection(host: NWEndpoint.Host(ip), port: port, using: .udp)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var didResume = false
            let resumeOnce: (Result<Void, Error>) -> Void = { result in
                guard !didResume else { return }
                didResume = true
                connection.cancel()
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: data, completion: .contentProcessed { error in
                        if let error {
                            resumeOnce(.failure(WizError.sendFailed(error)))
                            return
                        }
                        connection.receiveMessage { _, _, _, error in
                            if let error {
                                resumeOnce(.failure(WizError.sendFailed(error)))
                            } else {
                                resumeOnce(.success(()))
                            }
                        }
                    })
                case .failed(let error):
                    resumeOnce(.failure(WizError.sendFailed(error)))
                default:
                    break
                }
            }
            connection.start(queue: .global())

            DispatchQueue.global().asyncAfter(deadline: .now() + Self.timeoutSeconds) {
                resumeOnce(.failure(WizError.timeout))
            }
        }
    }
}
