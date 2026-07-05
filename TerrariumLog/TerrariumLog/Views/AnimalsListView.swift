import SwiftUI
import SwiftData

struct AnimalsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Animal>(\.name)]) private var animals: [Animal]
    @State private var showingAddSheet = false
    @State private var searchText = ""

    private var filteredAnimals: [Animal] {
        guard !searchText.isEmpty else { return animals }
        return animals.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.species.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredAnimals) { animal in
                    NavigationLink(destination: AnimalDetailView(animal: animal)) {
                        HStack(spacing: 14) {
                            AnimalRowThumbnail(animal: animal)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(animal.name)
                                    .font(.headline)
                                Text(animal.species)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let colonySummary = animal.colonySummary {
                                    Text(colonySummary)
                                        .font(.caption)
                                        .foregroundStyle(Brand.accent)
                                }
                            }
                            Spacer(minLength: 8)
                            Text(animal.status.displayName)
                                .font(.caption.bold())
                                .foregroundStyle(Brand.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Brand.primary.opacity(0.16))
                                .clipShape(Capsule())
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            context.delete(animal)
                            try? context.save()
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Animaux")
            .searchable(text: $searchText, prompt: "Rechercher un animal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AnimalFormView(animal: nil)
            }
        }
    }
}

/// Vignette de profil pour les lignes de la liste des animaux : affiche la photo
/// principale si elle existe, sinon le symbole du type sur une surface neutre.
struct AnimalRowThumbnail: View {
    let animal: Animal
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: animal.type.symbolName)
                    .font(.title2)
                    .foregroundStyle(Brand.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Brand.surfaceElevated)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            if image == nil, let path = animal.primaryPhotoPath {
                image = PhotoStorage.shared.loadImage(from: path)
            }
        }
    }
}

struct AnimalFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Terrarium>(\.name)]) private var terrariums: [Terrarium]

    let existingAnimal: Animal?

    @State private var name: String
    @State private var species: String
    @State private var scientificName: String
    @State private var type: AnimalType
    @State private var sex: AnimalSex
    @State private var origin: AnimalOrigin
    @State private var locality: String
    @State private var breeder: String
    @State private var purchasePrice: String
    @State private var arrivalDate: Date
    @State private var status: AnimalStatus
    @State private var currentStage: String
    @State private var notes: String
    @State private var selectedTerrarium: Terrarium?

    @State private var estimatedWorkerCount: String
    @State private var queenCount: String
    @State private var broodPresent: Bool

    init(animal: Animal?) {
        self.existingAnimal = animal
        _name = State(initialValue: animal?.name ?? "")
        _species = State(initialValue: animal?.species ?? "")
        _scientificName = State(initialValue: animal?.scientificName ?? "")
        _type = State(initialValue: animal?.type ?? .antColony)
        _sex = State(initialValue: animal?.sex ?? .unknown)
        _origin = State(initialValue: animal?.origin ?? .captured)
        _locality = State(initialValue: animal?.locality ?? "")
        _breeder = State(initialValue: animal?.breeder ?? "")
        _purchasePrice = State(initialValue: animal?.purchasePrice.map { String($0) } ?? "")
        _arrivalDate = State(initialValue: animal?.arrivalDate ?? .now)
        _status = State(initialValue: animal?.status ?? .foundation)
        _currentStage = State(initialValue: animal?.currentStage ?? "")
        _notes = State(initialValue: animal?.notes ?? "")
        _selectedTerrarium = State(initialValue: animal?.terrarium)
        _estimatedWorkerCount = State(initialValue: animal?.estimatedWorkerCount.map { String($0) } ?? "")
        _queenCount = State(initialValue: animal?.queenCount.map { String($0) } ?? "")
        _broodPresent = State(initialValue: animal?.broodPresent ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Nom", text: $name)
                    TextField("Espèce", text: $species)
                    TextField("Nom scientifique", text: $scientificName)
                    Picker("Type", selection: $type) {
                        ForEach(AnimalType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .onChange(of: type) { _, newType in
                        if !status.isAvailable(for: newType) {
                            status = .normal
                        }
                    }
                    Picker("Sexe", selection: $sex) {
                        ForEach(AnimalSex.allCases, id: \.self) { sex in
                            Text(sex.displayName).tag(sex)
                        }
                    }
                    Picker("Origine", selection: $origin) {
                        ForEach(AnimalOrigin.allCases, id: \.self) { origin in
                            Text(origin.displayName).tag(origin)
                        }
                    }
                    TextField("Localité (ex: Soroa, Cuba)", text: $locality)
                    TextField("Éleveur / fournisseur", text: $breeder)
                    TextField("Prix d’achat", text: $purchasePrice)
                        .keyboardType(.decimalPad)
                    DatePicker("Date d’arrivée", selection: $arrivalDate, displayedComponents: .date)
                    Picker("Statut", selection: $status) {
                        ForEach(AnimalStatus.allCases.filter { $0.isAvailable(for: type) }, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    TextField("Stade actuel", text: $currentStage)
                    Picker("Terrarium", selection: $selectedTerrarium) {
                        Text("Aucun").tag(nil as Terrarium?)
                        ForEach(terrariums) { terrarium in
                            Text(terrarium.name).tag(terrarium as Terrarium?)
                        }
                    }
                }

                if type == .antColony {
                    Section("Colonie") {
                        TextField("Nombre d’ouvrières estimé", text: $estimatedWorkerCount)
                            .keyboardType(.numberPad)
                        TextField("Nombre de reines", text: $queenCount)
                            .keyboardType(.numberPad)
                        Toggle("Couvain présent", isOn: $broodPresent)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle(existingAnimal == nil ? "Ajouter un animal" : "Modifier l’animal")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func save() {
        let animal = existingAnimal ?? Animal(
            name: "",
            species: "",
            type: .antColony,
            origin: .captured,
            arrivalDate: Date(),
            currentStage: "",
            status: .foundation,
            notes: ""
        )

        animal.name = name
        animal.species = species
        animal.scientificName = scientificName.isEmpty ? nil : scientificName
        animal.type = type
        animal.sex = sex
        animal.origin = origin
        animal.locality = locality.isEmpty ? nil : locality
        animal.breeder = breeder.isEmpty ? nil : breeder
        animal.purchasePrice = Double(purchasePrice)
        animal.arrivalDate = arrivalDate
        animal.status = status
        animal.currentStage = currentStage
        animal.notes = notes
        animal.terrarium = selectedTerrarium
        animal.estimatedWorkerCount = Int(estimatedWorkerCount)
        animal.queenCount = Int(queenCount)
        animal.broodPresent = broodPresent

        if existingAnimal == nil {
            let maxOrder = (try? context.fetch(FetchDescriptor<Animal>()))?.map(\.dashboardSortOrder).max() ?? -1
            animal.dashboardSortOrder = maxOrder + 1
            context.insert(animal)
        }
        try? context.save()
    }
}
