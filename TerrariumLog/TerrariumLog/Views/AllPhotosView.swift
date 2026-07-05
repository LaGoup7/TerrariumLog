import SwiftUI
import SwiftData

/// Galerie globale : toutes les photos prises dans l'app (journaux des animaux,
/// photos de profil, photos des terrariums), triées de la plus récente à la
/// plus ancienne. Un tap ouvre la visionneuse plein écran (zoom inclus).
struct AllPhotosView: View {
    @Query private var animals: [Animal]
    @Query private var terrariums: [Terrarium]

    @State private var viewerContext: ViewerContext?

    struct ViewerContext: Identifiable {
        let id = UUID()
        let index: Int
    }

    /// Toutes les photos connues, dédupliquées et triées par date décroissante.
    private var photos: [GalleryPhoto] {
        var seen = Set<String>()
        var result: [GalleryPhoto] = []

        for animal in animals {
            for entry in animal.journalEntries {
                for path in entry.photoPaths where seen.insert(path).inserted {
                    result.append(GalleryPhoto(path: path, date: entry.date, eventType: entry.eventType))
                }
            }
            if let path = animal.primaryPhotoPath, seen.insert(path).inserted {
                result.append(GalleryPhoto(path: path, date: animal.arrivalDate, eventType: ObservationEventType.photo.rawValue))
            }
        }
        for terrarium in terrariums {
            if let path = terrarium.mainPhotoPath, seen.insert(path).inserted {
                result.append(GalleryPhoto(path: path, date: terrarium.createdAt, eventType: ObservationEventType.photo.rawValue))
            }
        }
        return result.sorted { $0.date > $1.date }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ScrollView {
            if photos.isEmpty {
                ContentUnavailableView(
                    "Aucune photo",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Les photos prises dans l'app (journal, profils, terrariums) apparaîtront ici.")
                )
                .padding(.top, 80)
            } else {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        PhotoGridCell(path: photo.path)
                            .onTapGesture {
                                viewerContext = ViewerContext(index: index)
                            }
                    }
                }
                .padding(.top, 2)
            }
        }
        .background(Brand.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Photos (\(photos.count))")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $viewerContext) { context in
            PhotoGalleryViewer(photos: photos, selectedIndex: context.index)
        }
    }
}

/// Cellule carrée de la grille photos.
struct PhotoGridCell: View {
    let path: String
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
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
            .frame(width: proxy.size.width, height: proxy.size.width)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            if image == nil {
                image = ThumbnailStore.shared.thumbnail(for: path, maxDimension: 360)
            }
        }
    }
}
