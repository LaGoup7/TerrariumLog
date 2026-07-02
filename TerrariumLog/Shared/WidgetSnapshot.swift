import Foundation

/// Petit instantané des prochains rappels, partagé entre l'app et le widget via App Group.
/// Volontairement séparé du store SwiftData principal : le widget ne lit jamais la base de
/// données de l'app directement, seulement ce snapshot JSON. Si l'App Group n'est pas
/// disponible (ex: signature sans compte Apple Developer payant), la sauvegarde et la lecture
/// échouent silencieusement — l'app continue de fonctionner normalement, seul le widget reste
/// vide, et surtout les données réelles de l'utilisateur ne sont jamais affectées.
struct WidgetReminderSnapshot: Codable, Identifiable {
    var id: String { "\(title)-\(date.timeIntervalSince1970)" }
    let title: String
    let animalName: String?
    let date: Date
}

struct WidgetSnapshotData: Codable {
    let reminders: [WidgetReminderSnapshot]
    let generatedAt: Date
}

enum WidgetSnapshotStore {
    static let appGroupIdentifier = "group.com.example.terrariumlog"
    private static let key = "widgetReminderSnapshot"

    static func save(_ snapshot: WidgetSnapshotData) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        defaults.set(data, forKey: key)
    }

    static func load() -> WidgetSnapshotData? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(WidgetSnapshotData.self, from: data)
    }
}
