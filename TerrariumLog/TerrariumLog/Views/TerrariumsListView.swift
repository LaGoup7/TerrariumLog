import SwiftUI
import SwiftData

struct TerrariumThumbnail: View {
    let terrarium: Terrarium
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(.teal)
                    .frame(width: 50, height: 50)
                    .background(Color.teal.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .onAppear {
            if let path = terrarium.mainPhotoPath {
                image = PhotoStorage.shared.loadImage(from: path)
            }
        }
    }
}

struct TerrariumsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Terrarium>(\.name)]) private var terrariums: [Terrarium]
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(terrariums) { terrarium in
                    NavigationLink(destination: TerrariumDetailView(terrarium: terrarium)) {
                        HStack(spacing: 12) {
                            TerrariumThumbnail(terrarium: terrarium)
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
                    .swipeActions {
                        Button(role: .destructive) {
                            context.delete(terrarium)
                            try? context.save()
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
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
                TerrariumFormView(terrarium: nil)
            }
        }
    }
}

struct TerrariumFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let existingTerrarium: Terrarium?

    @State private var name: String
    @State private var type: TerrariumType
    @State private var dimensions: String
    @State private var substrate: String
    @State private var decor: String
    @State private var notes: String
    @State private var wizLightIP: String

    init(terrarium: Terrarium?) {
        self.existingTerrarium = terrarium
        _name = State(initialValue: terrarium?.name ?? "")
        _type = State(initialValue: terrarium?.type ?? .terrarium)
        _dimensions = State(initialValue: terrarium?.dimensions ?? "")
        _substrate = State(initialValue: terrarium?.substrate ?? "")
        _decor = State(initialValue: terrarium?.decor ?? "")
        _notes = State(initialValue: terrarium?.notes ?? "")
        _wizLightIP = State(initialValue: terrarium?.wizLightIP ?? "")
    }

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
                Section("Éclairage") {
                    TextField("Adresse IP lampe WiZ (ex: 192.168.1.42)", text: $wizLightIP)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(existingTerrarium == nil ? "Ajouter un terrarium" : "Modifier le terrarium")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        let terrarium = existingTerrarium ?? Terrarium(name: "", type: .terrarium)
                        terrarium.name = name
                        terrarium.type = type
                        terrarium.dimensions = dimensions
                        terrarium.substrate = substrate
                        terrarium.decor = decor
                        terrarium.notes = notes
                        terrarium.wizLightIP = wizLightIP.isEmpty ? nil : wizLightIP
                        if existingTerrarium == nil {
                            context.insert(terrarium)
                        }
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
