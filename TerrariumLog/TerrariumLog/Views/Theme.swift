import SwiftUI
import UIKit

/// Identité visuelle « Habitat ». Un seul langage graphique, deux ambiances :
/// un thème sombre premium et un thème clair inspiré d'Apple (Home / Health).
///
/// Chaque jeton est une couleur **dynamique** (valeur claire + valeur sombre) :
/// les vues n'utilisent que `Brand.xxx` et basculent automatiquement selon
/// l'apparence, sans code conditionnel. La source de vérité est une `UIColor`
/// dynamique (pour piloter aussi les barres système), déclinée en `Color`.
enum Brand {
    // MARK: Sources dynamiques (UIColor) — clair / sombre
    static let backgroundUI = dynamic(light: 0xF5F7F9, dark: 0x0B0D10)
    static let surfaceUI = dynamic(light: 0xFFFFFF, dark: 0x181B20)
    static let surfaceElevatedUI = dynamic(light: 0xEFF2F5, dark: 0x20242B)
    static let primaryUI = dynamic(light: 0x2EC27E, dark: 0x2EC27E)
    static let accentUI = dynamic(light: 0x3DD9C5, dark: 0x3DD9C5)
    static let textPrimaryUI = dynamic(light: 0x1A1D21, dark: 0xFFFFFF)
    static let textSecondaryUI = dynamic(light: 0x6B7280, dark: 0xA1A7B3)
    static let successUI = dynamic(light: 0x22C55E, dark: 0x22C55E)
    static let warningUI = dynamic(light: 0xF59E0B, dark: 0xF59E0B)
    static let errorUI = dynamic(light: 0xEF4444, dark: 0xEF4444)
    /// Filet des cartes : bordure nette et claire en mode clair, filet blanc très
    /// discret en mode sombre.
    static let hairlineUI = dynamic(light: 0xE5E7EB, lightAlpha: 1, dark: 0xFFFFFF, darkAlpha: 0.06)
    /// Ombre des cartes : très douce en clair (effet « flottant »), plus marquée en sombre.
    static let cardShadowUI = dynamic(light: 0x000000, lightAlpha: 0.06, dark: 0x000000, darkAlpha: 0.35)
    /// Bas du dégradé de fond (profondeur subtile).
    static let backgroundEndUI = dynamic(light: 0xF5F7F9, dark: 0x0C1013)

    // MARK: Jetons SwiftUI (à utiliser dans les vues)
    /// Fond principal de l'app.
    static let background = Color(uiColor: backgroundUI)
    /// Cartes / sections.
    static let surface = Color(uiColor: surfaceUI)
    /// Surface légèrement surélevée pour les éléments imbriqués (pastilles, vignettes).
    static let surfaceElevated = Color(uiColor: surfaceElevatedUI)
    /// Couleur principale (actions, éléments actifs, boutons).
    static let primary = Color(uiColor: primaryUI)
    /// Accent (caméras, objets connectés, éléments interactifs).
    static let accent = Color(uiColor: accentUI)
    /// Texte principal.
    static let textPrimary = Color(uiColor: textPrimaryUI)
    /// Texte secondaire.
    static let textSecondary = Color(uiColor: textSecondaryUI)
    /// Succès / état OK.
    static let success = Color(uiColor: successUI)
    /// Alertes / attention.
    static let warning = Color(uiColor: warningUI)
    /// Erreur.
    static let error = Color(uiColor: errorUI)
    /// Filet des cartes.
    static let hairline = Color(uiColor: hairlineUI)
    /// Ombre des cartes.
    static let cardShadow = Color(uiColor: cardShadowUI)

    // MARK: Métriques
    /// Rayon standard des cartes (≈20 px).
    static let cardRadius: CGFloat = 20
    /// Espacement vertical entre les grandes sections.
    static let sectionSpacing: CGFloat = 20

    // MARK: Dégradés
    /// Dégradé de marque (titres, accents forts) — identique dans les deux thèmes.
    static var gradient: LinearGradient {
        LinearGradient(colors: [accent, primary], startPoint: .leading, endPoint: .trailing)
    }

    /// Dégradé de fond de l'app : quasi plat et lumineux en clair, sombre avec
    /// une légère profondeur en mode sombre.
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [background, Color(uiColor: backgroundEndUI)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: Fabrique de couleurs dynamiques
    private static func dynamic(light: UInt, lightAlpha: Double = 1, dark: UInt, darkAlpha: Double = 1) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        }
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

extension UIColor {
    /// Initialise une `UIColor` depuis un entier hexadécimal (ex. `0x2EC27E`).
    convenience init(hex: UInt, alpha: Double = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: CGFloat(alpha)
        )
    }
}

extension View {
    /// Carte standard « Habitat » : surface adaptative, coins arrondis 20 px,
    /// filet discret et ombre douce (effet flottant), cohérente clair/sombre.
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
            .shadow(color: Brand.cardShadow, radius: 14, x: 0, y: 6)
    }

    /// Alias historique conservé pour les blocs du Dashboard.
    func dashboardCard() -> some View {
        brandCard()
    }
}
