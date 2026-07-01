import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Apparence") {
                    Toggle("Mode sombre", isOn: $isDarkMode)
                }
                Section("Architecture") {
                    Text("SwiftUI + SwiftData + Notifications locales")
                    Text("Prêt pour ajouter des capteurs et une API plus tard")
                }
            }
            .navigationTitle("Réglages")
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}
