import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Animal>(\.name)]) private var animals: [Animal]
    @AppStorage("appAppearance") private var appearanceRawValue = AppAppearance.system.rawValue

    @State private var selectedTab = 0

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house")
                }
                .tag(0)

            AnimalsListView()
                .tabItem {
                    Label("Animaux", systemImage: "pawprint")
                }
                .tag(1)

            TerrariumsListView()
                .tabItem {
                    Label("Terrariums", systemImage: "leaf")
                }
                .tag(2)

            TimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "clock.arrow.circlepath")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Réglages", systemImage: "gearshape")
                }
                .tag(4)
        }
        .tint(.teal)
        .background(Color(.systemBackground))
        .preferredColorScheme(appearance.colorScheme)
    }
}
