import Foundation

enum CalendarGridBuilder {
    /// Returns one entry per grid cell for the month containing `date`: `nil` for the
    /// leading blank cells before day 1, and each day of the month after that.
    static func days(for date: Date, calendar: Calendar = .current) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday,
              let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count
        else {
            return []
        }

        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for dayOffset in 0..<daysInMonth {
            if let day = calendar.date(byAdding: .day, value: dayOffset, to: monthInterval.start) {
                days.append(day)
            }
        }
        return days
    }

    /// Weekday symbols (very short, e.g. "L", "M"...) rotated to start on `calendar.firstWeekday`,
    /// matching the leading-blank offset used by `days(for:calendar:)`.
    static func orderedWeekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let firstWeekdayIndex = calendar.firstWeekday - 1
        guard symbols.indices.contains(firstWeekdayIndex) else { return symbols }
        return Array(symbols[firstWeekdayIndex...]) + Array(symbols[..<firstWeekdayIndex])
    }
}
