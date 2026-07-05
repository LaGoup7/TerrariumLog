import SwiftUI

/// Comparateur avant/après : deux photos de l'animal côte à côte, chacune
/// choisie par date — parfait pour visualiser la croissance entre deux stades.
struct EvolutionCompareView: View {
    @Environment(\.dismiss) private var dismiss
    /// Photos de l'animal, dans l'ordre chronologique croissant.
    let photos: [GalleryPhoto]

    @State private var leftIndex: Int
    @State private var rightIndex: Int

    init(photos: [GalleryPhoto]) {
        self.photos = photos
        _leftIndex = State(initialValue: 0)
        _rightIndex = State(initialValue: max(photos.count - 1, 0))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 10) {
                    comparePane(title: "Avant", selection: $leftIndex)
                    comparePane(title: "Après", selection: $rightIndex)
                }
                if photos.indices.contains(leftIndex), photos.indices.contains(rightIndex) {
                    let days = Calendar.current.dateComponents(
                        [.day],
                        from: photos[leftIndex].date,
                        to: photos[rightIndex].date
                    ).day ?? 0
                    Text(days == 0 ? "Même jour" : "\(abs(days)) jours d'écart")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Brand.accent)
                }
                Spacer()
            }
            .padding()
            .background(Brand.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Évolution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func comparePane(title: String, selection: Binding<Int>) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Group {
                if photos.indices.contains(selection.wrappedValue),
                   let image = ThumbnailStore.shared.thumbnail(for: photos[selection.wrappedValue].path, maxDimension: 700) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Brand.surfaceElevated)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Picker(title, selection: selection) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                    Text(photo.date.formatted(date: .abbreviated, time: .omitted)).tag(index)
                }
            }
            .pickerStyle(.menu)
            .tint(Brand.primary)
        }
        .frame(maxWidth: .infinity)
    }
}
