import XCTest
@testable import TerrariumLog

final class ReminderTests: XCTestCase {
    func testNoneRecurrenceHasNoNextOccurrence() {
        let reminder = Reminder(title: "Test", reminderDate: .now, recurrence: .none, category: .other)
        XCTAssertNil(reminder.nextOccurrence(after: .now))
    }

    func testDailyRecurrenceAddsOneDay() {
        let start = Date(timeIntervalSince1970: 0)
        let reminder = Reminder(title: "Test", reminderDate: start, recurrence: .daily, category: .feeding)
        let next = reminder.nextOccurrence(after: start)
        XCTAssertEqual(next?.timeIntervalSince(start), 86400, accuracy: 1)
    }

    func testWeeklyRecurrenceAddsSevenDays() {
        let start = Date(timeIntervalSince1970: 0)
        let reminder = Reminder(title: "Test", reminderDate: start, recurrence: .weekly, category: .feeding)
        let next = reminder.nextOccurrence(after: start)
        XCTAssertEqual(next?.timeIntervalSince(start), 7 * 86400, accuracy: 1)
    }

    func testBiweeklyRecurrenceAddsFourteenDays() {
        let start = Date(timeIntervalSince1970: 0)
        let reminder = Reminder(title: "Test", reminderDate: start, recurrence: .biweekly, category: .feeding)
        let next = reminder.nextOccurrence(after: start)
        XCTAssertEqual(next?.timeIntervalSince(start), 14 * 86400, accuracy: 1)
    }
}
