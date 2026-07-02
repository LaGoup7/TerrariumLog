import Foundation

struct FeedingStats {
    let lastFeedingDate: Date?
    let averageIntervalDays: Double?
    let refusalCount: Int

    static func compute(from entries: [ObservationEntry]) -> FeedingStats {
        let feedings = entries
            .filter { $0.eventType == ObservationEventType.feeding.rawValue }
            .sorted { $0.date < $1.date }

        let lastFeedingDate = feedings.last?.date

        var averageIntervalDays: Double?
        if feedings.count >= 2 {
            let intervals = zip(feedings, feedings.dropFirst()).map { $1.date.timeIntervalSince($0.date) }
            let averageSeconds = intervals.reduce(0, +) / Double(intervals.count)
            averageIntervalDays = averageSeconds / 86400
        }

        let refusalCount = feedings.filter { $0.eatenStatus == EatenStatus.no.rawValue }.count

        return FeedingStats(lastFeedingDate: lastFeedingDate, averageIntervalDays: averageIntervalDays, refusalCount: refusalCount)
    }
}
