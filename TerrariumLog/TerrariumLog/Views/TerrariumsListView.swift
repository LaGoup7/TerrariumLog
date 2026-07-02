import SwiftUI
import SwiftData

struct TerrariumsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Terrarium>(\.name)]) private var terrariums: [Terrarium]
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            List(terrariums) { terrarium in
                NavigationLink(destination: TerrariumDetailView(terrarium: terrarium)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(terrarium.name)
                            .font(.headline)
                        if !terrarium.dimensions.isEmpty {
                            Text(terrarium.dimensions)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(terrarium.animals.count) animal(aux) hébergé(s)")
                            .font(.caption)
                            .foregroundStyle(.teal)
                    }
                }
            }
            .navigationTitle("Terrariums")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddTerrariumView()
            }
        }
    }
}

struct AddTerrariumView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var type: TerrariumType = .terrarium
    @State private var dimensions = ""
    @State private var substrate = ""
    @State private var decor = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Nom", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(TerrariumType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    TextField("Dimensions (ex: 20 x 20 x 35 cm)", text: $dimensions)
                    TextField("Substrat", text: $substrate)
                    TextField("Décor", text: $decor)
                }
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Ajouter un terrarium")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        let terrarium = Terrarium(
                            name: name,
                            type: type,
                            notes: notes,
                            dimensions: dimensions,
                            substrate: substrate,
                            decor: decor
                        )
                        context.insert(terrarium)
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
