import SwiftUI
import SwiftData

struct CameraLiveView: View {
    @Environment(\.modelContext) private var context
    let camera: Camera

    @State private var showingConfig = false
    @State private var comingSoonMessage: String?
    @State private var streamStatus: CameraStreamStatus = .connecting
    @State private var streamDetail = "Ouverture…"
    @State private var reloadToken = UUID()
    @State private var diagnosticMessage: String?
    @State private var isTesting = false
    @State private var logLines: [String] = []
    // Le flux HD (/stream1) est en H.264 (décodable sans peine) et c'est celui
    // validé sur VLC desktop : on démarre dessus. « Fluide » reste dispo.
    @State private var quality: StreamQuality = .hd

    private let streamProvider: CameraStreamProvider = RTSPPassthroughProvider()

    /// Sur les Tapo, on peut basculer le chemin du flux (HD `/stream1` ↔
    /// SD `/stream2`) sans modifier la config stockée. Ailleurs, on respecte
    /// l'URL telle quelle.
    private var pathOverride: String? {
        camera.brand == .tapo ? quality.rawValue : nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                videoArea
                if camera.brand == .tapo {
                    qualityPicker
                }
                statusSection
                buttonsRow
                technicalJournal
            }
            .padding()
        }
        .navigationTitle(camera.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingConfig) {
            CameraConfigView(camera: camera)
        }
        .alert(
            "Bientôt disponible",
            isPresented: Binding(
                get: { comingSoonMessage != nil },
                set: { if !$0 { comingSoonMessage = nil } }
            )
        ) {
            Button("OK") { comingSoonMessage = nil }
        } message: {
            Text(comingSoonMessage ?? "")
        }
        .alert(
            "Test de connexion",
            isPresented: Binding(
                get: { diagnosticMessage != nil },
                set: { if !$0 { diagnosticMessage = nil } }
            )
        ) {
            Button("OK") { diagnosticMessage = nil }
        } message: {
            Text(diagnosticMessage ?? "")
        }
    }

    private func testConnection() {
        guard let url = streamProvider.playableURL(for: camera, streamPathOverride: pathOverride), let host = url.host, !host.isEmpty else {
            diagnosticMessage = "URL du flux vide ou invalide. Renseigne l'URL (rtsp://…:554/stream1) ou l'IP + les identifiants dans Réglages."
            return
        }
        let port = UInt16(url.port ?? 554)
        isTesting = true
        // L'alerte n'est présentée qu'une fois le résultat connu : une alerte
        // SwiftUI ne rafraîchit pas son texte tant qu'elle reste affichée.
        Task {
            let outcome = await NetworkProbe.probe(host: host, port: port, timeout: 6)
            isTesting = false
            var lines = [outcome.reachable ? "✅ \(host):\(port) joignable" : "❌ \(host):\(port) injoignable", "", outcome.detail]
            if outcome.reachable {
                lines.append("")
                lines.append("Le réseau est bon. Si l'image reste noire, vérifie le chemin (/stream1 en HD, /stream2 en SD) et surtout les identifiants du COMPTE CAMÉRA (app Tapo → Paramètres avancés → Compte de la caméra), différents du compte TP-Link.")
            }
            diagnosticMessage = lines.joined(separator: "\n")
        }
    }

    @ViewBuilder
    private var videoArea: some View {
        if let url = streamProvider.playableURL(for: camera, streamPathOverride: pathOverride) {
            ZStack {
                CameraStreamView(
                    url: url,
                    username: camera.username,
                    password: camera.password,
                    onStatusChange: { status, detail in
                        streamStatus = status
                        streamDetail = detail
                    },
                    onLog: { line in appendLog(line) }
                )
                .id(reloadToken)

                if streamStatus == .connecting {
                    VStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text(streamDetail)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                } else if streamStatus != .playing {
                    VStack(spacing: 8) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 34))
                            .foregroundStyle(.white.opacity(0.7))
                        Text("État : \(streamDetail)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        if let attempted = streamProvider.redactedURLString(for: camera, streamPathOverride: pathOverride) {
                            Text(attempted)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        Text("Réseau OK mais lecture KO ? Essaie l'autre qualité (HD/Fluide) ci-dessous, et vérifie le compte caméra.")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(alignment: .topLeading) {
                if streamStatus == .playing {
                    liveBadge.padding(10)
                }
            }
            .task(id: reloadToken) {
                // Timeout : si le flux n'est pas en lecture après 20 s, on bascule
                // en erreur avec un message plutôt que de rester noir sans fin.
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                if streamStatus != .playing {
                    streamStatus = .error
                    if streamDetail == "Ouverture…" || streamDetail == "Mise en mémoire tampon…" {
                        streamDetail = "Caméra injoignable (délai dépassé)"
                    }
                }
            }
        } else {
            videoPlaceholder
        }
    }

    private func reconnect() {
        streamStatus = .connecting
        streamDetail = "Ouverture…"
        logLines.removeAll()
        reloadToken = UUID()
    }

    private func appendLog(_ line: String) {
        let stamp = Date.now.formatted(date: .omitted, time: .standard)
        logLines.append("\(stamp)  \(line)")
        if logLines.count > 80 {
            logLines.removeFirst(logLines.count - 80)
        }
    }

    @ViewBuilder
    private var technicalJournal: some View {
        if !logLines.isEmpty {
            DisclosureGroup("Journal technique") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(logLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    Button {
                        UIPasteboard.general.string = logLines.joined(separator: "\n")
                    } label: {
                        Label("Copier le journal", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .padding(.top, 6)
                }
                .padding(.top, 6)
            }
            .font(.subheadline)
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var qualityPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Qualité", selection: $quality) {
                ForEach(StreamQuality.allCases) { quality in
                    Text(quality.displayName).tag(quality)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: quality) { _, _ in
                reconnect()
            }
            Text("HD = flux principal (2K). Si l'image tarde ou reste noire, essaie « Fluide » (plus léger).")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var liveBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(.red)
                .frame(width: 7, height: 7)
            Text("EN DIRECT")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.5), in: Capsule())
    }

    private var videoPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black)
            VStack(spacing: 10) {
                Image(systemName: "video.slash.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Caméra non configurée — renseigne l'URL du flux dans Réglages.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(height: 220)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent("Statut", value: camera.isConfigured ? "Configurée" : "Non configurée")
            LabeledContent("Marque", value: camera.brand.displayName)
            if !camera.model.isEmpty {
                LabeledContent("Modèle", value: camera.model)
            }
            LabeledContent("Connexion", value: camera.connectionType.displayName)
            if let terrarium = camera.terrarium {
                LabeledContent("Terrarium", value: terrarium.name)
            }
            if let displayURL = streamProvider.redactedURLString(for: camera, streamPathOverride: pathOverride) {
                LabeledContent("URL du flux", value: displayURL)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var buttonsRow: some View {
        HStack(spacing: 12) {
            actionButton(title: "Live", systemImage: "play.circle.fill") {
                if streamProvider.playableURL(for: camera) != nil {
                    reconnect()
                } else {
                    comingSoonMessage = "Renseigne l'URL du flux (rtsp://…) de la caméra dans Réglages avant de lancer le direct."
                }
            }
            actionButton(title: "Photo", systemImage: "camera.fill") {
                comingSoonMessage = "La capture de snapshot arrivera avec l'intégration du flux vidéo."
            }
            Button {
                testConnection()
            } label: {
                VStack(spacing: 4) {
                    if isTesting {
                        ProgressView()
                            .frame(height: 22)
                    } else {
                        Image(systemName: "network")
                            .font(.title2)
                    }
                    Text(isTesting ? "Test…" : "Tester")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(isTesting)
            actionButton(title: "Réglages", systemImage: "gearshape.fill") {
                showingConfig = true
            }
        }
    }

    private func actionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// Qualité du flux (chemin RTSP) pour les caméras Tapo : HD = flux principal
/// (`/stream1`), Fluide = flux secondaire (`/stream2`, plus léger).
enum StreamQuality: String, CaseIterable, Identifiable {
    case hd = "stream1"
    case sd = "stream2"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hd: return "HD"
        case .sd: return "Fluide"
        }
    }
}

struct CameraConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let terrarium: Terrarium?
    let existingCamera: Camera?

    @State private var name: String
    @State private var brand: CameraBrand
    @State private var model: String
    @State private var connectionType: CameraConnectionType
    @State private var streamURL: String
    @State private var ipAddress: String
    @State private var username: String
    @State private var password: String
    @State private var notes: String

    init(camera: Camera? = nil, terrarium: Terrarium? = nil) {
        self.existingCamera = camera
        self.terrarium = terrarium
        _name = State(initialValue: camera?.name ?? "")
        _brand = State(initialValue: camera?.brand ?? .tapo)
        _model = State(initialValue: camera?.model ?? "")
        _connectionType = State(initialValue: camera?.connectionType ?? .unconfigured)
        _streamURL = State(initialValue: camera?.streamURL ?? "")
        _ipAddress = State(initialValue: camera?.ipAddress ?? "")
        _username = State(initialValue: camera?.username ?? "")
        _password = State(initialValue: camera?.password ?? "")
        _notes = State(initialValue: camera?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Nom", text: $name)
                    Picker("Marque", selection: $brand) {
                        ForEach(CameraBrand.allCases, id: \.self) { brand in
                            Text(brand.displayName).tag(brand)
                        }
                    }
                    TextField("Modèle (ex: Tapo C220)", text: $model)
                    Picker("Connexion", selection: $connectionType) {
                        ForEach(CameraConnectionType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                if connectionType != .unconfigured {
                    Section {
                        TextField("Adresse IP", text: $ipAddress)
                            .keyboardType(.numbersAndPunctuation)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        TextField("URL du flux (ex: rtsp://192.168.1.50:554/stream1)", text: $streamURL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        TextField("Utilisateur", text: $username)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        SecureField("Mot de passe", text: $password)
                    } header: {
                        Text("Accès réseau")
                    } footer: {
                        Text("Tapo : renseigne l'IP (ou l'URL complète) + le **compte caméra** créé dans l'app Tapo → Paramètres avancés → Compte de la caméra (différent du compte TP-Link). Flux HD : /stream1, SD : /stream2. Le RTSP doit être activé dans l'app Tapo. Les identifiants sont ajoutés automatiquement à l'URL.")
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes)
                }
            }
            .navigationTitle(existingCamera == nil ? "Ajouter une caméra" : "Modifier la caméra")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func save() {
        let camera = existingCamera ?? Camera(name: "", terrarium: terrarium)
        camera.name = name
        camera.brand = brand
        camera.model = model
        camera.connectionType = connectionType
        camera.streamURL = streamURL.isEmpty ? nil : streamURL
        camera.ipAddress = ipAddress.isEmpty ? nil : ipAddress
        camera.username = username.isEmpty ? nil : username
        camera.password = password.isEmpty ? nil : password
        camera.notes = notes
        if existingCamera == nil {
            context.insert(camera)
        }
        try? context.save()
    }
}
