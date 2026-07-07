import Foundation

/// Suggestion d'entrée de journal proposée à l'utilisateur (jamais ajoutée
/// automatiquement). Croise l'historique déjà connu par Habitat (nourrissage,
/// mues) et, si disponible, un relevé capteurs face aux plages cibles du
/// terrarium. L'utilisateur valide → une `ObservationEntry` pré-remplie est créée.
struct JournalSuggestion: Identifiable {
    enum Kind: String {
        case feedingOverdue
        case moltApproaching
        case temperatureLow
        case temperatureHigh
        case humidityLow
        case humidityHigh
    }

    enum Severity {
        case info
        case warning
        case critical
    }

    let kind: Kind
    let animalName: String
    let suggestedEventType: ObservationEventType
    let title: String
    let reason: String
    let severity: Severity
    /// Note pré-remplie dans le formulaire si l'utilisateur accepte.
    let prefilledNote: String

    /// Identifiant stable (un seul type de suggestion actif par animal).
    var id: String { "\(kind.rawValue)-\(animalName)" }

    var symbolName: String { suggestedEventType.symbolName }
}

/// Moteur de suggestions. Volontairement **pur et synchrone** (comme
/// `FeedingStats`) : il prend les données déjà en mémoire et un relevé capteurs
/// optionnel. La récupération réseau du relevé se fait côté vue.
enum JournalSuggestionEngine {

    /// Seuils par défaut, ajustables ; extraits pour rester lisibles et testables.
    struct Thresholds {
        /// Facteur appliqué à l'intervalle de nourrissage moyen au-delà duquel on
        /// alerte (1.5 = 50 % de retard sur le rythme habituel).
        var feedingOverdueFactor: Double = 1.5
        /// Retard minimum en jours même quand aucun rythme moyen n'est connu.
        var feedingFallbackDays: Double = 14
        /// Marge sur l'intervalle moyen de mue à partir de laquelle on annonce une
        /// mue probable (0.85 = à 85 % du cycle habituel).
        var moltApproachFactor: Double = 0.85

        static let `default` = Thresholds()
    }

    /// Surcharge de commodité pour la vue : extrait les valeurs de l'`Animal`
    /// puis délègue à la version pure ci-dessous.
    static func suggestions(
        for animal: Animal,
        reading: TerrariumSensorReading? = nil,
        thresholds: Thresholds = .default,
        now: Date = .now
    ) -> [JournalSuggestion] {
        suggestions(
            animalName: animal.name,
            type: animal.type,
            status: animal.status,
            entries: animal.journalEntries.filter { !$0.isPhotoOnly },
            terrarium: animal.terrarium,
            reading: reading,
            thresholds: thresholds,
            now: now
        )
    }

    /// Version **pure** : ne dépend d'aucune relation SwiftData à charger, donc
    /// testable avec des `ObservationEntry` autonomes (sans ModelContext).
    static func suggestions(
        animalName: String,
        type: AnimalType,
        status: AnimalStatus,
        entries: [ObservationEntry],
        terrarium: Terrarium?,
        reading: TerrariumSensorReading? = nil,
        thresholds: Thresholds = .default,
        now: Date = .now
    ) -> [JournalSuggestion] {
        let events = entries.filter { !$0.isPhotoOnly }
        var result: [JournalSuggestion] = []
        result.append(contentsOf: feedingSuggestion(animalName: animalName, entries: events, thresholds: thresholds, now: now))
        result.append(contentsOf: moltSuggestion(animalName: animalName, type: type, status: status, entries: events, thresholds: thresholds, now: now))
        result.append(contentsOf: environmentSuggestions(animalName: animalName, terrarium: terrarium, reading: reading))
        return result
    }

    // MARK: Nourrissage en retard

    private static func feedingSuggestion(
        animalName: String,
        entries: [ObservationEntry],
        thresholds: Thresholds,
        now: Date
    ) -> [JournalSuggestion] {
        let stats = FeedingStats.compute(from: entries)
        guard let last = stats.lastFeedingDate else { return [] }
        let days = now.timeIntervalSince(last) / 86400
        guard days > 0 else { return [] }

        let threshold: Double
        if let average = stats.averageIntervalDays, average > 0 {
            threshold = max(average * thresholds.feedingOverdueFactor, average + 2)
        } else {
            threshold = thresholds.feedingFallbackDays
        }
        guard days >= threshold else { return [] }

        let rounded = Int(days.rounded())
        return [JournalSuggestion(
            kind: .feedingOverdue,
            animalName: animalName,
            suggestedEventType: .feeding,
            title: "Nourrissage à prévoir",
            reason: "Pas nourri depuis \(rounded) jour\(rounded > 1 ? "s" : "")",
            severity: days >= threshold * 1.5 ? .warning : .info,
            prefilledNote: ""
        )]
    }

    // MARK: Mue probable

    private static func moltSuggestion(
        animalName: String,
        type: AnimalType,
        status: AnimalStatus,
        entries: [ObservationEntry],
        thresholds: Thresholds,
        now: Date
    ) -> [JournalSuggestion] {
        guard type.tracksMolting else { return [] }
        // Déjà signalé comme en prémue / en mue : rien à suggérer.
        guard status != .premolt, status != .molting else { return [] }

        let stats = MoltStats.compute(from: entries)
        guard let average = stats.averageDaysBetweenMolts, average > 0,
              let lastMoltDate = stats.intervals.last?.date else { return [] }
        // Écart calculé depuis le `now` injecté (déterministe, testable) plutôt
        // que via MoltStats.daysSinceLastMolt qui lit Date.now en dur.
        let since = now.timeIntervalSince(lastMoltDate) / 86400
        guard since >= average * thresholds.moltApproachFactor else { return [] }

        let remaining = Int((average - since).rounded())
        let reason = remaining > 0
            ? "Cycle moyen ~\(Int(average.rounded())) j — mue probable d'ici ~\(remaining) j"
            : "Cycle moyen ~\(Int(average.rounded())) j déjà dépassé"
        return [JournalSuggestion(
            kind: .moltApproaching,
            animalName: animalName,
            suggestedEventType: .premoltStart,
            title: "Mue probable approche",
            reason: reason,
            severity: .info,
            prefilledNote: ""
        )]
    }

    // MARK: Environnement hors plage cible

    private static func environmentSuggestions(
        animalName: String,
        terrarium: Terrarium?,
        reading: TerrariumSensorReading?
    ) -> [JournalSuggestion] {
        guard let reading, let terrarium else { return [] }
        var result: [JournalSuggestion] = []

        if let temperature = reading.temperature {
            switch terrarium.temperatureStatus(for: temperature) {
            case .belowRange:
                result.append(JournalSuggestion(
                    kind: .temperatureLow,
                    animalName: animalName,
                    suggestedEventType: .temperatureAdjust,
                    title: "Température basse",
                    reason: "Relevé \(trim(temperature))°C sous la plage cible",
                    severity: .warning,
                    prefilledNote: "Température relevée : \(trim(temperature))°C"
                ))
            case .aboveRange:
                result.append(JournalSuggestion(
                    kind: .temperatureHigh,
                    animalName: animalName,
                    suggestedEventType: .temperatureAdjust,
                    title: "Température élevée",
                    reason: "Relevé \(trim(temperature))°C au-dessus de la plage cible",
                    severity: .warning,
                    prefilledNote: "Température relevée : \(trim(temperature))°C"
                ))
            case .inRange, .noTarget:
                break
            }
        }

        if let humidity = reading.humidity {
            switch terrarium.humidityStatus(for: humidity) {
            case .belowRange:
                result.append(JournalSuggestion(
                    kind: .humidityLow,
                    animalName: animalName,
                    suggestedEventType: .humidifying,
                    title: "Humidité basse",
                    reason: "Relevé \(trim(humidity))% sous la plage cible",
                    severity: .warning,
                    prefilledNote: "Humidité relevée : \(trim(humidity))%"
                ))
            case .aboveRange:
                result.append(JournalSuggestion(
                    kind: .humidityHigh,
                    animalName: animalName,
                    suggestedEventType: .humidityAdjust,
                    title: "Humidité élevée",
                    reason: "Relevé \(trim(humidity))% au-dessus de la plage cible",
                    severity: .warning,
                    prefilledNote: "Humidité relevée : \(trim(humidity))%"
                ))
            case .inRange, .noTarget:
                break
            }
        }

        return result
    }

    private static func trim(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}
