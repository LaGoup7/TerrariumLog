import Foundation
import SwiftData

/// Sauvegarde automatique légère : exporte les données (data.json, sans les
/// médias) dans `Documents/Sauvegardes` au plus tous les 7 jours, et garde les
/// 8 fichiers les plus récents. Le dossier est visible dans l'app Fichiers
/// (« Sur mon iPhone → Habitat ») grâce à UIFileSharingEnabled, pour pouvoir
/// copier une sauvegarde hors de l'app à tout moment.
///
/// L'export complet (données + photos + vidéos) reste manuel, dans Réglages.
final class AutoBackupService {
    static let shared = AutoBackupService()

    private let lastRunKey = "lastAutoBackupDate"
    private let interval: TimeInterval = 7 * 24 * 3600
    private let keepCount = 8

    var lastBackupDate: Date? {
        UserDefaults.standard.object(forKey: lastRunKey) as? Date
    }

    var backupsDirectory: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sauvegardes", isDirectory: true)
    }

    /// Lance une sauvegarde si la précédente date de plus de 7 jours.
    /// Silencieux en cas d'échec (relancé au prochain démarrage).
    @discardableResult
    func runIfNeeded(context: ModelContext) -> Bool {
        if let last = lastBackupDate, Date.now.timeIntervalSince(last) < interval {
            return false
        }
        return (try? performBackup(context: context)) != nil
    }

    /// Crée immédiatement une sauvegarde JSON et renvoie son URL.
    @discardableResult
    func performBackup(context: ModelContext) throws -> URL {
        let bundle = try BackupService.shared.exportBundle(context: context)
        try FileManager.default.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let url = backupsDirectory.appendingPathComponent("habitat-auto-\(formatter.string(from: .now)).json")
        try bundle.data.write(to: url, options: .atomic)

        UserDefaults.standard.set(Date.now, forKey: lastRunKey)
        pruneOldBackups()
        return url
    }

    /// Ne garde que les `keepCount` sauvegardes les plus récentes
    /// (les noms horodatés trient chronologiquement).
    private func pruneOldBackups() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: backupsDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        let backups = files
            .filter { $0.lastPathComponent.hasPrefix("habitat-auto-") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for old in backups.dropFirst(keepCount) {
            try? FileManager.default.removeItem(at: old)
        }
    }
}
