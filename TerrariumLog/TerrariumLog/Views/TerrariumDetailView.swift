import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct TerrariumDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let terrarium: Terrarium

    @State private var showingAddPlant = false
    @State private var showingAddCamera = false
    @State private var showingAddLight = false
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    @State private var mainImage: UIImage?
    @State private var photoPickerSource: ImagePickerSource?

    @State private var sensorReading: TerrariumSensorReading?
    @State private var isFetchingSensors = false
    @State private var sensorMessage: String?
    @State private var runningAction: SensorAction?
    @State private var didRecordReading = false

    private enum SensorAction { case mist, water }

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                photoSection
                infoSection
                if terrarium.sensorModuleIP != nil {
                    sensorsSection
                }
                lightSection
                camerasSection
                animalsSection
                plantsSection
                measurementsSection
            }
            .padding()
        }
        .background(Brand.backgroundGradient.ignoresSafeArea())
        .navigationTitle(terrarium.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let path = terrarium.mainPhotoPath {
                mainImage = PhotoStorage.shared.loadImage(from: path)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Modifier") { showingEditSheet = true }
                    Button("Supprimer", role: .destructive) { showingDeleteConfirmation = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Supprimer \(terrarium.name) ?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                context.delete(terrarium)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("Les animaux hébergés ne seront pas supprimés, mais perdront leur terrarium associé.")
        }
        .sheet(isPresented: $showingAddPlant) {
            AddPlantView(terrarium: terrarium)
        }
        .sheet(isPresented: $showingAddCamera) {
            CameraConfigView(terrarium: terrarium)
        }
        .sheet(isPresented: $showingAddLight) {
            LightConfigView(terrarium: terrarium)
        }
        .sheet(isPresented: $showingEditSheet) {
            TerrariumFormView(terrarium: terrarium)
        }
        .fullScreenCover(item: $photoPickerSource) { source in
            CroppingImagePicker(sourceType: source.type) { image in
                setMainImage(image)
            }
            .ignoresSafeArea()
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let mainImage {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(uiImage: mainImage)
                            .resizable()
                            .scaledToFill()
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Brand.surfaceElevated)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(Brand.accent)
                    )
            }
            HStack {
                Button {
                    photoPickerSource = ImagePickerSource(type: .photoLibrary)
                } label: {
                    Label("Changer la photo", systemImage: "photo")
                }
                if isCameraAvailable {
                    Button {
                        photoPickerSource = ImagePickerSource(type: .camera)
                    } label: {
                        Label("Prendre une photo", systemImage: "camera")
                    }
                }
            }
            .font(.caption)
        }
    }

    private func setMainImage(_ image: UIImage) {
        if let path = try? PhotoStorage.shared.saveImage(image, for: terrarium.name) {
            terrarium.mainPhotoPath = path
            terrarium.mainPhotoOffsetX = 0
            terrarium.mainPhotoOffsetY = 0
            try? context.save()
            mainImage = image
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(terrarium.type.displayName)
                .font(.title2.bold())
            if !terrarium.dimensions.isEmpty {
                LabeledContent("Dimensions", value: terrarium.dimensions)
            }
            if !terrarium.substrate.isEmpty {
                LabeledContent("Substrat", value: terrarium.substrate)
            }
            if !terrarium.decor.isEmpty {
                LabeledContent("Décor", value: terrarium.decor)
            }
            if let min = terrarium.targetTemperatureMin, let max = terrarium.targetTemperatureMax {
                LabeledContent("Température cible", value: "\(Int(min))–\(Int(max))°C")
            }
            if let min = terrarium.targetHumidityMin, let max = terrarium.targetHumidityMax {
                LabeledContent("Humidité cible", value: "\(Int(min))–\(Int(max))%")
            }
            if !terrarium.notes.isEmpty {
                Text(terrarium.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var lightSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Lumières")
                    .font(.headline)
                Spacer()
                Button { showingAddLight = true } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
            }
            if terrarium.lights.isEmpty {
                Text("Aucune lampe associée. Ajoute-la avec le +.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(terrarium.lights) { light in
                    NavigationLink(destination: LightControlView(light: light)) {
                        HStack {
                            Image(systemName: light.lastKnownOn ? "lightbulb.fill" : "lightbulb")
                                .foregroundStyle(light.lastKnownOn ? Brand.warning : Color.secondary)
                            VStack(alignment: .leading) {
                                Text(light.name)
                                    .font(.subheadline)
                                Text(light.brand.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Circle()
                                .fill(light.isConfigured ? Brand.success : Brand.warning)
                                .frame(width: 8, height: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            context.delete(light)
                            try? context.save()
                        } label: {
                            Label("Supprimer", systemImage: "trash")
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

    private var camerasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Caméra(s)")
                    .font(.headline)
                Spacer()
                Button { showingAddCamera = true } label: {
                    Image(systemName: "plus.circle")
                }
            }
            if terrarium.cameras.isEmpty {
                Text("Aucune caméra associée")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(terrarium.cameras) { camera in
                    NavigationLink(destination: CameraLiveView(camera: camera)) {
                        HStack {
                            Circle()
                                .fill(camera.isConfigured ? Brand.success : Brand.warning)
                                .frame(width: 8, height: 8)
                            Text(camera.name)
                            Spacer()
                            Text(camera.isConfigured ? "Configurée" : "Non configurée")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            context.delete(camera)
                            try? context.save()
                        } label: {
                            Label("Supprimer la caméra", systemImage: "trash")
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

    private var animalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Animaux hébergés")
                .font(.headline)
            if terrarium.animals.isEmpty {
                Text("Aucun animal associé")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(terrarium.animals) { animal in
                    NavigationLink(destination: AnimalDetailView(animal: animal)) {
                        HStack {
                            Text(animal.name)
                            Spacer()
                            Text(animal.status.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
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

    private var plantsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Plantes")
                    .font(.headline)
                Spacer()
                Button { showingAddPlant = true } label: {
                    Image(systemName: "plus.circle")
                }
            }
            if terrarium.plants.isEmpty {
                Text("Aucune plante")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(terrarium.plants) { plant in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(plant.name)
                                .font(.subheadline)
                            if let lastWatered = plant.lastWatered {
                                Text("Arrosée le \(lastWatered.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(plant.status.displayName)
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(plantStatusColor(plant.status).opacity(0.2))
                            .clipShape(Capsule())
                        Button {
                            context.delete(plant)
                            try? context.save()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Brand.error)
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

    // MARK: Capteurs (module ESP32 — voir docs/capteurs-terrarium.md)

    private var sensorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Capteurs")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await refreshSensors() }
                } label: {
                    if isFetchingSensors {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isFetchingSensors)
            }

            if let reading = sensorReading {
                HStack(spacing: 10) {
                    if let temperature = reading.temperature {
                        sensorTile(icon: "thermometer.medium", value: String(format: "%.1f°C", temperature), label: "Air", color: Brand.warning)
                    }
                    if let humidity = reading.humidity {
                        sensorTile(icon: "humidity.fill", value: String(format: "%.0f %%", humidity), label: "Humidité", color: Brand.accent)
                    }
                    if let soil = reading.soilMoisture {
                        sensorTile(icon: "leaf.fill", value: String(format: "%.0f %%", soil), label: "Sol", color: Brand.primary)
                    }
                    if let luminosity = reading.luminosity {
                        sensorTile(icon: "sun.max.fill", value: String(format: "%.0f", luminosity), label: "Lumière", color: Brand.warning)
                    }
                }

                HStack(spacing: 10) {
                    sensorActionButton(title: "Brumiser", icon: "cloud.fog.fill", action: .mist)
                    sensorActionButton(title: "Arroser", icon: "drop.fill", action: .water)
                    Spacer()
                    Button {
                        recordReading(reading)
                    } label: {
                        Label(didRecordReading ? "Enregistrée" : "Enregistrer",
                              systemImage: didRecordReading ? "checkmark" : "square.and.arrow.down")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .disabled(didRecordReading || terrarium.animals.isEmpty)
                }
            } else if isFetchingSensors {
                Text("Lecture du module…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Module injoignable. Vérifie que l'ESP32 est allumé et sur le même Wi-Fi, puis actualise.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let sensorMessage {
                Text(sensorMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .task { await refreshSensors() }
    }

    private func sensorTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Brand.surfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sensorActionButton(title: String, icon: String, action: SensorAction) -> some View {
        Button {
            runSensorAction(action)
        } label: {
            HStack(spacing: 5) {
                if runningAction == action {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Brand.primary.opacity(0.16), in: Capsule())
            .foregroundStyle(Brand.primary)
        }
        .buttonStyle(.plain)
        .disabled(runningAction != nil)
    }

    private func refreshSensors() async {
        guard let ip = terrarium.sensorModuleIP, !ip.isEmpty else { return }
        isFetchingSensors = true
        sensorMessage = nil
        do {
            sensorReading = try await TerrariumSensorClient(ip: ip).fetchReading()
            didRecordReading = false
        } catch {
            sensorMessage = "Capteurs : \(error.localizedDescription)"
        }
        isFetchingSensors = false
    }

    private func runSensorAction(_ action: SensorAction) {
        guard let ip = terrarium.sensorModuleIP, !ip.isEmpty else { return }
        runningAction = action
        Task {
            let client = TerrariumSensorClient(ip: ip)
            do {
                switch action {
                case .mist: try await client.triggerMist()
                case .water: try await client.triggerWater()
                }
                sensorMessage = action == .mist ? "Brumisation déclenchée." : "Arrosage déclenché."
            } catch {
                sensorMessage = "Action impossible : \(error.localizedDescription)"
            }
            runningAction = nil
        }
    }

    /// Ajoute le relevé à l'historique de chaque animal hébergé (ils partagent
    /// l'environnement du terrarium) : les graphiques existants se remplissent.
    private func recordReading(_ reading: TerrariumSensorReading) {
        for animal in terrarium.animals {
            let entry = MeasurementEntry(
                date: .now,
                temperature: reading.temperature,
                humidity: reading.humidity,
                luminosity: reading.luminosity,
                note: "Capteurs · \(terrarium.name)",
                animal: animal
            )
            context.insert(entry)
        }
        try? context.save()
        didRecordReading = true
        sensorMessage = "Mesure ajoutée à l'historique."
    }

    private var measurementsSection: some View {
        let allMeasurements = terrarium.animals.flatMap(\.measurements)
        let recent = allMeasurements.sorted { $0.date > $1.date }.prefix(5)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Mesures")
                    .font(.headline)
                Spacer()
                NavigationLink("Voir tout") {
                    MeasurementsView()
                }
                .font(.caption)
            }
            if allMeasurements.isEmpty {
                Text("Aucune mesure enregistrée")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                EnvironmentChartsView(measurements: allMeasurements)
                Text("Dernières mesures")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(Array(recent)) { measurement in
                    HStack {
                        Text(measurement.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                        Spacer()
                        if let temperature = measurement.temperature {
                            Text("\(temperature, specifier: "%.1f")°C")
                                .font(.caption)
                        }
                        if let humidity = measurement.humidity {
                            Text("\(humidity, specifier: "%.0f")%")
                                .font(.caption)
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

    private func plantStatusColor(_ status: PlantStatus) -> Color {
        switch status {
        case .ok: return Brand.success
        case .dry, .tooHumid: return Brand.warning
        case .mold, .pest: return Brand.error
        }
    }
}

struct AddPlantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let terrarium: Terrarium

    @State private var name = ""
    @State private var species = ""
    @State private var status: PlantStatus = .ok
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nom", text: $name)
                TextField("Espèce", text: $species)
                Picker("État", selection: $status) {
                    ForEach(PlantStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                TextField("Notes", text: $notes)
            }
            .navigationTitle("Ajouter une plante")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        let plant = Plant(name: name, species: species, status: status, notes: notes, terrarium: terrarium)
                        context.insert(plant)
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
