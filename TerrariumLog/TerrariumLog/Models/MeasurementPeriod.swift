import Foundation

enum MeasurementPeriod: String, CaseIterable, Identifiable, Sendable {
    case day
    case week
    case month

    var id: Self { self }

    var displayName: String {
        switch self {
        case .day: return "24 h"
        case .week: return "Semaine"
        case .month: return "Mois"
        }
    }

    func cutoffDate(reference: Date = .now) -> Date {
        let calendar = Calendar.current
        switch self {
        case .day:
            return calendar.date(byAdding: .day, value: -1, to: reference) ?? reference
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: reference) ?? reference
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: reference) ?? reference
        }
    }
}
