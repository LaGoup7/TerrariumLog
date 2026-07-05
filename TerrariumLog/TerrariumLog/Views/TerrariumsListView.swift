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
                    .foregroundStyle(Brand.accent)
                    .frame(width: 50, height: 50)
                    .background(Brand.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .onAppear {
            if let path = terrarium.mainPhotoPath {
                image = ThumbnailStore.shared.thumbnail(for: path, maxDimension: 160)
            }
        }
    }
}

/// Grande carte moderne : image mise en valeur en haut, informations en dessous.
struct TerrariumCard: View {
    let terrarium: Terrarium
    @State private var image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            imageBanner
            infoPanel
        }
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous)
                .strokeBorder(Brand.hairline, lineWidth: 1)
        )
        .shadow(color: Brand.cardShadow, radius: 14, x: 0, y: 6)
        .task(id: terrarium.mainPhotoPath) {
            if let path = terrarium.mainPhotoPath {
                image = ThumbnailStore.shared.thumbnail(for: path, maxDimension: 900)
            } else {
                image = nil
            }
        }
    }

    private var imageBanner: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Brand.accent.opacity(0.35), Brand.primary.opacity(0.25)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.9))
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 210)
        .clipped()
    }

    private var infoPanel: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(terrarium.name)
                    .font(.title3.bold())
                if !terrarium.dimensions.isEmpty {
                    Text(terrarium.dimensions)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("\(terrarium.animals.count) animal(aux) hébergé(s)")
                    .font(.caption)
                    .foregroundStyle(Brand.accent)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TerrariumsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Terrarium>(\.name)]) private var terrariums: [Terrarium]
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if terrariums.isEmpty {
                        ContentUnavailableView(
                            "Aucun terrarium",
                            systemImage: "leaf",
                            description: Text("Ajoute ton premier terrarium avec le bouton +.")
                        )
                        .padding(.top, 60)
                    } else {
                        ForEach(terrariums) { terrarium in
                            NavigationLink(destination: TerrariumDetailView(terrarium: terrarium)) {
                                TerrariumCard(terrarium: terrarium)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    context.delete(terrarium)
                                    try? context.save()
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Brand.backgroundGradient.ignoresSafeArea())
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
    @State private var sensorModuleIP: String
    @State private var targetTempMin: String
    @State private var targetTempMax: String
    @State private var targetHumMin: String
    @State private var targetHumMax: String

    init(terrarium: Terrarium?) {
        self.existingTerrarium = terrarium
        _name = State(initialValue: terrarium?.name ?? "")
        _type = State(initialValue: terrarium?.type ?? .terrarium)
        _dimensions = State(initialValue: terrarium?.dimensions ?? "")
        _substrate = State(initialValue: terrarium?.substrate ?? "")
        _decor = State(initialValue: terrarium?.decor ?? "")
        _notes = State(initialValue: terrarium?.notes ?? "")
        _wizLightIP = State(initialValue: terrarium?.wizLightIP ?? "")
        _sensorModuleIP = State(initialValue: terrarium?.sensorModuleIP ?? "")
        func text(_ value: Double?) -> String {
            guard let value else { return "" }
            return value.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(value))
                : String(value)
        }
        _targetTempMin = State(initialValue: text(terrarium?.targetTemperatureMin))
        _targetTempMax = State(initialValue: text(terrarium?.targetTemperatureMax))
        _targetHumMin = State(initialValue: text(terrarium?.targetHumidityMin))
        _targetHumMax = State(initialValue: text(terrarium?.targetHumidityMax))
    }

    /// Applique les plages recommandées d'une fiche espèce aux champs cibles.
    private func applySpeciesSheet(_ sheet: SpeciesSheet) {
        targetTempMin = String(Int(sheet.temperatureMin))
        targetTempMax = String(Int(sheet.temperatureMax))
        targetHumMin = String(Int(sheet.humidityMin))
        targetHumMax = String(Int(sheet.humidityMax))
    }

    /// Convertit la saisie en nombre (accepte la virgule française).
    private func parseTarget(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
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
                Section {
                    TextField("Adresse IP du module (ex: 192.168.1.60)", text: $sensorModuleIP)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Capteurs (ESP32)")
                } footer: {
                    Text("Module DIY température/humidité/sol avec brumisation et arrosage. Guide complet : docs/capteurs-terrarium.md dans le dépôt.")
                }
                Section {
                    Menu {
                        ForEach(SpeciesSheet.catalog) { sheet in
                            Button("\(sheet.name) — \(sheet.scientificName)") {
                                applySpeciesSheet(sheet)
                            }
                        }
                    } label: {
                        Label("Pré-remplir depuis une fiche espèce", systemImage: "book.closed")
                    }
                    HStack {
                        TextField("Temp. min (°C)", text: $targetTempMin)
                        TextField("Temp. max (°C)", text: $targetTempMax)
                    }
                    .keyboardType(.decimalPad)
                    HStack {
                        TextField("Humidité min (%)", text: $targetHumMin)
                        TextField("Humidité max (%)", text: $targetHumMax)
                    }
                    .keyboardType(.decimalPad)
                } header: {
                    Text("Environnement cible")
                } footer: {
                    Text("Les relevés des capteurs sont comparés à ces plages : la carte Capteurs du terrarium signale tout écart. Laisse vide pour ignorer une grandeur.")
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
                        terrarium.sensorModuleIP = sensorModuleIP.isEmpty ? nil : sensorModuleIP
                        terrarium.targetTemperatureMin = parseTarget(targetTempMin)
                        terrarium.targetTemperatureMax = parseTarget(targetTempMax)
                        terrarium.targetHumidityMin = parseTarget(targetHumMin)
                        terrarium.targetHumidityMax = parseTarget(targetHumMax)
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
