import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \[SortDescriptor(\.name)]) private var animals: [Animal]

    @State private var selectedTab = 0

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

            RemindersView()
                .tabItem {
                    Label("Rappels", systemImage: "bell")
                }
                .tag(2)

            MeasurementsView()
                .tabItem {
                    Label("Mesures", systemImage: "gauge")
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
    }
}
