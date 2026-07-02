import Foundation
import SwiftData

struct ReminderService {
    static let shared = ReminderService()

    func complete(_ reminder: Reminder, context: ModelContext) {
        NotificationService.shared.cancelReminder(reminder)

        if let nextDate = reminder.nextOccurrence(after: reminder.reminderDate) {
            reminder.reminderDate = nextDate
            reminder.isCompleted = false
            reminder.notificationIdentifier = nil
            NotificationService.shared.scheduleReminder(reminder)
        } else {
            reminder.isCompleted = true
        }

        try? context.save()
    }
}
