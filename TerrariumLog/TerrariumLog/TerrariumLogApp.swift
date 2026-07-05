import SwiftUI
import SwiftData
import UserNotifications

@main
struct TerrariumLogApp: App {
    let container: ModelContainer

    init() {
        let persistence = PersistenceController.shared
        self.container = persistence.container
        let context = persistence.container.mainContext
        persistence.seedDemoDataIfNeeded(context: context)

        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        NotificationService.shared.registerNotificationCategories()
        ReminderService.shared.refreshWidgetSnapshot(context: context)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .task {
                    await NotificationService.shared.requestAuthorizationIfNeeded()
                    AutoBackupService.shared.runIfNeeded(context: container.mainContext)
                }
        }
    }
}
