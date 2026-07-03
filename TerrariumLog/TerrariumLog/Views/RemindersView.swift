import SwiftUI
import SwiftData

struct RemindersView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Reminder>(\.reminderDate)]) private var reminders: [Reminder]
    @State private var showingSheet = false

    var body: some View {
        List {
            ForEach(reminders) { reminder in
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
                    Button(role: .destructive) {
                        NotificationService.shared.cancelReminder(reminder)
                        context.delete(reminder)
                        try? context.save()
                        ReminderService.shared.refreshWidgetSnapshot(context: context)
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                    Button("Terminé") {
                        ReminderService.shared.complete(reminder, context: context)
                    }
                    .tint(.green)
                }
            }
        }
        .navigationTitle("Rappels")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink("Calendrier") {
                    ReminderCalendarView()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingSheet = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingSheet) {
            AddReminderView()
        }
    }
}

struct AddReminderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Animal>(\.name)]) private var animals: [Animal]

    @State private var selectedAnimals: Set<Animal> = []
    @State private var showingAnimalPicker = false
    @State private var title = ""
    @State private var reminderDate: Date
    @State private var recurrence: ReminderRecurrence = .none
    @State private var category: ReminderCategory = .feeding

    init(initialDate: Date = Date()) {
        _reminderDate = State(initialValue: initialDate)
    }

    private var animalSelectionSummary: String {
        switch selectedAnimals.count {
        case 0: return "Aucun"
        case 1: return selectedAnimals.first?.name ?? "1 animal"
        default: return "\(selectedAnimals.count) animaux"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Button {
                    showingAnimalPicker = true
                } label: {
                    HStack {
                        Text("Animaux")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(animalSelectionSummary)
                            .foregroundStyle(.secondary)
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
                    Button("Enregistrer") { save() }
                }
            }
            .sheet(isPresented: $showingAnimalPicker) {
                NavigationStack {
                    List(animals) { animal in
                        Button {
                            if selectedAnimals.contains(animal) {
                                selectedAnimals.remove(animal)
                            } else {
                                selectedAnimals.insert(animal)
                            }
                        } label: {
                            HStack {
                                Text(animal.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedAnimals.contains(animal) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.teal)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .navigationTitle("Choisir les animaux")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("OK") { showingAnimalPicker = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func save() {
        if selectedAnimals.isEmpty {
            let reminder = Reminder(animal: nil, title: title, reminderDate: reminderDate, recurrence: recurrence, category: category)
            context.insert(reminder)
            NotificationService.shared.scheduleReminder(reminder)
        } else {
            for animal in selectedAnimals {
                let reminder = Reminder(animal: animal, title: title, reminderDate: reminderDate, recurrence: recurrence, category: category)
                context.insert(reminder)
                NotificationService.shared.scheduleReminder(reminder)
            }
        }
        try? context.save()
        ReminderService.shared.refreshWidgetSnapshot(context: context)
        dismiss()
    }
}
