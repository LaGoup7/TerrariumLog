import SwiftUI
import SwiftData
import UserNotifications

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
    @AppStorage("appAppearance") private var appearanceRawValue = AppAppearance.system.rawValue
    @Query private var animals: [Animal]
    @Query private var terrariums: [Terrarium]
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

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
}
