import XCTest
@testable import TerrariumLog

final class MoltStatsTests: XCTestCase {
    func testComputeWithNoMoltsReturnsEmptyIntervals() {
        let stats = MoltStats.compute(from: [])
        XCTAssertTrue(stats.intervals.isEmpty)
        XCTAssertNil(stats.averageDaysBetweenMolts)
    }

    func testComputeBuildsIntervalsBetweenSuccessiveMolts() {
        let day: TimeInterval = 86400
        let base = Date(timeIntervalSince1970: 0)
        let entries = [
            ObservationEntry(date: base, eventType: ObservationEventType.molt.rawValue, note: "", previousStage: "L4", newStage: "L5"),
            ObservationEntry(date: base.addingTimeInterval(10 * day), eventType: ObservationEventType.molt.rawValue, note: "", previousStage: "L5", newStage: "L6")
        ]

        let stats = MoltStats.compute(from: entries)

        XCTAssertEqual(stats.intervals.count, 2)
        XCTAssertNil(stats.intervals[0].daysSincePrevious)
        XCTAssertEqual(stats.intervals[1].daysSincePrevious ?? 0, 10, accuracy: 0.01)
        XCTAssertEqual(stats.averageDaysBetweenMolts ?? 0, 10, accuracy: 0.01)
    }
}
