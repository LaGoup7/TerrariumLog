import SwiftUI
import SwiftData
import UserNotifications
import UniformTypeIdentifiers

struct JSONFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
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
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    @State private var exportDocument: JSONFileDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var showingImportConfirmation = false
    @State private var pendingImportData: Data?
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
                contentType: .json,
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
                allowedContentTypes: [.json]
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
                    pendingImportData = nil
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

    private func exportData() {
        do {
            let data = try BackupService.shared.exportData(context: context)
            exportDocument = JSONFileDocument(data: data)
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
            pendingImportData = try Data(contentsOf: url)
            showingImportConfirmation = true
        } catch {
            backupMessage = "Impossible de lire le fichier : \(error.localizedDescription)"
        }
    }

    private func performImport() {
        guard let data = pendingImportData else { return }
        do {
            try BackupService.shared.importData(data, context: context)
            backupMessage = "Import réussi."
        } catch {
            backupMessage = "Échec de l'import : \(error.localizedDescription)"
        }
        pendingImportData = nil
    }
}
