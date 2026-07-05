import SwiftUI
import SwiftData

struct CameraLiveView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    let camera: Camera

    @State private var showingConfig = false
    @State private var comingSoonMessage: String?
    @State private var streamStatus: CameraStreamStatus = .connecting
    @State private var streamDetail = "Ouverture…"
    // nil = aucun lecteur actif (fenêtre de fermeture entre deux sessions RTSP).
    @State private var reloadToken: UUID? = UUID()
    @State private var diagnosticMessage: String?
    @State private var snapshotImage: UIImage?
    @State private var isFetchingSnapshot = false
    @State private var snapshotTrigger = 0
    @State private var isRecording = false
    @State private var recordedVideoURL: URL?
    @StateObject private var ptz: PtzController

    init(camera: Camera) {
        self.camera = camera
        let host = RTSPPassthroughProvider().playableURL(for: camera)?.host
            ?? camera.ipAddress ?? ""
        _ptz = StateObject(wrappedValue: PtzController(
            host: host,
            username: camera.username ?? "",
            password: camera.password ?? ""
        ))
    }
    // Flux léger (/stream2, 640×360) par défaut : bien moins exigeant pour le
    // Wi-Fi et le décodage — le plus fiable sur iPhone. « HD » reste disponible.
    @State private var quality: StreamQuality = .sd

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
                    ptzPad
                    qualityPicker
                }
                buttonsRow
                statusSection
            }
            .padding()
        }
        .navigationTitle(camera.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if camera.brand == .tapo {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        openTapoApp()
                    } label: {
                        Label("Ouvrir dans Tapo", systemImage: "arrow.up.forward.app")
                    }
                }
            }
        }
        .onAppear {
            // Seules les erreurs PTZ remontent à l'utilisateur (via l'alerte).
            ptz.log = { line in
                if line.hasPrefix("PTZ: échec") {
                    diagnosticMessage = "Mouvement impossible : vérifie que la caméra est joignable et que le compte caméra est renseigné."
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Libère la session RTSP quand l'app passe en arrière-plan (évite les
            // sessions fantômes côté caméra), et la relance au retour au premier plan.
            switch phase {
            case .background:
                reloadToken = nil
            case .active:
                if reloadToken == nil { reconnect() }
            default:
                break
            }
        }
        .sheet(isPresented: $showingConfig) {
            CameraConfigView(camera: camera)
        }
        .sheet(isPresented: Binding(
            get: { snapshotImage != nil },
            set: { if !$0 { snapshotImage = nil } }
        )) {
            if let snapshotImage {
                SnapshotViewer(image: snapshotImage, cameraName: camera.name)
            }
        }
        .sheet(isPresented: Binding(
            get: { recordedVideoURL != nil },
            set: { if !$0 { recordedVideoURL = nil } }
        )) {
            if let recordedVideoURL {
                RecordingResultView(videoURL: recordedVideoURL, cameraName: camera.name)
            }
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
            "Caméra",
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

    /// Ouvre l'app Tapo officielle (live fluide via leur protocole propriétaire).
    /// iOS ne permet pas de cibler directement une caméra précise : on ouvre
    /// l'app, ou sa fiche App Store si l'ouverture échoue. On tente l'ouverture
    /// directement (sans `canOpenURL`, peu fiable pour les schémas tiers).
    private func openTapoApp() {
        guard let tapoURL = URL(string: "tapo://") else { return }
        UIApplication.shared.open(tapoURL, options: [:]) { success in
            if !success, let storeURL = URL(string: "https://apps.apple.com/app/id1472718009") {
                UIApplication.shared.open(storeURL)
            }
        }
    }

    /// Capture d'image : si le flux est en lecture, on prend l'image affichée
    /// (instantané, sans réseau). Sinon, on tente le snapshot ONVIF — pas
    /// toujours supporté par les Tapo, mais tracé dans le journal.
    private func takeSnapshot() {
        if streamStatus == .playing {
            isFetchingSnapshot = true
            snapshotTrigger += 1
            return
        }
        fetchOnvifSnapshot()
    }

    private func fetchOnvifSnapshot() {
        let host = streamProvider.playableURL(for: camera, streamPathOverride: nil)?.host
            ?? (camera.ipAddress ?? "")
        guard !host.isEmpty else {
            diagnosticMessage = "Renseigne l'IP de la caméra dans Réglages pour utiliser la capture."
            return
        }
        isFetchingSnapshot = true
        Task {
            let client = OnvifClient(
                host: host,
                username: camera.username ?? "",
                password: camera.password ?? ""
            )
            do {
                let data = try await client.fetchSnapshot()
                if let image = UIImage(data: data) {
                    snapshotImage = image
                } else {
                    diagnosticMessage = "La caméra a répondu, mais pas avec une image. Réessaie."
                }
            } catch {
                diagnosticMessage = "Cette caméra ne fournit pas de capture sans flux (limitation Tapo). Lance le Live, puis appuie sur Photo une fois l'image affichée : la capture sera instantanée."
            }
            isFetchingSnapshot = false
        }
    }

    @ViewBuilder
    private var videoArea: some View {
        if let url = streamProvider.playableURL(for: camera, streamPathOverride: pathOverride) {
            ZStack {
                if let token = reloadToken {
                    CameraStreamView(
                        url: url,
                        snapshotTrigger: snapshotTrigger,
                        onSnapshot: { image in
                            isFetchingSnapshot = false
                            if let image {
                                snapshotImage = image
                            } else {
                                diagnosticMessage = "Capture impossible pour le moment. Attends que l'image soit affichée, puis réessaie."
                            }
                        },
                        isRecording: isRecording,
                        onRecordingFinished: { path in
                            isRecording = false
                            if let path {
                                recordedVideoURL = URL(fileURLWithPath: path)
                            } else {
                                diagnosticMessage = "Enregistrement impossible. Attends que l'image soit affichée, puis réessaie."
                            }
                        },
                        onStatusChange: { status, detail in
                            streamStatus = status
                            streamDetail = detail
                        }
                    )
                    .id(token)
                }

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
                        Text(streamDetail)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Text("Appuie sur Live pour réessayer, ou passe en « Fluide ».")
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
        } else {
            videoPlaceholder
        }
    }

    /// Reconnexion propre : on retire d'abord le lecteur (ce qui déclenche la
    /// fermeture de la session RTSP côté caméra), on laisse un délai pour qu'elle
    /// se libère, puis on en ouvre une neuve. Évite deux sessions simultanées,
    /// que la C220 refuse (d'où l'échec au 2e « Live »).
    private func reconnect() {
        streamStatus = .connecting
        streamDetail = "Reconnexion…"
        reloadToken = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            reloadToken = UUID()
        }
    }

    // MARK: Pavé directionnel PTZ

    @State private var ptzPressed = false

    /// Croix directionnelle : maintenir une flèche déplace la caméra
    /// (ContinuousMove ONVIF), relâcher l'arrête.
    private var ptzPad: some View {
        VStack(spacing: 6) {
            ptzButton("chevron.up", pan: 0, tilt: 0.5)
            HStack(spacing: 56) {
                ptzButton("chevron.left", pan: -0.5, tilt: 0)
                ptzButton("chevron.right", pan: 0.5, tilt: 0)
            }
            ptzButton("chevron.down", pan: 0, tilt: -0.5)
            Text("Maintiens une flèche pour orienter la caméra")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func ptzButton(_ systemImage: String, pan: Double, tilt: Double) -> some View {
        Image(systemName: systemImage)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Brand.primary)
            .frame(width: 52, height: 52)
            .background(Circle().fill(Brand.surfaceElevated))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !ptzPressed else { return }
                        ptzPressed = true
                        ptz.startMove(pan: pan, tilt: tilt)
                    }
                    .onEnded { _ in
                        ptzPressed = false
                        ptz.stopMove()
                    }
            )
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
            Text("Fluide = démarrage plus rapide • HD = pleine résolution")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
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
            if !camera.model.isEmpty {
                LabeledContent("Modèle", value: camera.model)
            } else {
                LabeledContent("Marque", value: camera.brand.displayName)
            }
            if let terrarium = camera.terrarium {
                LabeledContent("Terrarium", value: terrarium.name)
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
            Button {
                takeSnapshot()
            } label: {
                VStack(spacing: 4) {
                    if isFetchingSnapshot {
                        ProgressView()
                            .frame(height: 22)
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                    }
                    Text(isFetchingSnapshot ? "Photo…" : "Photo")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(isFetchingSnapshot)
            Button {
                isRecording.toggle()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                        .font(.title2)
                        .foregroundStyle(isRecording ? Brand.error : Color.accentColor)
                    Text(isRecording ? "Stop" : "REC")
                        .font(.caption)
                        .foregroundStyle(isRecording ? Brand.error : Color.accentColor)
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(streamStatus != .playing && !isRecording)
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

/// Pilotage des mouvements pan/tilt via ONVIF. La session (profil, service,
/// horloge) est découverte au premier mouvement puis réutilisée.
@MainActor
final class PtzController: ObservableObject {
    private var client: OnvifClient
    private var session: OnvifClient.PtzSession?
    var log: (String) -> Void = { _ in }

    init(host: String, username: String, password: String) {
        self.client = OnvifClient(host: host, username: username, password: password)
    }

    func startMove(pan: Double, tilt: Double) {
        Task {
            do {
                let session = try await ensureSession()
                try await client.continuousMove(session, pan: pan, tilt: tilt)
            } catch {
                log("PTZ: échec — \(error.localizedDescription)")
            }
        }
    }

    func stopMove() {
        Task {
            guard let session else { return }
            try? await client.stopMove(session)
        }
    }

    private func ensureSession() async throws -> OnvifClient.PtzSession {
        if let session { return session }
        client.log = log
        let newSession = try await client.preparePtz()
        session = newSession
        return newSession
    }
}

/// Visionneuse plein écran d'une capture instantanée : partage + galerie.
struct SnapshotViewer: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let cameraName: String
    @State private var savedToGallery = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            .navigationTitle(cameraName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        savedToGallery = true
                    } label: {
                        Image(systemName: savedToGallery ? "checkmark.circle.fill" : "square.and.arrow.down")
                    }
                    .disabled(savedToGallery)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: Image(uiImage: image),
                        preview: SharePreview(cameraName, image: Image(uiImage: image))
                    )
                }
            }
        }
    }
}

/// Fin d'enregistrement vidéo : proposer le partage/sauvegarde du fichier.
struct RecordingResultView: View {
    @Environment(\.dismiss) private var dismiss
    let videoURL: URL
    let cameraName: String

    private var fileSizeLabel: String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: videoURL.path)
        guard let bytes = attributes?[.size] as? Int64, bytes > 0 else { return "" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Brand.primary)
                Text("Enregistrement terminé")
                    .font(.headline)
                Text("\(videoURL.lastPathComponent)\(fileSizeLabel.isEmpty ? "" : " • \(fileSizeLabel)")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                ShareLink(item: videoURL) {
                    Label("Partager / Enregistrer la vidéo", systemImage: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Brand.primary.opacity(0.16), in: Capsule())
                }
                Text("Depuis le menu de partage : « Enregistrer la vidéo » pour la galerie, ou « Enregistrer dans Fichiers ».")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle(cameraName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
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
