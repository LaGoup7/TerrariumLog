import SwiftUI
import SwiftData
import UserNotifications
import UniformTypeIdentifiers

/// Exports as a folder containing `data.json` plus a `Photos/` subfolder with the
/// actual image files, so a restored backup doesn't lose photos (only the JSON's
/// file path references would otherwise survive).
struct BackupBundleDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.folder] }
    static var writableContentTypes: [UTType] { [.folder] }

    var jsonData: Data
    var photoURLs: [URL]

    init(jsonData: Data, photoURLs: [URL]) {
        self.jsonData = jsonData
        self.photoURLs = photoURLs
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnsupportedScheme)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let jsonWrapper = FileWrapper(regularFileWithContents: jsonData)
        jsonWrapper.preferredFilename = "data.json"

        var photoWrappers: [String: FileWrapper] = [:]
        for url in photoURLs {
            if let data = try? Data(contentsOf: url) {
                let wrapper = FileWrapper(regularFileWithContents: data)
                wrapper.preferredFilename = url.lastPathComponent
                photoWrappers[url.lastPathComponent] = wrapper
            }
        }
        let photosFolder = FileWrapper(directoryWithFileWrappers: photoWrappers)
        photosFolder.preferredFilename = "Photos"

        return FileWrapper(directoryWithFileWrappers: [
            "data.json": jsonWrapper,
            "Photos": photosFolder
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
    @State private var backupMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Apparence") {
                    Picker("Thème", selection: $appearanceRawValue) {
                        ForEach(AppAppearance.allCases, id: \.self) { appearance in
                            Text(appearance.displayName).tag(appearance.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
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
                defaultFilename: "TerrariumLog-\(exportFilenameDateStamp)"
            ) { result in
                switch result {
                case .success:
                    backupMessage = "Export réussi."
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
                    pendingImportData = nil
                    pendingImportPhotosStagingURL = nil
                }
            } message: {
                Text("Cette sauvegarde va remplacer tous les animaux, terrariums et leur historique actuellement enregistrés sur cet appareil. Cette action est irréversible.")
            }
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
            exportDocument = BackupBundleDocument(jsonData: bundle.data, photoURLs: photoURLs)
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

            // Photos are staged into a local temp folder now, while we still have
            // access to the picked folder (the confirmation dialog delays the
            // actual import, by which point security-scoped access would be gone).
            let photosSourceURL = url.appendingPathComponent("Photos")
            let stagingURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(at: stagingURL, withIntermediateDirectories: true)
            if let files = try? FileManager.default.contentsOfDirectory(at: photosSourceURL, includingPropertiesForKeys: nil) {
                for file in files {
                    try? FileManager.default.copyItem(at: file, to: stagingURL.appendingPathComponent(file.lastPathComponent))
                }
            }
            pendingImportPhotosStagingURL = stagingURL

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
            backupMessage = "Import réussi."
        } catch {
            backupMessage = "Échec de l'import : \(error.localizedDescription)"
        }
        pendingImportData = nil
        pendingImportPhotosStagingURL = nil
    }
}
