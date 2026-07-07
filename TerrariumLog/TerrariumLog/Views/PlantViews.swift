import SwiftUI
import SwiftData
import UIKit

/// Fiche d'une plante : photo, arrosage en un geste, suivi d'échéance,
/// état de santé avec conseil, édition directe des informations.
struct PlantDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var plant: Plant

    @State private var photoImage: UIImage?
    @State private var photoPickerSource: ImagePickerSource?
    @State private var showingDeleteConfirmation = false
    /// Feedback éphémère après l'arrosage (✓ pendant 2 s).
    @State private var justWatered = false

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    /// Binding du suivi d'arrosage : activer = 7 jours par défaut.
    private var wateringTrackingEnabled: Binding<Bool> {
        Binding(
            get: { plant.wateringIntervalDays != nil },
            set: { enabled in
                plant.wateringIntervalDays = enabled ? (plant.wateringIntervalDays ?? 7) : nil
                try? context.save()
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                photoSection
                wateringSection
                healthSection
                infoSection
            }
            .padding()
        }
        .background(Brand.backgroundGradient.ignoresSafeArea())
        .navigationTitle(plant.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let path = plant.photoPath {
                photoImage = PhotoStorage.shared.loadImage(from: path)
            }
        }
        .onDisappear {
            try? context.save()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Supprimer la plante", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Supprimer \(plant.name) ?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let path = plant.photoPath {
                    try? PhotoStorage.shared.deleteImage(at: path)
                }
                context.delete(plant)
                try? context.save()
                dismiss()
            }
        }
        .fullScreenCover(item: $photoPickerSource) { source in
            CroppingImagePicker(sourceType: source.type) { image in
                setPhoto(image)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: Photo

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let photoImage {
                Color.clear
                    .aspectRatio(1.4, contentMode: .fit)
                    .overlay(
                        Image(uiImage: photoImage)
                            .resizable()
                            .scaledToFill()
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Brand.surfaceElevated)
                    .aspectRatio(1.4, contentMode: .fit)
                    .overlay(
                        Image(systemName: "leaf")
                            .font(.largeTitle)
                            .foregroundStyle(Brand.primary)
                    )
            }
            HStack {
                Button {
                    photoPickerSource = ImagePickerSource(type: .photoLibrary)
                } label: {
                    Label("Choisir une photo", systemImage: "photo")
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

    private func setPhoto(_ image: UIImage) {
        if let oldPath = plant.photoPath {
            try? PhotoStorage.shared.deleteImage(at: oldPath)
        }
        if let path = try? PhotoStorage.shared.saveImage(image, for: "plante_\(plant.name)") {
            plant.photoPath = path
            try? context.save()
            photoImage = image
        }
    }

    // MARK: Arrosage

    private var wateringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Arrosage")
                .font(.headline)

            Button {
                plant.markWatered()
                try? context.save()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation { justWatered = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { justWatered = false }
                }
            } label: {
                Label(justWatered ? "C'est noté !" : "Arrosée aujourd'hui",
                      systemImage: justWatered ? "checkmark.circle.fill" : "drop.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(justWatered ? Brand.success : Brand.accent)

            HStack {
                Image(systemName: "drop")
                    .foregroundStyle(Brand.accent)
                Text(plant.lastWateredLabel.prefix(1).capitalized + plant.lastWateredLabel.dropFirst())
                    .font(.subheadline)
                Spacer()
            }

            Toggle(isOn: wateringTrackingEnabled) {
                Text("Suivre l'arrosage")
                    .font(.subheadline)
            }
            .tint(Brand.primary)

            if let interval = plant.wateringIntervalDays {
                Stepper(value: Binding(
                    get: { interval },
                    set: { newValue in
                        plant.wateringIntervalDays = newValue
                        try? context.save()
                    }
                ), in: 1...60) {
                    Text("Tous les \(interval) jour\(interval > 1 ? "s" : "")")
                        .font(.subheadline)
                }

                if let due = plant.wateringDueDate {
                    Label(
                        plant.isWateringDue
                            ? "À arroser (échéance \(due.formatted(date: .abbreviated, time: .omitted)))"
                            : "Prochain arrosage : \(due.formatted(date: .abbreviated, time: .omitted))",
                        systemImage: plant.isWateringDue ? "exclamationmark.triangle.fill" : "calendar"
                    )
                    .font(.caption)
                    .foregroundStyle(plant.isWateringDue ? Brand.warning : Color.secondary)
                }
                Text("L'échéance apparaît sur la fiche du terrarium et en alerte sur le Dashboard. Pour une notification, ajoute un rappel « Arrosage des plantes » depuis le Dashboard.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .brandCard()
    }

    // MARK: État de santé

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("État")
                .font(.headline)
            Picker("État", selection: $plant.status) {
                ForEach(PlantStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: plant.status) { _, _ in
                try? context.save()
            }
            if let advice = plant.status.advice {
                Label(advice, systemImage: "lightbulb")
                    .font(.caption)
                    .foregroundStyle(Brand.warning)
            }
        }
        .brandCard()
    }

    // MARK: Informations

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Informations")
                .font(.headline)
            TextField("Nom", text: $plant.name)
                .textFieldStyle(.roundedBorder)
            TextField("Espèce (ex : Fittonia albivenis)", text: $plant.species)
                .textFieldStyle(.roundedBorder)
            LabeledContent("Ajoutée le", value: plant.addedDate.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
            if let terrarium = plant.terrarium {
                LabeledContent("Terrarium", value: terrarium.name)
                    .font(.subheadline)
            }
            TextField("Notes", text: $plant.notes, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
        }
        .brandCard()
    }
}

/// Formulaire d'ajout d'une plante à un terrarium.
struct AddPlantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let terrarium: Terrarium

    @State private var name = ""
    @State private var species = ""
    @State private var status: PlantStatus = .ok
    @State private var notes = ""
    @State private var trackWatering = false
    @State private var wateringInterval = 7
    @State private var wateredToday = true

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
                Section("Arrosage") {
                    Toggle("Suivre l'arrosage", isOn: $trackWatering)
                        .tint(Brand.primary)
                    if trackWatering {
                        Stepper("Tous les \(wateringInterval) jour\(wateringInterval > 1 ? "s" : "")",
                                value: $wateringInterval, in: 1...60)
                        Toggle("Arrosée aujourd'hui", isOn: $wateredToday)
                            .tint(Brand.primary)
                    }
                }
                Section("Notes") {
                    TextField("Notes", text: $notes)
                }
            }
            .navigationTitle("Ajouter une plante")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        let plant = Plant(
                            name: name,
                            species: species,
                            lastWatered: trackWatering && wateredToday ? .now : nil,
                            status: status,
                            notes: notes,
                            wateringIntervalDays: trackWatering ? wateringInterval : nil,
                            terrarium: terrarium
                        )
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

/// Vignette carrée d'une plante (photo ou pictogramme feuille).
struct PlantThumbnail: View {
    let plant: Plant
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "leaf")
                    .font(.callout)
                    .foregroundStyle(Brand.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Brand.surfaceElevated)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onAppear {
            if image == nil, let path = plant.photoPath {
                image = ThumbnailStore.shared.thumbnail(for: path, maxDimension: 120)
            }
        }
    }
}
