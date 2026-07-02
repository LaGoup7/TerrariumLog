import Foundation
import SwiftData

enum BackupError: Error {
    case decodingFailed
}

struct BackupService {
    static let shared = BackupService()

    // MARK: - Export

    func exportData(context: ModelContext) throws -> Data {
        let terrariums = (try? context.fetch(FetchDescriptor<Terrarium>())) ?? []
        let animals = (try? context.fetch(FetchDescriptor<Animal>())) ?? []

        let terrariumDTOs = terrariums.map(makeTerrariumDTO)
        let unassignedAnimalDTOs = animals.filter { $0.terrarium == nil }.map(makeAnimalDTO)

        let backup = BackupData(
            exportedAt: .now,
            terrariums: terrariumDTOs,
            unassignedAnimals: unassignedAnimalDTOs
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    private func makeTerrariumDTO(_ terrarium: Terrarium) -> TerrariumDTO {
        TerrariumDTO(
            name: terrarium.name,
            type: terrarium.type,
            notes: terrarium.notes,
            dimensions: terrarium.dimensions,
            substrate: terrarium.substrate,
            decor: terrarium.decor,
            createdAt: terrarium.createdAt,
            mainPhotoPath: terrarium.mainPhotoPath,
            wizLightIP: terrarium.wizLightIP,
            targetTemperatureMin: terrarium.targetTemperatureMin,
            targetTemperatureMax: terrarium.targetTemperatureMax,
            targetHumidityMin: terrarium.targetHumidityMin,
            targetHumidityMax: terrarium.targetHumidityMax,
            animals: terrarium.animals.map(makeAnimalDTO),
            plants: terrarium.plants.map(makePlantDTO)
        )
    }

    private func makeAnimalDTO(_ animal: Animal) -> AnimalDTO {
        AnimalDTO(
            name: animal.name,
            species: animal.species,
            scientificName: animal.scientificName,
            type: animal.type,
            sex: animal.sex,
            origin: animal.origin,
            locality: animal.locality,
            breeder: animal.breeder,
            purchasePrice: animal.purchasePrice,
            arrivalDate: animal.arrivalDate,
            currentStage: animal.currentStage,
            status: animal.status,
            notes: animal.notes,
            primaryPhotoPath: animal.primaryPhotoPath,
            estimatedWorkerCount: animal.estimatedWorkerCount,
            queenCount: animal.queenCount,
            broodPresent: animal.broodPresent,
            swarmingDateEstimate: animal.swarmingDateEstimate,
            journalEntries: animal.journalEntries.map(makeObservationEntryDTO),
            reminders: animal.reminders.map(makeReminderDTO),
            measurements: animal.measurements.map(makeMeasurementDTO)
        )
    }

    private func makeObservationEntryDTO(_ entry: ObservationEntry) -> ObservationEntryDTO {
        ObservationEntryDTO(
            date: entry.date,
            eventType: entry.eventType,
            note: entry.note,
            photoPaths: entry.photoPaths,
            preyType: entry.preyType,
            preySize: entry.preySize,
            preyQuantity: entry.preyQuantity,
            eatenStatus: entry.eatenStatus,
            captureTimeMinutes: entry.captureTimeMinutes,
            previousStage: entry.previousStage,
            newStage: entry.newStage,
            moltSuspectedStartDate: entry.moltSuspectedStartDate
        )
    }

    private func makeReminderDTO(_ reminder: Reminder) -> ReminderDTO {
        ReminderDTO(
            title: reminder.title,
            reminderDate: reminder.reminderDate,
            recurrence: reminder.recurrence,
            category: reminder.category,
            notes: reminder.notes,
            isCompleted: reminder.isCompleted
        )
    }

    private func makeMeasurementDTO(_ measurement: MeasurementEntry) -> MeasurementEntryDTO {
        MeasurementEntryDTO(
            date: measurement.date,
            temperature: measurement.temperature,
            humidity: measurement.humidity,
            luminosity: measurement.luminosity,
            waterLevel: measurement.waterLevel,
            note: measurement.note
        )
    }

    private func makePlantDTO(_ plant: Plant) -> PlantDTO {
        PlantDTO(
            name: plant.name,
            species: plant.species,
            addedDate: plant.addedDate,
            lastWatered: plant.lastWatered,
            status: plant.status,
            notes: plant.notes
        )
    }

    // MARK: - Import

    /// Replaces all existing data with the contents of the backup.
    func importData(_ data: Data, context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup: BackupData
        do {
            backup = try decoder.decode(BackupData.self, from: data)
        } catch {
            throw BackupError.decodingFailed
        }

        try context.delete(model: Animal.self)
        try context.delete(model: Terrarium.self)

        for terrariumDTO in backup.terrariums {
            insert(terrariumDTO, into: context)
        }
        for animalDTO in backup.unassignedAnimals {
            insert(animalDTO, terrarium: nil, into: context)
        }

        try context.save()
    }

    private func insert(_ dto: TerrariumDTO, into context: ModelContext) {
        let terrarium = Terrarium(
            name: dto.name,
            type: dto.type,
            notes: dto.notes,
            dimensions: dto.dimensions,
            substrate: dto.substrate,
            decor: dto.decor,
            createdAt: dto.createdAt,
            mainPhotoPath: dto.mainPhotoPath,
            wizLightIP: dto.wizLightIP,
            targetTemperatureMin: dto.targetTemperatureMin,
            targetTemperatureMax: dto.targetTemperatureMax,
            targetHumidityMin: dto.targetHumidityMin,
            targetHumidityMax: dto.targetHumidityMax
        )
        context.insert(terrarium)

        for plantDTO in dto.plants {
            let plant = Plant(
                name: plantDTO.name,
                species: plantDTO.species,
                addedDate: plantDTO.addedDate,
                lastWatered: plantDTO.lastWatered,
                status: plantDTO.status,
                notes: plantDTO.notes,
                terrarium: terrarium
            )
            context.insert(plant)
        }

        for animalDTO in dto.animals {
            insert(animalDTO, terrarium: terrarium, into: context)
        }
    }

    private func insert(_ dto: AnimalDTO, terrarium: Terrarium?, into context: ModelContext) {
        let animal = Animal(
            name: dto.name,
            species: dto.species,
            scientificName: dto.scientificName,
            type: dto.type,
            sex: dto.sex,
            origin: dto.origin,
            locality: dto.locality,
            breeder: dto.breeder,
            purchasePrice: dto.purchasePrice,
            arrivalDate: dto.arrivalDate,
            currentStage: dto.currentStage,
            status: dto.status,
            notes: dto.notes,
            primaryPhotoPath: dto.primaryPhotoPath,
            estimatedWorkerCount: dto.estimatedWorkerCount,
            queenCount: dto.queenCount,
            broodPresent: dto.broodPresent,
            swarmingDateEstimate: dto.swarmingDateEstimate
        )
        animal.terrarium = terrarium
        context.insert(animal)

        for entryDTO in dto.journalEntries {
            let entry = ObservationEntry(
                date: entryDTO.date,
                eventType: entryDTO.eventType,
                note: entryDTO.note,
                photoPaths: entryDTO.photoPaths,
                preyType: entryDTO.preyType,
                preySize: entryDTO.preySize,
                preyQuantity: entryDTO.preyQuantity,
                eatenStatus: entryDTO.eatenStatus,
                captureTimeMinutes: entryDTO.captureTimeMinutes,
                previousStage: entryDTO.previousStage,
                newStage: entryDTO.newStage,
                moltSuspectedStartDate: entryDTO.moltSuspectedStartDate,
                animal: animal
            )
            context.insert(entry)
        }

        for reminderDTO in dto.reminders {
            let reminder = Reminder(
                animal: animal,
                title: reminderDTO.title,
                reminderDate: reminderDTO.reminderDate,
                recurrence: reminderDTO.recurrence,
                category: reminderDTO.category,
                notes: reminderDTO.notes,
                isCompleted: reminderDTO.isCompleted
            )
            context.insert(reminder)
            if !reminder.isCompleted {
                NotificationService.shared.scheduleReminder(reminder)
            }
        }

        for measurementDTO in dto.measurements {
            let measurement = MeasurementEntry(
                date: measurementDTO.date,
                temperature: measurementDTO.temperature,
                humidity: measurementDTO.humidity,
                luminosity: measurementDTO.luminosity,
                waterLevel: measurementDTO.waterLevel,
                note: measurementDTO.note,
                animal: animal
            )
            context.insert(measurement)
        }
    }
}
