import SwiftUI
import SwiftData

struct MeasurementsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<MeasurementEntry>(\.date, order: .reverse)]) private var measurements: [MeasurementEntry]
    @State private var showingSheet = false

    var body: some View {
        List {
            ForEach(measurements) { measurement in
                VStack(alignment: .leading, spacing: 6) {
                    Text(measurement.animal?.name ?? "Sans animal")
                        .font(.headline)
                    Text(measurement.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let temperature = measurement.temperature {
                        Text("Température : \(temperature, specifier: "%.1f")°C")
                    }
                    if let humidity = measurement.humidity {
                        Text("Humidité : \(humidity, specifier: "%.1f")%")
                    }
                    if let luminosity = measurement.luminosity {
                        Text("Luminosité : \(luminosity, specifier: "%.0f")")
                    }
                    if let waterLevel = measurement.waterLevel {
                        Text("Niveau d’eau : \(waterLevel, specifier: "%.0f")")
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        context.delete(measurement)
                        try? context.save()
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Mesures")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingSheet = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingSheet) {
            MeasurementEntryView(animal: nil)
        }
    }
}
