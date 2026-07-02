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
