import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    static let reminderCategoryIdentifier = "REMINDER_CATEGORY"
    static let completeActionIdentifier = "COMPLETE_REMINDER_ACTION"

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                print("Notifications authorized")
            }
        } catch {
            print("Failed to request notifications authorization: \(error)")
        }
    }

    /// Enregistre l'action "Terminé" directement disponible depuis la bannière de notification,
    /// sans avoir à ouvrir l'app. À appeler une fois au lancement.
    func registerNotificationCategories() {
        let completeAction = UNNotificationAction(
            identifier: Self.completeActionIdentifier,
            title: "Terminé",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.reminderCategoryIdentifier,
            actions: [completeAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func scheduleReminder(_ reminder: Reminder) {
        let identifier = reminder.notificationIdentifier ?? UUID().uuidString
        reminder.notificationIdentifier = identifier

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.animal?.name ?? "Rappel Terrarium"
        content.sound = .default
        content.categoryIdentifier = Self.reminderCategoryIdentifier

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    func cancelReminder(_ reminder: Reminder) {
        guard let identifier = reminder.notificationIdentifier else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
