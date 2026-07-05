import Foundation

/// Fiche d'élevage d'une espèce, chargée depuis le pack embarqué
/// `SpeciesData/fiches_animaux.txt` (20 champs par fiche, format
/// « - Libellé : valeur », blocs séparés par des lignes vides).
/// Les paramètres sont des plages de travail indicatives, à adapter au stade,
/// à la ventilation réelle et à l'observation de l'animal.
struct SpeciesSheet: Identifiable {
    let scientificName: String
    let commonName: String
    let classification: String
    let origin: String
    let biotope: String
    let adultSize: String
    let lifespan: String
    let temperatureText: String
    let humidityText: String
    let enclosureMin: String
    let substrate: String
    let furnishing: String
    let food: String
    let feedingFrequency: String
    let water: String
    let behavior: String
    let reproduction: String
    let difficulty: String
    let remarks: String
    /// Nom du fichier image dans le bundle (sans dossier), s'il existe.
    let imageName: String?

    var id: String { scientificName }

    /// Compatibilité avec l'UI existante (menu de pré-remplissage).
    var name: String { commonName }

    /// Première plage « min–max » trouvée dans le texte de température.
    var temperatureRange: (min: Double, max: Double)? {
        Self.firstRange(in: temperatureText)
    }

    var humidityRange: (min: Double, max: Double)? {
        Self.firstRange(in: humidityText)
    }

    static func firstRange(in text: String) -> (min: Double, max: Double)? {
        // Tirets demi-cadratin (–) ou simple (-) acceptés.
        let pattern = #"(\d+(?:[.,]\d+)?)\s*[–-]\s*(\d+(?:[.,]\d+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let minRange = Range(match.range(at: 1), in: text),
              let maxRange = Range(match.range(at: 2), in: text),
              let minValue = Double(text[minRange].replacingOccurrences(of: ",", with: ".")),
              let maxValue = Double(text[maxRange].replacingOccurrences(of: ",", with: "."))
        else { return nil }
        return (minValue, maxValue)
    }

    static let catalog: [SpeciesSheet] = loadBundledCatalog()

    static func loadBundledCatalog() -> [SpeciesSheet] {
        guard let url = Bundle.main.url(forResource: "fiches_animaux", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        return parse(content)
    }

    /// Parse le format du pack : lignes « - Libellé : valeur », fiches
    /// séparées par une ou plusieurs lignes vides. Tolérant aux deux
    /// apostrophes (« d'élevage » / « d’élevage ») et aux champs manquants.
    static func parse(_ content: String) -> [SpeciesSheet] {
        let blocks = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return blocks.compactMap { block in
            var fields: [String: String] = [:]
            for line in block.split(separator: "\n") {
                var text = line.trimmingCharacters(in: .whitespaces)
                guard text.hasPrefix("-") else { continue }
                text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
                guard let separator = text.range(of: " : ") ?? text.range(of: " :") else { continue }
                let label = String(text[..<separator.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "’", with: "'")
                let value = String(text[separator.upperBound...]).trimmingCharacters(in: .whitespaces)
                fields[label] = value
            }

            guard let scientific = fields["Nom scientifique"], !scientific.isEmpty else { return nil }

            let rawImage = fields["Image"] ?? ""
            let imageName = rawImage.isEmpty
                ? nil
                : String(rawImage.split(separator: "/").last ?? "")

            return SpeciesSheet(
                scientificName: scientific,
                commonName: fields["Nom commun"] ?? scientific,
                classification: fields["Classification"] ?? "",
                origin: fields["Origine géographique"] ?? "",
                biotope: fields["Biotope naturel"] ?? "",
                adultSize: fields["Taille adulte"] ?? "",
                lifespan: fields["Espérance de vie"] ?? "",
                temperatureText: fields["Température"] ?? "",
                humidityText: fields["Hygrométrie"] ?? "",
                enclosureMin: fields["Terrarium (taille minimale)"] ?? "",
                substrate: fields["Substrat"] ?? "",
                furnishing: fields["Aménagements"] ?? "",
                food: fields["Nourriture"] ?? "",
                feedingFrequency: fields["Fréquence de nourrissage"] ?? "",
                water: fields["Eau"] ?? "",
                behavior: fields["Comportement"] ?? "",
                reproduction: fields["Reproduction"] ?? "",
                difficulty: fields["Difficulté d'élevage"] ?? "",
                remarks: fields["Remarques importantes"] ?? "",
                imageName: imageName
            )
        }
    }
}
