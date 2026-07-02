import SwiftUI
import SwiftData

struct RemindersView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Reminder>(\.reminderDate)]) private var reminders: [Reminder]
    @State private var showingSheet = false

    var body: some View {
        NavigationStack {
            List(reminders) { reminder in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(reminder.title)
                            .font(.headline)
                        Spacer()
                        if reminder.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    Text(reminder.animal?.name ?? "Sans animal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(reminder.reminderDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                    Text(reminder.recurrence.displayName)
                        .font(.caption)
                        .foregroundStyle(.teal)
                }
                .swipeActions {
                    Button("Terminé") {
                        reminder.isCompleted = true
                        try? context.save()
                    }
                }
            }
            .navigationTitle("Rappels")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSheet = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingSheet) {
                AddReminderView()
            }
        }
    }
}

struct AddReminderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Animal>(\.name)]) private var animals: [Animal]

    @State private var selectedAnimal: Animal?
    @State private var title = ""
    @State private var reminderDate = Date()
    @State private var recurrence: ReminderRecurrence = .none
    @State private var category: ReminderCategory = .feeding

    var body: some View {
        NavigationStack {
            Form {
                Picker("Animal", selection: $selectedAnimal) {
                    Text("Aucun").tag(nil as Animal?)
                    ForEach(animals) { animal in
                        Text(animal.name).tag(animal as Animal?)
                    }
                }
                TextField("Titre", text: $title)
                DatePicker("Date", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
                Picker("Récurrence", selection: $recurrence) {
                    ForEach(ReminderRecurrence.allCases, id: \.self) { recurrence in
                        Text(recurrence.displayName).tag(recurrence)
                    }
                }
                Picker("Catégorie", selection: $category) {
                    ForEach(ReminderCategory.allCases, id: \.self) { category in
                        Text(category.displayName).tag(category)
                    }
                }
            }
            .navigationTitle("Nouveau rappel")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        let reminder = Reminder(animal: selectedAnimal, title: title, reminderDate: reminderDate, recurrence: recurrence, category: category)
                        context.insert(reminder)
                        NotificationService.shared.scheduleReminder(reminder)
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
