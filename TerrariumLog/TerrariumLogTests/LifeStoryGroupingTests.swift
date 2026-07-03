import XCTest
@testable import TerrariumLog

final class LifeStoryGroupingTests: XCTestCase {
    private func makeEntry(daysFromNow: Double, note: String) -> ObservationEntry {
        ObservationEntry(
            date: Date(timeIntervalSinceNow: daysFromNow * 86400),
            eventType: ObservationEventType.other.rawValue,
            note: note
        )
    }

    func testGroupsEntriesByYearMostRecentFirst() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let entryThisYear = ObservationEntry(date: calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!, eventType: ObservationEventType.other.rawValue, note: "this year")
        let entryLastYear = ObservationEntry(date: calendar.date(from: DateComponents(year: 2025, month: 6, day: 1))!, eventType: ObservationEventType.other.rawValue, note: "last year")

        let groups = LifeStoryGrouping.groupedByYear([entryLastYear, entryThisYear], calendar: calendar)

        XCTAssertEqual(groups.map(\.year), [2026, 2025])
        XCTAssertEqual(groups[0].entries.first?.note, "this year")
        XCTAssertEqual(groups[1].entries.first?.note, "last year")
    }

    func testEntriesWithinYearSortedMostRecentFirst() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let early = ObservationEntry(date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!, eventType: ObservationEventType.other.rawValue, note: "early")
        let late = ObservationEntry(date: calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!, eventType: ObservationEventType.other.rawValue, note: "late")

        let groups = LifeStoryGrouping.groupedByYear([early, late], calendar: calendar)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].entries.map(\.note), ["late", "early"])
    }

    func testEmptyEntriesReturnsEmptyGroups() {
        XCTAssertTrue(LifeStoryGrouping.groupedByYear([]).isEmpty)
    }
}
