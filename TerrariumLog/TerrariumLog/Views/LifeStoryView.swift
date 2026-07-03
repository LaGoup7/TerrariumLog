import SwiftUI

struct LifeStoryView: View {
    let animal: Animal
    @State private var selectedGalleryIndex: Int?

    private var yearGroups: [LifeStoryYearGroup] {
        LifeStoryGrouping.groupedByYear(animal.journalEntries)
    }

    private var allPhotos: [GalleryPhoto] {
        animal.journalEntries
            .sorted { $0.date < $1.date }
            .flatMap { entry in entry.photoPaths.map { GalleryPhoto(path: $0, date: entry.date, eventType: entry.eventType) } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if yearGroups.isEmpty {
                    Text("Pas encore d'histoire à raconter — ajoute des observations dans le journal.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    ForEach(yearGroups) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(group.year))
                                .font(.title2.bold())
                                .foregroundStyle(.teal)
                            ForEach(group.entries) { entry in
                                entryRow(entry)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Life Story · \(animal.name)")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: Binding(
            get: { selectedGalleryIndex != nil },
            set: { if !$0 { selectedGalleryIndex = nil } }
        )) {
            PhotoGalleryViewer(photos: allPhotos, selectedIndex: selectedGalleryIndex ?? 0)
        }
    }

    private func entryRow(_ entry: ObservationEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: ObservationEventType(rawValue: entry.eventType)?.symbolName ?? "note.text")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.teal)
                    .clipShape(Circle())
                Rectangle()
                    .fill(Color.teal.opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(ObservationEventType(rawValue: entry.eventType)?.displayName ?? entry.eventType)
                    .font(.subheadline.bold())
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.footnote)
                }
                if let firstPhotoPath = entry.photoPaths.first,
                   let image = PhotoStorage.shared.loadImage(from: firstPhotoPath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .onTapGesture {
                            selectedGalleryIndex = allPhotos.firstIndex { $0.path == firstPhotoPath }
                        }
                }
            }
            .padding(.bottom, 12)
        }
    }
}
