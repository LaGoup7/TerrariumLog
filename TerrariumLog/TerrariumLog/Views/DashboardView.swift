import SwiftUI
import SwiftData

/// Blocs modulables du Dashboard : chacun peut être masqué et réordonné depuis
/// l'écran de personnalisation (bouton unique en haut du Dashboard).
enum DashboardSection: String, CaseIterable, Identifiable {
    case reminders
    case calendar
    case cameras
    case lights
    case preyStock
    case terrariums
    case animals

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .reminders: return "Prochains rappels"
        case .calendar: return "Calendrier des tâches"
        case .cameras: return "Caméras"
        case .lights: return "Lumières"
        case .preyStock: return "Stock de proies"
        case .terrariums: return "Terrariums"
        case .animals: return "Animaux"
        }
    }

    var symbolName: String {
        switch self {
        case .reminders: return "bell"
        case .calendar: return "calendar"
        case .cameras: return "video"
        case .lights: return "lightbulb"
        case .preyStock: return "shippingbox"
        case .terrariums: return "leaf"
        case .animals: return "pawprint"
        }
    }

    /// Ordre stocké (persisté en chaîne), complété par les blocs manquants —
    /// robuste si de nouveaux blocs apparaissent dans une future version.
    static func order(from raw: String) -> [DashboardSection] {
        let stored = raw.split(separator: ",").compactMap { DashboardSection(rawValue: String($0)) }
        let missing = allCases.filter { !stored.contains($0) }
        return stored + missing
    }

    static func hidden(from raw: String) -> Set<DashboardSection> {
        Set(raw.split(separator: ",").compactMap { DashboardSection(rawValue: String($0)) })
    }
}

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Animal>(\.dashboardSortOrder)]) private var animals: [Animal]
    @Query(sort: [SortDescriptor<Reminder>(\.reminderDate)]) private var reminders: [Reminder]
    @Query private var cameras: [Camera]
    @Query(sort: [SortDescriptor<Light>(\.name)]) private var lights: [Light]
    @Query(sort: [SortDescriptor<Terrarium>(\.name)]) private var terrariums: [Terrarium]
    @Query private var preyStocks: [PreyStock]
    @Query private var plants: [Plant]

    private var lowStocks: [PreyStock] {
        preyStocks.filter(\.isLow)
    }

    /// Plantes dont l'échéance d'arrosage est atteinte (suivi activé).
    private var plantsToWater: [Plant] {
        plants.filter(\.isWateringDue)
    }

    @State private var showingAddReminder = false
    @State private var showingAddLight = false
    @State private var showingCustomize = false
    /// Capture photo rapide (appareil d'abord) depuis la barre du Dashboard.
    @State private var showingQuickPhoto = false
    /// Animal choisi pour une observation rapide depuis la barre du Dashboard.
    @State private var observationAnimal: Animal?
    @AppStorage("dashboardSectionOrder") private var sectionOrderRaw = ""
    @AppStorage("dashboardHiddenSections") private var hiddenSectionsRaw = ""

    private var orderedSections: [DashboardSection] {
        DashboardSection.order(from: sectionOrderRaw)
    }

    private var hiddenSections: Set<DashboardSection> {
        DashboardSection.hidden(from: hiddenSectionsRaw)
    }

    /// Marges verticales/horizontales uniformes entre toutes les cartes du Dashboard.
    /// Espacement vertical généreux pour aérer la hiérarchie visuelle.
    private let cardInsets = EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)

    private var brandGradient: LinearGradient { Brand.gradient }

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

                // Les alertes restent toujours en tête : ce sont des alertes,
                // pas des blocs décoratifs.
                if !lowStocks.isEmpty {
                    Section {
                        lowStockCard
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(cardInsets)
                }
                if !plantsToWater.isEmpty {
                    Section {
                        plantsToWaterCard
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(cardInsets)
                }

                ForEach(orderedSections) { section in
                    if !hiddenSections.contains(section) {
                        sectionView(for: section)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Brand.backgroundGradient.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Analyses (statistiques d'élevage), sorties des Réglages.
                    NavigationLink(destination: AnalyticsView()) {
                        Image(systemName: "chart.bar.xaxis")
                    }
                    .disabled(animals.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // Photo rapide : l'appareil s'ouvre tout de suite, puis note
                    // + rattachement à un animal ou un terrarium.
                    Button {
                        showingQuickPhoto = true
                    } label: {
                        Image(systemName: "camera")
                    }
                    .disabled(animals.isEmpty && terrariums.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // Observation rapide : formulaire du journal en mode
                    // multi-animaux (une entrée créée pour chaque animal coché).
                    Button {
                        observationAnimal = visibleAnimals.first ?? animals.first
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .disabled(animals.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCustomize = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(item: $observationAnimal) { animal in
                JournalEntryView(animal: animal, allowsMultipleAnimals: true)
            }
            .sheet(isPresented: $showingQuickPhoto) {
                QuickPhotoCaptureView()
            }
            .sheet(isPresented: $showingCustomize) {
                DashboardCustomizeView()
            }
            .sheet(isPresented: $showingAddLight) {
                LightConfigView()
            }
        }
    }

    /// Rend un bloc du Dashboard avec les modificateurs de rangée standard.
    /// Les blocs sans contenu (caméras/terrariums vides) restent masqués même
    /// s'ils sont activés.
    @ViewBuilder
    private func sectionView(for section: DashboardSection) -> some View {
        switch section {
        case .reminders:
            listSection { remindersSection }
        case .calendar:
            listSection { DashboardCalendarCard(reminders: reminders) }
        case .cameras:
            if !cameras.isEmpty {
                listSection { camerasSection }
            }
        case .lights:
            listSection { lightsSection }
        case .preyStock:
            if !preyStocks.isEmpty {
                listSection { preyStockSection }
            }
        case .terrariums:
            if !terrariums.isEmpty {
                listSection { terrariumsSection }
            }
        case .animals:
            Section {
                ForEach(visibleAnimals) { animal in
                    AnimalCardView(animal: animal)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(cardInsets)
                }
            }
        }
    }

    private func listSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Section {
            content()
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(cardInsets)
    }

    private var brandTitle: some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(brandGradient)
            Text("Habitat")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Brand.textPrimary)
                .tracking(0.5)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
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
                .foregroundStyle(Brand.primary)
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
                            .foregroundStyle(Brand.warning)
                        VStack(alignment: .leading) {
                            Text(reminder.title)
                                .font(.subheadline)
                            Text(reminder.animal?.name ?? "Général")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            // Rappel de nourrissage : la proie suggérée par la
                            // rotation du régime est visible directement ici.
                            if reminder.category == .feeding,
                               let animal = reminder.animal,
                               let suggestion = FeedingDiversity.analyze(animal: animal).suggestionDisplayName {
                                Label("Suggestion : \(suggestion)", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.caption2)
                                    .foregroundStyle(Brand.primary)
                            }
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

    /// Bloc permanent du stock de proies : vue d'ensemble + accès à la gestion.
    /// (L'alerte rouge en tête de Dashboard reste dédiée aux stocks bas.)
    private var preyStockSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Stock de proies")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: PreyStockView()) {
                    Text("Gérer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Brand.primary)
                }
            }
            ForEach(preyStocks.sorted { $0.quantity < $1.quantity }.prefix(4), id: \.persistentModelID) { stock in
                HStack {
                    Image(systemName: "shippingbox")
                        .foregroundStyle(stock.isLow ? Brand.warning : Brand.accent)
                    Text(stock.displayName)
                        .font(.subheadline)
                    Spacer()
                    Text("\(stock.quantity)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(stock.isLow ? Brand.warning : Color.primary)
                }
            }
            if preyStocks.count > 4 {
                Text("+ \(preyStocks.count - 4) autre(s) stock(s)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .dashboardCard()
    }

    /// Alerte d'arrosage : plantes dont l'échéance est atteinte. Chaque rangée
    /// ouvre la fiche plante ; « Arrosée » règle le cas en un tap.
    private var plantsToWaterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "drop.fill")
                    .foregroundStyle(Brand.accent)
                Text("Plantes à arroser")
                    .font(.headline)
                Spacer()
            }
            ForEach(plantsToWater, id: \.persistentModelID) { plant in
                HStack(spacing: 12) {
                    NavigationLink(destination: PlantDetailView(plant: plant)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plant.name)
                                .font(.subheadline)
                            Text(plant.terrarium?.name ?? "Sans terrarium")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button {
                        plant.markWatered()
                        try? context.save()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        Label("Arrosée", systemImage: "drop")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Brand.accent.opacity(0.16), in: Capsule())
                            .foregroundStyle(Brand.accent)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .dashboardCard()
    }

    /// Alerte de stock bas, affichée seulement quand un stock passe sous son seuil.
    private var lowStockCard: some View {
        ZStack {
            NavigationLink(destination: PreyStockView()) { EmptyView() }
                .opacity(0)
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Brand.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stock de proies bas")
                        .font(.headline)
                    Text(lowStocks.map { "\($0.displayName) (\($0.quantity))" }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .dashboardCard()
        }
    }

    private var camerasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Caméras")
                .font(.headline)
            ForEach(cameras) { camera in
                NavigationLink(destination: CameraLiveView(camera: camera)) {
                    HStack(spacing: 12) {
                        CameraPreviewThumbnail(camera: camera)
                        VStack(alignment: .leading) {
                            Text(camera.name)
                                .font(.subheadline)
                            Text(camera.terrarium?.name ?? "Sans terrarium")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Circle()
                            .fill(camera.isConfigured ? Brand.primary : Brand.warning)
                            .frame(width: 8, height: 8)
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(Brand.accent)
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        context.delete(camera)
                        try? context.save()
                    } label: {
                        Label("Supprimer la caméra", systemImage: "trash")
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
                        .foregroundStyle(Brand.primary)
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
                                .foregroundStyle(light.lastKnownOn ? Brand.warning : Color.secondary)
                            VStack(alignment: .leading) {
                                Text(light.name)
                                    .font(.subheadline)
                                Text(light.terrarium?.name ?? light.brand.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                // Cycle jour/nuit actif : visible d'un coup d'œil.
                                if light.scheduleMode != .manual {
                                    Label(light.scheduleMode.displayName, systemImage: light.scheduleMode.symbolName)
                                        .font(.caption2)
                                        .foregroundStyle(Brand.accent)
                                }
                            }
                            Spacer()
                            Circle()
                                .fill(light.isConfigured ? Brand.primary : Brand.warning)
                                .frame(width: 8, height: 8)
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
                    }
                }
            }
        }
        .dashboardCard()
    }
}

/// Vignette Dashboard d'une caméra : dernière image vue du live (mise en cache
/// automatiquement pendant la lecture), sinon pictogramme neutre.
struct CameraPreviewThumbnail: View {
    let camera: Camera
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "video.fill")
                    .font(.callout)
                    .foregroundStyle(Brand.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Brand.surfaceElevated)
            }
        }
        .frame(width: 64, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onAppear {
            image = CameraPreviewStore.shared.load(for: camera)
        }
    }
}

struct AnimalCardView: View {
    let animal: Animal
    @Environment(\.modelContext) private var context
    @State private var image: UIImage?
    @State private var lightIsOn = false
    @State private var isSendingLightCommand = false
    /// Type d'événement qui vient d'être ajouté en un tap (feedback ✓ éphémère).
    @State private var quickLoggedEvent: ObservationEventType?

    /// Première lampe configurée du terrarium de l'animal (modèle `Light`).
    private var terrariumLight: Light? {
        animal.terrarium?.lights.first { $0.isConfigured }
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
                                .foregroundStyle(Brand.accent)
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
                        if animal.isLikelyPreMolt {
                            Label("Pré-mue ?", systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption2.bold())
                                .foregroundStyle(Brand.warning)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Brand.warning.opacity(0.16))
                                .clipShape(Capsule())
                                .fixedSize()
                        }
                        Text(animal.status.displayName)
                            .font(.caption.bold())
                            .foregroundStyle(Brand.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Brand.primary.opacity(0.16))
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
                            .foregroundStyle(Brand.warning)
                    }
                }
            }
            .buttonStyle(.plain)

            Divider()
            quickActionsRow
        }
        .dashboardCard()
        .onAppear {
            if let path = animal.primaryPhotoPath {
                image = ThumbnailStore.shared.thumbnail(for: path, maxDimension: 240)
            }
            lightIsOn = terrariumLight?.lastKnownOn ?? false
        }
    }

    /// Rangée d'actions en tuiles compactes de largeur égale : tient sur UNE
    /// ligne même avec les quatre actions (Nourri, Brumisé, Lumière, Caméra).
    private var quickActionsRow: some View {
        HStack(spacing: 8) {
            actionTile(
                title: "Nourri",
                icon: quickLoggedEvent == .feeding ? "checkmark.circle.fill" : "fork.knife",
                tint: quickLoggedEvent == .feeding ? Brand.success : Brand.primary,
                disabled: quickLoggedEvent == .feeding
            ) { quickLog(.feeding) }

            actionTile(
                title: "Brumisé",
                icon: quickLoggedEvent == .humidifying ? "checkmark.circle.fill" : "drop",
                tint: quickLoggedEvent == .humidifying ? Brand.success : Brand.primary,
                disabled: quickLoggedEvent == .humidifying
            ) { quickLog(.humidifying) }

            if let light = terrariumLight {
                actionTile(
                    title: lightIsOn ? "Éteindre" : "Lumière",
                    icon: lightIsOn ? "lightbulb.fill" : "lightbulb",
                    tint: lightIsOn ? Brand.warning : Brand.accent,
                    disabled: isSendingLightCommand
                ) {
                    lightIsOn.toggle()
                    toggleLight(light, on: lightIsOn)
                }
            }

            if let camera = terrariumCamera {
                NavigationLink(destination: CameraLiveView(camera: camera)) {
                    tileLabel(title: "Caméra", icon: "video", tint: Brand.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func actionTile(title: String, icon: String, tint: Color, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            tileLabel(title: title, icon: icon, tint: tint)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func tileLabel(title: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.body)
            Text(title)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Brand.surfaceElevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .foregroundStyle(tint)
    }

    private func quickLog(_ event: ObservationEventType) {
        let entry = ObservationEntry(
            date: .now,
            eventType: event.rawValue,
            note: "Ajout rapide",
            animal: animal
        )
        context.insert(entry)
        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { quickLoggedEvent = event }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { quickLoggedEvent = nil }
        }
    }

    /// Allume/éteint via le `LightController` de la marque et synchronise
    /// `lastKnownOn` : la section « Lumières » du Dashboard et l'écran lampe
    /// affichent le même état.
    private func toggleLight(_ light: Light, on: Bool) {
        guard let ip = light.ipAddress, !ip.isEmpty else { return }
        isSendingLightCommand = true
        Task {
            let controller = LightControllerFactory.controller(for: light.brand)
            try? await controller.setPower(on, ip: ip)
            light.lastKnownOn = on
            try? context.save()
            isSendingLightCommand = false
        }
    }

    private var alertColor: Color {
        switch animal.status.alertLevel {
        case .critical:
            return Brand.error
        case .warning:
            return Brand.warning
        case .ok:
            let reminderSoon = animal.reminders.contains { reminder in
                !reminder.isCompleted && reminder.reminderDate.timeIntervalSinceNow < 48 * 3600
            }
            return reminderSoon ? Brand.warning : Brand.primary
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
                    .foregroundStyle(Brand.accent)
                    .background(Brand.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

/// Personnalisation complète du Dashboard : ordre et visibilité des blocs,
/// ordre et visibilité des animaux — le tout au même endroit (glisser pour
/// réordonner, interrupteur pour masquer).
struct DashboardCustomizeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Animal>(\.dashboardSortOrder)]) private var animals: [Animal]
    @AppStorage("dashboardSectionOrder") private var sectionOrderRaw = ""
    @AppStorage("dashboardHiddenSections") private var hiddenSectionsRaw = ""

    private var orderedSections: [DashboardSection] {
        DashboardSection.order(from: sectionOrderRaw)
    }

    private var hiddenSections: Set<DashboardSection> {
        DashboardSection.hidden(from: hiddenSectionsRaw)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(orderedSections) { section in
                        Toggle(isOn: visibilityBinding(for: section)) {
                            Label(section.displayName, systemImage: section.symbolName)
                        }
                        .tint(Brand.primary)
                    }
                    .onMove(perform: moveSections)
                } header: {
                    Text("Blocs")
                } footer: {
                    Text("Glisse pour réordonner, désactive pour masquer. L'alerte de stock bas reste toujours en tête quand elle est active.")
                }

                Section {
                    ForEach(animals) { animal in
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
                        .tint(Brand.primary)
                    }
                    .onMove(perform: moveAnimals)
                } header: {
                    Text("Animaux")
                }
            }
            // Mode édition permanent : les poignées de réordonnancement sont
            // toujours visibles, plus besoin d'un bouton Modifier séparé.
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Personnaliser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func visibilityBinding(for section: DashboardSection) -> Binding<Bool> {
        Binding(
            get: { !hiddenSections.contains(section) },
            set: { isVisible in
                var hidden = hiddenSections
                if isVisible {
                    hidden.remove(section)
                } else {
                    hidden.insert(section)
                }
                hiddenSectionsRaw = hidden.map(\.rawValue).sorted().joined(separator: ",")
            }
        )
    }

    private func moveSections(from source: IndexSet, to destination: Int) {
        var sections = orderedSections
        sections.move(fromOffsets: source, toOffset: destination)
        sectionOrderRaw = sections.map(\.rawValue).joined(separator: ",")
    }

    private func moveAnimals(from source: IndexSet, to destination: Int) {
        var reordered = animals
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, animal) in reordered.enumerated() {
            animal.dashboardSortOrder = index
        }
        try? context.save()
    }
}
