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
                        if let image = PhotoStorage.shared.loadImage(from: photo.path) {
                            ZoomableImage(image: image)
                        } else {
                            Spacer()
                        }
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

/// Image zoomable : pincer pour zoomer (1×–4×), double-tap pour basculer
/// 1× ↔ 2,5×, glisser pour se déplacer une fois zoomé. Le glissement de page
/// du TabView reste actif tant qu'on est à 1× (pas de conflit de gestes).
struct ZoomableImage: View {
    let image: UIImage

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(magnification(in: proxy.size))
                // Le déplacement n'est actif que zoomé : à 1×, le TabView garde
                // son glissement de page.
                .gesture(pan(in: proxy.size), including: scale > 1 ? .all : .subviews)
                .onTapGesture(count: 2) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        if scale > 1 {
                            resetZoom()
                        } else {
                            scale = 2.5
                            lastScale = 2.5
                        }
                    }
                }
                .animation(.easeOut(duration: 0.15), value: scale)
        }
    }

    private func magnification(in size: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, minScale), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 {
                    withAnimation(.easeOut(duration: 0.2)) { resetZoom() }
                } else {
                    clampOffset(in: size)
                }
            }
    }

    private func pan(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                clampOffset(in: size)
            }
    }

    /// Ramène l'image dans les bords visibles après un déplacement.
    private func clampOffset(in size: CGSize) {
        let maxX = size.width * (scale - 1) / 2
        let maxY = size.height * (scale - 1) / 2
        withAnimation(.easeOut(duration: 0.2)) {
            offset = CGSize(
                width: min(max(offset.width, -maxX), maxX),
                height: min(max(offset.height, -maxY), maxY)
            )
        }
        lastOffset = offset
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}
