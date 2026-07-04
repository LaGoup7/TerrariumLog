import SwiftUI

/// Identité visuelle « Habitat » — un thème sombre premium (inspiration
/// Apple Home / Tesla / Notion). Toutes les couleurs de la charte et les
/// primitives de style (cartes, rayons, espacements) vivent ici pour rester
/// cohérentes sur l'ensemble de l'application.
enum Brand {
    // MARK: Palette de la charte
    /// Fond principal de l'app.
    static let background = Color(hex: 0x0B0D10)
    /// Cartes / sections.
    static let surface = Color(hex: 0x181B20)
    /// Couleur principale (actions, éléments actifs, boutons).
    static let primary = Color(hex: 0x2EC27E)
    /// Accent (caméras, objets connectés, éléments interactifs).
    static let accent = Color(hex: 0x3DD9C5)
    /// Texte principal.
    static let textPrimary = Color(hex: 0xFFFFFF)
    /// Texte secondaire.
    static let textSecondary = Color(hex: 0xA1A7B3)
    /// Alertes / attention.
    static let warning = Color(hex: 0xF59E0B)
    /// Erreur.
    static let error = Color(hex: 0xEF4444)

    // MARK: Dérivés utilitaires
    /// Surface légèrement surélevée pour les éléments imbriqués (pastilles, vignettes).
    static let surfaceElevated = Color(hex: 0x20242B)
    /// Filet très discret pour border les cartes.
    static let hairline = Color.white.opacity(0.06)

    // MARK: Métriques
    /// Rayon standard des cartes (≈20 px).
    static let cardRadius: CGFloat = 20
    /// Espacement vertical entre les grandes sections.
    static let sectionSpacing: CGFloat = 20

    // MARK: Dégradés
    /// Dégradé de marque (titres, accents forts).
    static var gradient: LinearGradient {
        LinearGradient(colors: [accent, primary], startPoint: .leading, endPoint: .trailing)
    }

    /// Dégradé de fond de l'app : sombre, quasi plat, avec une très légère
    /// dérive verte pour donner de la profondeur sans bruit visuel.
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [background, Color(hex: 0x0C1013)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

extension Color {
    /// Initialise une couleur depuis un entier hexadécimal (ex. `0x2EC27E`).
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension View {
    /// Carte standard « Habitat » : surface #181B20, coins arrondis 20 px,
    /// filet discret et ombre douce pour un rendu premium et homogène.
    func brandCard(padding: CGFloat = 16) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(
                Brand.surface,
                in: RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous)
                    .strokeBorder(Brand.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 8)
    }

    /// Alias historique conservé pour les blocs du Dashboard.
    func dashboardCard() -> some View {
        brandCard()
    }
}
