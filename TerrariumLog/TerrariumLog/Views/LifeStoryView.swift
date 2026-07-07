import SwiftUI

struct LifeStoryView: View {
    let animal: Animal
    @State private var selectedGalleryIndex: Int?
    @State private var exportedPDF: ExportedPDF?

    @State private var exportedCSV: ExportedFile?

    struct ExportedPDF: Identifiable {
        let id = UUID()
        let url: URL
    }

    struct ExportedFile: Identifiable {
        let id = UUID()
        let url: URL
    }

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
                                .foregroundStyle(Brand.primary)
                            ForEach(group.entries) { entry in
                                entryRow(entry)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Brand.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Life Story · \(animal.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        if let url = LifeStoryPDFExporter.export(animal: animal) {
                            exportedPDF = ExportedPDF(url: url)
                        }
                    } label: {
                        Label("Exporter en PDF", systemImage: "doc.richtext")
                    }
                    Button {
                        if let url = JournalCSVExporter.export(animal: animal) {
                            exportedCSV = ExportedFile(url: url)
                        }
                    } label: {
                        Label("Exporter en CSV", systemImage: "tablecells")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(item: $exportedCSV) { csv in
            NavigationStack {
                VStack(spacing: 16) {
                    Image(systemName: "tablecells")
                        .font(.system(size: 48))
                        .foregroundStyle(Brand.primary)
                    Text("Journal exporté en CSV")
                        .font(.headline)
                    ShareLink(item: csv.url) {
                        Label("Partager le CSV", systemImage: "square.and.arrow.up")
                            .font(.body.weight(.semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Brand.primary.opacity(0.16), in: Capsule())
                    }
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fermer") { exportedCSV = nil }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $exportedPDF) { pdf in
            NavigationStack {
                VStack(spacing: 16) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 48))
                        .foregroundStyle(Brand.primary)
                    Text("Life Story exportée en PDF")
                        .font(.headline)
                    ShareLink(item: pdf.url) {
                        Label("Partager le PDF", systemImage: "square.and.arrow.up")
                            .font(.body.weight(.semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Brand.primary.opacity(0.16), in: Capsule())
                    }
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fermer") { exportedPDF = nil }
                    }
                }
            }
            .presentationDetents([.medium])
        }
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
                    .background(Brand.primary)
                    .clipShape(Circle())
                Rectangle()
                    .fill(Brand.primary.opacity(0.3))
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
