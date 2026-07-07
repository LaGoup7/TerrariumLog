import XCTest
@testable import TerrariumLog

final class JournalInsightsTests: XCTestCase {
    private let day: TimeInterval = 86400
    private let base = Date(timeIntervalSince1970: 0)

    func testEmptyJournalProducesEmptyInsights() {
        let insights = JournalInsights.compute(from: [])
        XCTAssertTrue(insights.weightSeries.isEmpty)
        XCTAssertNil(insights.longestFastingDays)
        XCTAssertEqual(insights.feedingCount, 0)
        XCTAssertEqual(insights.maintenanceCount, 0)
        XCTAssertNil(insights.maintenancePerMonth)
    }

    func testWeightSeriesIsSortedByDate() {
        let entries = [
            ObservationEntry(date: base.addingTimeInterval(10 * day), eventType: ObservationEventType.weighing.rawValue, note: "", weightGrams: 12),
            ObservationEntry(date: base, eventType: ObservationEventType.weighing.rawValue, note: "", weightGrams: 8),
            ObservationEntry(date: base.addingTimeInterval(5 * day), eventType: ObservationEventType.weighing.rawValue, note: "", weightGrams: 10)
        ]
        let insights = JournalInsights.compute(from: entries)
        XCTAssertEqual(insights.weightSeries.map(\.grams), [8, 10, 12])
    }

    func testLongestFastingIsMaxGapBetweenFeedings() {
        let feedings = [0, 4, 20].map {
            ObservationEntry(date: base.addingTimeInterval(Double($0) * day), eventType: ObservationEventType.feeding.rawValue, note: "")
        }
        // now = date du dernier repas → pas de jeûne en cours, on isole les écarts historiques.
        let insights = JournalInsights.compute(from: feedings, now: base.addingTimeInterval(20 * day))
        XCTAssertEqual(insights.longestFastingDays ?? 0, 16, accuracy: 0.01)
        XCTAssertEqual(insights.feedingCount, 3)
    }

    func testOngoingFastCountsTowardLongestFasting() {
        let feedings = [0, 4].map {
            ObservationEntry(date: base.addingTimeInterval(Double($0) * day), eventType: ObservationEventType.feeding.rawValue, note: "")
        }
        let insights = JournalInsights.compute(from: feedings, now: base.addingTimeInterval(30 * day))
        // Jeûne en cours (26 j) plus long que l'écart historique (4 j).
        XCTAssertEqual(insights.longestFastingDays ?? 0, 26, accuracy: 0.01)
    }

    func testMaintenanceFrequencyPerMonth() {
        let entries = [
            ObservationEntry(date: base, eventType: ObservationEventType.cleaning.rawValue, note: ""),
            ObservationEntry(date: base.addingTimeInterval(30 * day), eventType: ObservationEventType.substrateChange.rawValue, note: ""),
            ObservationEntry(date: base.addingTimeInterval(60 * day), eventType: ObservationEventType.waterRefill.rawValue, note: "")
        ]
        let insights = JournalInsights.compute(from: entries)
        XCTAssertEqual(insights.maintenanceCount, 3)
        // 3 opérations sur ~2 mois → ~1.5/mois.
        XCTAssertEqual(insights.maintenancePerMonth ?? 0, 1.5, accuracy: 0.05)
    }

    func testMoltCountReflectsMoltEvents() {
        let entries = [
            ObservationEntry(date: base, eventType: ObservationEventType.molt.rawValue, note: "", previousStage: "L4", newStage: "L5"),
            ObservationEntry(date: base.addingTimeInterval(10 * day), eventType: ObservationEventType.molt.rawValue, note: "", previousStage: "L5", newStage: "L6"),
            ObservationEntry(date: base.addingTimeInterval(11 * day), eventType: ObservationEventType.feeding.rawValue, note: "")
        ]
        let insights = JournalInsights.compute(from: entries)
        XCTAssertEqual(insights.moltCount, 2)
        XCTAssertEqual(insights.feedingCount, 1)
    }
}
