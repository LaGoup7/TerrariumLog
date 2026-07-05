import SwiftUI
import SwiftData

struct TimelineView: View {
    @Query(sort: [SortDescriptor<ObservationEntry>(\.date, order: .reverse)]) private var entries: [ObservationEntry]
    @Query(sort: [SortDescriptor<Animal>(\.name)]) private var animals: [Animal]
    @State private var selectedAnimal: Animal?
    @State private var searchText = ""
    @State private var galleryContext: TimelineGalleryContext?

    /// Galerie ouverte depuis les photos d'un événement de la timeline.
    struct TimelineGalleryContext: Identifiable {
        let id = UUID()
        let photos: [GalleryPhoto]
        let index: Int
    }

    private var filteredEntries: [ObservationEntry] {
        // Les ajouts de photos (type .photo) ne sont pas des événements : ils
        // restent dans la galerie mais n'apparaissent pas dans la timeline.
        var result = entries.filter { !$0.isPhotoOnly }
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
                image = PhotoStorage.shared.loadImage(from: path)
            }
        }
    }
}
