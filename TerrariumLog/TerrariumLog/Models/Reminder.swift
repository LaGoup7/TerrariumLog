import Foundation
import SwiftData

@Model
final class Reminder {
    var animal: Animal?
    var title: String
    var reminderDate: Date
    var recurrence: ReminderRecurrence
    var category: ReminderCategory
    var notificationIdentifier: String?
    var notes: String
    var isCompleted: Bool

    init(
        animal: Animal? = nil,
        title: String,
        reminderDate: Date,
        recurrence: ReminderRecurrence,
        category: ReminderCategory,
        notificationIdentifier: String? = nil,
        notes: String = "",
        isCompleted: Bool = false
    ) {
        self.animal = animal
        self.title = title
        self.reminderDate = reminderDate
        self.recurrence = recurrence
        self.category = category
        self.notificationIdentifier = notificationIdentifier
        self.notes = notes
        self.isCompleted = isCompleted
    }

    func nextOccurrence(after date: Date) -> Date? {
        let calendar = Calendar.current
        switch recurrence {
        case .none:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        }
    }
}

enum ReminderRecurrence: String, CaseIterable, Codable, Sendable {
    case none
    case daily
    case weekly
    case biweekly
    case monthly

    var displayName: String {
        switch self {
        case .none: return "Aucune"
        case .daily: return "Quotidienne"
        case .weekly: return "Hebdomadaire"
        case .biweekly: return "Toutes les 2 semaines"
        case .monthly: return "Mensuelle"
        }
    }
}

enum ReminderCategory: String, CaseIterable, Codable, Sendable {
    case feeding
    case humidification
    case watering
    case weeklyCheck
    case hibernation
    case cleaning
    case other

    var displayName: String {
        switch self {
        case .feeding: return "Nourrissage"
        case .humidification: return "Humidification"
        case .watering: return "Arrosage des plantes"
        case .weeklyCheck: return "Contrôle hebdomadaire"
        case .hibernation: return "Hivernation"
        case .cleaning: return "Nettoyage"
        case .other: return "Autre"
        }
    }
}
