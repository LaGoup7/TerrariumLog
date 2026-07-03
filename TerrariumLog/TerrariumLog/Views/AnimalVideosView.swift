import SwiftUI
import SwiftData
import PhotosUI
import AVKit
import UniformTypeIdentifiers

/// Wraps a video file picked via `PhotosPicker` so it can be copied into `VideoStorage`
/// once the transfer completes (the received file lives in a transient location).
struct TransferableVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(received.file.lastPathComponent)
            if FileManager.default.fileExists(atPath: copy.path) {
                try? FileManager.default.removeItem(at: copy)
            }
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}

struct AnimalVideosSection: View {
    @Environment(\.modelContext) private var context
    let animal: Animal

    @State private var showingAddVideo = false
    @State private var selectedVideo: AnimalVideo?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Vidéos")
                    .font(.headline)
                Spacer()
                Button {
                    showingAddVideo = true
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
            if animal.videos.isEmpty {
                Text("Aucune vidéo")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(animal.videos.sorted { $0.date > $1.date }) { video in
                    Button {
                        selectedVideo = video
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.teal)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(video.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                if !video.notes.isEmpty {
                                    Text(video.notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(video.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            deleteVideo(video)
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .sheet(isPresented: $showingAddVideo) {
            AddAnimalVideoView(animal: animal)
        }
        .fullScreenCover(item: $selectedVideo) { video in
            AnimalVideoPlayerView(video: video)
        }
    }

    private func deleteVideo(_ video: AnimalVideo) {
        try? VideoStorage.shared.deleteVideo(at: video.videoPath)
        context.delete(video)
        try? context.save()
    }
}

struct AddAnimalVideoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let animal: Animal

    @State private var title = ""
    @State private var notes = ""
    @State private var date = Date()
    @State private var selectedItem: PhotosPickerItem?
    @State private var pendingVideoURL: URL?
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var importProgress: Progress?
    @State private var progressFraction: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Vidéo") {
                    PhotosPicker(selection: $selectedItem, matching: .videos) {
                        Label(pendingVideoURL == nil ? "Choisir une vidéo" : "Vidéo sélectionnée", systemImage: "video.badge.plus")
                    }
                    if isImporting {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: progressFraction)
                            HStack {
                                Text("\(Int(progressFraction * 100)) %")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Annuler l'import", role: .destructive) {
                                    cancelImport()
                                }
                                .font(.caption)
                            }
                        }
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                Section("Détails") {
                    TextField("Titre", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                    DatePicker("Date", selection: $date)
                }
            }
            .navigationTitle("Nouvelle vidéo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(title.isEmpty || pendingVideoURL == nil)
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                startImport(of: newItem)
            }
        }
    }

    private func startImport(of item: PhotosPickerItem) {
        isImporting = true
        progressFraction = 0
        errorMessage = nil
        pendingVideoURL = nil

        let progress = item.loadTransferable(type: TransferableVideo.self) { result in
            Task { @MainActor in
                guard isImporting else { return } // ignore late callback after a manual cancel
                isImporting = false
                switch result {
                case .success(let video):
                    pendingVideoURL = video?.url
                case .failure:
                    errorMessage = "Impossible de charger cette vidéo."
                }
            }
        }
        importProgress = progress

        Task { @MainActor in
            while isImporting && !progress.isFinished && !progress.isCancelled {
                progressFraction = progress.fractionCompleted
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
    }

    private func cancelImport() {
        importProgress?.cancel()
        importProgress = nil
        isImporting = false
        selectedItem = nil
        pendingVideoURL = nil
        errorMessage = "Import annulé."
    }

    private func save() {
        guard let pendingVideoURL else { return }
        do {
            let path = try VideoStorage.shared.saveVideo(from: pendingVideoURL, for: animal.name)
            let video = AnimalVideo(title: title, notes: notes, date: date, videoPath: path, animal: animal)
            context.insert(video)
            try context.save()
            dismiss()
        } catch {
            errorMessage = "Impossible d'enregistrer cette vidéo."
        }
    }
}

struct AnimalVideoPlayerView: View {
    let video: AnimalVideo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VideoPlayer(player: AVPlayer(url: VideoStorage.shared.url(for: video.videoPath)))
                .ignoresSafeArea()
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
