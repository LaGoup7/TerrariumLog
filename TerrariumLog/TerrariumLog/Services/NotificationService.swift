import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

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

    func scheduleReminder(_ reminder: Reminder) {
        let identifier = reminder.notificationIdentifier ?? UUID().uuidString
        reminder.notificationIdentifier = identifier

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.animal?.name ?? "Rappel Terrarium"
        content.sound = .default

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
