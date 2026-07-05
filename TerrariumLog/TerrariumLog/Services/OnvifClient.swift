import Foundation
import CryptoKit

/// Extraction minimaliste des champs utiles des réponses SOAP ONVIF.
/// Les réponses des caméras varient sur les préfixes de namespace (`tt:`, `trt:`…),
/// d'où des motifs tolérants plutôt qu'un vrai parseur XML.
enum OnvifXML {
    static func firstMatch(in xml: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(xml.startIndex..., in: xml)
        guard let match = regex.firstMatch(in: xml, options: [], range: range),
              match.numberOfRanges > 1,
              let captured = Range(match.range(at: 1), in: xml) else { return nil }
        return String(xml[captured])
    }

    /// Adresse du service Média dans une réponse GetCapabilities.
    static func mediaXAddr(from xml: String) -> String? {
        firstMatch(in: xml, pattern: #"<(?:[\w-]+:)?Media>.*?<(?:[\w-]+:)?XAddr>\s*([^<\s]+)\s*</"#)
    }

    /// Premier jeton de profil dans une réponse GetProfiles.
    static func firstProfileToken(from xml: String) -> String? {
        firstMatch(in: xml, pattern: #"token="([^"]+)""#)
    }

    /// URI dans une réponse GetSnapshotUri / GetStreamUri.
    static func uri(from xml: String) -> String? {
        firstMatch(in: xml, pattern: #"<(?:[\w-]+:)?Uri>\s*([^<\s]+)\s*</"#)
    }

    /// Date UTC de la caméra dans une réponse GetSystemDateAndTime.
    static func utcDateTime(from xml: String) -> Date? {
        guard let block = firstMatch(in: xml, pattern: #"<(?:[\w-]+:)?UTCDateTime>(.*?)</(?:[\w-]+:)?UTCDateTime>"#) else { return nil }
        func value(_ field: String) -> Int? {
            firstMatch(in: block, pattern: "<(?:[\\w-]+:)?\(field)>\\s*(\\d+)\\s*</").flatMap(Int.init)
        }
        guard let hour = value("Hour"), let minute = value("Minute"), let second = value("Second"),
              let year = value("Year"), let month = value("Month"), let day = value("Day") else { return nil }
        var components = DateComponents()
        components.timeZone = TimeZone(identifier: "UTC")
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return Calendar(identifier: .gregorian).date(from: components)
    }

    /// Raison lisible d'une faute SOAP (ex. « NotAuthorized »).
    /// Les préfixes peuvent contenir des tirets (`SOAP-ENV:`), d'où `[\w-]+`.
    static func faultReason(from xml: String) -> String? {
        firstMatch(in: xml, pattern: #"<(?:[\w-]+:)?Text[^>]*>\s*([^<]+?)\s*</"#)
            ?? firstMatch(in: xml, pattern: #"<(?:[\w-]+:)?Subcode>.*?<(?:[\w-]+:)?Value>\s*([^<]+?)\s*</"#)
    }
}

/// Client ONVIF minimal pour les caméras du réseau local (Tapo : port 2020).
/// Authentification WS-Security UsernameToken (PasswordDigest = SHA1(nonce+date+mdp)),
/// avec les identifiants du « compte caméra » (les mêmes que pour le RTSP).
struct OnvifClient {
    let host: String
    let username: String
    let password: String
    /// Port du service ONVIF (2020 chez Tapo, 80/8080 ailleurs).
    var port: Int = 2020
    /// Journal technique (mêmes lignes que le lecteur vidéo).
    var log: (String) -> Void = { _ in }

    enum OnvifError: LocalizedError {
        case http(Int)
        case missingField(String)

        var errorDescription: String? {
            switch self {
            case .http(let code): return "Réponse HTTP \(code) du service ONVIF"
            case .missingField(let field): return "Champ \(field) introuvable dans la réponse ONVIF"
            }
        }
    }

    // MARK: API

    /// Récupère l'image JPEG instantanée de la caméra (premier profil média).
    func fetchSnapshot() async throws -> Data {
        // Signer avec l'heure de la CAMÉRA : un décalage d'horloge fait rejeter
        // la signature WS-Security (faute SOAP « NotAuthorized » → HTTP 500).
        let offset = await deviceTimeOffset()
        let snapshotURL = try await snapshotURI(timeOffset: offset)
        log("ONVIF: téléchargement \(snapshotURL.absoluteString)")
        let data = try await authenticatedGet(snapshotURL)
        log("ONVIF: reçu \(data.count) octets")
        return data
    }

    /// URI de snapshot du premier profil (découverte capacités → profils → URI,
    /// avec repli sur l'adresse média standard Tapo si la découverte échoue).
    func snapshotURI(timeOffset: TimeInterval) async throws -> URL {
        let deviceService = URL(string: "http://\(host):\(port)/onvif/device_service")!
        var mediaURL = URL(string: "http://\(host):\(port)/onvif/service")!
        do {
            log("ONVIF: GetCapabilities → \(deviceService.absoluteString)")
            let capabilities = try await soapCall(
                to: deviceService,
                body: #"<GetCapabilities xmlns="http://www.onvif.org/ver10/device/wsdl"><Category>Media</Category></GetCapabilities>"#,
                timeOffset: timeOffset
            )
            if let mediaAddress = OnvifXML.mediaXAddr(from: capabilities),
               let discovered = URL(string: mediaAddress) {
                mediaURL = discovered
            }
            log("ONVIF: service média = \(mediaURL.absoluteString)")
        } catch {
            log("ONVIF: découverte échouée (\(error.localizedDescription)) — essai direct \(mediaURL.absoluteString)")
        }

        let profiles = try await soapCall(
            to: mediaURL,
            body: #"<GetProfiles xmlns="http://www.onvif.org/ver10/media/wsdl"/>"#,
            timeOffset: timeOffset
        )
        guard let token = OnvifXML.firstProfileToken(from: profiles) else {
            throw OnvifError.missingField("profil média")
        }
        log("ONVIF: profil = \(token)")

        let snapshot = try await soapCall(
            to: mediaURL,
            body: #"<GetSnapshotUri xmlns="http://www.onvif.org/ver10/media/wsdl"><ProfileToken>\#(token)</ProfileToken></GetSnapshotUri>"#,
            timeOffset: timeOffset
        )
        guard let uriString = OnvifXML.uri(from: snapshot), let uri = URL(string: uriString) else {
            throw OnvifError.missingField("Snapshot Uri")
        }
        return uri
    }

    // MARK: Heure de la caméra

    /// Décalage entre l'horloge de la caméra et celle de l'iPhone, via
    /// GetSystemDateAndTime (requête ONVIF autorisée SANS authentification).
    /// Renvoie 0 si la lecture échoue.
    func deviceTimeOffset() async -> TimeInterval {
        let deviceService = URL(string: "http://\(host):\(port)/onvif/device_service")!
        do {
            let response = try await soapCall(
                to: deviceService,
                body: #"<GetSystemDateAndTime xmlns="http://www.onvif.org/ver10/device/wsdl"/>"#,
                timeOffset: nil
            )
            guard let cameraDate = OnvifXML.utcDateTime(from: response) else {
                log("ONVIF: heure caméra illisible — signature avec l'heure locale")
                return 0
            }
            let offset = cameraDate.timeIntervalSinceNow
            log("ONVIF: décalage horloge caméra = \(Int(offset)) s")
            return offset
        } catch {
            log("ONVIF: GetSystemDateAndTime échoué (\(error.localizedDescription)) — heure locale")
            return 0
        }
    }

    // MARK: SOAP

    /// `timeOffset` : décalage à appliquer à l'horodatage de la signature
    /// (heure caméra). `nil` = requête sans en-tête d'authentification.
    private func soapCall(to url: URL, body: String, timeOffset: TimeInterval?) async throws -> String {
        let header = timeOffset.map { securityHeader(timeOffset: $0) } ?? ""
        let envelope = """
        <?xml version="1.0" encoding="UTF-8"?>\
        <s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">\
        \(header)<s:Body>\(body)</s:Body></s:Envelope>
        """
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/soap+xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = envelope.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            // La faute SOAP contient la vraie raison (NotAuthorized, etc.) :
            // on la remonte dans le journal au lieu de deviner.
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            let flattened = bodyText.replacingOccurrences(of: "\n", with: " ")
            let reason = OnvifXML.faultReason(from: bodyText) ?? String(flattened.suffix(300))
            log("ONVIF: HTTP \(status) sur \(url.lastPathComponent) — \(reason)")
            throw OnvifError.http(status)
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// En-tête WS-Security UsernameToken avec PasswordDigest,
    /// le mode d'authentification exigé par les Tapo en ONVIF.
    /// L'horodatage est corrigé du décalage d'horloge de la caméra.
    private func securityHeader(timeOffset: TimeInterval) -> String {
        var nonceBytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, nonceBytes.count, &nonceBytes)
        let nonce = Data(nonceBytes)
        let created = ISO8601DateFormatter().string(from: Date().addingTimeInterval(timeOffset))

        var digestInput = Data()
        digestInput.append(nonce)
        digestInput.append(Data(created.utf8))
        digestInput.append(Data(password.utf8))
        let digest = Data(Insecure.SHA1.hash(data: digestInput))

        return """
        <s:Header><wsse:Security s:mustUnderstand="1" \
        xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd" \
        xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">\
        <wsse:UsernameToken><wsse:Username>\(username)</wsse:Username>\
        <wsse:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest">\(digest.base64EncodedString())</wsse:Password>\
        <wsse:Nonce EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary">\(nonce.base64EncodedString())</wsse:Nonce>\
        <wsu:Created>\(created)</wsu:Created></wsse:UsernameToken></wsse:Security></s:Header>
        """
    }

    // MARK: HTTP GET authentifié (digest)

    /// Télécharge une ressource protégée par HTTP Digest (le snapshot des Tapo).
    private func authenticatedGet(_ url: URL) async throws -> Data {
        let delegate = DigestAuthDelegate(username: username, password: password)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw OnvifError.http(status)
        }
        return data
    }

    private final class DigestAuthDelegate: NSObject, URLSessionTaskDelegate {
        let username: String
        let password: String

        init(username: String, password: String) {
            self.username = username
            self.password = password
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            didReceive challenge: URLAuthenticationChallenge
        ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            guard challenge.previousFailureCount < 2 else {
                return (.cancelAuthenticationChallenge, nil)
            }
            return (.useCredential, URLCredential(user: username, password: password, persistence: .forSession))
        }
    }
}
