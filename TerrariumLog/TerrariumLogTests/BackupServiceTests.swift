import XCTest
import SwiftData
@testable import TerrariumLog

@MainActor
final class BackupServiceTests: XCTestCase {
    func testExportThenImportRoundTrip() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext

        let terrarium = Terrarium(name: "Terrarium Test", type: .terrarium, dimensions: "10x10x10")
        context.insert(terrarium)

        let animal = Animal(
            name: "TestAnimal",
            species: "Test species",
            type: .jumpingSpider,
            origin: .captured,
            arrivalDate: .now,
            currentStage: "L5",
            status: .normal,
            notes: "notes"
        )
        animal.terrarium = terrarium
        context.insert(animal)

        let entry = ObservationEntry(date: .now, eventType: ObservationEventType.arrival.rawValue, note: "arrived", animal: animal)
        context.insert(entry)
        try context.save()

        let data = try BackupService.shared.exportData(context: context)
        try BackupService.shared.importData(data, context: context)

        let animals = try context.fetch(FetchDescriptor<Animal>())
        XCTAssertEqual(animals.count, 1)
        XCTAssertEqual(animals.first?.name, "TestAnimal")
        XCTAssertEqual(animals.first?.terrarium?.name, "Terrarium Test")
        XCTAssertEqual(animals.first?.journalEntries.count, 1)
        XCTAssertEqual(animals.first?.journalEntries.first?.note, "arrived")

        let terrariums = try context.fetch(FetchDescriptor<Terrarium>())
        XCTAssertEqual(terrariums.count, 1)
    }

    func testImportRejectsInvalidData() {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext
        let invalidData = "not json".data(using: .utf8)!

        XCTAssertThrowsError(try BackupService.shared.importData(invalidData, context: context))
    }
}
