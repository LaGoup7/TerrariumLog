import SwiftUI
import SwiftData
import PhotosUI

struct AnimalDetailView: View {
    @Environment(\.modelContext) private var context
    let animal: Animal

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingJournalSheet = false
    @State private var showingMeasurementSheet = false
    @State private var notes = ""
    @State private var primaryImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                infoSection
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
                    Button("Ajouter une mesure") { showingMeasurementSheet = true }
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
        }
        .sheet(isPresented: $showingJournalSheet) {
            JournalEntryView(animal: animal)
        }
        .sheet(isPresented: $showingMeasurementSheet) {
            MeasurementEntryView(animal: animal)
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
            LabeledContent("Origine", value: animal.origin.displayName)
            LabeledContent("Date d’arrivée", value: animal.arrivalDate.formatted(date: .abbreviated, time: .omitted))
            LabeledContent("Stade actuel", value: animal.currentStage)
            LabeledContent("Statut", value: animal.status.displayName)
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

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Journal")
                .font(.headline)
            ForEach(animal.journalEntries.sorted { $0.date > $1.date }) { entry in
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
                    ForEach(animal.journalEntries.flatMap(\.photoPaths)) { path in
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
                    Text("T: \(measurement.temperature.map(String.init) ?? "—")")
                        .font(.caption)
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
    @State private var eventType: ObservationEventType = .other
    @State private var note = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var photoPaths: [String] = []

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                Picker("Type", selection: $eventType) {
                    ForEach(ObservationEventType.allCases.filter { $0.isAvailable(for: animal.type) }, id: \.self) { type in
                        Text(type.displayName).tag(type)
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
                        let entry = ObservationEntry(date: selectedDate, eventType: eventType.rawValue, note: note, photoPaths: photoPaths, animal: animal)
                        context.insert(entry)
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
    @Query(sort: [SortDescriptor(\.name)]) private var animals: [Animal]
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
