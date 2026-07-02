import Foundation

struct DiapausePeriod: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date?

    var durationDays: Int? {
        guard let endDate else { return nil }
        return Calendar.current.dateComponents([.day], from: startDate, to: endDate).day
    }
}

struct DiapauseStats {
    let periods: [DiapausePeriod]

    static func compute(from entries: [ObservationEntry]) -> DiapauseStats {
        let starts = entries
            .filter { $0.eventType == ObservationEventType.hibernationStart.rawValue }
            .sorted { $0.date < $1.date }
        let ends = entries
            .filter { $0.eventType == ObservationEventType.hibernationEnd.rawValue }
            .sorted { $0.date < $1.date }

        var periods: [DiapausePeriod] = []
        var endIndex = 0
        for start in starts {
            while endIndex < ends.count && ends[endIndex].date < start.date {
                endIndex += 1
            }
            let matchingEnd = endIndex < ends.count ? ends[endIndex] : nil
            periods.append(DiapausePeriod(startDate: start.date, endDate: matchingEnd?.date))
            if matchingEnd != nil {
                endIndex += 1
            }
        }
        return DiapauseStats(periods: periods)
    }
}
