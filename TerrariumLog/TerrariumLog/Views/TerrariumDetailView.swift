import SwiftUI
import SwiftData
import Charts

struct TerrariumDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let terrarium: Terrarium

    @State private var showingAddPlant = false
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    @State private var lightIsOn = false
    @State private var lightBrightness: Double = 100
    @State private var lightError: String?
    @State private var isSendingLightCommand = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                infoSection
                lightSection
                animalsSection
                plantsSection
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

    private var lightSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lumière")
                .font(.headline)
            if let ip = terrarium.wizLightIP, !ip.isEmpty {
                Toggle("Allumée", isOn: $lightIsOn)
                    .disabled(isSendingLightCommand)
                    .onChange(of: lightIsOn) { _, newValue in
                        sendLightCommand(WizCommandBuilder.power(newValue), ip: ip)
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Intensité : \(Int(lightBrightness))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $lightBrightness, in: 10...100, step: 5) { editing in
                        if !editing {
                            sendLightCommand(WizCommandBuilder.brightness(Int(lightBrightness)), ip: ip)
                        }
                    }
                    .disabled(isSendingLightCommand)
                }
                HStack {
                    Button("Chaud") { sendLightCommand(WizCommandBuilder.colorTemperature(2700), ip: ip) }
                    Button("Neutre") { sendLightCommand(WizCommandBuilder.colorTemperature(4000), ip: ip) }
                    Button("Froid") { sendLightCommand(WizCommandBuilder.colorTemperature(6500), ip: ip) }
                }
                .buttonStyle(.bordered)
                .disabled(isSendingLightCommand)
                if let lightError {
                    Text(lightError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } else {
                Text("Aucune lampe WiZ configurée. Ajoute son adresse IP locale dans « Modifier ».")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func sendLightCommand(_ command: WizCommand, ip: String) {
        isSendingLightCommand = true
        Task {
            do {
                try await WizLightService.shared.send(command, to: ip)
                lightError = nil
            } catch {
                lightError = "Lampe injoignable à \(ip). Vérifie qu'elle est sur le même Wi-Fi."
            }
            isSendingLightCommand = false
        }
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

    private var measurementsSection: some View {
        let allMeasurements = terrarium.animals.flatMap(\.measurements)
        let chronological = allMeasurements.sorted { $0.date < $1.date }.suffix(30)
        let recent = allMeasurements.sorted { $0.date > $1.date }.prefix(5)
        let stats = MeasurementStats.compute(from: allMeasurements)

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
                if chronological.contains(where: { $0.temperature != nil }) {
                    Text("Température")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Chart(Array(chronological.filter { $0.temperature != nil })) { measurement in
                        LineMark(
                            x: .value("Date", measurement.date),
                            y: .value("°C", measurement.temperature ?? 0)
                        )
                    }
                    .foregroundStyle(.orange)
                    .frame(height: 100)
                    if let min = stats.minTemperature, let max = stats.maxTemperature, let avg = stats.avgTemperature {
                        Text("Min \(min, specifier: "%.1f")°C · Max \(max, specifier: "%.1f")°C · Moy \(avg, specifier: "%.1f")°C")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if chronological.contains(where: { $0.humidity != nil }) {
                    Text("Humidité")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Chart(Array(chronological.filter { $0.humidity != nil })) { measurement in
                        LineMark(
                            x: .value("Date", measurement.date),
                            y: .value("%", measurement.humidity ?? 0)
                        )
                    }
                    .foregroundStyle(.blue)
                    .frame(height: 100)
                    if let min = stats.minHumidity, let max = stats.maxHumidity, let avg = stats.avgHumidity {
                        Text("Min \(min, specifier: "%.0f")% · Max \(max, specifier: "%.0f")% · Moy \(avg, specifier: "%.0f")%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
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
