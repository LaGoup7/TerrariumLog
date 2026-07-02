import SwiftUI
import SwiftData

struct TimelineView: View {
    @Query(sort: [SortDescriptor<ObservationEntry>(\.date, order: .reverse)]) private var entries: [ObservationEntry]
    @Query(sort: [SortDescriptor<Animal>(\.name)]) private var animals: [Animal]
    @State private var selectedAnimal: Animal?

    private var filteredEntries: [ObservationEntry] {
        guard let selectedAnimal else { return entries }
        return entries.filter { $0.animal?.id == selectedAnimal.id }
    }

    var body: some View {
        NavigationStack {
            List(filteredEntries) { entry in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: icon(for: entry))
                        .font(.title3)
                        .foregroundStyle(.teal)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName(for: entry))
                            .font(.subheadline.bold())
                        if let animalName = entry.animal?.name {
                            Text(animalName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !entry.note.isEmpty {
                            Text(entry.note)
                                .font(.footnote)
                        }
                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Timeline")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Tous les animaux") { selectedAnimal = nil }
                        ForEach(animals) { animal in
                            Button(animal.name) { selectedAnimal = animal }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }

    private func displayName(for entry: ObservationEntry) -> String {
        ObservationEventType(rawValue: entry.eventType)?.displayName ?? entry.eventType
    }

    private func icon(for entry: ObservationEntry) -> String {
        switch ObservationEventType(rawValue: entry.eventType) {
        case .feeding: return "fork.knife"
        case .foodRefusal: return "xmark.circle"
        case .molt: return "arrow.triangle.2.circlepath"
        case .arrival, .capture: return "sparkles"
        case .death: return "heart.slash"
        case .humidifying: return "drop"
        case .cleaning: return "sparkle"
        case .webBuilding: return "circle.hexagongrid"
        case .laying, .eggs: return "circle.grid.2x2"
        case .larvae, .cocoons, .firstWorkers: return "ant"
        default: return "note.text"
        }
    }
}
