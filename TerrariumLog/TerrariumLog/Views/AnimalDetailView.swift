import SwiftUI
import SwiftData
import PhotosUI
import Charts
import UIKit

struct AnimalDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let animal: Animal

    @State private var showingJournalSheet = false
    @State private var showingMeasurementSheet = false
    @State private var notes = ""
    @State private var primaryImage: UIImage?

    @State private var showingFeedingSheet = false
    @State private var showingMoltSheet = false
    @State private var showingDiapauseSheet = false
    @State private var showingDiapausePlanner = false
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var photoPickerSource: ImagePickerSource?
    @State private var selectedGalleryIndex: Int?
    @State private var selectedGalleryFilter: String?
    @State private var selectedGalleryItems: [PhotosPickerItem] = []
    @State private var editingJournalEntry: ObservationEntry?
    @State private var showingEvolutionCompare = false
    @State private var showingDietConfig = false

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    /// Fiche espèce du catalogue correspondant à cet animal (rapprochement par
    /// nom scientifique ou espèce, insensible à la casse et aux guillemets de
    /// localité du pack, ex. « Phidippus regius “Soroa” »).
    private var matchingSpeciesSheet: SpeciesSheet? {
        func normalize(_ text: String) -> String {
            text.lowercased()
                .replacingOccurrences(of: "“", with: "")
                .replacingOccurrences(of: "”", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .trimmingCharacters(in: .whitespaces)
        }
        let candidates = [animal.scientificName, animal.species]
            .compactMap { $0 }
            .map(normalize)
            .filter { !$0.isEmpty }
        guard !candidates.isEmpty else { return nil }

        return SpeciesSheet.catalog.first { sheet in
            let sheetName = normalize(sheet.scientificName)
            // « Genre espèce » sans la localité éventuelle.
            let sheetBinomial = sheetName.split(separator: " ").prefix(2).joined(separator: " ")
            return candidates.contains { candidate in
                sheetName == candidate || sheetBinomial == candidate
                    || candidate.hasPrefix(sheetBinomial) || sheetName.hasPrefix(candidate)
            }
        }
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
        .background(Brand.backgroundGradient.ignoresSafeArea())
        .navigationTitle(animal.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            notes = animal.notes
            if let path = animal.primaryPhotoPath {
                primaryImage = PhotoStorage.shared.loadImage(from: path)
            }
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
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(uiImage: primaryImage)
                            .resizable()
                            .scaledToFill()
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                Image(systemName: animal.type.symbolName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Brand.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(animal.name)
                    .font(.title2.bold())
                Text(animal.species)
                    .foregroundStyle(.secondary)
                Label(animal.type.displayName, systemImage: animal.type.symbolName)
                    .font(.subheadline)
                    .foregroundStyle(Brand.accent)
                if let sheet = matchingSpeciesSheet {
                    NavigationLink {
                        SpeciesSheetDetailView(sheet: sheet)
                    } label: {
                        Label("Fiche espèce · \(sheet.scientificName)", systemImage: "book.closed.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Brand.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Brand.primary.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Button {
                    photoPickerSource = ImagePickerSource(type: .photoLibrary)
                } label: {
                    Label("Changer la photo principale", systemImage: "photo")
                }
                if isCameraAvailable {
                    Button {
                        photoPickerSource = ImagePickerSource(type: .camera)
                    } label: {
                        Label("Prendre une photo", systemImage: "camera")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .fullScreenCover(item: $photoPickerSource) { source in
            CroppingImagePicker(sourceType: source.type) { image in
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Brand.surface)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var feedingSection: some View {
        let stats = FeedingStats.compute(from: animal.journalEntries)
        let diversity = FeedingDiversity.analyze(animal: animal)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Repas")
                    .font(.headline)
                Spacer()
                Button {
                    showingDietConfig = true
                } label: {
                    Label("Régime", systemImage: "fork.knife.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .tint(Brand.primary)
            }
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
            if let suggestion = diversity.suggestionDisplayName {
                Label {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Prochaine proie suggérée : \(suggestion)")
                            .font(.footnote.weight(.semibold))
                        if let reason = diversity.reason {
                            Text(reason)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .foregroundStyle(Brand.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .sheet(isPresented: $showingDietConfig) {
            DietConfigView(animal: animal)
        }
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
                        .foregroundStyle(Brand.accent)
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
                growthChart
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    /// Courbe de croissance : taille (mm) saisie à chaque mue.
    @ViewBuilder
    private var growthChart: some View {
        let sizedMolts = animal.journalEntries
            .filter { $0.eventType == ObservationEventType.molt.rawValue && $0.moltSizeMM != nil }
            .sorted { $0.date < $1.date }
        if sizedMolts.count >= 2 {
            VStack(alignment: .leading, spacing: 6) {
                Text("Croissance (mm)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Chart(sizedMolts) { molt in
                    LineMark(
                        x: .value("Date", molt.date),
                        y: .value("mm", molt.moltSizeMM ?? 0)
                    )
                    .foregroundStyle(Brand.primary)
                    PointMark(
                        x: .value("Date", molt.date),
                        y: .value("mm", molt.moltSizeMM ?? 0)
                    )
                    .foregroundStyle(Brand.primary)
                }
                .frame(height: 140)
            }
        } else if sizedMolts.count == 1 {
            Text("Renseigne la taille à chaque mue pour tracer la courbe de croissance.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Suggestion saisonnière : quand la durée du jour passe sous ~10 h 30 sur
    /// le biotope de référence (ou l'Europe par défaut), il est temps de
    /// planifier l'hivernage — sauf si une diapause est en cours ou déjà
    /// planifiée.
    private var diapauseSeasonSuggestion: String? {
        guard animal.type.tracksDiapause else { return nil }
        let stats = DiapauseStats.compute(from: animal.journalEntries)
        if let last = stats.periods.last, last.endDate == nil { return nil } // déjà en diapause
        let hasPlanned = animal.reminders.contains { $0.category == .hibernation && !$0.isCompleted }
        guard !hasPlanned else { return nil }

        let reference = animal.terrarium?.lights
            .compactMap { BiotopePreset.preset(id: $0.biotopePresetID) }
            .first
        let latitude = reference?.latitude ?? 48.8
        let placeName = reference?.name ?? "nos latitudes"
        let hours = SunCalculator.dayLengthHours(latitude: abs(latitude))
        guard hours < 10.5 else { return nil }
        return String(format: "Les jours raccourcissent (%.1f h de jour sur %@) : c'est la période idéale pour planifier la diapause.", hours, placeName)
    }

    private var diapauseSection: some View {
        let stats = DiapauseStats.compute(from: animal.journalEntries)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Diapause")
                .font(.headline)
            if let suggestion = diapauseSeasonSuggestion {
                Label(suggestion, systemImage: "leaf.arrow.circlepath")
                    .font(.footnote)
                    .foregroundStyle(Brand.warning)
            }
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
                                    .foregroundStyle(Brand.warning)
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
            Button {
                showingDiapausePlanner = true
            } label: {
                Label("Planifier la diapause", systemImage: "calendar.badge.clock")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .tint(Brand.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .sheet(isPresented: $showingDiapausePlanner) {
            DiapausePlannerView(animal: animal)
        }
    }

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Journal")
                    .font(.headline)
                Spacer()
                Text("Tape une entrée pour la modifier")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            ForEach(animal.journalEntries.filter { !$0.isPhotoOnly }.sorted { $0.date > $1.date }) { entry in
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingJournalEntry = entry
                    }
                    Button {
                        context.delete(entry)
                        try? context.save()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Brand.error)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .sheet(item: $editingJournalEntry) { entry in
            JournalEntryView(animal: animal, editing: entry)
        }
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
                if galleryPhotos.count >= 2 {
                    Button {
                        showingEvolutionCompare = true
                    } label: {
                        Image(systemName: "square.split.2x1")
                    }
                    .buttonStyle(.borderless)
                }
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
                                if let image = ThumbnailStore.shared.thumbnail(for: photo.path, maxDimension: 330) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 110, height: 110)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .onTapGesture {
                                            selectedGalleryIndex = index
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                deleteGalleryPhoto(photo)
                                            } label: {
                                                Label("Supprimer la photo", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .fullScreenCover(isPresented: Binding(
            get: { selectedGalleryIndex != nil },
            set: { if !$0 { selectedGalleryIndex = nil } }
        )) {
            PhotoGalleryViewer(photos: photos, selectedIndex: selectedGalleryIndex ?? 0)
        }
        .sheet(isPresented: $showingEvolutionCompare) {
            EvolutionCompareView(photos: galleryPhotos)
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

    /// Supprime une photo depuis la galerie. On retire son chemin de l'entrée qui
    /// la contient : si c'est une entrée purement photo devenue vide, l'entrée est
    /// supprimée ; si la photo était attachée à un vrai événement, l'événement est
    /// conservé. Le fichier local est supprimé du stockage.
    private func deleteGalleryPhoto(_ photo: GalleryPhoto) {
        if let entry = animal.journalEntries.first(where: { $0.photoPaths.contains(photo.path) }) {
            entry.photoPaths.removeAll { $0 == photo.path }
            if entry.isPhotoOnly && entry.photoPaths.isEmpty {
                context.delete(entry)
            }
        }
        if animal.primaryPhotoPath == photo.path {
            animal.primaryPhotoPath = nil
        }
        try? PhotoStorage.shared.deleteImage(at: photo.path)
        try? context.save()
        if filteredGalleryPhotos.isEmpty {
            selectedGalleryFilter = nil
        }
    }

    private func galleryFilterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? Brand.primary : Color.primary)
                .background(isSelected ? Brand.primary.opacity(0.18) : Brand.surfaceElevated)
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
                            .foregroundStyle(Brand.error)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Brand.surface)
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
        case .critical: return Brand.error
        case .warning: return Brand.warning
        case .ok: return Brand.success
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
            if animal.isLikelyPreMolt {
                Label("Pré-mue probable : le cycle moyen de mue est presque écoulé. Évite de nourrir (une proie vivante peut blesser un animal en mue) et maintiens l'humidité.", systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote)
                    .foregroundStyle(Brand.warning)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Brand.surface)
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
                if let averageDaysBetweenMolts = moltStats.averageDaysBetweenMolts,
                   let lastMoltDate = moltStats.intervals.last?.date {
                    let estimated = lastMoltDate.addingTimeInterval(averageDaysBetweenMolts * 86400)
                    statRow(
                        label: "Prochaine mue estimée",
                        value: estimated < .now
                            ? "imminente (\(estimated.formatted(date: .abbreviated, time: .omitted)))"
                            : "≈ \(estimated.formatted(date: .abbreviated, time: .omitted))"
                    )
                }
            }
            statRow(label: "Photos", value: "\(galleryPhotos.count)")
            statRow(label: "Entrées de journal", value: "\(animal.journalEntries.filter { !$0.isPhotoOnly }.count)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Brand.surface)
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
    @Query(sort: [SortDescriptor<Animal>(\.dashboardSortOrder)]) private var allAnimals: [Animal]
    let animal: Animal
    /// Mode Dashboard : l'observation peut être appliquée à plusieurs animaux
    /// à la fois (une entrée de journal est créée pour chacun).
    var allowsMultipleAnimals: Bool = false
    /// Entrée existante en cours de modification (nil = création).
    private var editingEntry: ObservationEntry?

    @State private var selectedAnimalIDs: Set<PersistentIdentifier>
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
    @State private var moltSize = ""

    // Champs santé / note
    @State private var weight = ""
    @State private var tagsText = ""

    /// Snapshot capteurs capturé à l'ouverture (best-effort), figé dans la
    /// nouvelle entrée pour documenter le contexte environnemental.
    @State private var capturedSnapshot: TerrariumSensorReading?

    @State private var showingCamera = false

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    init(animal: Animal, initialEventType: ObservationEventType = .other, initialNote: String = "", allowsMultipleAnimals: Bool = false) {
        self.animal = animal
        self.allowsMultipleAnimals = allowsMultipleAnimals
        self.editingEntry = nil
        _eventType = State(initialValue: initialEventType)
        _note = State(initialValue: initialNote)
        _previousStage = State(initialValue: animal.currentStage)
        _selectedAnimalIDs = State(initialValue: [animal.persistentModelID])
    }

    /// Mode édition : le formulaire est pré-rempli avec l'entrée existante,
    /// qui sera mise à jour à l'enregistrement.
    init(animal: Animal, editing entry: ObservationEntry) {
        self.animal = animal
        self.allowsMultipleAnimals = false
        self.editingEntry = entry
        _eventType = State(initialValue: ObservationEventType(rawValue: entry.eventType) ?? .other)
        _previousStage = State(initialValue: entry.previousStage ?? animal.currentStage)
        _selectedAnimalIDs = State(initialValue: [animal.persistentModelID])
        _selectedDate = State(initialValue: entry.date)
        _note = State(initialValue: entry.note)
        _photoPaths = State(initialValue: entry.photoPaths)
        _preyTypeRawValue = State(initialValue: entry.preyType ?? PreyType.drosophile.rawValue)
        _preyQuantity = State(initialValue: entry.preyQuantity.map(String.init) ?? "")
        _eatenStatus = State(initialValue: entry.eatenStatus.flatMap(EatenStatus.init(rawValue:)) ?? .yes)
        _captureTimeMinutes = State(initialValue: entry.captureTimeMinutes.map { String($0) } ?? "")
        _newStage = State(initialValue: entry.newStage ?? "")
        _moltSize = State(initialValue: entry.moltSizeMM.map { value in
            value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
        } ?? "")
        _weight = State(initialValue: entry.weightGrams.map { value in
            value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
        } ?? "")
        _tagsText = State(initialValue: entry.tags.joined(separator: ", "))
    }

    /// Poids saisi converti (virgule française acceptée).
    private var parsedWeight: Double? {
        Double(weight.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    /// Tags nettoyés à partir du champ séparé par des virgules.
    private var parsedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Catégories réellement disponibles pour les animaux visés (ordre stable).
    private var availableCategories: [ObservationCategory] {
        var seen: [ObservationCategory] = []
        for type in availableEventTypes where !seen.contains(type.category) {
            seen.append(type.category)
        }
        return seen
    }

    private func types(in category: ObservationCategory) -> [ObservationEventType] {
        availableEventTypes.filter { $0.category == category }
    }

    /// Récupère un relevé capteurs si le terrarium en expose un (best-effort).
    private func captureSnapshotIfPossible() async {
        guard editingEntry == nil, capturedSnapshot == nil,
              let ip = animal.terrarium?.sensorModuleIP,
              !ip.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        capturedSnapshot = try? await TerrariumSensorClient(ip: ip).fetchReading()
    }

    @ViewBuilder
    private func snapshotSummaryRow(_ snapshot: TerrariumSensorReading) -> some View {
        HStack(spacing: 14) {
            if let t = snapshot.temperature {
                Label("\(t, specifier: "%.1f")°C", systemImage: "thermometer.medium")
            }
            if let h = snapshot.humidity {
                Label("\(h, specifier: "%.0f")%", systemImage: "humidity")
            }
            if let s = snapshot.soilMoisture {
                Label("\(s, specifier: "%.0f")%", systemImage: "leaf")
            }
            if let l = snapshot.luminosity {
                Label("\(l, specifier: "%.0f")", systemImage: "sun.max")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// Taille saisie convertie (virgule française acceptée).
    private var parsedMoltSize: Double? {
        Double(moltSize.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    /// Analyse de diversité pour la suggestion de proie (régime de l'animal).
    private var dietAnalysis: FeedingDiversityAnalysis {
        FeedingDiversity.analyze(animal: animal)
    }
    @State private var appliedDietSuggestion = false

    /// Pré-sélectionne la proie suggérée à l'ouverture d'un nouveau repas
    /// (une seule fois — les choix manuels sont respectés ensuite).
    private func applyDietSuggestionIfNeeded() {
        guard editingEntry == nil, !appliedDietSuggestion, eventType == .feeding,
              let suggestion = dietAnalysis.suggestionRawValue else { return }
        preyTypeRawValue = suggestion
        appliedDietSuggestion = true
    }

    /// Animaux visés par l'observation (l'animal d'origine en mode simple).
    private var targetAnimals: [Animal] {
        guard allowsMultipleAnimals else { return [animal] }
        return allAnimals.filter { selectedAnimalIDs.contains($0.persistentModelID) }
    }

    /// Types d'événements proposés : union des types disponibles pour les
    /// animaux sélectionnés (un événement valable pour l'un reste proposé).
    private var availableEventTypes: [ObservationEventType] {
        let targets = targetAnimals.isEmpty ? [animal] : targetAnimals
        return ObservationEventType.allCases.filter { type in
            targets.contains { type.isAvailable(for: $0.type) }
        }
    }

    private var availablePreyTypes: [PreyType] {
        let targets = targetAnimals.isEmpty ? [animal] : targetAnimals
        return PreyType.allCases.filter { prey in
            targets.contains { prey.isAvailable(for: $0.type) }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if allowsMultipleAnimals {
                    Section("Animaux concernés") {
                        ForEach(allAnimals) { candidate in
                            Toggle(isOn: Binding(
                                get: { selectedAnimalIDs.contains(candidate.persistentModelID) },
                                set: { isOn in
                                    if isOn {
                                        selectedAnimalIDs.insert(candidate.persistentModelID)
                                    } else {
                                        selectedAnimalIDs.remove(candidate.persistentModelID)
                                    }
                                }
                            )) {
                                Label(candidate.name, systemImage: candidate.type.symbolName)
                            }
                            .tint(Brand.primary)
                        }
                    }
                }

                DatePicker("Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                Picker("Type", selection: $eventType) {
                    ForEach(availableCategories) { category in
                        Section(category.displayName) {
                            ForEach(types(in: category), id: \.self) { type in
                                Label(type.displayName, systemImage: type.symbolName).tag(type)
                            }
                        }
                    }
                }

                if eventType == .feeding {
                    Section("Repas") {
                        if editingEntry == nil, let suggestion = dietAnalysis.suggestionDisplayName {
                            Label {
                                Text("Suggestion : \(suggestion)\(dietAnalysis.reason.map { " — \($0)" } ?? "")")
                                    .font(.caption)
                            } icon: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            .foregroundStyle(Brand.primary)
                        }
                        Picker("Proie", selection: $preyTypeRawValue) {
                            ForEach(availablePreyTypes, id: \.self) { prey in
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
                        TextField("Taille après mue (mm)", text: $moltSize)
                            .keyboardType(.decimalPad)
                    }
                }

                if eventType.category == .health {
                    Section("Santé") {
                        TextField("Poids (g)", text: $weight)
                            .keyboardType(.decimalPad)
                    }
                }

                if let snapshot = capturedSnapshot, !snapshot.isEmpty {
                    Section("Relevé capteurs (au moment de l'observation)") {
                        snapshotSummaryRow(snapshot)
                    }
                }

                TextEditor(text: $note)
                    .frame(minHeight: 120)
                TextField("Tags (séparés par des virgules)", text: $tagsText)
                    .autocorrectionDisabled()
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
            .navigationTitle(editingEntry == nil ? "Nouvelle observation" : "Modifier l'observation")
            .onAppear { applyDietSuggestionIfNeeded() }
            .task { await captureSnapshotIfPossible() }
            .onChange(of: eventType) { _, _ in applyDietSuggestionIfNeeded() }
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
                        if let editingEntry {
                            // Mise à jour de l'entrée existante.
                            editingEntry.date = selectedDate
                            editingEntry.eventType = eventType.rawValue
                            editingEntry.note = note
                            editingEntry.photoPaths = photoPaths
                            editingEntry.preyType = eventType == .feeding ? preyTypeRawValue : nil
                            editingEntry.preyQuantity = eventType == .feeding ? Int(preyQuantity) : nil
                            editingEntry.eatenStatus = eventType == .feeding ? eatenStatus.rawValue : nil
                            editingEntry.captureTimeMinutes = eventType == .feeding ? Double(captureTimeMinutes) : nil
                            editingEntry.previousStage = eventType == .molt ? previousStage : nil
                            editingEntry.newStage = eventType == .molt ? newStage : nil
                            editingEntry.moltSizeMM = eventType == .molt ? parsedMoltSize : nil
                            editingEntry.weightGrams = eventType.category == .health ? parsedWeight : editingEntry.weightGrams
                            editingEntry.tags = parsedTags
                            if eventType == .molt, !newStage.isEmpty, animal.type.tracksMolting {
                                animal.currentStage = newStage
                            }
                            try? context.save()
                            dismiss()
                            return
                        }
                        // Une entrée par animal sélectionné (les photos sont
                        // partagées entre les entrées).
                        for target in targetAnimals {
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
                                moltSizeMM: eventType == .molt ? parsedMoltSize : nil,
                                snapshotTemperature: capturedSnapshot?.temperature,
                                snapshotHumidity: capturedSnapshot?.humidity,
                                snapshotSoilMoisture: capturedSnapshot?.soilMoisture,
                                snapshotLuminosity: capturedSnapshot?.luminosity,
                                weightGrams: eventType.category == .health ? parsedWeight : nil,
                                tags: parsedTags,
                                animal: target
                            )
                            context.insert(entry)
                            if eventType == .molt, !newStage.isEmpty, target.type.tracksMolting {
                                target.currentStage = newStage
                            }
                            if eventType == .feeding {
                                PreyStock.consume(
                                    typeRawValue: preyTypeRawValue,
                                    quantity: Int(preyQuantity),
                                    context: context
                                )
                            }
                        }
                        try? context.save()
                        dismiss()
                    }
                    .disabled(targetAnimals.isEmpty)
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
