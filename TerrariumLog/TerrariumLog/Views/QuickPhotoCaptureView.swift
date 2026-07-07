import SwiftUI
import SwiftData
import UIKit

/// Capture photo rapide depuis le Dashboard : l'appareil photo s'ouvre
/// immédiatement (« appareil d'abord »), puis un petit formulaire permet
/// d'ajouter une note et de rattacher la photo à un animal OU à un terrarium.
///
/// L'entrée créée est une `ObservationEntry` :
/// - sans note → type `.photo` (photo de galerie, hors timeline/journal) ;
/// - avec note → type `.behavior` (« Comportement ») : elle devient une vraie
///   observation, visible dans le journal de l'animal ou la fiche du terrarium.
struct QuickPhotoCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Animal>(\.dashboardSortOrder)]) private var animals: [Animal]
    @Query(sort: [SortDescriptor<Terrarium>(\.name)]) private var terrariums: [Terrarium]

    /// Cible du rattachement : un animal ou un terrarium.
    enum Target: String, CaseIterable, Identifiable {
        case animal
        case terrarium
        var id: String { rawValue }
        var displayName: String { self == .animal ? "Animal" : "Terrarium" }
    }

    @State private var capturedImage: UIImage?
    @State private var note = ""
    @State private var date = Date()
    @State private var target: Target = .animal
    @State private var selectedAnimalID: PersistentIdentifier?
    @State private var selectedTerrariumID: PersistentIdentifier?
    @State private var showingCamera = true

    private var canSave: Bool {
        capturedImage != nil && (
            (target == .animal && selectedAnimalID != nil) ||
            (target == .terrarium && selectedTerrariumID != nil)
        )
    }

    /// Cibles proposées : on ne montre le sélecteur animal/terrarium que pour les
    /// catégories qui contiennent au moins un élément.
    private var availableTargets: [Target] {
        var result: [Target] = []
        if !animals.isEmpty { result.append(.animal) }
        if !terrariums.isEmpty { result.append(.terrarium) }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if capturedImage == nil {
                    // En attente de la capture : l'appareil photo est présenté
                    // en plein écran par-dessus ce fond neutre.
                    Color.clear
                } else {
                    formContent
                }
            }
            .background(Brand.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Nouvelle photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") { save() }
                        .disabled(!canSave)
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera, onDismiss: {
            // Appareil photo fermé sans photo (annulation) → on referme tout.
            if capturedImage == nil { dismiss() }
        }) {
            CameraCaptureView { image in
                capturedImage = image
            }
            .ignoresSafeArea()
        }
        .onAppear(perform: applyDefaultSelection)
    }

    @ViewBuilder
    private var formContent: some View {
        Form {
            if let image = capturedImage {
                Section {
                    HStack {
                        Spacer()
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Spacer()
                    }
                    Button {
                        capturedImage = nil
                        showingCamera = true
                    } label: {
                        Label("Reprendre la photo", systemImage: "arrow.clockwise.circle")
                    }
                    .font(.caption)
                }
                .listRowBackground(Color.clear)
            }

            Section("Rattacher à") {
                if availableTargets.count > 1 {
                    Picker("Type", selection: $target) {
                        ForEach(availableTargets) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if target == .animal {
                    Picker("Animal", selection: $selectedAnimalID) {
                        ForEach(animals) { animal in
                            Label(animal.name, systemImage: animal.type.symbolName)
                                .tag(Optional(animal.persistentModelID))
                        }
                    }
                } else {
                    Picker("Terrarium", selection: $selectedTerrariumID) {
                        ForEach(terrariums) { terrarium in
                            Label(terrarium.name, systemImage: "leaf")
                                .tag(Optional(terrarium.persistentModelID))
                        }
                    }
                }
            }

            Section("Note d'observation") {
                TextEditor(text: $note)
                    .frame(minHeight: 100)
            }

            Section {
                DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
            }
        }
    }

    /// Pré-sélectionne une cible par défaut à l'ouverture (premier animal, sinon
    /// premier terrarium) pour que « Enregistrer » soit actif d'emblée.
    private func applyDefaultSelection() {
        selectedAnimalID = animals.first?.persistentModelID
        selectedTerrariumID = terrariums.first?.persistentModelID
        if animals.isEmpty, !terrariums.isEmpty {
            target = .terrarium
        }
    }

    private func save() {
        guard let image = capturedImage else { return }
        let targetAnimal = target == .animal
            ? animals.first { $0.persistentModelID == selectedAnimalID }
            : nil
        let targetTerrarium = target == .terrarium
            ? terrariums.first { $0.persistentModelID == selectedTerrariumID }
            : nil
        guard targetAnimal != nil || targetTerrarium != nil else { return }

        let nameForFile = targetAnimal?.name ?? targetTerrarium?.name ?? "photo"
        guard let path = try? PhotoStorage.shared.saveImage(image, for: nameForFile) else { return }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        // Une note fait de la photo une vraie observation (« Comportement »),
        // sinon elle reste une simple photo de galerie.
        let eventType: ObservationEventType = trimmedNote.isEmpty ? .photo : .behavior
        let entry = ObservationEntry(
            date: date,
            eventType: eventType.rawValue,
            note: trimmedNote,
            photoPaths: [path],
            animal: targetAnimal,
            terrarium: targetTerrarium
        )
        context.insert(entry)
        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
