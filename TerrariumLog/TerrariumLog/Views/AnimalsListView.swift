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

    @State private var name = ""
    @State private var species = ""
    @State private var type: AnimalType = .antColony
    @State private var origin: AnimalOrigin = .captured
    @State private var status: AnimalStatus = .foundation
    @State private var currentStage = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Nom", text: $name)
                    TextField("Espèce", text: $species)
                    Picker("Type", selection: $type) {
                        ForEach(AnimalType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    Picker("Origine", selection: $origin) {
                        ForEach(AnimalOrigin.allCases, id: \.self) { origin in
                            Text(origin.displayName).tag(origin)
                        }
                    }
                    Picker("Statut", selection: $status) {
                        ForEach(AnimalStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    TextField("Stade actuel", text: $currentStage)
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
                        let animal = Animal(name: name, species: species, type: type, origin: origin, arrivalDate: Date(), currentStage: currentStage, status: status, notes: notes)
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
