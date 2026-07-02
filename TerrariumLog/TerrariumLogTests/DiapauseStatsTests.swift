import XCTest
@testable import TerrariumLog

final class DiapauseStatsTests: XCTestCase {
    func testComputeWithNoEntriesReturnsEmptyPeriods() {
        let stats = DiapauseStats.compute(from: [])
        XCTAssertTrue(stats.periods.isEmpty)
    }

    func testCompletedPeriodHasDuration() {
        let day: TimeInterval = 86400
        let start = Date(timeIntervalSince1970: 0)
        let entries = [
            ObservationEntry(date: start, eventType: ObservationEventType.hibernationStart.rawValue, note: ""),
            ObservationEntry(date: start.addingTimeInterval(90 * day), eventType: ObservationEventType.hibernationEnd.rawValue, note: "")
        ]

        let stats = DiapauseStats.compute(from: entries)

        XCTAssertEqual(stats.periods.count, 1)
        XCTAssertEqual(stats.periods.first?.durationDays, 90)
    }

    func testOngoingPeriodHasNoEndOrDuration() {
        let entries = [
            ObservationEntry(date: .now, eventType: ObservationEventType.hibernationStart.rawValue, note: "")
        ]

        let stats = DiapauseStats.compute(from: entries)

        XCTAssertEqual(stats.periods.count, 1)
        XCTAssertNil(stats.periods.first?.endDate)
        XCTAssertNil(stats.periods.first?.durationDays)
    }

    func testMultiplePeriodsArePairedInOrder() {
        let day: TimeInterval = 86400
        let base = Date(timeIntervalSince1970: 0)
        let entries = [
            ObservationEntry(date: base, eventType: ObservationEventType.hibernationStart.rawValue, note: ""),
            ObservationEntry(date: base.addingTimeInterval(10 * day), eventType: ObservationEventType.hibernationEnd.rawValue, note: ""),
            ObservationEntry(date: base.addingTimeInterval(100 * day), eventType: ObservationEventType.hibernationStart.rawValue, note: ""),
            ObservationEntry(date: base.addingTimeInterval(130 * day), eventType: ObservationEventType.hibernationEnd.rawValue, note: "")
        ]

        let stats = DiapauseStats.compute(from: entries)

        XCTAssertEqual(stats.periods.count, 2)
        XCTAssertEqual(stats.periods[0].durationDays, 10)
        XCTAssertEqual(stats.periods[1].durationDays, 30)
    }
}
