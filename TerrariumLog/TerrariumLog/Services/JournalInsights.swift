import Foundation

/// Synthèses transversales calculées à partir du journal d'un animal :
/// évolution du poids, plus long jeûne, fréquence de maintenance et compteurs.
/// Service **pur** (aucune dépendance SwiftUI), testable comme `FeedingStats`.
struct JournalInsights {
    struct WeightPoint: Identifiable {
        let id = UUID()
        let date: Date
        let grams: Double
    }

    let weightSeries: [WeightPoint]
    /// Plus long intervalle sans nourrissage (jours), jeûne en cours inclus.
    let longestFastingDays: Double?
    let feedingCount: Int
    let refusalCount: Int
    let moltCount: Int
    let maintenanceCount: Int
    /// Fréquence de maintenance (opérations par mois) sur la période observée.
    let maintenancePerMonth: Double?
    let averageFeedingIntervalDays: Double?
    let averageMoltIntervalDays: Double?

    static func compute(from entries: [ObservationEntry], now: Date = .now) -> JournalInsights {
        let events = entries.filter { !$0.isPhotoOnly }

        // Poids
        let weightSeries = events
            .compactMap { entry -> WeightPoint? in
                guard let grams = entry.weightGrams else { return nil }
                return WeightPoint(date: entry.date, grams: grams)
            }
            .sorted { $0.date < $1.date }

        // Nourrissage
        let feedings = events
            .filter { $0.eventType == ObservationEventType.feeding.rawValue }
            .sorted { $0.date < $1.date }
        let feedingDates = feedings.map(\.date)

        var longestFasting: Double?
        if let first = feedingDates.first {
            var maxGap: Double = 0
            var previous = first
            for date in feedingDates.dropFirst() {
                maxGap = max(maxGap, date.timeIntervalSince(previous) / 86400)
                previous = date
            }
            // Jeûne en cours (dernier repas → maintenant).
            if let last = feedingDates.last {
                maxGap = max(maxGap, now.timeIntervalSince(last) / 86400)
            }
            longestFasting = maxGap > 0 ? maxGap : nil
        }

        let feedingStats = FeedingStats.compute(from: events)
        let moltStats = MoltStats.compute(from: events)

        // Maintenance
        let maintenanceEvents = events.filter { $0.category == .maintenance }
        var maintenancePerMonth: Double?
        if maintenanceEvents.count >= 2 {
            let sorted = maintenanceEvents.map(\.date).sorted()
            if let first = sorted.first, let last = sorted.last {
                let months = max(last.timeIntervalSince(first) / (86400 * 30), 0.0001)
                maintenancePerMonth = Double(maintenanceEvents.count) / months
            }
        }

        return JournalInsights(
            weightSeries: weightSeries,
            longestFastingDays: longestFasting,
            feedingCount: feedings.count,
            refusalCount: feedingStats.refusalCount,
            moltCount: moltStats.intervals.count,
            maintenanceCount: maintenanceEvents.count,
            maintenancePerMonth: maintenancePerMonth,
            averageFeedingIntervalDays: feedingStats.averageIntervalDays,
            averageMoltIntervalDays: moltStats.averageDaysBetweenMolts
        )
    }
}
