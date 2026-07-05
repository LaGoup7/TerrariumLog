import SwiftUI
import SwiftData
import Charts

/// Analyses transversales de l'élevage : heatmap d'activité, diversité
/// alimentaire par animal, tendance des refus, comparaison des cycles de mue.
struct AnalyticsView: View {
    @Query(sort: [SortDescriptor<Animal>(\.dashboardSortOrder)]) private var animals: [Animal]
    @State private var selectedAnimalID: PersistentIdentifier?

    private var selectedAnimal: Animal? {
        guard let selectedAnimalID else { return nil }
        return animals.first { $0.persistentModelID == selectedAnimalID }
    }

    /// Entrées considérées (tous les animaux, ou l'animal filtré).
    private var scopedEntries: [ObservationEntry] {
        let source = selectedAnimal.map { [$0] } ?? animals
        return source.flatMap(\.journalEntries).filter { !$0.isPhotoOnly }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                animalPicker
                activityCard
                if let animal = selectedAnimal {
                    diversityCard(for: animal)
                }
                refusalsCard
                moltComparisonCard
            }
            .padding()
        }
        .background(Brand.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Analyses")
    }

    // MARK: Filtre animal

    private var animalPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "Tous", isSelected: selectedAnimalID == nil) {
                    selectedAnimalID = nil
                }
                ForEach(animals) { animal in
                    chip(label: animal.name, isSelected: selectedAnimalID == animal.persistentModelID) {
                        selectedAnimalID = selectedAnimalID == animal.persistentModelID ? nil : animal.persistentModelID
                    }
                }
            }
        }
    }

    private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .foregroundStyle(isSelected ? Brand.primary : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Brand.primary.opacity(0.18) : Brand.surfaceElevated)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Heatmap d'activité (13 dernières semaines)

    private var activityCard: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let totalDays = 13 * 7
        var counts: [Date: Int] = [:]
        for entry in scopedEntries {
            let day = calendar.startOfDay(for: entry.date)
            counts[day, default: 0] += 1
        }
        // Colonnes = semaines (ancienne → récente), lignes = jours.
        let days: [Date] = (0..<totalDays).compactMap {
            calendar.date(byAdding: .day, value: -(totalDays - 1 - $0), to: today)
        }
        let weeks = stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }

        return VStack(alignment: .leading, spacing: 10) {
            Text("Activité (13 semaines)")
                .font(.headline)
            HStack(alignment: .top, spacing: 3) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: 3) {
                        ForEach(week, id: \.self) { day in
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(heatColor(counts[day, default: 0]))
                                .frame(width: 14, height: 14)
                        }
                    }
                }
            }
            HStack(spacing: 6) {
                Text("Moins")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(0..<4) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatColor(level * 2))
                        .frame(width: 10, height: 10)
                }
                Text("Plus")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(scopedEntries.count) événements au total")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .brandCard()
    }

    private func heatColor(_ count: Int) -> Color {
        switch count {
        case 0: return Brand.surfaceElevated
        case 1: return Brand.primary.opacity(0.3)
        case 2...3: return Brand.primary.opacity(0.55)
        default: return Brand.primary
        }
    }

    // MARK: Diversité alimentaire (animal filtré)

    private func diversityCard(for animal: Animal) -> some View {
        let analysis = FeedingDiversity.analyze(animal: animal)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Diversité alimentaire · \(animal.name)")
                .font(.headline)
            if analysis.recentCounts.isEmpty {
                Text("Aucun repas avec proie renseignée sur la période.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Chart(analysis.recentCounts, id: \.preyRawValue) { item in
                    BarMark(
                        x: .value("Repas", item.count),
                        y: .value("Proie", PreyType(rawValue: item.preyRawValue)?.displayName ?? item.preyRawValue)
                    )
                    .foregroundStyle(Brand.accent)
                }
                .frame(height: CGFloat(max(analysis.recentCounts.count, 2)) * 34)
                Text("Sur les \(FeedingDiversity.window) derniers repas.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let suggestion = analysis.suggestionDisplayName {
                Label {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Prochaine proie suggérée : \(suggestion)")
                            .font(.footnote.weight(.semibold))
                        if let reason = analysis.reason {
                            Text(reason)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .foregroundStyle(Brand.primary)
                }
            }
        }
        .brandCard()
    }

    // MARK: Refus de nourriture (6 derniers mois)

    private var refusalsCard: some View {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "LLL"
        let months: [Date] = (0..<6).compactMap {
            calendar.date(byAdding: .month, value: -(5 - $0), to: calendar.startOfDay(for: .now))
        }
        let refusals = scopedEntries.filter {
            $0.eventType == ObservationEventType.feeding.rawValue && $0.eatenStatus == EatenStatus.no.rawValue
        }
        let data: [(month: String, count: Int)] = months.map { month in
            let count = refusals.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }.count
            return (formatter.string(from: month).capitalized, count)
        }

        return VStack(alignment: .leading, spacing: 10) {
            Text("Refus de nourriture (6 mois)")
                .font(.headline)
            if data.allSatisfy({ $0.count == 0 }) {
                Label("Aucun refus sur la période — appétit au top.", systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(Brand.success)
            } else {
                Chart(data, id: \.month) { item in
                    BarMark(
                        x: .value("Mois", item.month),
                        y: .value("Refus", item.count)
                    )
                    .foregroundStyle(Brand.warning)
                }
                .frame(height: 140)
            }
        }
        .brandCard()
    }

    // MARK: Cycles de mue comparés

    private var moltComparisonCard: some View {
        let data: [(name: String, average: Double)] = animals.compactMap { animal in
            guard animal.type.tracksMolting else { return nil }
            let stats = MoltStats.compute(from: animal.journalEntries)
            guard let average = stats.averageDaysBetweenMolts else { return nil }
            return (animal.name, average)
        }

        return Group {
            if !data.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Cycle de mue moyen")
                        .font(.headline)
                    Chart(data, id: \.name) { item in
                        BarMark(
                            x: .value("Jours", item.average),
                            y: .value("Animal", item.name)
                        )
                        .foregroundStyle(Brand.primary)
                        .annotation(position: .trailing) {
                            Text("\(Int(item.average.rounded())) j")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: CGFloat(max(data.count, 2)) * 40)
                }
                .brandCard()
            }
        }
    }
}
