import SwiftUI
import SwiftData
import Charts

/// Analyses transversales de l'élevage : heatmap d'activité, diversité
/// alimentaire par animal, tendance des refus, comparaison des cycles de mue.
struct AnalyticsView: View {
    @Query(sort: [SortDescriptor<Animal>(\.dashboardSortOrder)]) private var animals: [Animal]
    @State private var selectedAnimalID: PersistentIdentifier?
    @State private var exportedCSV: ExportedCSV?

    struct ExportedCSV: Identifiable {
        let id = UUID()
        let url: URL
    }

    private var selectedAnimal: Animal? {
        guard let selectedAnimalID else { return nil }
        return animals.first { $0.persistentModelID == selectedAnimalID }
    }

    /// Entrées considérées (tous les animaux, ou l'animal filtré).
    private var scopedEntries: [ObservationEntry] {
        let source = selectedAnimal.map { [$0] } ?? animals
        return source.flatMap(\.journalEntries).filter { !$0.isPhotoOnly }
    }

    /// Synthèses transversales sur le périmètre courant.
    private var insights: JournalInsights {
        JournalInsights.compute(from: scopedEntries)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                animalPicker
                activityCard
                insightsCard
                if !insights.weightSeries.isEmpty {
                    weightCard
                }
                if let animal = selectedAnimal {
                    diversityCard(for: animal)
                }
                refusalsCard
                moltComparisonCard
                maintenanceCard
            }
            .padding()
        }
        .background(Brand.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Analyses")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let scope = selectedAnimal.map { [$0] } ?? animals
                    let name = selectedAnimal?.name ?? "journal-complet"
                    if let url = JournalCSVExporter.export(animals: scope, filename: "journal-\(name)") {
                        exportedCSV = ExportedCSV(url: url)
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
    }

    // MARK: Synthèses (jeûne, compteurs)

    private var insightsCard: some View {
        let stats = insights
        return VStack(alignment: .leading, spacing: 12) {
            Text("Synthèse du journal")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metric("Nourrissages", "\(stats.feedingCount)", "fork.knife", Brand.primary)
                metric("Refus", "\(stats.refusalCount)", "xmark.circle", Brand.warning)
                metric("Mues", "\(stats.moltCount)", "arrow.triangle.2.circlepath", Brand.accent)
                if let fast = stats.longestFastingDays {
                    metric("Jeûne max", "\(Int(fast.rounded())) j", "hourglass", Brand.warning)
                }
                if let interval = stats.averageFeedingIntervalDays {
                    metric("Intervalle repas", "\(Int(interval.rounded())) j", "calendar", Brand.primary)
                }
                if let moltInterval = stats.averageMoltIntervalDays {
                    metric("Cycle de mue", "\(Int(moltInterval.rounded())) j", "clock.arrow.circlepath", Brand.accent)
                }
            }
        }
        .brandCard()
    }

    private func metric(_ label: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline.bold())
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Brand.surfaceElevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Évolution du poids

    private var weightCard: some View {
        let series = insights.weightSeries
        return VStack(alignment: .leading, spacing: 10) {
            Text("Évolution du poids")
                .font(.headline)
            Chart(series) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Poids (g)", point.grams)
                )
                .foregroundStyle(Brand.primary)
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Poids (g)", point.grams)
                )
                .foregroundStyle(Brand.primary)
            }
            .frame(height: 160)
            if let first = series.first, let last = series.last, series.count > 1 {
                let delta = last.grams - first.grams
                Text("\(delta >= 0 ? "+" : "")\(trim(delta)) g depuis le \(first.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(delta >= 0 ? Brand.success : Brand.warning)
            }
        }
        .brandCard()
    }

    // MARK: Fréquence de maintenance

    private var maintenanceCard: some View {
        let stats = insights
        return Group {
            if stats.maintenanceCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Maintenance de l'habitat")
                        .font(.headline)
                    HStack {
                        Label("\(stats.maintenanceCount) opérations", systemImage: "wrench.and.screwdriver")
                            .font(.footnote)
                        Spacer()
                        if let perMonth = stats.maintenancePerMonth {
                            Text("~\(String(format: "%.1f", perMonth))/mois")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Brand.warning)
                        }
                    }
                }
                .brandCard()
            }
        }
    }

    private func trim(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
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
