import SwiftUI
import SwiftData
import PhotosUI
import Charts

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
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                infoSection
                if animal.type == .antColony {
                    colonySection
                }
                feedingSection
                moltSection
                journalSection
                gallerySection
                measurementsSection
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
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Ajouter une observation") { showingJournalSheet = true }
                    Button("Ajouter un repas") { showingFeedingSheet = true }
                    Button("Ajouter une mue") { showingMoltSheet = true }
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
        .sheet(isPresented: $showingMeasurementSheet) {
            MeasurementEntryView(animal: animal)
        }
        .sheet(isPresented: $showingEditSheet) {
            AnimalFormView(animal: animal)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                if let primaryImage {
                    Image(uiImage: primaryImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    Image(systemName: animal.type == .antColony ? "ant.fill" : "spider.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .padding()
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
            }

            PhotosPicker(selection: $selectedItems, maxSelectionCount: 1, matching: .images) {
                Label("Changer la photo principale", systemImage: "photo")
            }
            .onChange(of: selectedItems) { _, newItems in
                guard let first = newItems.first else { return }
                Task {
                    if let data = try? await first.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        if let path = try? PhotoStorage.shared.saveImage(image, for: animal.name) {
                            animal.primaryPhotoPath = path
                            try? context.save()
                            primaryImage = image
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
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

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Journal")
                .font(.headline)
            ForEach(animal.journalEntries.sorted { $0.date > $1.date }) { entry in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.eventType)
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

    private var gallerySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Galerie")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(animal.journalEntries.flatMap(\.photoPaths), id: \.self) { path in
                        if let image = PhotoStorage.shared.loadImage(from: path) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 110, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var measurementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mesures récentes")
                .font(.headline)
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
}

struct JournalEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let animal: Animal

    @State private var selectedDate = Date()
    @State private var eventType: ObservationEventType
    @State private var note = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var photoPaths: [String] = []

    // Champs repas
    @State private var preyType: PreyType = .drosophile
    @State private var preyQuantity = ""
    @State private var eatenStatus: EatenStatus = .yes
    @State private var captureTimeMinutes = ""

    // Champs mue
    @State private var previousStage: String
    @State private var newStage = ""

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
                        Picker("Proie", selection: $preyType) {
                            ForEach(PreyType.allCases, id: \.self) { prey in
                                Text(prey.displayName).tag(prey)
                            }
                        }
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
            }
            .navigationTitle("Nouvelle observation")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        let entry = ObservationEntry(
                            date: selectedDate,
                            eventType: eventType.rawValue,
                            note: note,
                            photoPaths: photoPaths,
                            preyType: eventType == .feeding ? preyType.rawValue : nil,
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
