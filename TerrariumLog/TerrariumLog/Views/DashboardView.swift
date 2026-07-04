import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Animal>(\.dashboardSortOrder)]) private var animals: [Animal]
    @Query(sort: [SortDescriptor<Reminder>(\.reminderDate)]) private var reminders: [Reminder]
    @Query private var cameras: [Camera]
    @Query(sort: [SortDescriptor<Light>(\.name)]) private var lights: [Light]
    @Query(sort: [SortDescriptor<Terrarium>(\.name)]) private var terrariums: [Terrarium]

    @State private var showingAddReminder = false
    @State private var showingAddLight = false
    @State private var showingAnimalVisibility = false

    /// Marges verticales/horizontales uniformes entre toutes les cartes du Dashboard.
    private let cardInsets = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)

    private var brandGradient: LinearGradient {
        LinearGradient(colors: [.teal, .green], startPoint: .leading, endPoint: .trailing)
    }

    private var upcomingReminders: [Reminder] {
        Array(reminders.filter { !$0.isCompleted }.prefix(3))
    }

    private var visibleAnimals: [Animal] {
        animals.filter { !$0.isHiddenFromDashboard }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    brandTitle
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))

                Section {
                    remindersSection
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(cardInsets)

                if !cameras.isEmpty {
                    Section {
                        camerasSection
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(cardInsets)
                }

                Section {
                    lightsSection
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(cardInsets)

                if !terrariums.isEmpty {
                    Section {
                        terrariumsSection
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(cardInsets)
                }

                Section {
                    ForEach(visibleAnimals) { animal in
                        AnimalCardView(animal: animal)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(cardInsets)
                    }
                    .onMove(perform: moveAnimals)
                } header: {
                    if !visibleAnimals.isEmpty {
                        Text("Glisse-dépose pour réordonner")
                            .textCase(nil)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.15), Color.teal.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAnimalVisibility = true
                    } label: {
                        Image(systemName: "eye")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAnimalVisibility) {
                AnimalVisibilityView()
            }
            .sheet(isPresented: $showingAddLight) {
                LightConfigView()
            }
        }
    }

    private func moveAnimals(from source: IndexSet, to destination: Int) {
        var reordered = visibleAnimals
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, animal) in reordered.enumerated() {
            animal.dashboardSortOrder = index
        }
        try? context.save()
    }

    private var brandTitle: some View {
        HStack(spacing: 10) {
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(brandGradient)
            Text("TerrariumLog")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(brandGradient)
                .tracking(0.5)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("Prochains rappels")
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                HStack(spacing: 16) {
                    Button {
                        showingAddReminder = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    NavigationLink(destination: ReminderCalendarView()) {
                        Image(systemName: "calendar")
                    }
                    NavigationLink(destination: RemindersView()) {
                        Text("Voir tout")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
                .imageScale(.large)
                .foregroundStyle(.teal)
                .layoutPriority(1)
            }
            if upcomingReminders.isEmpty {
                Text("Aucun rappel à venir")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
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
        }
        .dashboardCard()
        .sheet(isPresented: $showingAddReminder) {
            AddReminderView()
        }
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
        .dashboardCard()
    }

    private var lightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("Lumières")
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Button {
                    showingAddLight = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(.teal)
                }
                .buttonStyle(.borderless)
            }
            if lights.isEmpty {
                Text("Aucune lampe configurée")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(lights) { light in
                    NavigationLink(destination: LightControlView(light: light)) {
                        HStack {
                            Image(systemName: light.lastKnownOn ? "lightbulb.fill" : "lightbulb")
                                .foregroundStyle(light.lastKnownOn ? .yellow : .secondary)
                            VStack(alignment: .leading) {
                                Text(light.name)
                                    .font(.subheadline)
                                Text(light.terrarium?.name ?? light.brand.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Circle()
                                .fill(light.isConfigured ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            context.delete(light)
                            try? context.save()
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .dashboardCard()
    }

    private var terrariumsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Terrariums")
                .font(.headline)
            ForEach(terrariums) { terrarium in
                NavigationLink(destination: TerrariumDetailView(terrarium: terrarium)) {
                    HStack(spacing: 12) {
                        TerrariumThumbnail(terrarium: terrarium)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(terrarium.name)
                                .font(.subheadline)
                            Text("\(terrarium.animals.count) animal(aux) hébergé(s)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .dashboardCard()
    }
}

/// Style de carte partagé par tous les blocs du Dashboard : matière translucide,
/// coins arrondis continus, bordure et ombre subtiles pour un rendu premium et
/// homogène.
extension View {
    func dashboardCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
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
                        Text(animal.journalEntries.filter { !$0.isPhotoOnly }.sorted { $0.date > $1.date }.first.map { ObservationEventType(rawValue: $0.eventType)?.displayName ?? $0.eventType } ?? "Aucun")
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
        .dashboardCard()
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

struct AnimalVisibilityView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Animal>(\.dashboardSortOrder)]) private var animals: [Animal]

    var body: some View {
        NavigationStack {
            List(animals) { animal in
                Toggle(isOn: Binding(
                    get: { !animal.isHiddenFromDashboard },
                    set: { isVisible in
                        animal.isHiddenFromDashboard = !isVisible
                        try? context.save()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(animal.name)
                            .font(.subheadline)
                        Text(animal.species)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Animaux affichés")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}
