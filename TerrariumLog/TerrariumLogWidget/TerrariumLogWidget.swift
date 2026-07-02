import WidgetKit
import SwiftUI

struct ReminderEntry: TimelineEntry {
    let date: Date
    let reminders: [WidgetReminderSnapshot]
}

struct ReminderTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReminderEntry {
        ReminderEntry(date: .now, reminders: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (ReminderEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReminderEntry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func currentEntry() -> ReminderEntry {
        let snapshot = WidgetSnapshotStore.load()
        return ReminderEntry(date: .now, reminders: snapshot?.reminders ?? [])
    }
}

struct TerrariumLogWidgetEntryView: View {
    var entry: ReminderTimelineProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Prochains rappels")
                .font(.caption.bold())
                .foregroundStyle(.teal)
            if entry.reminders.isEmpty {
                Spacer()
                Text("Aucun rappel à venir")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.reminders.prefix(3)) { reminder in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(reminder.title)
                            .font(.caption.bold())
                            .lineLimit(1)
                        Text("\(reminder.animalName ?? "Général") · \(reminder.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct TerrariumLogWidget: Widget {
    let kind: String = "TerrariumLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReminderTimelineProvider()) { entry in
            TerrariumLogWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Prochains rappels")
        .description("Affiche les prochains rappels TerrariumLog.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct TerrariumLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        TerrariumLogWidget()
    }
}
