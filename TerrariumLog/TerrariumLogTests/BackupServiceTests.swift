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
            notes: "notes",
            dashboardSortOrder: 3
        )
        animal.terrarium = terrarium
        context.insert(animal)

        let entry = ObservationEntry(date: .now, eventType: ObservationEventType.arrival.rawValue, note: "arrived", animal: animal)
        context.insert(entry)

        let camera = Camera(
            name: "Cam Terrarium",
            brand: .tapo,
            model: "Tapo C220",
            connectionType: .rtsp,
            streamURL: "rtsp://192.168.1.50:554/stream1",
            terrarium: terrarium
        )
        context.insert(camera)

        context.insert(CustomPreyType(name: "Larve de teigne"))
        try context.save()

        let data = try BackupService.shared.exportData(context: context)
        try BackupService.shared.importData(data, context: context)

        let customPreyTypes = try context.fetch(FetchDescriptor<CustomPreyType>())
        XCTAssertEqual(customPreyTypes.count, 1)
        XCTAssertEqual(customPreyTypes.first?.name, "Larve de teigne")

        let animals = try context.fetch(FetchDescriptor<Animal>())
        XCTAssertEqual(animals.count, 1)
        XCTAssertEqual(animals.first?.name, "TestAnimal")
        XCTAssertEqual(animals.first?.dashboardSortOrder, 3)
        XCTAssertEqual(animals.first?.terrarium?.name, "Terrarium Test")
        XCTAssertEqual(animals.first?.journalEntries.count, 1)
        XCTAssertEqual(animals.first?.journalEntries.first?.note, "arrived")

        let terrariums = try context.fetch(FetchDescriptor<Terrarium>())
        XCTAssertEqual(terrariums.count, 1)
        XCTAssertEqual(terrariums.first?.cameras.count, 1)
        XCTAssertEqual(terrariums.first?.cameras.first?.name, "Cam Terrarium")
        XCTAssertEqual(terrariums.first?.cameras.first?.streamURL, "rtsp://192.168.1.50:554/stream1")
        XCTAssertTrue(terrariums.first?.cameras.first?.isConfigured ?? false)
    }

    func testImportRejectsInvalidData() {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext
        let invalidData = "not json".data(using: .utf8)!

        XCTAssertThrowsError(try BackupService.shared.importData(invalidData, context: context))
    }

    func testImportAcceptsBackupWithoutCustomPreyTypeNamesKey() throws {
        // Simulates a backup exported before customPreyTypeNames existed.
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext
        let legacyJSON = """
        {
            "exportedAt": "2026-01-01T00:00:00Z",
            "terrariums": [],
            "unassignedAnimals": []
        }
        """.data(using: .utf8)!

        XCTAssertNoThrow(try BackupService.shared.importData(legacyJSON, context: context))
    }
}
