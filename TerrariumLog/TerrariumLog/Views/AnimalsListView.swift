import SwiftUI
import SwiftData

struct AnimalsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Animal>(\.name)]) private var animals: [Animal]
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            List(animals) { animal in
                NavigationLink(destination: AnimalDetailView(animal: animal)) {
                    HStack(spacing: 12) {
                        Image(systemName: animal.type == .antColony ? "ant.fill" : "spider.fill")
                            .font(.title2)
                            .foregroundStyle(.teal)
                        VStack(alignment: .leading) {
                            Text(animal.name)
                                .font(.headline)
                            Text(animal.species)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(animal.status.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Animaux")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddAnimalView()
            }
        }
    }
}

struct AddAnimalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Terrarium>(\.name)]) private var terrariums: [Terrarium]

    @State private var name = ""
    @State private var species = ""
    @State private var scientificName = ""
    @State private var type: AnimalType = .antColony
    @State private var sex: AnimalSex = .unknown
    @State private var origin: AnimalOrigin = .captured
    @State private var locality = ""
    @State private var breeder = ""
    @State private var purchasePrice = ""
    @State private var status: AnimalStatus = .foundation
    @State private var currentStage = ""
    @State private var notes = ""
    @State private var selectedTerrarium: Terrarium?

    @State private var estimatedWorkerCount = ""
    @State private var queenCount = ""
    @State private var broodPresent = false

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
                    Picker("Statut", selection: $status) {
                        ForEach(AnimalStatus.allCases, id: \.self) { status in
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
            .navigationTitle("Ajouter un animal")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        let animal = Animal(
                            name: name,
                            species: species,
                            scientificName: scientificName.isEmpty ? nil : scientificName,
                            type: type,
                            sex: sex,
                            origin: origin,
                            locality: locality.isEmpty ? nil : locality,
                            breeder: breeder.isEmpty ? nil : breeder,
                            purchasePrice: Double(purchasePrice),
                            arrivalDate: Date(),
                            currentStage: currentStage,
                            status: status,
                            notes: notes,
                            estimatedWorkerCount: Int(estimatedWorkerCount),
                            queenCount: Int(queenCount),
                            broodPresent: broodPresent
                        )
                        animal.terrarium = selectedTerrarium
                        context.insert(animal)
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
