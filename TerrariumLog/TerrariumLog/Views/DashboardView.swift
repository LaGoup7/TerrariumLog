import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Animal>(\.dashboardSortOrder)]) private var animals: [Animal]
    @Query(sort: [SortDescriptor<Reminder>(\.reminderDate)]) private var reminders: [Reminder]
    @Query private var cameras: [Camera]

    private var upcomingReminders: [Reminder] {
        Array(reminders.filter { !$0.isCompleted }.prefix(3))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    headerSection
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if !upcomingReminders.isEmpty {
                    Section {
                        remindersSection
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }

                if !cameras.isEmpty {
                    Section {
                        camerasSection
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }

                Section {
                    ForEach(animals) { animal in
                        AnimalCardView(animal: animal)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .onMove(perform: moveAnimals)
                } header: {
                    if !animals.isEmpty {
                        Text("Glisse-dépose pour réordonner")
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.15), Color.teal.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing))
            .navigationTitle("Terrarium Log")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    private func moveAnimals(from source: IndexSet, to destination: Int) {
        var reordered = animals
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, animal) in reordered.enumerated() {
            animal.dashboardSortOrder = index
        }
        try? context.save()
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
    @State private var lightIsOn = false
    @State private var isSendingLightCommand = false

    private var terrariumLightIP: String? {
        guard let ip = animal.terrarium?.wizLightIP, !ip.isEmpty else { return nil }
        return ip
    }

    private var terrariumCamera: Camera? {
        animal.terrarium?.cameras.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            }
            .buttonStyle(.plain)

            if terrariumLightIP != nil || terrariumCamera != nil {
                Divider()
                quickActionsRow
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            if let path = animal.primaryPhotoPath {
                image = PhotoStorage.shared.loadImage(from: path)
            }
        }
    }

    private var quickActionsRow: some View {
        HStack(spacing: 20) {
            if let lightIP = terrariumLightIP {
                Button {
                    lightIsOn.toggle()
                    sendLightCommand(WizCommandBuilder.power(lightIsOn), ip: lightIP)
                } label: {
                    Label(lightIsOn ? "Éteindre" : "Lumière", systemImage: lightIsOn ? "lightbulb.fill" : "lightbulb")
                        .foregroundStyle(lightIsOn ? .yellow : .primary)
                }
                .disabled(isSendingLightCommand)
            }
            if let camera = terrariumCamera {
                NavigationLink(destination: CameraLiveView(camera: camera)) {
                    Label("Caméra", systemImage: "video")
                }
            }
            Spacer()
        }
        .font(.caption)
        .buttonStyle(.plain)
    }

    private func sendLightCommand(_ command: WizCommand, ip: String) {
        isSendingLightCommand = true
        Task {
            try? await WizLightService.shared.send(command, to: ip)
            isSendingLightCommand = false
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
