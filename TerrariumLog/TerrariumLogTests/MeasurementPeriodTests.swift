import XCTest
@testable import TerrariumLog

final class MeasurementPeriodTests: XCTestCase {
    func testDayCutoffIsOneDayBeforeReference() {
        let reference = Date(timeIntervalSince1970: 1_000_000)
        let cutoff = MeasurementPeriod.day.cutoffDate(reference: reference)
        XCTAssertEqual(cutoff, reference.addingTimeInterval(-24 * 3600))
    }

    func testWeekCutoffIsSevenDaysBeforeReference() {
        let reference = Date(timeIntervalSince1970: 1_000_000)
        let cutoff = MeasurementPeriod.week.cutoffDate(reference: reference)
        XCTAssertEqual(cutoff, reference.addingTimeInterval(-7 * 24 * 3600))
    }

    func testMonthCutoffIsBeforeWeekCutoff() {
        let reference = Date.now
        let monthCutoff = MeasurementPeriod.month.cutoffDate(reference: reference)
        let weekCutoff = MeasurementPeriod.week.cutoffDate(reference: reference)
        XCTAssertLessThan(monthCutoff, weekCutoff)
    }
}
