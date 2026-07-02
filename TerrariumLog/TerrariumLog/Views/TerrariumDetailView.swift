import SwiftUI
import SwiftData

struct TerrariumDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let terrarium: Terrarium

    @State private var showingAddPlant = false
    @State private var showingAddPrintedPart = false
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                infoSection
                animalsSection
                plantsSection
                printedPartsSection
                measurementsSection
            }
            .padding()
        }
        .navigationTitle(terrarium.name)
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(isPresented: $showingAddPrintedPart) {
            AddPrintedPartView(terrarium: terrarium)
        }
        .sheet(isPresented: $showingEditSheet) {
            TerrariumFormView(terrarium: terrarium)
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
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var printedPartsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Pièces imprimées 3D")
                    .font(.headline)
                Spacer()
                Button { showingAddPrintedPart = true } label: {
                    Image(systemName: "plus.circle")
                }
            }
            if terrarium.printedParts.isEmpty {
                Text("Aucune pièce enregistrée")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(terrarium.printedParts) { part in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(part.name)
                                .font(.subheadline)
                            Text("\(part.material.displayName) · \(part.technology.displayName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            context.delete(part)
                            try? context.save()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var measurementsSection: some View {
        let recent = terrarium.animals
            .flatMap(\.measurements)
            .sorted { $0.date > $1.date }
            .prefix(5)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Dernières mesures")
                    .font(.headline)
                Spacer()
                NavigationLink("Voir tout") {
                    MeasurementsView()
                }
                .font(.caption)
            }
            if recent.isEmpty {
                Text("Aucune mesure enregistrée")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
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

struct AddPrintedPartView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let terrarium: Terrarium

    @State private var name = ""
    @State private var material: PrintMaterial = .petg
    @State private var technology: PrintTechnology = .fdm
    @State private var usageNotes = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nom", text: $name)
                Picker("Matériau", selection: $material) {
                    ForEach(PrintMaterial.allCases, id: \.self) { material in
                        Text(material.displayName).tag(material)
                    }
                }
                Picker("Technologie", selection: $technology) {
                    ForEach(PrintTechnology.allCases, id: \.self) { technology in
                        Text(technology.displayName).tag(technology)
                    }
                }
                TextField("Usage (ex: couvercle, fond, support capteur)", text: $usageNotes)
                TextField("Notes", text: $notes)
            }
            .navigationTitle("Ajouter une pièce 3D")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        let part = PrintedPart(name: name, material: material, technology: technology, usageNotes: usageNotes, printedDate: .now, notes: notes, terrarium: terrarium)
                        context.insert(part)
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
