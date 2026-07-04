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

    private let streamProvider: CameraStreamProvider = RTSPPassthroughProvider()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                videoArea
                statusSection
                buttonsRow
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
        guard let url = streamProvider.playableURL(for: camera), let host = url.host, !host.isEmpty else {
            diagnosticMessage = "URL du flux vide ou invalide. Renseigne rtsp://…:554/stream1 dans Réglages."
            return
        }
        let port = UInt16(url.port ?? 554)
        diagnosticMessage = "Test en cours vers \(host):\(port)…"
        Task {
            let reachable = await NetworkProbe.canConnect(host: host, port: port, timeout: 6)
            diagnosticMessage = reachable
                ? "✅ \(host):\(port) est joignable.\n\nLe port RTSP répond : le réseau est bon. Le noir vient donc de l'URL/chemin (/stream1 vs /stream2), des identifiants (casse) ou du décodage — pas du réseau."
                : "❌ \(host):\(port) injoignable.\n\nLe port RTSP ne répond pas. Vérifie : iPhone sur le même Wi-Fi que la caméra, IP exacte, et RTSP réellement activé (compte caméra) sur la Tapo."
        }
    }

    @ViewBuilder
    private var videoArea: some View {
        if let url = streamProvider.playableURL(for: camera) {
            ZStack {
                CameraStreamView(url: url) { status, detail in
                    streamStatus = status
                    streamDetail = detail
                }
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
                        Text("Vérifie : iPhone sur le même Wi-Fi que la caméra, IP correcte, et identifiants (sensibles à la casse). Puis « Live ».")
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
        reloadToken = UUID()
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
            if let url = streamProvider.playableURL(for: camera) {
                LabeledContent("URL du flux", value: url.absoluteString)
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
            actionButton(title: "Tester", systemImage: "network") {
                testConnection()
            }
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
                    Section("Accès réseau") {
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
