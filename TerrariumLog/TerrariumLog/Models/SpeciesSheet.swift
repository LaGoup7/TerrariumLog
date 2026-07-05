import Foundation

/// Fiche d'élevage d'une espèce : paramètres d'environnement recommandés et
/// conseils clés. Sert de référence (Réglages → Fiches espèces) et pré-remplit
/// les plages cibles d'un terrarium en un tap.
///
/// Valeurs issues des fourchettes communément admises en élevage amateur —
/// à ajuster selon la localité et les retours de l'animal.
struct SpeciesSheet: Identifiable {
    let name: String
    let scientificName: String
    let temperatureMin: Double
    let temperatureMax: Double
    let humidityMin: Double
    let humidityMax: Double
    /// Fréquence de nourrissage indicative, texte libre.
    let feeding: String
    let notes: String

    var id: String { scientificName }

    static let catalog: [SpeciesSheet] = [
        SpeciesSheet(
            name: "Araignée sauteuse royale",
            scientificName: "Phidippus regius",
            temperatureMin: 24, temperatureMax: 28,
            humidityMin: 55, humidityMax: 70,
            feeding: "Tous les 2-4 j (juvénile), 4-7 j (adulte)",
            notes: "Diurne, a besoin de lumière (12 h/j) et de hauteur pour ses toiles de repos. Suspendre le nourrissage en pré-mue. Brumiser légèrement un coin le soir."
        ),
        SpeciesSheet(
            name: "Araignée sauteuse audacieuse",
            scientificName: "Phidippus audax",
            temperatureMin: 21, temperatureMax: 26,
            humidityMin: 50, humidityMax: 65,
            feeding: "Tous les 3-5 j",
            notes: "Plus tolérante au frais que P. regius. Mêmes besoins de lumière et de hauteur."
        ),
        SpeciesSheet(
            name: "Fourmi noire des jardins",
            scientificName: "Lasius niger",
            temperatureMin: 21, temperatureMax: 26,
            humidityMin: 50, humidityMax: 65,
            feeding: "Eau miellée 2-3×/sem., protéines 1-2×/sem.",
            notes: "Diapause obligatoire de novembre à mars (8-12 °C, cave ou frigo ventilé). Croissance rapide dès la 2e année."
        ),
        SpeciesSheet(
            name: "Fourmi jaune",
            scientificName: "Lasius flavus",
            temperatureMin: 18, temperatureMax: 24,
            humidityMin: 60, humidityMax: 75,
            feeding: "Eau miellée 2×/sem., petites proies molles",
            notes: "Espèce souterraine discrète : nid sombre et humide indispensable. Diapause obligatoire de novembre à mars. Fondation lente, patience !"
        ),
        SpeciesSheet(
            name: "Fourmi moissonneuse",
            scientificName: "Messor barbarus",
            temperatureMin: 21, temperatureMax: 28,
            humidityMin: 30, humidityMax: 50,
            feeding: "Graines à volonté, insecte occasionnel",
            notes: "Fait son pain de graines : aire de fourragement sèche, nid légèrement humide. Diapause douce (12-15 °C) de décembre à février."
        ),
        SpeciesSheet(
            name: "Gecko léopard",
            scientificName: "Eublepharis macularius",
            temperatureMin: 24, temperatureMax: 32,
            humidityMin: 30, humidityMax: 45,
            feeding: "Tous les 2 j (juvénile), 2-3×/sem. (adulte)",
            notes: "Point chaud à 31-32 °C, zone fraîche à 24 °C. Boîte humide indispensable pour la mue. Supplémentation calcium/D3."
        ),
        SpeciesSheet(
            name: "Dendrobate",
            scientificName: "Dendrobates tinctorius",
            temperatureMin: 22, temperatureMax: 26,
            humidityMin: 80, humidityMax: 100,
            feeding: "Drosophiles poudrées, tous les 1-2 j",
            notes: "Hygrométrie très élevée obligatoire (brumisation quotidienne, drainage). Jamais au-dessus de 28 °C."
        )
    ]
}
