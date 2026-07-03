import SwiftUI
import Charts

struct EnvironmentChartsView: View {
    let measurements: [MeasurementEntry]
    @State private var period: MeasurementPeriod = .week

    private var filtered: [MeasurementEntry] {
        let cutoff = period.cutoffDate()
        return measurements
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
    }

    private var stats: MeasurementStats {
        MeasurementStats.compute(from: filtered)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Période", selection: $period) {
                ForEach(MeasurementPeriod.allCases) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .pickerStyle(.segmented)

            if filtered.isEmpty {
                Text("Aucune mesure sur cette période")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                if filtered.contains(where: { $0.temperature != nil }) {
                    chartBlock(
                        title: "Température",
                        color: .orange,
                        data: filtered.filter { $0.temperature != nil },
                        value: { $0.temperature ?? 0 },
                        unit: "°C"
                    )
                    if let min = stats.minTemperature, let max = stats.maxTemperature, let avg = stats.avgTemperature {
                        Text("Min \(min, specifier: "%.1f")°C · Max \(max, specifier: "%.1f")°C · Moy \(avg, specifier: "%.1f")°C")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if filtered.contains(where: { $0.humidity != nil }) {
                    chartBlock(
                        title: "Humidité",
                        color: .blue,
                        data: filtered.filter { $0.humidity != nil },
                        value: { $0.humidity ?? 0 },
                        unit: "%"
                    )
                    if let min = stats.minHumidity, let max = stats.maxHumidity, let avg = stats.avgHumidity {
                        Text("Min \(min, specifier: "%.0f")% · Max \(max, specifier: "%.0f")% · Moy \(avg, specifier: "%.0f")%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if filtered.contains(where: { $0.luminosity != nil }) {
                    chartBlock(
                        title: "Luminosité",
                        color: .yellow,
                        data: filtered.filter { $0.luminosity != nil },
                        value: { $0.luminosity ?? 0 },
                        unit: ""
                    )
                    if let min = stats.minLuminosity, let max = stats.maxLuminosity, let avg = stats.avgLuminosity {
                        Text("Min \(min, specifier: "%.0f") · Max \(max, specifier: "%.0f") · Moy \(avg, specifier: "%.0f")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func chartBlock(
        title: String,
        color: Color,
        data: [MeasurementEntry],
        value: @escaping (MeasurementEntry) -> Double,
        unit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Chart(data) { measurement in
                LineMark(
                    x: .value("Date", measurement.date),
                    y: .value(unit, value(measurement))
                )
            }
            .foregroundStyle(color)
            .frame(height: 100)
        }
    }
}
