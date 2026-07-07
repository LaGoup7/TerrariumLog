import Foundation

/// Exporte le journal (une ou plusieurs bêtes) en CSV, pour un tableur ou un
/// export vétérinaire. Fichier écrit dans le dossier temporaire, prêt à partager
/// via `ShareLink` — même philosophie que `LifeStoryPDFExporter`.
enum JournalCSVExporter {
    private static let columns = [
        "Animal", "Date", "Categorie", "Type", "Note",
        "Proie", "Quantite", "Mange", "TempsCapture_min",
        "AncienStade", "NouveauStade", "TailleMue_mm", "Poids_g",
        "Temp_C", "Humidite_%", "Sol_%", "Luminosite", "Tags"
    ]

    /// Génère le contenu CSV (séparateur virgule, UTF-8) pour un ensemble d'animaux.
    static func makeCSV(for animals: [Animal]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var rows: [String] = [columns.joined(separator: ",")]
        let entries = animals
            .flatMap { animal in animal.journalEntries.filter { !$0.isPhotoOnly }.map { (animal, $0) } }
            .sorted { $0.1.date > $1.1.date }

        for (animal, entry) in entries {
            let type = entry.resolvedEventType
            let fields: [String] = [
                animal.name,
                formatter.string(from: entry.date),
                (type?.category.displayName) ?? "",
                (type?.displayName) ?? entry.eventType,
                entry.note,
                entry.preyType.flatMap { PreyType(rawValue: $0)?.displayName } ?? entry.preyType ?? "",
                entry.preyQuantity.map(String.init) ?? "",
                entry.eatenStatus.flatMap { EatenStatus(rawValue: $0)?.displayName } ?? "",
                entry.captureTimeMinutes.map { trim($0) } ?? "",
                entry.previousStage ?? "",
                entry.newStage ?? "",
                entry.moltSizeMM.map { trim($0) } ?? "",
                entry.weightGrams.map { trim($0) } ?? "",
                entry.snapshotTemperature.map { trim($0) } ?? "",
                entry.snapshotHumidity.map { trim($0) } ?? "",
                entry.snapshotSoilMoisture.map { trim($0) } ?? "",
                entry.snapshotLuminosity.map { trim($0) } ?? "",
                entry.tags.joined(separator: "; ")
            ]
            rows.append(fields.map(escape).joined(separator: ","))
        }
        return rows.joined(separator: "\r\n")
    }

    /// Écrit le CSV dans un fichier temporaire et renvoie son URL.
    static func export(animals: [Animal], filename: String = "journal") -> URL? {
        let csv = makeCSV(for: animals)
        let safeName = filename.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(String(safeName)).csv")
        do {
            try csv.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func export(animal: Animal) -> URL? {
        export(animals: [animal], filename: "journal-\(animal.name)")
    }

    // MARK: Helpers

    /// Échappe un champ CSV : guillemets doublés et entourage si nécessaire.
    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func trim(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}
