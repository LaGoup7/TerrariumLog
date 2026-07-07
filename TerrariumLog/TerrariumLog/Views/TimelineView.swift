import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<ObservationEntry>(\.date, order: .reverse)]) private var entries: [ObservationEntry]
    @Query(sort: [SortDescriptor<Animal>(\.name)]) private var animals: [Animal]
    @State private var selectedAnimal: Animal?
    @State private var selectedEventType: String?
    @State private var searchText = ""
    @State private var galleryContext: TimelineGalleryContext?
    @State private var editingEntry: ObservationEntry?
    /// Contenu affiché : journal des événements ou grille de toutes les photos.
    @State private var displayMode: DisplayMode = .journal

    enum DisplayMode: String, CaseIterable, Identifiable {
        case journal
        case photos
        var id: String { rawValue }
        var displayName: String { self == .journal ? "Journal" : "Photos" }
    }

    /// Galerie ouverte depuis les photos d'un événement de la timeline.
    struct TimelineGalleryContext: Identifiable {
        let id = UUID()
        let photos: [GalleryPhoto]
        let index: Int
    }

    /// Groupe mensuel pour les en-têtes de section.
    struct MonthGroup: Identifiable {
        let id: String
        let title: String
        let entries: [ObservationEntry]
    }

    private var filteredEntries: [ObservationEntry] {
        // Les ajouts de photos (type .photo) ne sont pas des événements : ils
        // restent dans la galerie mais n'apparaissent pas dans la timeline.
        var result = entries.filter { !$0.isPhotoOnly }
        if let selectedAnimal {
            result = result.filter { $0.animal?.id == selectedAnimal.id }
        }
        if let selectedEventType {
            result = result.filter { $0.eventType == selectedEventType }
        }
        guard !searchText.isEmpty else { return result }
        return result.filter { entry in
            entry.note.localizedCaseInsensitiveContains(searchText) ||
            displayName(for: entry).localizedCaseInsensitiveContains(searchText) ||
            (entry.animal?.name.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    /// Types d'événements réellement présents (pour les puces de filtre).
    private var presentEventTypes: [String] {
        var seen: [String] = []
        for entry in entries where !entry.isPhotoOnly && !seen.contains(entry.eventType) {
            seen.append(entry.eventType)
        }
        return seen
    }

    /// Entrées groupées par mois, du plus récent au plus ancien.
    private var monthGroups: [MonthGroup] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"

        var groups: [String: [ObservationEntry]] = [:]
        var order: [String] = []
        for entry in filteredEntries {
            let components = calendar.dateComponents([.year, .month], from: entry.date)
            let key = "\(components.year ?? 0)-\(components.month ?? 0)"
            if groups[key] == nil {
                order.append(key)
            }
            groups[key, default: []].append(entry)
        }
        return order.map { key in
            let sample = groups[key]?.first?.date ?? .now
            return MonthGroup(
                id: key,
                title: formatter.string(from: sample).capitalized,
                entries: groups[key] ?? []
            )
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if displayMode == .journal {
                    journalList
                } else {
                    AllPhotosView()
                }
            }
            // Sélecteur Journal / Photos toujours visible en tête d'écran.
            .safeAreaInset(edge: .top, spacing: 0) {
                Picker("Affichage", selection: $displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .navigationTitle("Timeline")
            .toolbar {
                if displayMode == .journal {
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
            .fullScreenCover(item: $galleryContext) { context in
                PhotoGalleryViewer(photos: context.photos, selectedIndex: context.index)
            }
            .sheet(item: $editingEntry) { entry in
                if let animal = entry.animal {
                    JournalEntryView(animal: animal, editing: entry)
                }
            }
        }
    }

    private var journalList: some View {
        List {
            if presentEventTypes.count > 1 {
                Section {
                    eventTypeChips
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 0))
            }

            ForEach(monthGroups) { group in
                Section {
                    ForEach(group.entries) { entry in
                        entryRow(entry)
                    }
                } header: {
                    Text(group.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Brand.primary)
                        .textCase(nil)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Rechercher dans le journal")
    }

    /// Puces de filtre par type d'événement.
    private var eventTypeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "Tous", isSelected: selectedEventType == nil) {
                    selectedEventType = nil
                }
                ForEach(presentEventTypes, id: \.self) { eventType in
                    filterChip(
                        label: ObservationEventType(rawValue: eventType)?.displayName ?? eventType,
                        isSelected: selectedEventType == eventType
                    ) {
                        selectedEventType = selectedEventType == eventType ? nil : eventType
                    }
                }
            }
            .padding(.trailing, 16)
        }
    }

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .foregroundStyle(isSelected ? Brand.primary : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Brand.primary.opacity(0.18) : Brand.surfaceElevated)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func entryRow(_ entry: ObservationEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon(for: entry))
                .font(.title3)
                .foregroundStyle(Brand.accent)
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
                if !entry.photoPaths.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(entry.photoPaths.enumerated()), id: \.offset) { photoIndex, path in
                                TimelinePhotoThumbnail(path: path)
                                    .onTapGesture {
                                        galleryContext = TimelineGalleryContext(
                                            photos: galleryPhotos(for: entry),
                                            index: photoIndex
                                        )
                                    }
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            if entry.animal != nil {
                Button {
                    editingEntry = entry
                } label: {
                    Label("Modifier", systemImage: "pencil")
                }
            }
            Button(role: .destructive) {
                context.delete(entry)
                try? context.save()
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }

    private func displayName(for entry: ObservationEntry) -> String {
        ObservationEventType(rawValue: entry.eventType)?.displayName ?? entry.eventType
    }

    private func icon(for entry: ObservationEntry) -> String {
        ObservationEventType(rawValue: entry.eventType)?.symbolName ?? "note.text"
    }

    private func galleryPhotos(for entry: ObservationEntry) -> [GalleryPhoto] {
        entry.photoPaths.map { path in
            GalleryPhoto(path: path, date: entry.date, eventType: entry.eventType)
        }
    }
}

/// Miniature d'une photo d'événement dans la timeline.
struct TimelinePhotoThumbnail: View {
    let path: String
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Brand.surfaceElevated)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onAppear {
            if image == nil {
                image = ThumbnailStore.shared.thumbnail(for: path, maxDimension: 200)
            }
        }
    }
}
