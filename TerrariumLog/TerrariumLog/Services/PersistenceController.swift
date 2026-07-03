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
            Terrarium.self,
            Plant.self,
            Camera.self,
            CustomPreyType.self,
            AnimalVideo.self
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

        let calendar = Calendar.current

        // Terrarium et araignée de l'exemple du cahier des charges
        let spiderTerrarium = Terrarium(
            name: "Terrarium Phidippus",
            type: .terrarium,
            notes: "Décor cubain/Soroa",
            dimensions: "20 x 20 x 35 cm",
            substrate: "Fibre de coco",
            decor: "Écorce stérile 25-40 cm, mousse verte sèche",
            createdAt: calendar.date(byAdding: .weekOfYear, value: -2, to: Date()) ?? Date(),
            targetTemperatureMin: 24,
            targetTemperatureMax: 28,
            targetHumidityMin: 55,
            targetHumidityMax: 70
        )
        context.insert(spiderTerrarium)

        let spider = Animal(
            name: "Soroa",
            species: "Phidippus regius",
            scientificName: "Phidippus regius",
            type: .jumpingSpider,
            sex: .unknown,
            origin: .purchased,
            locality: "Soroa, Cuba",
            arrivalDate: calendar.date(byAdding: .weekOfYear, value: -2, to: Date()) ?? Date(),
            currentStage: "L5",
            status: .normal,
            notes: "Acclimatation en cours"
        )
        spider.terrarium = spiderTerrarium
        context.insert(spider)

        for plant in [
            Plant(name: "Fittonia", species: "Fittonia albivenis", terrarium: spiderTerrarium),
            Plant(name: "Callisia Turtle", species: "Callisia repens", terrarium: spiderTerrarium),
            Plant(name: "Peperomia", species: "Peperomia sp.", terrarium: spiderTerrarium)
        ] {
            context.insert(plant)
        }

        let arrivalDate = spider.arrivalDate
        let sprayDate = calendar.date(byAdding: .day, value: 1, to: arrivalDate) ?? arrivalDate
        let firstFeedingDate = calendar.date(byAdding: .day, value: 3, to: arrivalDate) ?? arrivalDate
        let moltDate = calendar.date(byAdding: .day, value: 10, to: arrivalDate) ?? arrivalDate

        let arrivalEvent = ObservationEntry(date: arrivalDate, eventType: ObservationEventType.arrival.rawValue, note: "Arrivée de Soroa", animal: spider)
        let sprayEvent = ObservationEntry(date: sprayDate, eventType: ObservationEventType.humidifying.rawValue, note: "Première pulvérisation", animal: spider)
        let feedingEvent = ObservationEntry(
            date: firstFeedingDate,
            eventType: ObservationEventType.feeding.rawValue,
            note: "Premier repas proposé",
            preyType: PreyType.drosophile.rawValue,
            preyQuantity: 3,
            eatenStatus: EatenStatus.yes.rawValue,
            animal: spider
        )
        let moltEvent = ObservationEntry(
            date: moltDate,
            eventType: ObservationEventType.molt.rawValue,
            note: "Mue observée",
            previousStage: "L5",
            newStage: "L6",
            animal: spider
        )
        for event in [arrivalEvent, sprayEvent, feedingEvent, moltEvent] {
            context.insert(event)
        }
        spider.currentStage = "L6"

        let spiderReminder = Reminder(
            animal: spider,
            title: "Nourrir Soroa",
            reminderDate: Date().addingTimeInterval(86400 * 3),
            recurrence: .none,
            category: .feeding
        )
        context.insert(spiderReminder)

        // Colonie de fourmis pour illustrer le second cas d'usage
        let antTerrarium = Terrarium(
            name: "Terrarium principal",
            type: .terrarium,
            notes: "Habitat principal",
            dimensions: "30 x 30 x 40 cm",
            substrate: "Terre de bruyère",
            targetTemperatureMin: 22,
            targetTemperatureMax: 26,
            targetHumidityMin: 50,
            targetHumidityMax: 70
        )
        context.insert(antTerrarium)

        let ants = Animal(
            name: "Lasius flavus",
            species: "Lasius flavus",
            type: .antColony,
            origin: .captured,
            arrivalDate: calendar.date(byAdding: .month, value: -2, to: Date()) ?? Date(),
            currentStage: "Fondation",
            status: .foundation,
            notes: "Colonie en démarrage",
            estimatedWorkerCount: 5,
            queenCount: 1,
            broodPresent: true
        )
        ants.terrarium = antTerrarium
        context.insert(ants)

        let antsJournal = ObservationEntry(date: Date(), eventType: ObservationEventType.capture.rawValue, note: "Première observation", animal: ants)
        context.insert(antsJournal)

        let antsReminder = Reminder(
            animal: ants,
            title: "Humidification",
            reminderDate: Date().addingTimeInterval(86400),
            recurrence: .weekly,
            category: .humidification
        )
        context.insert(antsReminder)

        try? context.save()
    }
}
