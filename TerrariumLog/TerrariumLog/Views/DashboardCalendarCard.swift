import SwiftUI

/// Aperçu compact du calendrier des tâches sur le Dashboard : le mois courant
/// avec le jour du jour mis en avant et une pastille sous chaque jour comportant
/// un rappel à venir. La carte entière ouvre le calendrier complet.
struct DashboardCalendarCard: View {
    let reminders: [Reminder]

    private let calendar = Calendar.current

    /// Jours (à minuit) qui portent au moins un rappel non terminé.
    private var reminderDays: Set<Date> {
        Set(
            reminders
                .filter { !$0.isCompleted }
                .map { calendar.startOfDay(for: $0.reminderDate) }
        )
    }

    var body: some View {
        NavigationLink(destination: ReminderCalendarView()) {
            VStack(alignment: .leading, spacing: 14) {
                header
                weekdayHeader
                grid
            }
            .dashboardCard()
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Calendrier des tâches")
                .font(.headline)
                .foregroundStyle(Brand.textPrimary)
            Spacer(minLength: 8)
            Text(Date.now.formatted(.dateTime.month(.wide)).capitalized)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Brand.textSecondary)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Brand.textSecondary)
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(Array(CalendarGridBuilder.orderedWeekdaySymbols(calendar: calendar).enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Brand.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        let days = CalendarGridBuilder.days(for: .now, calendar: calendar)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 34)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isToday = calendar.isDateInToday(day)
        let hasReminder = reminderDays.contains(calendar.startOfDay(for: day))
        return VStack(spacing: 3) {
            Text("\(calendar.component(.day, from: day))")
                .font(.caption.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Color.white : Brand.textPrimary)
                .frame(width: 26, height: 26)
                .background(isToday ? Brand.primary : Color.clear, in: Circle())
            Circle()
                .fill(hasReminder ? Brand.warning : Color.clear)
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity)
    }
}
