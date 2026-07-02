import XCTest
@testable import TerrariumLog

final class ReminderTests: XCTestCase {
    func testNoneRecurrenceHasNoNextOccurrence() {
        let reminder = Reminder(title: "Test", reminderDate: .now, recurrence: .none, category: .other)
        XCTAssertNil(reminder.nextOccurrence(after: .now))
    }

    func testDailyRecurrenceAddsOneDay() throws {
        let start = Date(timeIntervalSince1970: 0)
        let reminder = Reminder(title: "Test", reminderDate: start, recurrence: .daily, category: .feeding)
        let next = try XCTUnwrap(reminder.nextOccurrence(after: start))
        XCTAssertEqual(next.timeIntervalSince(start), 86400, accuracy: 1)
    }

    func testWeeklyRecurrenceAddsSevenDays() throws {
        let start = Date(timeIntervalSince1970: 0)
        let reminder = Reminder(title: "Test", reminderDate: start, recurrence: .weekly, category: .feeding)
        let next = try XCTUnwrap(reminder.nextOccurrence(after: start))
        XCTAssertEqual(next.timeIntervalSince(start), 7 * 86400, accuracy: 1)
    }

    func testBiweeklyRecurrenceAddsFourteenDays() throws {
        let start = Date(timeIntervalSince1970: 0)
        let reminder = Reminder(title: "Test", reminderDate: start, recurrence: .biweekly, category: .feeding)
        let next = try XCTUnwrap(reminder.nextOccurrence(after: start))
        XCTAssertEqual(next.timeIntervalSince(start), 14 * 86400, accuracy: 1)
    }
}
