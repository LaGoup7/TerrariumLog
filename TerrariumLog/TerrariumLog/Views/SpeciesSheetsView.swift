import SwiftUI
import UIKit

/// Bibliothèque des fiches espèces du pack embarqué : liste illustrée, fiche
/// détaillée complète. Les plages peuvent être appliquées à un terrarium
/// depuis son formulaire (Environnement cible → « Pré-remplir »).
struct SpeciesSheetsView: View {
    @State private var searchText = ""

    private var filteredSheets: [SpeciesSheet] {
        guard !searchText.isEmpty else { return SpeciesSheet.catalog }
        return SpeciesSheet.catalog.filter {
            $0.commonName.localizedCaseInsensitiveContains(searchText) ||
            $0.scientificName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(filteredSheets) { sheet in
            NavigationLink {
                SpeciesSheetDetailView(sheet: sheet)
            } label: {
                HStack(spacing: 12) {
                    SpeciesImageView(imageName: sheet.imageName, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sheet.commonName)
                            .font(.headline)
                        Text(sheet.scientificName)
                            .font(.caption)
                            .italic()
                            .foregroundStyle(.secondary)
                        if let temperature = sheet.temperatureRange, let humidity = sheet.humidityRange {
                            Text("\(Int(temperature.min))–\(Int(temperature.max)) °C · \(Int(humidity.min))–\(Int(humidity.max)) %")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Brand.accent)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .searchable(text: $searchText, prompt: "Rechercher une espèce")
        .navigationTitle("Fiches espèces (\(SpeciesSheet.catalog.count))")
    }
}

/// Illustration d'une espèce (image du pack, chargée depuis le bundle).
struct SpeciesImageView: View {
    let imageName: String?
    var size: CGFloat = 56

    private var image: UIImage? {
        guard let imageName,
              let path = Bundle.main.path(forResource: imageName, ofType: nil) else { return nil }
        return UIImage(contentsOfFile: path)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "book.closed")
                    .font(.title3)
                    .foregroundStyle(Brand.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Brand.surfaceElevated)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Fiche complète d'une espèce : tous les champs du pack, organisés par thème.
struct SpeciesSheetDetailView: View {
    let sheet: SpeciesSheet

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                card("Environnement", icon: "thermometer.medium") {
                    row("Température", sheet.temperatureText)
                    row("Hygrométrie", sheet.humidityText)
                    row("Eau", sheet.water)
                }
                card("Habitat", icon: "leaf.fill") {
                    row("Terrarium minimal", sheet.enclosureMin)
                    row("Substrat", sheet.substrate)
                    row("Aménagements", sheet.furnishing)
                    row("Biotope naturel", sheet.biotope)
                }
                card("Alimentation", icon: "fork.knife") {
                    row("Nourriture", sheet.food)
                    row("Fréquence", sheet.feedingFrequency)
                }
                card("Vie de l'animal", icon: "pawprint.fill") {
                    row("Taille adulte", sheet.adultSize)
                    row("Espérance de vie", sheet.lifespan)
                    row("Comportement", sheet.behavior)
                    row("Reproduction", sheet.reproduction)
                }
                if !sheet.remarks.isEmpty {
                    card("À retenir", icon: "exclamationmark.triangle.fill") {
                        Text(sheet.remarks)
                            .font(.footnote)
                    }
                }
                Text("Plages indicatives : adapte toujours au stade, à la ventilation réelle et au comportement observé.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Brand.backgroundGradient.ignoresSafeArea())
        .navigationTitle(sheet.commonName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            if sheet.imageName != nil {
                SpeciesImageView(imageName: sheet.imageName, size: 140)
                    .frame(maxWidth: .infinity)
            }
            Text(sheet.commonName)
                .font(.title2.bold())
            Text(sheet.scientificName)
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)
            if !sheet.classification.isEmpty {
                Text(sheet.classification)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !sheet.origin.isEmpty {
                Label(sheet.origin, systemImage: "globe.europe.africa")
                    .font(.caption)
                    .foregroundStyle(Brand.accent)
            }
            if !sheet.difficulty.isEmpty {
                Text(sheet.difficulty)
                    .font(.caption.bold())
                    .foregroundStyle(Brand.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Brand.primary.opacity(0.16))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(Brand.primary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        if !value.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.footnote)
            }
        }
    }
}
