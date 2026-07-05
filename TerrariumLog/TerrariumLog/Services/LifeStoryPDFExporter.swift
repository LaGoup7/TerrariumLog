import SwiftUI
import UIKit

/// Exporte la « Life Story » d'un animal en PDF (une page continue) : identité,
/// photo, chronologie complète du journal et statistiques. Pensé pour être
/// partagé (forums, documentation d'élevage) — fond blanc, imprimable.
@MainActor
enum LifeStoryPDFExporter {
    static func export(animal: Animal) -> URL? {
        let renderer = ImageRenderer(content: LifeStoryPDFContent(animal: animal))
        renderer.proposedSize = ProposedViewSize(width: 612, height: nil)

        let safeName = animal.name.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LifeStory-\(String(safeName)).pdf")

        var success = false
        renderer.render { size, renderInContext in
            var mediaBox = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(url: url as CFURL),
                  let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }
            pdfContext.beginPDFPage(nil)
            renderInContext(pdfContext)
            pdfContext.endPDFPage()
            pdfContext.closePDF()
            success = true
        }
        return success ? url : nil
    }
}

/// Contenu du PDF — style fixe clair (imprimable), indépendant du thème de l'app.
private struct LifeStoryPDFContent: View {
    let animal: Animal

    private var entries: [ObservationEntry] {
        animal.journalEntries
            .filter { !$0.isPhotoOnly }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            Divider()
            chronology
            Divider()
            statistics
            Text("Généré par Habitat le \(Date.now.formatted(date: .long, time: .omitted))")
                .font(.system(size: 9))
                .foregroundStyle(.gray)
        }
        .padding(36)
        .frame(width: 612, alignment: .leading)
        .background(Color.white)
        .foregroundStyle(.black)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            if let path = animal.primaryPhotoPath,
               let image = ThumbnailStore.shared.thumbnail(for: path, maxDimension: 400) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(animal.name)
                    .font(.system(size: 26, weight: .bold))
                Text(animal.species)
                    .font(.system(size: 14))
                    .italic()
                    .foregroundStyle(.gray)
                Text("\(animal.type.displayName) · \(animal.status.displayName) · Stade \(animal.currentStage)")
                    .font(.system(size: 11))
                Text("Arrivée : \(animal.arrivalDate.formatted(date: .long, time: .omitted))")
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)
                if let colonySummary = animal.colonySummary {
                    Text(colonySummary)
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                }
            }
        }
    }

    private var chronology: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chronologie")
                .font(.system(size: 16, weight: .semibold))
            if entries.isEmpty {
                Text("Aucun événement enregistré.")
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)
            }
            ForEach(entries) { entry in
                HStack(alignment: .top, spacing: 10) {
                    Text(entry.date.formatted(date: .numeric, time: .omitted))
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 64, alignment: .leading)
                        .foregroundStyle(.gray)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(ObservationEventType(rawValue: entry.eventType)?.displayName ?? entry.eventType)
                            .font(.system(size: 11, weight: .semibold))
                        if !entry.note.isEmpty {
                            Text(entry.note)
                                .font(.system(size: 10))
                                .foregroundStyle(.gray)
                        }
                    }
                }
            }
        }
    }

    private var statistics: some View {
        let molts = MoltStats.compute(from: animal.journalEntries)
        let feedingCount = animal.journalEntries.filter { $0.eventType == ObservationEventType.feeding.rawValue }.count
        return VStack(alignment: .leading, spacing: 4) {
            Text("Statistiques")
                .font(.system(size: 16, weight: .semibold))
            Text("Événements : \(entries.count) · Mues : \(molts.intervals.count)\(molts.averageDaysBetweenMolts.map { String(format: " (cycle moyen %.0f j)", $0) } ?? "") · Repas : \(feedingCount)")
                .font(.system(size: 11))
        }
    }
}
