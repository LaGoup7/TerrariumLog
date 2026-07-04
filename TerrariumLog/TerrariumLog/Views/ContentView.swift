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
        // Identité « Habitat » : thèmes clair et sombre partageant le même langage
        // graphique (voir Theme.swift). L'utilisateur choisit dans les Réglages.
        .preferredColorScheme(appearance.colorScheme)
    }

    /// Aligne les barres système (onglets + navigation) sur l'identité « Habitat ».
    /// On utilise directement les `UIColor` dynamiques : elles se résolvent en
    /// clair ou sombre selon l'apparence, sans configuration conditionnelle.
    private static func configureBarAppearance() {
        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = Brand.backgroundUI

        let selected = Brand.primaryUI
        let normal = Brand.textSecondaryUI
        for item in [tabBar.stackedLayoutAppearance, tabBar.inlineLayoutAppearance, tabBar.compactInlineLayoutAppearance] {
            item.selected.iconColor = selected
            item.selected.titleTextAttributes = [.foregroundColor: selected]
            item.normal.iconColor = normal
            item.normal.titleTextAttributes = [.foregroundColor: normal]
        }
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar

        let navBar = UINavigationBarAppearance()
        // Fond système translucide (« chrome material ») : s'adapte seul au thème
        // clair/sombre pour un rendu premium type Apple.
        navBar.configureWithDefaultBackground()
        navBar.titleTextAttributes = [.foregroundColor: Brand.textPrimaryUI]
        navBar.largeTitleTextAttributes = [.foregroundColor: Brand.textPrimaryUI]
        UINavigationBar.appearance().standardAppearance = navBar
        UINavigationBar.appearance().scrollEdgeAppearance = navBar
        UINavigationBar.appearance().compactAppearance = navBar
    }
}
