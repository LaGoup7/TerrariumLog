import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<ObservationEntry>(\.date, order: .reverse)]) private var entries: [ObservationEntry]
    @Query(sort: [SortDescriptor<Animal>(\.name)]) private var animals: [Animal]
    @State private var selectedAnimal: Animal?
    @State private var selectedCategory: ObservationCategory?
    @State private var searchText = ""
    @State private var galleryContext: TimelineGalleryContext?
    @State private var editingEntry: ObservationEntry?
    @State private var expandedIDs: Set<PersistentIdentifier> = []
    @State private var composeContext: ComposeContext?
    @State private var dismissedSuggestionIDs: Set<String> = []

    /// Galerie ouverte depuis les photos d'un événement de la timeline.
    struct TimelineGalleryContext: Identifiable {
        let id = UUID()
        let photos: [GalleryPhoto]
        let index: Int
    }

    /// Ouverture d'une nouvelle observation pré-remplie (depuis une suggestion).
    struct ComposeContext: Identifiable {
        let id = UUID()
        let animal: Animal
        let eventType: ObservationEventType
        let note: String
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
        if let selectedCategory {
            result = result.filter { $0.category == selectedCategory }
        }
        guard !searchText.isEmpty else { return result }
        return result.filter { entry in
            entry.note.localizedCaseInsensitiveContains(searchText) ||
            displayName(for: entry).localizedCaseInsensitiveContains(searchText) ||
            entry.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
            (entry.animal?.name.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    /// Catégories réellement présentes (pour les puces de filtre).
    private var presentCategories: [ObservationCategory] {
        var seen: [ObservationCategory] = []
        for entry in entries where !entry.isPhotoOnly && !seen.contains(entry.category) {
            seen.append(entry.category)
        }
        return ObservationCategory.allCases.filter { seen.contains($0) }
    }

    /// Suggestions actives (nourrissage/mue) pour tous les animaux ou l'animal
    /// filtré. Sans relevé capteurs live, seules les suggestions historiques
    /// apparaissent ici ; l'environnement est proposé à la saisie.
    private var suggestions: [JournalSuggestion] {
        let scope = selectedAnimal.map { [$0] } ?? animals
        return scope
            .flatMap { JournalSuggestionEngine.suggestions(for: $0) }
            .filter { !dismissedSuggestionIDs.contains($0.id) }
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
            List {
                if !suggestions.isEmpty {
                    Section {
                        ForEach(suggestions) { suggestion in
                            suggestionRow(suggestion)
                        }
                    } header: {
                        Text("Suggestions")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Brand.primary)
                            .textCase(nil)
                    }
                }

                if presentCategories.count > 1 {
                    Section {
                        categoryChips
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
            .fullScreenCover(item: $galleryContext) { context in
                PhotoGalleryViewer(photos: context.photos, selectedIndex: context.index)
            }
            .sheet(item: $editingEntry) { entry in
                if let animal = entry.animal {
                    JournalEntryView(animal: animal, editing: entry)
                }
            }
            .sheet(item: $composeContext) { ctx in
                JournalEntryView(animal: ctx.animal, initialEventType: ctx.eventType, initialNote: ctx.note)
            }
        }
    }

    // MARK: Suggestions

    private func suggestionRow(_ suggestion: JournalSuggestion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: suggestion.symbolName)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(severityColor(suggestion.severity), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.title)
                    .font(.subheadline.bold())
                Text("\(suggestion.animalName) · \(suggestion.reason)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                acceptSuggestion(suggestion)
            } label: {
                Text("Ajouter")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Brand.primary.opacity(0.18), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .cancel) {
                dismissedSuggestionIDs.insert(suggestion.id)
            } label: {
                Label("Ignorer", systemImage: "xmark")
            }
        }
    }

    private func acceptSuggestion(_ suggestion: JournalSuggestion) {
        guard let animal = animals.first(where: { $0.name == suggestion.animalName }) else { return }
        composeContext = ComposeContext(
            animal: animal,
            eventType: suggestion.suggestedEventType,
            note: suggestion.prefilledNote
        )
    }

    private func severityColor(_ severity: JournalSuggestion.Severity) -> Color {
        switch severity {
        case .info: return Brand.accent
        case .warning: return Brand.warning
        case .critical: return Brand.error
        }
    }

    // MARK: Filtres par catégorie

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "Tout", color: Brand.primary, isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(presentCategories) { category in
                    filterChip(
                        label: category.displayName,
                        color: Brand.color(for: category),
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.trailing, 16)
        }
    }

    private func filterChip(label: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .foregroundStyle(isSelected ? color : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.18) : Brand.surfaceElevated)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Carte d'événement

    private func entryRow(_ entry: ObservationEntry) -> some View {
        let isExpanded = expandedIDs.contains(entry.persistentModelID)
        let color = Brand.color(for: entry.category)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon(for: entry))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(color, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(displayName(for: entry))
                            .font(.subheadline.bold())
                        Text(entry.category.displayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(color.opacity(0.15), in: Capsule())
                    }
                    if let animalName = entry.animal?.name {
                        Text(animalName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }

            if !entry.note.isEmpty {
                Text(entry.note)
                    .font(.footnote)
                    .lineLimit(isExpanded ? nil : 2)
            }

            if isExpanded {
                expandedDetails(entry, color: color)
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
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isExpanded { expandedIDs.remove(entry.persistentModelID) }
                else { expandedIDs.insert(entry.persistentModelID) }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                context.delete(entry)
                try? context.save()
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
            if entry.animal != nil {
                Button {
                    editingEntry = entry
                } label: {
                    Label("Modifier", systemImage: "pencil")
                }
                .tint(Brand.accent)
            }
        }
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

    /// Détails supplémentaires affichés quand la carte est dépliée.
    @ViewBuilder
    private func expandedDetails(_ entry: ObservationEntry, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if entry.eventType == ObservationEventType.feeding.rawValue {
                let prey = entry.preyType.flatMap { PreyType(rawValue: $0)?.displayName } ?? entry.preyType
                let eaten = entry.eatenStatus.flatMap { EatenStatus(rawValue: $0)?.displayName }
                detailLine("Proie", [prey, entry.preyQuantity.map { "×\($0)" }, eaten].compactMap { $0 }.joined(separator: " · "))
                if let capture = entry.captureTimeMinutes {
                    detailLine("Capture", "\(trim(capture)) min")
                }
            }
            if entry.eventType == ObservationEventType.molt.rawValue {
                if let from = entry.previousStage, let to = entry.newStage {
                    detailLine("Stade", "\(from) → \(to)")
                }
                if let size = entry.moltSizeMM {
                    detailLine("Taille", "\(trim(size)) mm")
                }
            }
            if let weight = entry.weightGrams {
                detailLine("Poids", "\(trim(weight)) g")
            }
            if let snapshot = entry.environmentSnapshotSummary {
                detailLine("Environnement", snapshot)
            }
            if !entry.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(entry.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2)
                            .foregroundStyle(color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(color.opacity(0.12), in: Capsule())
                    }
                }
            }
        }
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
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

    private func trim(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
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
