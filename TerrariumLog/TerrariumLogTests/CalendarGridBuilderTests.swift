import XCTest
@testable import TerrariumLog

final class CalendarGridBuilderTests: XCTestCase {
    private func mondayFirstCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)!
    }

    func testJanuary2024HasNoLeadingBlanks() {
        // January 1, 2024 was a Monday, matching firstWeekday = 2.
        let calendar = mondayFirstCalendar()
        let reference = date(year: 2024, month: 1, day: 15, calendar: calendar)

        let days = CalendarGridBuilder.days(for: reference, calendar: calendar)
        let leadingBlanks = days.prefix(while: { $0 == nil }).count

        XCTAssertEqual(leadingBlanks, 0)
        XCTAssertEqual(days.count, 31)
    }

    func testFebruary2024HasThreeLeadingBlanks() {
        // February 1, 2024 was a Thursday: 3 blanks before it in a Monday-first grid.
        let calendar = mondayFirstCalendar()
        let reference = date(year: 2024, month: 2, day: 10, calendar: calendar)

        let days = CalendarGridBuilder.days(for: reference, calendar: calendar)
        let leadingBlanks = days.prefix(while: { $0 == nil }).count

        XCTAssertEqual(leadingBlanks, 3)
        XCTAssertEqual(days.count, 3 + 29)
    }

    func testOrderedWeekdaySymbolsStartsOnFirstWeekday() {
        let calendar = mondayFirstCalendar()
        let symbols = CalendarGridBuilder.orderedWeekdaySymbols(calendar: calendar)

        XCTAssertEqual(symbols.count, 7)
        XCTAssertEqual(symbols.first, calendar.veryShortStandaloneWeekdaySymbols[1])
    }
}
