import SwiftUI

/// A square-cropped image the user can pan by dragging to choose which part is visible.
/// `offsetX`/`offsetY` are persisted by the caller (via `onCommit`) so the chosen framing
/// survives across app launches.
struct RepositionableSquareImage: View {
    let image: UIImage
    @Binding var offsetX: Double
    @Binding var offsetY: Double
    var onCommit: () -> Void = {}

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            let side = geometry.size.width
            let imageAspect = image.size.width / max(image.size.height, 1)
            let renderedSize: CGSize = imageAspect > 1
                ? CGSize(width: side * imageAspect, height: side)
                : CGSize(width: side, height: side / imageAspect)
            let maxOffsetX = max(0, (renderedSize.width - side) / 2)
            let maxOffsetY = max(0, (renderedSize.height - side) / 2)

            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .offset(
                    x: clamped(offsetX + dragOffset.width, max: maxOffsetX),
                    y: clamped(offsetY + dragOffset.height, max: maxOffsetY)
                )
                .frame(width: side, height: side)
                .clipped()
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            offsetX = clamped(offsetX + value.translation.width, max: maxOffsetX)
                            offsetY = clamped(offsetY + value.translation.height, max: maxOffsetY)
                            dragOffset = .zero
                            onCommit()
                        }
                )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func clamped(_ value: Double, max maxValue: Double) -> Double {
        min(max(value, -maxValue), maxValue)
    }
}
