import Foundation
import SwiftData
import UserNotifications

/// Gère les actions déclenchées depuis la bannière de notification (ex: "Terminé"),
/// en dehors de la hiérarchie de vues SwiftUI — utilise directement le ModelContainer partagé.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard response.actionIdentifier == NotificationService.completeActionIdentifier else {
            completionHandler()
            return
        }

        let identifier = response.notification.request.identifier
        Task { @MainActor in
            let context = PersistenceController.shared.container.mainContext
            if let reminders = try? context.fetch(FetchDescriptor<Reminder>()),
               let reminder = reminders.first(where: { $0.notificationIdentifier == identifier }) {
                ReminderService.shared.complete(reminder, context: context)
            }
            completionHandler()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
