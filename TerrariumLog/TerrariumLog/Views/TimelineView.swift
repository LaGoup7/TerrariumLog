import SwiftUI
import SwiftData

struct TimelineView: View {
    @Query(sort: [SortDescriptor<ObservationEntry>(\.date, order: .reverse)]) private var entries: [ObservationEntry]
    @Query(sort: [SortDescriptor<Animal>(\.name)]) private var animals: [Animal]
    @State private var selectedAnimal: Animal?
    @State private var searchText = ""

    private var filteredEntries: [ObservationEntry] {
        var result = entries
        if let selectedAnimal {
            result = result.filter { $0.animal?.id == selectedAnimal.id }
        }
        guard !searchText.isEmpty else { return result }
        return result.filter { entry in
            entry.note.localizedCaseInsensitiveContains(searchText) ||
            displayName(for: entry).localizedCaseInsensitiveContains(searchText) ||
            (entry.animal?.name.localizedCaseInsensitiveContains(searchText) ?? false)
        }
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
            .searchable(text: $searchText, prompt: "Rechercher dans le journal")
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
        case .photo: return "photo"
        default: return "note.text"
        }
    }
}
