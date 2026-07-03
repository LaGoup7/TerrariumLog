import Foundation

struct LifeStoryYearGroup: Identifiable {
    var id: Int { year }
    let year: Int
    let entries: [ObservationEntry]
}

enum LifeStoryGrouping {
    /// Groups entries by calendar year, most recent year first, entries within a year
    /// sorted most recent first.
    static func groupedByYear(_ entries: [ObservationEntry], calendar: Calendar = .current) -> [LifeStoryYearGroup] {
        let grouped = Dictionary(grouping: entries) { calendar.component(.year, from: $0.date) }
        return grouped
            .map { year, entries in
                LifeStoryYearGroup(year: year, entries: entries.sorted { $0.date > $1.date })
            }
            .sorted { $0.year > $1.year }
    }
}
