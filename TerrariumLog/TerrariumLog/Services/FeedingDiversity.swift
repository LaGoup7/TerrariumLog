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
///    une alternative quand il en existe une ;
/// 4. les proies dont le stock suivi est à zéro sont écartées de la
///    suggestion (et signalées « à commander ») ; un stock bas est signalé
///    sans écarter la proie.
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
    /// Alerte de réassort liée à la suggestion (proie idéale en rupture,
    /// stock bas sur la proie suggérée…), prête à afficher. Nil si rien à
    /// signaler.
    let restockNote: String?

    var suggestionDisplayName: String? {
        suggestionRawValue.map { PreyType(rawValue: $0)?.displayName ?? $0 }
    }
}

enum FeedingDiversity {
    /// Nombre de repas récents pris en compte.
    static let window = 15

    /// `stocks` : l'inventaire suivi (facultatif). Une proie sans entrée de
    /// stock est considérée disponible (l'utilisateur ne suit pas tout).
    static func analyze(animal: Animal, stocks: [PreyStock] = []) -> FeedingDiversityAnalysis {
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
                reason: nil,
                restockNote: nil
            )
        }

        // Stocks suivis, indexés par proie. (uniquingKeysWith par prudence :
        // deux entrées de stock sur le même type ne doivent pas faire planter.)
        let stockByPrey = Dictionary(stocks.map { ($0.typeRawValue, $0) },
                                     uniquingKeysWith: { first, _ in first })
        func isOutOfStock(_ prey: String) -> Bool {
            guard let stock = stockByPrey[prey] else { return false }
            return stock.quantity <= 0
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

        // La rotation idéale (sans les stocks) vs la rotation réelle
        // (proies disponibles uniquement).
        let idealSuggestion = ranked.first
        let available = ranked.filter { !isOutOfStock($0) }

        var suggestion = available.first ?? idealSuggestion
        // Éviter de resservir la même proie après une série, si une
        // alternative disponible existe.
        if let current = suggestion, current == lastPrey, streak >= 2,
           let alternative = available.first(where: { $0 != lastPrey }) {
            suggestion = alternative
        }

        func displayName(_ prey: String) -> String {
            PreyType(rawValue: prey)?.displayName ?? prey
        }

        // Note de réassort : rupture qui a dévié la rotation, rupture totale,
        // ou stock bas sur la proie suggérée.
        var restockNote: String?
        if available.isEmpty {
            restockNote = "Toutes les proies du régime sont en rupture — commande à prévoir."
        } else if let ideal = idealSuggestion, isOutOfStock(ideal) {
            restockNote = "\(displayName(ideal)) en rupture de stock — à commander."
        } else if let suggestion, let stock = stockByPrey[suggestion], stock.isLow {
            restockNote = "Stock de \(displayName(suggestion).lowercased()) bas (\(stock.quantity)) — pense à recommander."
        }

        var reason: String?
        if let suggestion {
            let name = displayName(suggestion)
            if lastGiven[suggestion] == nil {
                reason = recent.isEmpty
                    ? "\(name) pour commencer la rotation"
                    : "\(name) n'a pas été donné sur les \(recent.count) derniers repas"
            } else if let date = lastGiven[suggestion] {
                let days = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
                if let lastPrey, lastPrey != suggestion, streak >= 2 {
                    let lastName = displayName(lastPrey)
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
            reason: reason,
            restockNote: restockNote
        )
    }
}
