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

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                photoSection
                infoSection
                lightSection
                camerasSection
                animalsSection
                plantsSection
                measurementsSection
            }
            .padding()
        }
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
                    .fill(Color.teal.opacity(0.15))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.teal)
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
        .background(.ultraThinMaterial)
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
                                .foregroundStyle(light.lastKnownOn ? .yellow : .secondary)
                            VStack(alignment: .leading) {
                                Text(light.name)
                                    .font(.subheadline)
                                Text(light.brand.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Circle()
                                .fill(light.isConfigured ? Color.green : Color.orange)
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
        .background(.ultraThinMaterial)
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
                                .fill(camera.isConfigured ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(camera.name)
                            Spacer()
                            Text(camera.isConfigured ? "Configurée" : "Non configurée")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
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
        .background(.ultraThinMaterial)
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
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func plantStatusColor(_ status: PlantStatus) -> Color {
        switch status {
        case .ok: return .green
        case .dry, .tooHumid: return .orange
        case .mold, .pest: return .red
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
