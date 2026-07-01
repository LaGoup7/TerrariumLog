import Foundation
import SwiftData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    init(inMemory: Bool = false) {
        let schema = Schema([
            Animal.self,
            ObservationEntry.self,
            Reminder.self,
            MeasurementEntry.self,
            Terrarium.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    func seedDemoDataIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Animal>()
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return
        }

        let ants1 = Animal(
            name: "Lasius 1",
            species: "Lasius niger",
            type: .antColony,
            origin: .captured,
            arrivalDate: Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date(),
            currentStage: "Fondation",
            status: .foundation,
            notes: "Colonie en démarrage"
        )

        let ants2 = Animal(
            name: "Lasius 2",
            species: "Lasius niger",
            type: .antColony,
            origin: .adopted,
            arrivalDate: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
            currentStage: "Croissance",
            status: .growth,
            notes: "Bonne progression"
        )

        let ants3 = Animal(
            name: "Lasius 3",
            species: "Lasius flavus",
            type: .antColony,
            origin: .purchased,
            arrivalDate: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
            currentStage: "Adultes",
            status: .adult,
            notes: "Colonie stable"
        )

        let messor = Animal(
            name: "Messor barbarus",
            species: "Messor barbarus",
            type: .antColony,
            origin: .captured,
            arrivalDate: Calendar.current.date(byAdding: .month, value: -4, to: Date()) ?? Date(),
            currentStage: "Croissance",
            status: .growth,
            notes: "Très active"
        )

        let spider = Animal(
            name: "Phidippus regius Soroa",
            species: "Phidippus regius",
            type: .jumpingSpider,
            origin: .purchased,
            arrivalDate: Calendar.current.date(byAdding: .weekOfYear, value: -2, to: Date()) ?? Date(),
            currentStage: "Adulte",
            status: .adult,
            notes: "Araignée en bonne santé"
        )

        let terrarium = Terrarium(
            name: "Terrarium principal",
            type: .terrarium,
            notes: "Habitat principal",
            dimensions: "30 x 30 x 40 cm",
            targetTemperatureMin: 24,
            targetTemperatureMax: 28,
            targetHumidityMin: 50,
            targetHumidityMax: 70,
            animal: nil
        )

        context.insert(terrarium)
        ants1.terrarium = terrarium
        ants2.terrarium = terrarium
        ants3.terrarium = terrarium
        messor.terrarium = terrarium
        spider.terrarium = terrarium

        context.insert(ants1)
        context.insert(ants2)
        context.insert(ants3)
        context.insert(messor)
        context.insert(spider)

        let journal1 = ObservationEntry(date: Date(), eventType: ObservationEventType.capture.rawValue, note: "Première observation", animal: ants1)
        context.insert(journal1)

        let reminder = Reminder(
            animal: ants1,
            title: "Humidification",
            reminderDate: Date().addingTimeInterval(86400),
            recurrence: .weekly,
            category: .humidification
        )
        context.insert(reminder)

        try? context.save()
    }
}
