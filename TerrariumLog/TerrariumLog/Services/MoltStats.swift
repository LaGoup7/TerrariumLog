import Foundation

struct MoltInterval: Identifiable {
    let id = UUID()
    let fromStage: String
    let toStage: String
    let date: Date
    let daysSincePrevious: Double?
}

struct MoltStats {
    let intervals: [MoltInterval]

    var averageDaysBetweenMolts: Double? {
        let known = intervals.compactMap(\.daysSincePrevious)
        guard !known.isEmpty else { return nil }
        return known.reduce(0, +) / Double(known.count)
    }

    /// Jours écoulés depuis la dernière mue, s'il y en a eu une.
    var daysSinceLastMolt: Double? {
        guard let last = intervals.last?.date else { return nil }
        return Date.now.timeIntervalSince(last) / 86400
    }

    static func compute(from entries: [ObservationEntry]) -> MoltStats {
        let molts = entries
            .filter { $0.eventType == ObservationEventType.molt.rawValue }
            .sorted { $0.date < $1.date }

        var intervals: [MoltInterval] = []
        var previousDate: Date?
        for molt in molts {
            let daysSincePrevious = previousDate.map { molt.date.timeIntervalSince($0) / 86400 }
            intervals.append(
                MoltInterval(
                    fromStage: molt.previousStage ?? "—",
                    toStage: molt.newStage ?? "—",
                    date: molt.date,
                    daysSincePrevious: daysSincePrevious
                )
            )
            previousDate = molt.date
        }

        return MoltStats(intervals: intervals)
    }
}

extension Animal {
    /// Pré-mue probable : il faut au moins deux mues au journal pour estimer le
    /// cycle ; on considère l'animal en pré-mue quand 80 % du cycle moyen s'est
    /// écoulé depuis la dernière mue. Conseil associé : suspendre le
    /// nourrissage (une proie vivante peut blesser un animal en mue).
    var isLikelyPreMolt: Bool {
        let stats = MoltStats.compute(from: journalEntries)
        guard let average = stats.averageDaysBetweenMolts,
              average > 0,
              let daysSince = stats.daysSinceLastMolt else { return false }
        return daysSince >= 0.8 * average
    }
}
