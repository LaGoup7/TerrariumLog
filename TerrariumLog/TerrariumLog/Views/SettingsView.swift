import SwiftUI
import SwiftData
import UserNotifications
import UniformTypeIdentifiers

/// Exports as a folder containing `data.json` plus `Photos/` and `Videos/` subfolders with
/// the actual media files, so a restored backup doesn't lose them (only the JSON's file path
/// references would otherwise survive).
struct BackupBundleDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.folder] }
    static var writableContentTypes: [UTType] { [.folder] }

    var jsonData: Data
    var photoURLs: [URL]
    var videoURLs: [URL]

    init(jsonData: Data, photoURLs: [URL], videoURLs: [URL] = []) {
        self.jsonData = jsonData
        self.photoURLs = photoURLs
        self.videoURLs = videoURLs
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnsupportedScheme)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let jsonWrapper = FileWrapper(regularFileWithContents: jsonData)
        jsonWrapper.preferredFilename = "data.json"

        func mediaFolder(named name: String, urls: [URL]) -> FileWrapper {
            var wrappers: [String: FileWrapper] = [:]
            for url in urls {
                if let data = try? Data(contentsOf: url) {
                    let wrapper = FileWrapper(regularFileWithContents: data)
                    wrapper.preferredFilename = url.lastPathComponent
                    wrappers[url.lastPathComponent] = wrapper
                }
            }
            let folder = FileWrapper(directoryWithFileWrappers: wrappers)
            folder.preferredFilename = name
            return folder
        }

        return FileWrapper(directoryWithFileWrappers: [
            "data.json": jsonWrapper,
            "Photos": mediaFolder(named: "Photos", urls: photoURLs),
            "Videos": mediaFolder(named: "Videos", urls: videoURLs)
        ])
    }
}

enum AppAppearance: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "Système"
        case .light: return "Clair"
        case .dark: return "Sombre"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("appAppearance") private var appearanceRawValue = AppAppearance.system.rawValue
    /// Date du dernier export complet manuel (secondes depuis referenceDate ; 0 = jamais).
    @AppStorage("lastManualExportDate") private var lastManualExportTimestamp: Double = 0
    @Query private var animals: [Animal]
    @Query private var terrariums: [Terrarium]
    @Query(sort: [SortDescriptor<CustomPreyType>(\.name)]) private var customPreyTypes: [CustomPreyType]
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    @State private var exportDocument: BackupBundleDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var showingImportConfirmation = false
    @State private var pendingImportData: Data?
    @State private var pendingImportPhotosStagingURL: URL?
    @State private var pendingImportVideosStagingURL: URL?
    @State private var backupMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Thème", selection: $appearanceRawValue) {
                        ForEach(AppAppearance.allCases, id: \.self) { appearance in
                            Text(appearance.displayName).tag(appearance.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Apparence")
                } footer: {
                    Text("Habitat s'adapte automatiquement au thème choisi, en clair comme en sombre.")
                }

                Section("Notifications") {
                    LabeledContent("Statut", value: notificationStatusLabel)
                    if notificationStatus == .denied {
                        Button("Ouvrir les réglages de notifications") {
                            openSystemSettings()
                        }
                    } else if notificationStatus == .notDetermined {
                        Button("Activer les notifications") {
                            Task {
                                await NotificationService.shared.requestAuthorizationIfNeeded()
                                await refreshNotificationStatus()
                            }
                        }
                    }
                }

                Section("Élevage") {
                    NavigationLink {
                        PreyStockView()
                    } label: {
                        Label("Stock de proies", systemImage: "shippingbox")
                    }
                    NavigationLink {
                        AllPhotosView()
                    } label: {
                        Label("Toutes les photos", systemImage: "photo.on.rectangle.angled")
                    }
                }

                if !customPreyTypes.isEmpty {
                    Section("Types de proies personnalisés") {
                        ForEach(customPreyTypes) { custom in
                            Text(custom.name)
                        }
                        .onDelete(perform: deleteCustomPreyTypes)
                    }
                }

                Section("Données") {
                    LabeledContent("Animaux", value: "\(animals.count)")
                    LabeledContent("Terrariums", value: "\(terrariums.count)")
                    Button("Exporter mes données") {
                        exportData()
                    }
                    Button("Importer une sauvegarde") {
                        showingImporter = true
                    }
                    if let backupMessage {
                        Text(backupMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    LabeledContent("Sauvegarde auto", value: autoBackupLabel)
                    LabeledContent("Dernier export complet", value: manualExportLabel)
                        .foregroundStyle(manualExportIsStale ? Brand.warning : Color.primary)
                    Button("Sauvegarder maintenant") {
                        runAutoBackupNow()
                    }
                } header: {
                    Text("Sauvegardes")
                } footer: {
                    Text("Une sauvegarde des données (sans les photos/vidéos) est créée automatiquement chaque semaine dans Fichiers → Sur mon iPhone → Habitat → Sauvegardes. Pense à faire un export complet (avec médias) vers iCloud Drive régulièrement : c'est lui qui protège tes photos.")
                }

                Section("À propos") {
                    LabeledContent("Version", value: appVersion)
                    Text("SwiftUI + SwiftData, données 100% locales et hors ligne.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Réglages")
            .task {
                await refreshNotificationStatus()
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .folder,
                defaultFilename: "Habitat-\(exportFilenameDateStamp)"
            ) { result in
                switch result {
                case .success:
                    backupMessage = "Export réussi."
                    lastManualExportTimestamp = Date.now.timeIntervalSinceReferenceDate
                case .failure(let error):
                    backupMessage = "Échec de l'export : \(error.localizedDescription)"
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.folder]
            ) { result in
                switch result {
                case .success(let url):
                    loadImportFile(from: url)
                case .failure(let error):
                    backupMessage = "Échec de la sélection : \(error.localizedDescription)"
                }
            }
            .confirmationDialog(
                "Remplacer toutes les données actuelles ?",
                isPresented: $showingImportConfirmation,
                titleVisibility: .visible
            ) {
                Button("Importer et remplacer", role: .destructive) {
                    performImport()
                }
                Button("Annuler", role: .cancel) {
                    if let stagingURL = pendingImportPhotosStagingURL {
                        try? FileManager.default.removeItem(at: stagingURL)
                    }
                    if let stagingURL = pendingImportVideosStagingURL {
                        try? FileManager.default.removeItem(at: stagingURL)
                    }
                    pendingImportData = nil
                    pendingImportPhotosStagingURL = nil
                    pendingImportVideosStagingURL = nil
                }
            } message: {
                Text("Cette sauvegarde va remplacer tous les animaux, terrariums et leur historique actuellement enregistrés sur cet appareil. Cette action est irréversible.")
            }
        }
    }

    private var autoBackupLabel: String {
        guard let date = AutoBackupService.shared.lastBackupDate else { return "Jamais" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private var manualExportLabel: String {
        guard lastManualExportTimestamp > 0 else { return "Jamais" }
        let date = Date(timeIntervalSinceReferenceDate: lastManualExportTimestamp)
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    /// Alerte visuelle si aucun export complet (avec médias) depuis plus de 30 jours.
    private var manualExportIsStale: Bool {
        guard lastManualExportTimestamp > 0 else { return true }
        let date = Date(timeIntervalSinceReferenceDate: lastManualExportTimestamp)
        return Date.now.timeIntervalSince(date) > 30 * 24 * 3600
    }

    private func runAutoBackupNow() {
        do {
            let url = try AutoBackupService.shared.performBackup(context: context)
            backupMessage = "Sauvegarde créée : \(url.lastPathComponent) (Fichiers → Habitat → Sauvegardes)."
        } catch {
            backupMessage = "Échec de la sauvegarde : \(error.localizedDescription)"
        }
    }

    private var notificationStatusLabel: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Activées"
        case .denied:
            return "Désactivées"
        case .notDetermined:
            return "Non demandées"
        @unknown default:
            return "Inconnu"
        }
    }

    private var appVersion: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(shortVersion) (\(buildVersion))"
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private var exportFilenameDateStamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }

    private func deleteCustomPreyTypes(at offsets: IndexSet) {
        for index in offsets {
            context.delete(customPreyTypes[index])
        }
        try? context.save()
    }

    private func exportData() {
        do {
            let bundle = try BackupService.shared.exportBundle(context: context)
            let photoURLs = bundle.photoPaths.map { PhotoStorage.shared.url(for: $0) }
            let videoURLs = bundle.videoPaths.map { VideoStorage.shared.url(for: $0) }
            exportDocument = BackupBundleDocument(jsonData: bundle.data, photoURLs: photoURLs, videoURLs: videoURLs)
            showingExporter = true
        } catch {
            backupMessage = "Échec de l'export : \(error.localizedDescription)"
        }
    }

    private func loadImportFile(from url: URL) {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let jsonURL = url.appendingPathComponent("data.json")
            pendingImportData = try Data(contentsOf: jsonURL)

            // Photos/videos are staged into local temp folders now, while we still have
            // access to the picked folder (the confirmation dialog delays the
            // actual import, by which point security-scoped access would be gone).
            func stageMedia(from folderName: String) -> URL {
                let sourceURL = url.appendingPathComponent(folderName)
                let stagingURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try? FileManager.default.createDirectory(at: stagingURL, withIntermediateDirectories: true)
                if let files = try? FileManager.default.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: nil) {
                    for file in files {
                        try? FileManager.default.copyItem(at: file, to: stagingURL.appendingPathComponent(file.lastPathComponent))
                    }
                }
                return stagingURL
            }
            pendingImportPhotosStagingURL = stageMedia(from: "Photos")
            pendingImportVideosStagingURL = stageMedia(from: "Videos")

            showingImportConfirmation = true
        } catch {
            backupMessage = "Impossible de lire le fichier : \(error.localizedDescription)"
        }
    }

    private func performImport() {
        guard let data = pendingImportData else { return }
        do {
            try BackupService.shared.importData(data, context: context)
            if let stagingURL = pendingImportPhotosStagingURL,
               let files = try? FileManager.default.contentsOfDirectory(at: stagingURL, includingPropertiesForKeys: nil) {
                for file in files {
                    try? PhotoStorage.shared.importPhoto(from: file, filename: file.lastPathComponent)
                }
                try? FileManager.default.removeItem(at: stagingURL)
            }
            if let stagingURL = pendingImportVideosStagingURL,
               let files = try? FileManager.default.contentsOfDirectory(at: stagingURL, includingPropertiesForKeys: nil) {
                for file in files {
                    try? VideoStorage.shared.importVideo(from: file, filename: file.lastPathComponent)
                }
                try? FileManager.default.removeItem(at: stagingURL)
            }
            backupMessage = "Import réussi."
        } catch {
            backupMessage = "Échec de l'import : \(error.localizedDescription)"
        }
        pendingImportData = nil
        pendingImportPhotosStagingURL = nil
        pendingImportVideosStagingURL = nil
    }
}
