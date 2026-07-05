import SwiftUI

/// Référence des fiches espèces : paramètres recommandés et conseils.
/// Les plages peuvent être appliquées à un terrarium depuis son formulaire
/// (Environnement cible → menu « Fiche espèce »).
struct SpeciesSheetsView: View {
    var body: some View {
        List(SpeciesSheet.catalog) { sheet in
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sheet.name)
                        .font(.headline)
                    Text(sheet.scientificName)
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 14) {
                    Label("\(Int(sheet.temperatureMin))–\(Int(sheet.temperatureMax)) °C", systemImage: "thermometer.medium")
                        .foregroundStyle(Brand.warning)
                    Label("\(Int(sheet.humidityMin))–\(Int(sheet.humidityMax)) %", systemImage: "humidity.fill")
                        .foregroundStyle(Brand.accent)
                }
                .font(.caption.weight(.semibold))
                Label(sheet.feeding, systemImage: "fork.knife")
                    .font(.caption)
                    .foregroundStyle(Brand.primary)
                Text(sheet.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Fiches espèces")
    }
}