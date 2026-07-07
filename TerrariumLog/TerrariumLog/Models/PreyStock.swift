import Foundation
import SwiftData

/// Stock d'un type de proie (drosophiles, micro-grillons…). La quantité est
/// décrémentée automatiquement à chaque nourrissage enregistré avec ce type,
/// et le Dashboard alerte quand on passe sous le seuil.
@Model
final class PreyStock {
    /// `rawValue` d'un `PreyType` ou nom d'un type personnalisé — la même clé
    /// que `ObservationEntry.preyType`, pour le décompte automatique.
    var typeRawValue: String
    var quantity: Int
    var lowThreshold: Int
    var updatedAt: Date

    /// Animaux auxquels ce stock est réservé (ex. les graines pour la colonie
    /// de Messor barbarus). Vide = stock partagé par tous les animaux. Les
    /// suggestions de proies ignorent les stocks réservés à d'autres animaux.
    @Relationship(deleteRule: .nullify)
    var eaters: [Animal] = []

    init(typeRawValue: String, quantity: Int, lowThreshold: Int = 5, updatedAt: Date = .now) {
        self.typeRawValue = typeRawValue
        self.quantity = quantity
        self.lowThreshold = lowThreshold
        self.updatedAt = updatedAt
    }

    var displayName: String {
        PreyType(rawValue: typeRawValue)?.displayName ?? typeRawValue
    }

    var isLow: Bool {
        quantity <= lowThreshold
    }

    /// Vrai si ce stock concerne cet animal (réservé à lui, ou partagé).
    func isFor(_ animal: Animal) -> Bool {
        eaters.isEmpty || eaters.contains { $0.persistentModelID == animal.persistentModelID }
    }

    /// Libellé de l'attribution, ex. « Pour Messor » ou nil si partagé.
    var eatersLabel: String? {
        guard !eaters.isEmpty else { return nil }
        return "Pour " + eaters.map(\.name).sorted().joined(separator: ", ")
    }
}

extension PreyStock {
    /// Décrémente le stock correspondant à un nourrissage, s'il est suivi.
    static func consume(typeRawValue: String?, quantity: Int?, context: ModelContext) {
        guard let typeRawValue, !typeRawValue.isEmpty else { return }
        let consumed = max(quantity ?? 1, 1)
        let descriptor = FetchDescriptor<PreyStock>(
            predicate: #Predicate { $0.typeRawValue == typeRawValue }
        )
        guard let stock = try? context.fetch(descriptor).first else { return }
        stock.quantity = max(0, stock.quantity - consumed)
        stock.updatedAt = .now
    }
}
