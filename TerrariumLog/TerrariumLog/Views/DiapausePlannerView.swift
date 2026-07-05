import SwiftUI
import SwiftData

/// Planifie l'hivernage d'une colonie : crée deux rappels notifiés (mise en
/// diapause et réveil), catégorie « Hivernation ». Les dates par défaut suivent
/// le cycle classique des Lasius (mi-novembre → début mars).
struct DiapausePlannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let animal: Animal

    @State private var startDate: Date
    @State private var endDate: Date

    init(animal: Animal) {
        self.animal = animal
        let calendar = Calendar.current
        let year = calendar.component(.year, from: .now)
        let november15 = calendar.date(from: DateComponents(year: year, month: 11, day: 15, hour: 10)) ?? .now
        let defaultStart = november15 > .now
            ? november15
            : (calendar.date(byAdding: .year, value: 1, to: november15) ?? november15)
        let defaultEnd = calendar.date(
            from: DateComponents(year: calendar.component(.year, from: defaultStart) + 1, month: 3, day: 1, hour: 10)
        ) ?? defaultStart
        _startDate = State(initialValue: defaultStart)
        _endDate = State(initialValue: defaultEnd)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Mise en diapause", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Réveil", selection: $endDate, in: startDate..., displayedComponents: [.date, .hourAndMinute])
                } footer: {
                    Text("Deux rappels notifiés seront créés pour \(animal.name). Pour les Lasius : descente progressive vers 8-12 °C (cave, garage frais), pas de nourrissage pendant la diapause, juste l'humidité du nid.")
                }
            }
            .navigationTitle("Planifier la diapause")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Planifier") {
                        createReminders()
                        dismiss()
                    }
                }
            }
        }
    }

    private func createReminders() {
        let start = Reminder(
            animal: animal,
            title: "Mise en diapause de \(animal.name)",
            reminderDate: startDate,
            recurrence: .none,
            category: .hibernation,
            notes: "Descente progressive vers 8-12 °C. Enregistre l'événement « Début de diapause » au journal."
        )
        let end = Reminder(
            animal: animal,
            title: "Réveil de diapause de \(animal.name)",
            reminderDate: endDate,
            recurrence: .none,
            category: .hibernation,
            notes: "Réchauffement progressif sur quelques jours, puis reprise de l'eau miellée. Enregistre « Fin de diapause » au journal."
        )
        context.insert(start)
        context.insert(end)
        try? context.save()
        NotificationService.shared.scheduleReminder(start)
        NotificationService.shared.scheduleReminder(end)
        ReminderService.shared.refreshWidgetSnapshot(context: context)
    }
}
