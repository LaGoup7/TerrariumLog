import XCTest
@testable import TerrariumLog

/// Teste la version **pure** du moteur (valeurs explicites + `ObservationEntry`
/// autonomes), sans ModelContext — même approche que `JournalInsightsTests`.
final class JournalSuggestionEngineTests: XCTestCase {
    private let day: TimeInterval = 86400
    private let base = Date(timeIntervalSince1970: 1_000_000)

    private func feeding(dayOffset: Int) -> ObservationEntry {
        ObservationEntry(
            date: base.addingTimeInterval(Double(dayOffset) * day),
            eventType: ObservationEventType.feeding.rawValue,
            note: ""
        )
    }

    private func molt(dayOffset: Int, from: String, to: String) -> ObservationEntry {
        ObservationEntry(
            date: base.addingTimeInterval(Double(dayOffset) * day),
            eventType: ObservationEventType.molt.rawValue,
            note: "",
            previousStage: from,
            newStage: to
        )
    }

    // MARK: Nourrissage

    func testSuggestsFeedingWhenOverdue() {
        let entries = [feeding(dayOffset: 0), feeding(dayOffset: 2), feeding(dayOffset: 4)]
        let suggestions = JournalSuggestionEngine.suggestions(
            animalName: "Testeur", type: .jumpingSpider, status: .normal,
            entries: entries, terrarium: nil, now: base.addingTimeInterval(40 * day)
        )
        XCTAssertTrue(suggestions.contains { $0.kind == .feedingOverdue })
    }

    func testNoFeedingSuggestionWhenRecentlyFed() {
        let entries = [feeding(dayOffset: 0), feeding(dayOffset: 2), feeding(dayOffset: 4)]
        let suggestions = JournalSuggestionEngine.suggestions(
            animalName: "Testeur", type: .jumpingSpider, status: .normal,
            entries: entries, terrarium: nil, now: base.addingTimeInterval(5 * day)
        )
        XCTAssertFalse(suggestions.contains { $0.kind == .feedingOverdue })
    }

    // MARK: Mue

    func testSuggestsMoltApproachingForMoltingSpecies() {
        let entries = [molt(dayOffset: 0, from: "L4", to: "L5"), molt(dayOffset: 30, from: "L5", to: "L6")]
        // 27 j depuis la dernière mue, cycle moyen 30 j → 27 ≥ 25,5.
        let suggestions = JournalSuggestionEngine.suggestions(
            animalName: "Testeur", type: .jumpingSpider, status: .normal,
            entries: entries, terrarium: nil, now: base.addingTimeInterval(57 * day)
        )
        XCTAssertTrue(suggestions.contains { $0.kind == .moltApproaching })
    }

    func testNoMoltSuggestionForNonMoltingSpecies() {
        let entries = [molt(dayOffset: 0, from: "L4", to: "L5"), molt(dayOffset: 30, from: "L5", to: "L6")]
        let suggestions = JournalSuggestionEngine.suggestions(
            animalName: "Testeur", type: .antColony, status: .normal,
            entries: entries, terrarium: nil, now: base.addingTimeInterval(57 * day)
        )
        XCTAssertFalse(suggestions.contains { $0.kind == .moltApproaching })
    }

    func testNoMoltSuggestionWhenAlreadyInPremolt() {
        let entries = [molt(dayOffset: 0, from: "L4", to: "L5"), molt(dayOffset: 30, from: "L5", to: "L6")]
        let suggestions = JournalSuggestionEngine.suggestions(
            animalName: "Testeur", type: .jumpingSpider, status: .premolt,
            entries: entries, terrarium: nil, now: base.addingTimeInterval(57 * day)
        )
        XCTAssertFalse(suggestions.contains { $0.kind == .moltApproaching })
    }

    // MARK: Environnement

    func testSuggestsTemperatureLowWhenReadingBelowTarget() {
        let terrarium = Terrarium(name: "T", type: .terrarium, targetTemperatureMin: 24, targetTemperatureMax: 28)
        let reading = TerrariumSensorReading(temperature: 20, humidity: 60, soilMoisture: nil, luminosity: nil)
        let suggestions = JournalSuggestionEngine.suggestions(
            animalName: "Testeur", type: .jumpingSpider, status: .normal,
            entries: [], terrarium: terrarium, reading: reading, now: base
        )
        XCTAssertTrue(suggestions.contains { $0.kind == .temperatureLow })
    }

    func testNoEnvironmentSuggestionWhenReadingInRange() {
        let terrarium = Terrarium(name: "T", type: .terrarium, targetTemperatureMin: 24, targetTemperatureMax: 28, targetHumidityMin: 55, targetHumidityMax: 70)
        let reading = TerrariumSensorReading(temperature: 26, humidity: 62, soilMoisture: nil, luminosity: nil)
        let suggestions = JournalSuggestionEngine.suggestions(
            animalName: "Testeur", type: .jumpingSpider, status: .normal,
            entries: [], terrarium: terrarium, reading: reading, now: base
        )
        XCTAssertFalse(suggestions.contains { $0.kind == .temperatureLow || $0.kind == .temperatureHigh || $0.kind == .humidityLow || $0.kind == .humidityHigh })
    }
}
