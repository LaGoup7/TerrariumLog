import Foundation

/// Analyse de la diversité alimentaire d'un animal et suggestion de la
/// prochaine proie, pour éviter la monotonie (ex. trois asticots d'affilée).
///
/// La rotation se fait dans le « régime » de l'animal
/// (`Animal.dietPreyRawValues`, paramétrable individuellement) ; à défaut,
/// dans les proies adaptées à son espèce. Règles :
/// 1. une proie du régime jamais donnée récemment passe en premier ;
/// 2. sinon, la proie donnée il y a le plus longtemps ;
/// 3. si la même proie vient d'être servie 2 fois ou plus d'affilée, on force
///    une alternative quand il en existe une.
struct FeedingDiversityAnalysis {
    /// Répartition des derniers repas (rawValue → nombre), ordre décroissant.
    let recentCounts: [(preyRawValue: String, count: Int)]
    let lastPreyRawValue: String?
    /// Nombre de fois où la dernière proie a été servie d'affilée.
    let consecutiveSameCount: Int
    /// Proie suggérée pour le prochain repas (rawValue), si calculable.
    let suggestionRawValue: String?
    /// Explication courte de la suggestion, prête à afficher.
    let reason: String?

    var suggestionDisplayName: String? {
        suggestionRawValue.map { PreyType(rawValue: $0)?.displayName ?? $0 }
    }
}

enum FeedingDiversity {
    /// Nombre de repas récents pris en compte.
    static let window = 15

    static func analyze(animal: Animal) -> FeedingDiversityAnalysis {
        let feedings = animal.journalEntries
            .filter { $0.eventType == ObservationEventType.feeding.rawValue && !($0.preyType ?? "").isEmpty }
            .sorted { $0.date > $1.date }
        let recent = Array(feedings.prefix(window))

        // Répartition.
        var counts: [String: Int] = [:]
        var lastGiven: [String: Date] = [:]
        for feeding in recent {
            guard let prey = feeding.preyType else { continue }
            counts[prey, default: 0] += 1
            if lastGiven[prey] == nil {
                lastGiven[prey] = feeding.date // le plus récent d'abord
            }
        }
        let recentCounts = counts
            .map { (preyRawValue: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        // Série en cours sur la dernière proie.
        let lastPrey = recent.first?.preyType
        var streak = 0
        if let lastPrey {
            for feeding in recent {
                if feeding.preyType == lastPrey { streak += 1 } else { break }
            }
        }

        // Régime de l'animal (ou proies adaptées à l'espèce par défaut).
        var menu = animal.dietPreyRawValues
        if menu.isEmpty {
            menu = PreyType.allCases
                .filter { $0 != .other && $0.isAvailable(for: animal.type) }
                .map(\.rawValue)
        }
        guard !menu.isEmpty else {
            return FeedingDiversityAnalysis(
                recentCounts: recentCounts,
                lastPreyRawValue: lastPrey,
                consecutiveSameCount: streak,
                suggestionRawValue: nil,
                reason: nil
            )
        }

        // Candidats triés : jamais donnés d'abord, puis les plus anciens.
        let ranked = menu.sorted { first, second in
            switch (lastGiven[first], lastGiven[second]) {
            case (nil, nil): return counts[first, default: 0] < counts[second, default: 0]
            case (nil, _): return true
            case (_, nil): return false
            case (let dateA?, let dateB?): return dateA < dateB
            }
        }

        var suggestion = ranked.first
        // Éviter de resservir la même proie après une série, si alternative.
        if let current = suggestion, current == lastPrey, streak >= 2,
           let alternative = ranked.first(where: { $0 != lastPrey }) {
            suggestion = alternative
        }

        var reason: String?
        if let suggestion {
            let name = PreyType(rawValue: suggestion)?.displayName ?? suggestion
            if lastGiven[suggestion] == nil {
                reason = recent.isEmpty
                    ? "\(name) pour commencer la rotation"
                    : "\(name) n'a pas été donné sur les \(recent.count) derniers repas"
            } else if let date = lastGiven[suggestion] {
                let days = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
                if let lastPrey, lastPrey != suggestion, streak >= 2 {
                    let lastName = PreyType(rawValue: lastPrey)?.displayName ?? lastPrey
                    reason = "déjà \(streak)× \(lastName) d'affilée — varie avec \(name)"
                } else {
                    reason = "dernier \(name) il y a \(days) j"
                }
            }
        }

        return FeedingDiversityAnalysis(
            recentCounts: recentCounts,
            lastPreyRawValue: lastPrey,
            consecutiveSameCount: streak,
            suggestionRawValue: suggestion,
            reason: reason
        )
    }
}
