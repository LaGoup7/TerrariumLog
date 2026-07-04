import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Animal>(\.name)]) private var animals: [Animal]

    @State private var selectedTab = 0

    init() {
        Self.configureBarAppearance()
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
        .tint(Brand.primary)
        .background(Brand.background.ignoresSafeArea())
        // Identité « Habitat » : thème sombre premium verrouillé (voir Theme.swift).
        .preferredColorScheme(.dark)
    }

    /// Aligne les barres système (onglets + navigation) sur l'identité sombre :
    /// fond sombre translucide, teinte de sélection verte.
    private static func configureBarAppearance() {
        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = UIColor(Brand.background)

        let selected = UIColor(Brand.primary)
        let normal = UIColor(Brand.textSecondary)
        for item in [tabBar.stackedLayoutAppearance, tabBar.inlineLayoutAppearance, tabBar.compactInlineLayoutAppearance] {
            item.selected.iconColor = selected
            item.selected.titleTextAttributes = [.foregroundColor: selected]
            item.normal.iconColor = normal
            item.normal.titleTextAttributes = [.foregroundColor: normal]
        }
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar

        let navBar = UINavigationBarAppearance()
        navBar.configureWithTransparentBackground()
        navBar.backgroundColor = UIColor(Brand.background.opacity(0.6))
        navBar.titleTextAttributes = [.foregroundColor: UIColor(Brand.textPrimary)]
        navBar.largeTitleTextAttributes = [.foregroundColor: UIColor(Brand.textPrimary)]
        UINavigationBar.appearance().standardAppearance = navBar
        UINavigationBar.appearance().scrollEdgeAppearance = navBar
        UINavigationBar.appearance().compactAppearance = navBar
    }
}
