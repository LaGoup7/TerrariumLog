import Foundation
import SwiftData

/// Type de proie ajouté par l'utilisateur, en complément des cas prédéfinis de `PreyType`.
/// Stocké et affiché comme texte libre (le champ `ObservationEntry.preyType` reste un simple
/// String, qui vaut soit le rawValue d'un `PreyType` connu, soit le nom d'un `CustomPreyType`).
@Model
final class CustomPreyType {
    var name: String
    var createdAt: Date

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }
}
