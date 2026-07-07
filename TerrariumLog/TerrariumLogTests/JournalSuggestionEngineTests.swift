import XCTest
import SwiftData
@testable import TerrariumLog

@MainActor
final class JournalSuggestionEngineTests: XCTestCase {
    private let day: TimeInterval = 86400
    private let base = Date(timeIntervalSince1970: 1_000_000)

    private func makeContext() -> ModelContext {
        PersistenceController(inMemory: true).container.mainContext
    }

    private func makeAnimal(
        type: AnimalType = .jumpingSpider,
        status: AnimalStatus = .normal,
        terrarium: Terrarium? = nil,
        in context: ModelContext
    ) -> Animal {
        let animal = Animal(
            name: "Testeur-\(UUID().uuidString.prefix(4))",
            species: "Test",
            type: type,
            origin: .captured,
            arrivalDate: base,
            currentStage: "L5",
            status: status,
            notes: ""
        )
        animal.terrarium = terrarium
        context.insert(animal)
        return animal
    }

    private func addFeeding(_ animal: Animal, dayOffset: Int, in context: ModelContext) {
        let entry = ObservationEntry(
            date: base.addingTimeInterval(Double(dayOffset) * day),
            eventType: ObservationEventType.feeding.rawValue,
            note: "",
            animal: animal
        )
        context.insert(entry)
    }

    private func addMolt(_ animal: Animal, dayOffset: Int, from: String, to: String, in context: ModelContext) {
        let entry = ObservationEntry(
            date: base.addingTimeInterval(Double(dayOffset) * day),
            eventType: ObservationEventType.molt.rawValue,
            note: "",
            previousStage: from,
            newStage: to,
            animal: animal
        )
        context.insert(entry)
    }

    // MARK: Nourrissage

    func testSuggestsFeedingWhenOverdue() {
        let context = makeContext()
        let animal = makeAnimal(in: context)
        addFeeding(animal, dayOffset: 0, in: context)
        addFeeding(animal, dayOffset: 2, in: context)
        addFeeding(animal, dayOffset: 4, in: context)

        let suggestions = JournalSuggestionEngine.suggestions(for: animal, now: base.addingTimeInterval(40 * day))
        XCTAssertTrue(suggestions.contains { $0.kind == .feedingOverdue })
    }

    func testNoFeedingSuggestionWhenRecentlyFed() {
        let context = makeContext()
        let animal = makeAnimal(in: context)
        addFeeding(animal, dayOffset: 0, in: context)
        addFeeding(animal, dayOffset: 2, in: context)
        addFeeding(animal, dayOffset: 4, in: context)

        let suggestions = JournalSuggestionEngine.suggestions(for: animal, now: base.addingTimeInterval(5 * day))
        XCTAssertFalse(suggestions.contains { $0.kind == .feedingOverdue })
    }

    // MARK: Mue

    func testSuggestsMoltApproachingForMoltingSpecies() {
        let context = makeContext()
        let animal = makeAnimal(type: .jumpingSpider, in: context)
        addMolt(animal, dayOffset: 0, from: "L4", to: "L5", in: context)
        addMolt(animal, dayOffset: 30, from: "L5", to: "L6", in: context)

        // 27 j depuis la dernière mue, cycle moyen 30 j → 27 ≥ 25,5.
        let suggestions = JournalSuggestionEngine.suggestions(for: animal, now: base.addingTimeInterval(57 * day))
        XCTAssertTrue(suggestions.contains { $0.kind == .moltApproaching })
    }

    func testNoMoltSuggestionForNonMoltingSpecies() {
        let context = makeContext()
        let animal = makeAnimal(type: .antColony, in: context)
        addMolt(animal, dayOffset: 0, from: "L4", to: "L5", in: context)
        addMolt(animal, dayOffset: 30, from: "L5", to: "L6", in: context)

        let suggestions = JournalSuggestionEngine.suggestions(for: animal, now: base.addingTimeInterval(57 * day))
        XCTAssertFalse(suggestions.contains { $0.kind == .moltApproaching })
    }

    func testNoMoltSuggestionWhenAlreadyInPremolt() {
        let context = makeContext()
        let animal = makeAnimal(type: .jumpingSpider, status: .premolt, in: context)
        addMolt(animal, dayOffset: 0, from: "L4", to: "L5", in: context)
        addMolt(animal, dayOffset: 30, from: "L5", to: "L6", in: context)

        let suggestions = JournalSuggestionEngine.suggestions(for: animal, now: base.addingTimeInterval(57 * day))
        XCTAssertFalse(suggestions.contains { $0.kind == .moltApproaching })
    }

    // MARK: Environnement

    func testSuggestsTemperatureLowWhenReadingBelowTarget() {
        let context = makeContext()
        let terrarium = Terrarium(name: "T", type: .terrarium, targetTemperatureMin: 24, targetTemperatureMax: 28)
        context.insert(terrarium)
        let animal = makeAnimal(terrarium: terrarium, in: context)

        let reading = TerrariumSensorReading(temperature: 20, humidity: 60, soilMoisture: nil, luminosity: nil)
        let suggestions = JournalSuggestionEngine.suggestions(for: animal, reading: reading, now: base)
        XCTAssertTrue(suggestions.contains { $0.kind == .temperatureLow })
    }

    func testNoEnvironmentSuggestionWhenReadingInRange() {
        let context = makeContext()
        let terrarium = Terrarium(name: "T", type: .terrarium, targetTemperatureMin: 24, targetTemperatureMax: 28, targetHumidityMin: 55, targetHumidityMax: 70)
        context.insert(terrarium)
        let animal = makeAnimal(terrarium: terrarium, in: context)

        let reading = TerrariumSensorReading(temperature: 26, humidity: 62, soilMoisture: nil, luminosity: nil)
        let suggestions = JournalSuggestionEngine.suggestions(for: animal, reading: reading, now: base)
        XCTAssertFalse(suggestions.contains { $0.kind == .temperatureLow || $0.kind == .temperatureHigh || $0.kind == .humidityLow || $0.kind == .humidityHigh })
    }
}
