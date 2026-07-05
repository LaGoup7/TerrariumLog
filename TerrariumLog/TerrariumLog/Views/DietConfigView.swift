import SwiftUI
import SwiftData

/// Régime alimentaire d'UN animal : coche les proies à mettre en rotation.
/// Sélection vide = toutes les proies adaptées à l'espèce. Les suggestions de
/// diversité (fiche, formulaire de repas, rappels) tournent dans cette liste.
struct DietConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<CustomPreyType>(\.name)]) private var customPreyTypes: [CustomPreyType]
    let animal: Animal

    private var standardPrey: [PreyType] {
        PreyType.allCases.filter { $0 != .other && $0.isAvailable(for: animal.type) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(standardPrey, id: \.self) { prey in
                        dietToggle(rawValue: prey.rawValue, label: prey.displayName)
                    }
                    ForEach(customPreyTypes) { custom in
                        dietToggle(rawValue: custom.name, label: custom.name)
                    }
                } header: {
                    Text("Proies au menu de \(animal.name)")
                } footer: {
                    Text(animal.dietPreyRawValues.isEmpty
                         ? "Aucune sélection = toutes les proies adaptées à l'espèce sont proposées en rotation."
                         : "Les suggestions de diversité tournent dans cette sélection.")
                }
            }
            .navigationTitle("Régime alimentaire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func dietToggle(rawValue: String, label: String) -> some View {
        Toggle(isOn: Binding(
            get: { animal.dietPreyRawValues.contains(rawValue) },
            set: { isOn in
                if isOn {
                    if !animal.dietPreyRawValues.contains(rawValue) {
                        animal.dietPreyRawValues.append(rawValue)
                    }
                } else {
                    animal.dietPreyRawValues.removeAll { $0 == rawValue }
                }
                try? context.save()
            }
        )) {
            Text(label)
        }
        .tint(Brand.primary)
    }
}
