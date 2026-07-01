import SwiftUI
import SwiftData

@main
struct TerrariumLogApp: App {
    let container: ModelContainer

    init() {
        let persistence = PersistenceController.shared
        self.container = persistence.container
        let context = persistence.container.mainContext
        persistence.seedDemoDataIfNeeded(context: context)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .task {
                    await NotificationService.shared.requestAuthorizationIfNeeded()
                }
        }
    }
}
