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
            primaryPhotoOffsetX: 12,
            primaryPhotoOffsetY: -8,
            dashboardSortOrder: 3,
            isHiddenFromDashboard: true
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

        let video = AnimalVideo(title: "Chasse", notes: "Belle capture", date: .now, videoPath: "test_video.mov", animal: animal)
        context.insert(video)

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
        XCTAssertEqual(animals.first?.videos.count, 1)
        XCTAssertEqual(animals.first?.videos.first?.title, "Chasse")
        XCTAssertEqual(animals.first?.videos.first?.videoPath, "test_video.mov")
        XCTAssertEqual(animals.first?.primaryPhotoOffsetX, 12)
        XCTAssertEqual(animals.first?.primaryPhotoOffsetY, -8)
        XCTAssertEqual(animals.first?.isHiddenFromDashboard, true)

        let terrariums = try context.fetch(FetchDescriptor<Terrarium>())
        XCTAssertEqual(terrariums.count, 1)
        XCTAssertEqual(terrariums.first?.cameras.count, 1)
        XCTAssertEqual(terrariums.first?.cameras.first?.name, "Cam Terrarium")
        XCTAssertEqual(terrariums.first?.cameras.first?.streamURL, "rtsp://192.168.1.50:554/stream1")
        XCTAssertTrue(terrariums.first?.cameras.first?.isConfigured ?? false)
    }

    func testTerrariumObservationRoundTrip() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext

        let terrarium = Terrarium(name: "Bac planté", type: .terrarium)
        context.insert(terrarium)

        let observation = ObservationEntry(
            date: .now,
            eventType: ObservationEventType.behavior.rawValue,
            note: "Nouvelle mousse sur la racine",
            photoPaths: ["terrarium_photo.jpg"],
            terrarium: terrarium
        )
        context.insert(observation)
        try context.save()

        let data = try BackupService.shared.exportData(context: context)
        try BackupService.shared.importData(data, context: context)

        let terrariums = try context.fetch(FetchDescriptor<Terrarium>())
        XCTAssertEqual(terrariums.count, 1)
        XCTAssertEqual(terrariums.first?.observations.count, 1)
        XCTAssertEqual(terrariums.first?.observations.first?.note, "Nouvelle mousse sur la racine")
        XCTAssertEqual(terrariums.first?.observations.first?.photoPaths, ["terrarium_photo.jpg"])

        // Une observation de terrarium n'est pas rattachée à un animal.
        let orphanAnimals = try context.fetch(FetchDescriptor<Animal>())
        XCTAssertTrue(orphanAnimals.isEmpty)
    }

    @MainActor
    func testLightRoundTrip() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext

        let terrarium = Terrarium(name: "Bac tropical", type: .terrarium)
        context.insert(terrarium)

        let light = Light(name: "Lampe WiZ", brand: .wiz, ipAddress: "192.168.1.50", terrarium: terrarium)
        light.scheduleMode = .fixed
        light.dayStartMinutes = 8 * 60
        light.dayEndMinutes = 20 * 60
        light.dayBrightness = 80
        light.biotopeMoonEnabled = true
        context.insert(light)

        let orphan = Light(name: "Lampe libre", brand: .wiz, ipAddress: "192.168.1.51")
        orphan.scheduleMode = .biotope
        orphan.biotopePresetID = "soroa"
        context.insert(orphan)
        try context.save()

        let data = try BackupService.shared.exportData(context: context)
        try BackupService.shared.importData(data, context: context)

        let lights = try context.fetch(FetchDescriptor<Light>())
        XCTAssertEqual(lights.count, 2)

        let attached = lights.first { $0.terrarium != nil }
        XCTAssertEqual(attached?.name, "Lampe WiZ")
        XCTAssertEqual(attached?.terrarium?.name, "Bac tropical")
        XCTAssertEqual(attached?.scheduleMode, .fixed)
        XCTAssertEqual(attached?.dayStartMinutes, 8 * 60)
        XCTAssertEqual(attached?.dayEndMinutes, 20 * 60)
        XCTAssertEqual(attached?.dayBrightness, 80)
        XCTAssertEqual(attached?.biotopeMoonEnabled, true)

        let unattached = lights.first { $0.terrarium == nil }
        XCTAssertEqual(unattached?.name, "Lampe libre")
        XCTAssertEqual(unattached?.scheduleMode, .biotope)
        XCTAssertEqual(unattached?.biotopePresetID, "soroa")
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

    func testImportAcceptsAnimalWithoutVideosKey() throws {
        // Simulates a backup exported before AnimalDTO.videos existed.
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext
        let legacyJSON = """
        {
            "exportedAt": "2026-01-01T00:00:00Z",
            "terrariums": [],
            "unassignedAnimals": [
                {
                    "name": "Legacy",
                    "species": "Test",
                    "type": "jumping_spider",
                    "sex": "unknown",
                    "origin": "captured",
                    "arrivalDate": "2026-01-01T00:00:00Z",
                    "currentStage": "L5",
                    "status": "normal",
                    "notes": "",
                    "broodPresent": false,
                    "journalEntries": [],
                    "reminders": [],
                    "measurements": []
                }
            ]
        }
        """.data(using: .utf8)!

        try BackupService.shared.importData(legacyJSON, context: context)

        let animals = try context.fetch(FetchDescriptor<Animal>())
        XCTAssertEqual(animals.first?.videos.count ?? -1, 0)
    }
}
