import Foundation
import SwiftData
import WidgetKit

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
        refreshWidgetSnapshot(context: context)
    }

    /// Recalcule et publie l'instantané des prochains rappels pour le widget. À appeler après
    /// toute création/suppression/complétion de rappel (le widget ne lit jamais SwiftData
    /// directement, voir WidgetSnapshot.swift).
    func refreshWidgetSnapshot(context: ModelContext) {
        let descriptor = FetchDescriptor<Reminder>(sortBy: [SortDescriptor(\.reminderDate)])
        let reminders = (try? context.fetch(descriptor)) ?? []
        let upcoming = reminders
            .filter { !$0.isCompleted }
            .prefix(5)
            .map { WidgetReminderSnapshot(title: $0.title, animalName: $0.animal?.name, date: $0.reminderDate) }

        WidgetSnapshotStore.save(WidgetSnapshotData(reminders: Array(upcoming), generatedAt: .now))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
