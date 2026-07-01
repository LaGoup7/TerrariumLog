import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\.name)]) private var animals: [Animal]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection

                    ForEach(animals) { animal in
                        AnimalCardView(animal: animal)
                    }
                }
                .padding()
            }
            .navigationTitle("Terrarium Log")
            .background(LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.15), Color.teal.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bienvenue")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Suivez l’évolution de vos colonies")
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AnimalCardView: View {
    let animal: Animal
    @State private var image: UIImage?

    var body: some View {
        NavigationLink(destination: AnimalDetailView(animal: animal)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    imageView
                    VStack(alignment: .leading, spacing: 4) {
                        Text(animal.name)
                            .font(.headline)
                        Text(animal.species)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Label(animal.type.displayName, systemImage: animal.type.symbolName)
                            .font(.footnote)
                            .foregroundStyle(.teal)
                    }
                }

                HStack {
                    Label(animal.currentStage, systemImage: "leaf")
                        .font(.footnote)
                    Spacer()
                    Text(animal.status.displayName)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.teal.opacity(0.2))
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Dernier événement")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(animal.journalEntries.sorted { $0.date > $1.date }.first?.eventType ?? "Aucun")
                        .font(.subheadline)
                }

                if let reminder = animal.reminders.sorted(by: { $0.reminderDate < $1.reminderDate }).first {
                    Label("Prochain rappel : \(reminder.title)", systemImage: "bell.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .onAppear {
            if let path = animal.primaryPhotoPath {
                image = PhotoStorage.shared.loadImage(from: path)
            }
        }
    }

    private var imageView: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Image(systemName: animal.type == .antColony ? "ant.fill" : "spider.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                    .padding(12)
                    .background(Color.teal.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}
