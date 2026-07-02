import XCTest
@testable import TerrariumLog

final class FeedingStatsTests: XCTestCase {
    func testComputeWithNoEntriesReturnsEmptyStats() {
        let stats = FeedingStats.compute(from: [])
        XCTAssertNil(stats.lastFeedingDate)
        XCTAssertNil(stats.averageIntervalDays)
        XCTAssertEqual(stats.refusalCount, 0)
    }

    func testComputeAveragesIntervalsAndCountsRefusals() {
        let day: TimeInterval = 86400
        let base = Date(timeIntervalSince1970: 0)
        let entries = [
            ObservationEntry(date: base, eventType: ObservationEventType.feeding.rawValue, note: "", eatenStatus: EatenStatus.yes.rawValue),
            ObservationEntry(date: base.addingTimeInterval(4 * day), eventType: ObservationEventType.feeding.rawValue, note: "", eatenStatus: EatenStatus.no.rawValue),
            ObservationEntry(date: base.addingTimeInterval(8 * day), eventType: ObservationEventType.feeding.rawValue, note: "", eatenStatus: EatenStatus.yes.rawValue)
        ]

        let stats = FeedingStats.compute(from: entries)

        XCTAssertEqual(stats.lastFeedingDate, base.addingTimeInterval(8 * day))
        XCTAssertEqual(stats.averageIntervalDays ?? 0, 4, accuracy: 0.01)
        XCTAssertEqual(stats.refusalCount, 1)
    }

    func testComputeIgnoresNonFeedingEntries() {
        let entries = [
            ObservationEntry(date: .now, eventType: ObservationEventType.molt.rawValue, note: "")
        ]
        let stats = FeedingStats.compute(from: entries)
        XCTAssertNil(stats.lastFeedingDate)
    }
}
