import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Animal>(\.name)]) private var animals: [Animal]
    @Query(sort: [SortDescriptor<Reminder>(\.reminderDate)]) private var reminders: [Reminder]
    @Query private var cameras: [Camera]

    private var upcomingReminders: [Reminder] {
        Array(reminders.filter { !$0.isCompleted }.prefix(3))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection

                    if !upcomingReminders.isEmpty {
                        remindersSection
                    }

                    if !cameras.isEmpty {
                        camerasSection
                    }

                    ForEach(animals) { animal in
                        AnimalCardView(animal: animal)
                    }
                }
                .padding()
            }
            .navigationTitle("Terrarium Log")
            .background(LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.15), Color.teal.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bienvenue")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Suivez l’évolution de vos colonies")
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Prochains rappels")
                    .font(.headline)
                Spacer()
                NavigationLink("Voir tout") {
                    RemindersView()
                }
                .font(.caption)
            }
            ForEach(upcomingReminders) { reminder in
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading) {
                        Text(reminder.title)
                            .font(.subheadline)
                        Text(reminder.animal?.name ?? "Général")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(reminder.reminderDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var camerasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Caméras")
                .font(.headline)
            ForEach(cameras) { camera in
                NavigationLink(destination: CameraLiveView(camera: camera)) {
                    HStack {
                        Circle()
                            .fill(camera.isConfigured ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading) {
                            Text(camera.name)
                                .font(.subheadline)
                            Text(camera.terrarium?.name ?? "Sans terrarium")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "play.circle")
                            .foregroundStyle(.teal)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct AnimalCardView: View {
    let animal: Animal
    @State private var image: UIImage?

    var body: some View {
        NavigationLink(destination: AnimalDetailView(animal: animal)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    imageView
                    VStack(alignment: .leading, spacing: 4) {
                        Text(animal.name)
                            .font(.headline)
                        Text(animal.species)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Label(animal.type.displayName, systemImage: animal.type.symbolName)
                            .font(.footnote)
                            .foregroundStyle(.teal)
                        if let colonySummary = animal.colonySummary {
                            Text(colonySummary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack {
                    Circle()
                        .fill(alertColor)
                        .frame(width: 10, height: 10)
                    Label(animal.currentStage, systemImage: "leaf")
                        .font(.footnote)
                    Spacer()
                    Text(animal.status.displayName)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.teal.opacity(0.2))
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Dernier événement")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(animal.journalEntries.sorted { $0.date > $1.date }.first.map { ObservationEventType(rawValue: $0.eventType)?.displayName ?? $0.eventType } ?? "Aucun")
                        .font(.subheadline)
                }

                if let reminder = animal.reminders.sorted(by: { $0.reminderDate < $1.reminderDate }).first {
                    Label("Prochain rappel : \(reminder.title)", systemImage: "bell.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .onAppear {
            if let path = animal.primaryPhotoPath {
                image = PhotoStorage.shared.loadImage(from: path)
            }
        }
    }

    private var alertColor: Color {
        switch animal.status.alertLevel {
        case .critical:
            return .red
        case .warning:
            return .orange
        case .ok:
            let reminderSoon = animal.reminders.contains { reminder in
                !reminder.isCompleted && reminder.reminderDate.timeIntervalSinceNow < 48 * 3600
            }
            return reminderSoon ? .orange : .green
        }
    }

    private var imageView: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Image(systemName: animal.type.symbolName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                    .padding(12)
                    .background(Color.teal.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}
