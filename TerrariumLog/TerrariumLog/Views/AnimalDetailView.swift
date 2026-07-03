import SwiftUI
import SwiftData
import PhotosUI
import Charts
import UIKit

struct AnimalDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let animal: Animal

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingJournalSheet = false
    @State private var showingMeasurementSheet = false
    @State private var notes = ""
    @State private var primaryImage: UIImage?

    @State private var showingFeedingSheet = false
    @State private var showingMoltSheet = false
    @State private var showingDiapauseSheet = false
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingCamera = false
    @State private var selectedGalleryIndex: Int?
    @State private var selectedGalleryFilter: String?
    @State private var primaryPhotoOffsetX: Double = 0
    @State private var primaryPhotoOffsetY: Double = 0
    @State private var selectedGalleryItems: [PhotosPickerItem] = []

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                infoSection
                healthSection
                if animal.type == .antColony {
                    colonySection
                }
                feedingSection
                if animal.type.tracksMolting {
                    moltSection
                }
                if animal.type.tracksDiapause {
                    diapauseSection
                }
                journalSection
                gallerySection
                AnimalVideosSection(animal: animal)
                measurementsSection
                statisticsSection
            }
            .padding()
        }
        .navigationTitle(animal.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            notes = animal.notes
            if let path = animal.primaryPhotoPath {
                primaryImage = PhotoStorage.shared.loadImage(from: path)
            }
            primaryPhotoOffsetX = animal.primaryPhotoOffsetX
            primaryPhotoOffsetY = animal.primaryPhotoOffsetY
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: LifeStoryView(animal: animal)) {
                    Image(systemName: "book.closed")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Ajouter une observation") { showingJournalSheet = true }
                    Button("Ajouter un repas") { showingFeedingSheet = true }
                    if animal.type.tracksMolting {
                        Button("Ajouter une mue") { showingMoltSheet = true }
                    }
                    if animal.type.tracksDiapause {
                        Button("Ajouter une diapause") { showingDiapauseSheet = true }
                    }
                    Button("Ajouter une mesure") { showingMeasurementSheet = true }
                    Divider()
                    Button("Modifier") { showingEditSheet = true }
                    Button("Supprimer", role: .destructive) { showingDeleteConfirmation = true }
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
        }
        .confirmationDialog(
            "Supprimer \(animal.name) ?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                context.delete(animal)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("Cette action supprime aussi tout son historique (journal, mesures, rappels).")
        }
        .sheet(isPresented: $showingJournalSheet) {
            JournalEntryView(animal: animal)
        }
        .sheet(isPresented: $showingFeedingSheet) {
            JournalEntryView(animal: animal, initialEventType: .feeding)
        }
        .sheet(isPresented: $showingMoltSheet) {
            JournalEntryView(animal: animal, initialEventType: .molt)
        }
        .sheet(isPresented: $showingDiapauseSheet) {
            JournalEntryView(animal: animal, initialEventType: .hibernationStart)
        }
        .sheet(isPresented: $showingMeasurementSheet) {
            MeasurementEntryView(animal: animal)
        }
        .sheet(isPresented: $showingEditSheet) {
            AnimalFormView(animal: animal)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let primaryImage {
                RepositionableSquareImage(
                    image: primaryImage,
                    offsetX: $primaryPhotoOffsetX,
                    offsetY: $primaryPhotoOffsetY,
                    onCommit: {
                        animal.primaryPhotoOffsetX = primaryPhotoOffsetX
                        animal.primaryPhotoOffsetY = primaryPhotoOffsetY
                        try? context.save()
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                Text("Glisse la photo pour la recentrer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: animal.type.symbolName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.teal.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(animal.name)
                    .font(.title2.bold())
                Text(animal.species)
                    .foregroundStyle(.secondary)
                Label(animal.type.displayName, systemImage: animal.type.symbolName)
                    .font(.subheadline)
                    .foregroundStyle(.teal)
            }

            HStack {
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 1, matching: .images) {
                    Label("Changer la photo principale", systemImage: "photo")
                }
                if isCameraAvailable {
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Prendre une photo", systemImage: "camera")
                    }
                }
            }
            .onChange(of: selectedItems) { _, newItems in
                guard let first = newItems.first else { return }
                Task {
                    if let data = try? await first.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        setPrimaryImage(image)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .fullScreenCover(isPresented: $showingCamera) {
            CameraCaptureView { image in
                setPrimaryImage(image)
            }
            .ignoresSafeArea()
        }
    }

    private func setPrimaryImage(_ image: UIImage) {
        if let path = try? PhotoStorage.shared.saveImage(image, for: animal.name) {
            animal.primaryPhotoPath = path
            animal.primaryPhotoOffsetX = 0
            animal.primaryPhotoOffsetY = 0
            // Aussi enregistrée comme entrée de journal pour apparaître dans la Galerie et la Timeline,
            // et pour ne pas perdre l'historique des anciennes photos de profil.
            let entry = ObservationEntry(
                date: .now,
                eventType: ObservationEventType.photo.rawValue,
                note: "Photo de profil mise à jour",
                photoPaths: [path],
                animal: animal
            )
            context.insert(entry)
            try? context.save()
            primaryImage = image
            primaryPhotoOffsetX = 0
            primaryPhotoOffsetY = 0
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Informations")
                .font(.headline)
            if let scientificName = animal.scientificName, !scientificName.isEmpty {
                LabeledContent("Nom scientifique", value: scientificName)
            }
            LabeledContent("Sexe", value: animal.sex.displayName)
            LabeledContent("Origine", value: animal.origin.displayName)
            if let locality = animal.locality, !locality.isEmpty {
                LabeledContent("Localité", value: locality)
            }
            if let breeder = animal.breeder, !breeder.isEmpty {
                LabeledContent("Éleveur", value: breeder)
            }
            if let price = animal.purchasePrice {
                LabeledContent("Prix d’achat", value: price.formatted(.currency(code: "EUR")))
            }
            LabeledContent("Date d’arrivée", value: animal.arrivalDate.formatted(date: .abbreviated, time: .omitted))
            LabeledContent("Stade actuel", value: animal.currentStage)
            LabeledContent("Statut", value: animal.status.displayName)
            if let terrarium = animal.terrarium {
                LabeledContent("Terrarium", value: terrarium.name)
            }
            TextEditor(text: $notes)
                .frame(minHeight: 90)
                .onChange(of: notes) { _, newValue in
                    animal.notes = newValue
                    try? context.save()
                }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var colonySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Colonie")
                .font(.headline)
            if let workers = animal.estimatedWorkerCount {
                LabeledContent("Ouvrières estimées", value: "\(workers)")
            }
            if let queens = animal.queenCount {
                LabeledContent("Reines", value: "\(queens)")
            }
            LabeledContent("Couvain", value: animal.broodPresent ? "Présent" : "Absent")
            if let swarming = animal.swarmingDateEstimate {
                LabeledContent("Essaimage estimé", value: swarming.formatted(date: .abbreviated, time: .omitted))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var feedingSection: some View {
        let stats = FeedingStats.compute(from: animal.journalEntries)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Repas")
                .font(.headline)
            if let lastFeeding = stats.lastFeedingDate {
                LabeledContent("Dernier repas", value: lastFeeding.formatted(date: .abbreviated, time: .omitted))
            } else {
                Text("Aucun repas enregistré")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let average = stats.averageIntervalDays {
                LabeledContent("Intervalle moyen", value: "\(Int(average.rounded())) j")
            }
            LabeledContent("Refus", value: "\(stats.refusalCount)")
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var moltSection: some View {
        let stats = MoltStats.compute(from: animal.journalEntries)
        let chartableIntervals = stats.intervals.filter { $0.daysSincePrevious != nil }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Mues")
                .font(.headline)
            if stats.intervals.isEmpty {
                Text("Aucune mue enregistrée")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                if !chartableIntervals.isEmpty {
                    Chart(chartableIntervals) { interval in
                        BarMark(
                            x: .value("Mue", interval.toStage),
                            y: .value("Jours", interval.daysSincePrevious ?? 0)
                        )
                        .foregroundStyle(.teal)
                    }
                    .frame(height: 140)
                }
                ForEach(stats.intervals) { interval in
                    HStack {
                        Text("\(interval.fromStage) → \(interval.toStage)")
                            .font(.subheadline)
                        Spacer()
                        if let days = interval.daysSincePrevious {
                            Text("\(Int(days.rounded())) j")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let average = stats.averageDaysBetweenMolts {
                    LabeledContent("Intervalle moyen", value: "\(Int(average.rounded())) j")
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var diapauseSection: some View {
        let stats = DiapauseStats.compute(from: animal.journalEntries)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Diapause")
                .font(.headline)
            if stats.periods.isEmpty {
                Text("Aucune diapause enregistrée")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(stats.periods) { period in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(period.startDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                            if let endDate = period.endDate {
                                Text("→ \(endDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("En cours")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        Spacer()
                        if let days = period.durationDays {
                            Text("\(days) j")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Journal")
                .font(.headline)
            ForEach(animal.journalEntries.sorted { $0.date > $1.date }) { entry in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ObservationEventType(rawValue: entry.eventType)?.displayName ?? entry.eventType)
                            .font(.subheadline.bold())
                        Text(entry.note.isEmpty ? "Sans commentaire" : entry.note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button {
                        context.delete(entry)
                        try? context.save()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var galleryPhotos: [GalleryPhoto] {
        animal.journalEntries
            .sorted { $0.date < $1.date }
            .flatMap { entry in
                entry.photoPaths.map { GalleryPhoto(path: $0, date: entry.date, eventType: entry.eventType) }
            }
    }

    private var galleryEventTypes: [String] {
        var seen: [String] = []
        for photo in galleryPhotos where !seen.contains(photo.eventType) {
            seen.append(photo.eventType)
        }
        return seen
    }

    private var filteredGalleryPhotos: [GalleryPhoto] {
        guard let selectedGalleryFilter else { return galleryPhotos }
        return galleryPhotos.filter { $0.eventType == selectedGalleryFilter }
    }

    private var gallerySection: some View {
        let photos = filteredGalleryPhotos
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Galerie")
                    .font(.headline)
                Spacer()
                PhotosPicker(selection: $selectedGalleryItems, matching: .images) {
                    Image(systemName: "plus.circle")
                }
            }
            if galleryPhotos.isEmpty {
                Text("Aucune photo")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                if galleryEventTypes.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            galleryFilterChip(label: "Tous", isSelected: selectedGalleryFilter == nil) {
                                selectedGalleryFilter = nil
                            }
                            ForEach(galleryEventTypes, id: \.self) { eventType in
                                galleryFilterChip(
                                    label: ObservationEventType(rawValue: eventType)?.displayName ?? eventType,
                                    isSelected: selectedGalleryFilter == eventType
                                ) {
                                    selectedGalleryFilter = eventType
                                }
                            }
                        }
                    }
                }
                if photos.isEmpty {
                    Text("Aucune photo dans cette catégorie")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                                if let image = PhotoStorage.shared.loadImage(from: photo.path) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 110, height: 110)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .onTapGesture {
                                            selectedGalleryIndex = index
                                        }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .fullScreenCover(isPresented: Binding(
            get: { selectedGalleryIndex != nil },
            set: { if !$0 { selectedGalleryIndex = nil } }
        )) {
            PhotoGalleryViewer(photos: photos, selectedIndex: selectedGalleryIndex ?? 0)
        }
        .onChange(of: selectedGalleryItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        addGalleryPhoto(image)
                    }
                }
                selectedGalleryItems = []
            }
        }
    }

    private func addGalleryPhoto(_ image: UIImage) {
        guard let path = try? PhotoStorage.shared.saveImage(image, for: animal.name) else { return }
        let entry = ObservationEntry(
            date: .now,
            eventType: ObservationEventType.photo.rawValue,
            note: "",
            photoPaths: [path],
            animal: animal
        )
        context.insert(entry)
        try? context.save()
    }

    private func galleryFilterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.teal.opacity(0.3) : Color.teal.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var measurementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mesures")
                .font(.headline)
            if !animal.measurements.isEmpty {
                EnvironmentChartsView(measurements: animal.measurements)
            }
            Text("Dernières mesures")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(animal.measurements.sorted { $0.date > $1.date }) { measurement in
                HStack {
                    VStack(alignment: .leading) {
                        Text(measurement.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                        Text(measurement.note.isEmpty ? "Aucune note" : measurement.note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("T: \(measurement.temperature.map { String($0) } ?? "—")")
                        .font(.caption)
                    Button {
                        context.delete(measurement)
                        try? context.save()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var healthEntries: [ObservationEntry] {
        Array(
            animal.journalEntries
                .filter { $0.eventType == ObservationEventType.behavior.rawValue || $0.eventType == ObservationEventType.foodRefusal.rawValue }
                .sorted { $0.date > $1.date }
                .prefix(5)
        )
    }

    private var statusColor: Color {
        switch animal.status.alertLevel {
        case .critical: return .red
        case .warning: return .orange
        case .ok: return .green
        }
    }

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Santé")
                .font(.headline)
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(animal.status.displayName)
                    .font(.subheadline.bold())
            }
            if healthEntries.isEmpty {
                Text("Aucune observation de comportement ou refus de nourriture récente")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(healthEntries) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: ObservationEventType(rawValue: entry.eventType)?.symbolName ?? "note.text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.note.isEmpty ? (ObservationEventType(rawValue: entry.eventType)?.displayName ?? entry.eventType) : entry.note)
                                .font(.footnote)
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var statisticsSection: some View {
        let feedingStats = FeedingStats.compute(from: animal.journalEntries)
        let moltStats = MoltStats.compute(from: animal.journalEntries)
        let ageDays = Calendar.current.dateComponents([.day], from: animal.arrivalDate, to: .now).day ?? 0
        let daysSinceLastFeeding = feedingStats.lastFeedingDate.map { Calendar.current.dateComponents([.day], from: $0, to: .now).day ?? 0 }
        let daysSinceLastMolt = moltStats.intervals.last.map { Calendar.current.dateComponents([.day], from: $0.date, to: .now).day ?? 0 }

        return VStack(alignment: .leading, spacing: 10) {
            Text("Statistiques")
                .font(.headline)
            statRow(label: "Depuis l'arrivée", value: "\(ageDays) j")
            if let daysSinceLastFeeding {
                statRow(label: "Dernier repas", value: "il y a \(daysSinceLastFeeding) j")
            }
            if let averageIntervalDays = feedingStats.averageIntervalDays {
                statRow(label: "Intervalle moyen entre repas", value: String(format: "%.1f j", averageIntervalDays))
            }
            if animal.type.tracksMolting {
                if let daysSinceLastMolt {
                    statRow(label: "Dernière mue", value: "il y a \(daysSinceLastMolt) j")
                }
                if let averageDaysBetweenMolts = moltStats.averageDaysBetweenMolts {
                    statRow(label: "Intervalle moyen entre mues", value: String(format: "%.1f j", averageDaysBetweenMolts))
                }
            }
            statRow(label: "Photos", value: "\(galleryPhotos.count)")
            statRow(label: "Entrées de journal", value: "\(animal.journalEntries.count)")
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.footnote.bold())
        }
    }
}

struct JournalEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<CustomPreyType>(\.name)]) private var customPreyTypes: [CustomPreyType]
    let animal: Animal

    @State private var selectedDate = Date()
    @State private var eventType: ObservationEventType
    @State private var note = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var photoPaths: [String] = []

    // Champs repas
    @State private var preyTypeRawValue: String = PreyType.drosophile.rawValue
    @State private var preyQuantity = ""
    @State private var eatenStatus: EatenStatus = .yes
    @State private var captureTimeMinutes = ""
    @State private var showingAddCustomPrey = false
    @State private var newCustomPreyName = ""

    // Champs mue
    @State private var previousStage: String
    @State private var newStage = ""

    @State private var showingCamera = false

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    init(animal: Animal, initialEventType: ObservationEventType = .other) {
        self.animal = animal
        _eventType = State(initialValue: initialEventType)
        _previousStage = State(initialValue: animal.currentStage)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                Picker("Type", selection: $eventType) {
                    ForEach(ObservationEventType.allCases.filter { $0.isAvailable(for: animal.type) }, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                if eventType == .feeding {
                    Section("Repas") {
                        Picker("Proie", selection: $preyTypeRawValue) {
                            ForEach(PreyType.allCases.filter { $0.isAvailable(for: animal.type) }, id: \.self) { prey in
                                Text(prey.displayName).tag(prey.rawValue)
                            }
                            ForEach(customPreyTypes) { custom in
                                Text(custom.name).tag(custom.name)
                            }
                        }
                        Button("Ajouter un type de proie personnalisé") {
                            showingAddCustomPrey = true
                        }
                        .font(.caption)
                        TextField("Quantité", text: $preyQuantity)
                            .keyboardType(.numberPad)
                        Picker("Mangé ?", selection: $eatenStatus) {
                            ForEach(EatenStatus.allCases, id: \.self) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                        TextField("Temps avant capture (min)", text: $captureTimeMinutes)
                            .keyboardType(.decimalPad)
                    }
                }

                if eventType == .molt {
                    Section("Mue") {
                        TextField("Ancien stade", text: $previousStage)
                        TextField("Nouveau stade", text: $newStage)
                    }
                }

                TextEditor(text: $note)
                    .frame(minHeight: 120)
                PhotosPicker(selection: $selectedItems, matching: .images) {
                    Label("Ajouter des photos", systemImage: "photo.on.rectangle")
                }
                .onChange(of: selectedItems) { _, newItems in
                    Task {
                        for item in newItems {
                            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                                if let path = try? PhotoStorage.shared.saveImage(image, for: animal.name) {
                                    photoPaths.append(path)
                                }
                            }
                        }
                    }
                }
                if isCameraAvailable {
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Prendre une photo", systemImage: "camera")
                    }
                }
            }
            .navigationTitle("Nouvelle observation")
            .fullScreenCover(isPresented: $showingCamera) {
                CameraCaptureView { image in
                    if let path = try? PhotoStorage.shared.saveImage(image, for: animal.name) {
                        photoPaths.append(path)
                    }
                }
                .ignoresSafeArea()
            }
            .alert("Nouveau type de proie", isPresented: $showingAddCustomPrey) {
                TextField("Nom", text: $newCustomPreyName)
                Button("Ajouter") {
                    let trimmed = newCustomPreyName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    let custom = CustomPreyType(name: trimmed)
                    context.insert(custom)
                    try? context.save()
                    preyTypeRawValue = trimmed
                    newCustomPreyName = ""
                }
                Button("Annuler", role: .cancel) {
                    newCustomPreyName = ""
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        let entry = ObservationEntry(
                            date: selectedDate,
                            eventType: eventType.rawValue,
                            note: note,
                            photoPaths: photoPaths,
                            preyType: eventType == .feeding ? preyTypeRawValue : nil,
                            preyQuantity: eventType == .feeding ? Int(preyQuantity) : nil,
                            eatenStatus: eventType == .feeding ? eatenStatus.rawValue : nil,
                            captureTimeMinutes: eventType == .feeding ? Double(captureTimeMinutes) : nil,
                            previousStage: eventType == .molt ? previousStage : nil,
                            newStage: eventType == .molt ? newStage : nil,
                            animal: animal
                        )
                        context.insert(entry)
                        if eventType == .molt, !newStage.isEmpty {
                            animal.currentStage = newStage
                        }
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MeasurementEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Animal>(\.name)]) private var animals: [Animal]
    let animal: Animal?

    @State private var selectedAnimal: Animal?
    @State private var date = Date()
    @State private var temperature: String = ""
    @State private var humidity: String = ""
    @State private var luminosity: String = ""
    @State private var waterLevel: String = ""
    @State private var note = ""

    init(animal: Animal?) {
        self.animal = animal
        _selectedAnimal = State(initialValue: animal)
    }

    var body: some View {
        NavigationStack {
            Form {
                if animal == nil {
                    Picker("Animal", selection: $selectedAnimal) {
                        Text("Aucun").tag(nil as Animal?)
                        ForEach(animals) { animal in
                            Text(animal.name).tag(animal as Animal?)
                        }
                    }
                }
                DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                TextField("Température", text: $temperature)
                    .keyboardType(.decimalPad)
                TextField("Humidité", text: $humidity)
                    .keyboardType(.decimalPad)
                TextField("Luminosité", text: $luminosity)
                    .keyboardType(.decimalPad)
                TextField("Niveau d’eau", text: $waterLevel)
                    .keyboardType(.decimalPad)
                TextEditor(text: $note)
                    .frame(minHeight: 100)
            }
            .navigationTitle("Nouvelle mesure")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        let entry = MeasurementEntry(date: date, temperature: Double(temperature), humidity: Double(humidity), luminosity: Double(luminosity), waterLevel: Double(waterLevel), note: note, animal: selectedAnimal ?? animal)
                        context.insert(entry)
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
