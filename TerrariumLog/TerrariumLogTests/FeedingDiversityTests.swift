import XCTest
import SwiftData
@testable import TerrariumLog

/// La suggestion de proie doit tenir compte des stocks réels : une proie en
/// rupture est écartée (et signalée « à commander »), un stock bas est signalé.
final class FeedingDiversityTests: XCTestCase {

    /// Animal de test avec un régime à deux proies et un historique de repas.
    @MainActor
    private func makeAnimal(context: ModelContext, diet: [PreyType], meals: [(PreyType, daysAgo: Int)]) -> Animal {
        let animal = Animal(
            name: "Test",
            species: "Phidippus regius",
            type: .jumpingSpider,
            origin: .purchased,
            arrivalDate: .now,
            currentStage: "Adulte",
            status: .normal,
            notes: ""
        )
        animal.dietPreyRawValues = diet.map(\.rawValue)
        context.insert(animal)
        for (prey, daysAgo) in meals {
            let entry = ObservationEntry(
                date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now,
                eventType: ObservationEventType.feeding.rawValue,
                note: "",
                preyType: prey.rawValue,
                animal: animal
            )
            context.insert(entry)
        }
        try? context.save()
        return animal
    }

    /// Sans stocks fournis : comportement historique inchangé.
    @MainActor
    func testWithoutStocksBehavesAsBefore() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext
        // Que des mouches récemment → la rotation propose le grillon.
        let animal = makeAnimal(context: context, diet: [.fly, .cricket], meals: [(.fly, 1), (.fly, 3)])

        let analysis = FeedingDiversity.analyze(animal: animal)
        XCTAssertEqual(analysis.suggestionRawValue, PreyType.cricket.rawValue)
        XCTAssertNil(analysis.restockNote)
    }

    /// La proie idéale est en rupture → on suggère la suivante disponible et
    /// on signale la commande à passer.
    @MainActor
    func testOutOfStockPreyIsSkippedAndFlagged() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext
        let animal = makeAnimal(context: context, diet: [.fly, .cricket], meals: [(.fly, 1), (.fly, 3)])

        // Rotation idéale = grillon, mais le stock de grillons est vide.
        let cricketStock = PreyStock(typeRawValue: PreyType.cricket.rawValue, quantity: 0)
        let flyStock = PreyStock(typeRawValue: PreyType.fly.rawValue, quantity: 50)
        context.insert(cricketStock)
        context.insert(flyStock)

        let analysis = FeedingDiversity.analyze(animal: animal, stocks: [cricketStock, flyStock])
        XCTAssertEqual(analysis.suggestionRawValue, PreyType.fly.rawValue,
                       "La proie en rupture doit être écartée de la suggestion")
        let note = try XCTUnwrap(analysis.restockNote)
        XCTAssertTrue(note.contains("Grillon"), "La rupture doit être signalée : \(note)")
        XCTAssertTrue(note.contains("commander"))
    }

    /// La proie suggérée a un stock bas (mais non nul) → suggestion inchangée,
    /// avec un rappel de réassort.
    @MainActor
    func testLowStockOnSuggestionIsFlagged() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext
        let animal = makeAnimal(context: context, diet: [.fly, .cricket], meals: [(.fly, 1), (.fly, 3)])

        let cricketStock = PreyStock(typeRawValue: PreyType.cricket.rawValue, quantity: 3, lowThreshold: 5)
        context.insert(cricketStock)

        let analysis = FeedingDiversity.analyze(animal: animal, stocks: [cricketStock])
        XCTAssertEqual(analysis.suggestionRawValue, PreyType.cricket.rawValue,
                       "Un stock bas ne doit pas écarter la proie")
        let note = try XCTUnwrap(analysis.restockNote)
        XCTAssertTrue(note.contains("recommander"), "Le stock bas doit être signalé : \(note)")
    }

    /// Tout le régime est en rupture → suggestion conservée mais alerte claire.
    @MainActor
    func testAllOutOfStockKeepsSuggestionWithAlert() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext
        let animal = makeAnimal(context: context, diet: [.fly, .cricket], meals: [(.fly, 1)])

        let stocks = [
            PreyStock(typeRawValue: PreyType.fly.rawValue, quantity: 0),
            PreyStock(typeRawValue: PreyType.cricket.rawValue, quantity: 0)
        ]
        stocks.forEach { context.insert($0) }

        let analysis = FeedingDiversity.analyze(animal: animal, stocks: stocks)
        XCTAssertNotNil(analysis.suggestionRawValue)
        let note = try XCTUnwrap(analysis.restockNote)
        XCTAssertTrue(note.contains("rupture"), "La rupture totale doit être signalée : \(note)")
    }

    /// Une proie sans stock suivi reste disponible (on ne suit pas tout).
    @MainActor
    func testUntrackedPreyIsConsideredAvailable() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext
        let animal = makeAnimal(context: context, diet: [.fly, .cricket], meals: [(.fly, 1), (.fly, 3)])

        // Seules les mouches sont suivies ; les grillons (non suivis) restent
        // suggérables sans note de réassort.
        let flyStock = PreyStock(typeRawValue: PreyType.fly.rawValue, quantity: 50)
        context.insert(flyStock)

        let analysis = FeedingDiversity.analyze(animal: animal, stocks: [flyStock])
        XCTAssertEqual(analysis.suggestionRawValue, PreyType.cricket.rawValue)
        XCTAssertNil(analysis.restockNote)
    }

    /// L'évitement de série (2× la même proie d'affilée) ne doit proposer que
    /// des alternatives en stock.
    @MainActor
    func testStreakAvoidanceRespectsStocks() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext
        // 3 proies au régime ; série de grillons en cours. La mouche est la
        // plus ancienne (= tête de rotation idéale).
        let animal = makeAnimal(
            context: context,
            diet: [.cricket, .fly, .roach],
            meals: [(.cricket, 1), (.cricket, 2), (.roach, 10), (.fly, 12)]
        )

        // La mouche (tête de rotation) est en rupture : la suggestion doit
        // retomber sur la blatte, disponible.
        let flyStock = PreyStock(typeRawValue: PreyType.fly.rawValue, quantity: 0)
        context.insert(flyStock)

        let analysis = FeedingDiversity.analyze(animal: animal, stocks: [flyStock])
        XCTAssertEqual(analysis.suggestionRawValue, PreyType.roach.rawValue,
                       "L'alternative à la série doit être une proie en stock")
    }
}
