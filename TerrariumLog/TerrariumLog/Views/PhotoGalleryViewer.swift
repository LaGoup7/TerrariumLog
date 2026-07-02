import SwiftUI

struct GalleryPhoto: Identifiable {
    let id = UUID()
    let path: String
    let date: Date
    let eventType: String

    var eventDisplayName: String {
        ObservationEventType(rawValue: eventType)?.displayName ?? eventType
    }
}

struct PhotoGalleryViewer: View {
    let photos: [GalleryPhoto]
    @State var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                    VStack(spacing: 12) {
                        Spacer()
                        if let image = PhotoStorage.shared.loadImage(from: photo.path) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                        }
                        Spacer()
                        VStack(spacing: 4) {
                            Text(photo.eventDisplayName)
                                .font(.headline)
                            Text(photo.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .foregroundStyle(.white)
                        .padding(.bottom, 24)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, .black.opacity(0.4))
            }
            .padding()
        }
    }
}
