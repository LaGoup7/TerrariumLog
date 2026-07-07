import SwiftUI
import SwiftData

struct ReminderCalendarView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Reminder>(\.reminderDate)]) private var reminders: [Reminder]
    @Query private var preyStocks: [PreyStock]

    @State private var displayedMonth: Date = .now
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var showingAddSheet = false

    private let calendar = Calendar.current

    private var remindersByDay: [Date: [Reminder]] {
        Dictionary(grouping: reminders) { calendar.startOfDay(for: $0.reminderDate) }
    }

    private var selectedDayReminders: [Reminder] {
        remindersByDay[calendar.startOfDay(for: selectedDate)] ?? []
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                monthHeader
                weekdayHeader
                calendarGrid
                selectedDaySection
            }
            .padding()
        }
        .background(Brand.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Calendrier")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAddSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddReminderView(initialDate: selectedDate)
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
            Spacer()
            Button { changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(Array(CalendarGridBuilder.orderedWeekdaySymbols(calendar: calendar).enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let days = CalendarGridBuilder.days(for: displayedMonth, calendar: calendar)
        let columns = Array(repeating: GridItem(.flexible()), count: 7)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(for: day)
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    private func dayCell(for day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let hasReminders = !(remindersByDay[calendar.startOfDay(for: day)] ?? []).isEmpty

        return Button {
            selectedDate = day
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .white : .primary)
                Circle()
                    .fill(hasReminders ? (isSelected ? Color.white : Brand.warning) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(isSelected ? Brand.primary : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedDate.formatted(date: .complete, time: .omitted))
                .font(.headline)
            if selectedDayReminders.isEmpty {
                Text("Aucun rappel ce jour-là")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(selectedDayReminders) { reminder in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reminder.title)
                                .font(.subheadline)
                            Text(reminder.animal?.name ?? "Sans animal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            // Nourrissage : proie suggérée par la rotation du
                            // régime (stocks pris en compte), dans le calendrier.
                            if reminder.category == .feeding, let animal = reminder.animal {
                                let analysis = FeedingDiversity.analyze(animal: animal, stocks: preyStocks)
                                if let suggestion = analysis.suggestionDisplayName {
                                    Label("Suggestion : \(suggestion)", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.caption2)
                                        .foregroundStyle(Brand.primary)
                                }
                                if let restockNote = analysis.restockNote {
                                    Label(restockNote, systemImage: "cart")
                                        .font(.caption2)
                                        .foregroundStyle(Brand.warning)
                                }
                            }
                        }
                        Spacer()
                        if reminder.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Brand.success)
                        } else {
                            Button {
                                ReminderService.shared.complete(reminder, context: context)
                            } label: {
                                Image(systemName: "checkmark.circle")
                            }
                        }
                        Button {
                            NotificationService.shared.cancelReminder(reminder)
                            context.delete(reminder)
                            try? context.save()
                            ReminderService.shared.refreshWidgetSnapshot(context: context)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Brand.error)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}
