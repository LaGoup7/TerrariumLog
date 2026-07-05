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
        let customPreyTypes = (try? context.fetch(FetchDescriptor<CustomPreyType>())) ?? []

        let terrariumDTOs = terrariums.map(makeTerrariumDTO)
        let unassignedAnimalDTOs = animals.filter { $0.terrarium == nil }.map(makeAnimalDTO)

        let backup = BackupData(
            exportedAt: .now,
            terrariums: terrariumDTOs,
            unassignedAnimals: unassignedAnimalDTOs,
            customPreyTypeNames: customPreyTypes.map(\.name)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    /// Same as `exportData`, plus the list of photo and video filenames referenced by the exported
    /// records (primary/main photos, journal entry photos, animal videos), so the caller can bundle
    /// the actual files.
    func exportBundle(context: ModelContext) throws -> (data: Data, photoPaths: [String], videoPaths: [String]) {
        let data = try exportData(context: context)

        let terrariums = (try? context.fetch(FetchDescriptor<Terrarium>())) ?? []
        let animals = (try? context.fetch(FetchDescriptor<Animal>())) ?? []

        var photoPaths = Set<String>()
        var videoPaths = Set<String>()
        for terrarium in terrariums {
            if let path = terrarium.mainPhotoPath {
                photoPaths.insert(path)
            }
        }
        for animal in animals {
            if let path = animal.primaryPhotoPath {
                photoPaths.insert(path)
            }
            for entry in animal.journalEntries {
                photoPaths.formUnion(entry.photoPaths)
            }
            for video in animal.videos {
                videoPaths.insert(video.videoPath)
            }
        }

        return (data, Array(photoPaths), Array(videoPaths))
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
            mainPhotoOffsetX: terrarium.mainPhotoOffsetX,
            mainPhotoOffsetY: terrarium.mainPhotoOffsetY,
            wizLightIP: terrarium.wizLightIP,
            sensorModuleIP: terrarium.sensorModuleIP,
            targetTemperatureMin: terrarium.targetTemperatureMin,
            targetTemperatureMax: terrarium.targetTemperatureMax,
            targetHumidityMin: terrarium.targetHumidityMin,
            targetHumidityMax: terrarium.targetHumidityMax,
            animals: terrarium.animals.map(makeAnimalDTO),
            plants: terrarium.plants.map(makePlantDTO),
            cameras: terrarium.cameras.map(makeCameraDTO)
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
            primaryPhotoOffsetX: animal.primaryPhotoOffsetX,
            primaryPhotoOffsetY: animal.primaryPhotoOffsetY,
            dashboardSortOrder: animal.dashboardSortOrder,
            isHiddenFromDashboard: animal.isHiddenFromDashboard,
            estimatedWorkerCount: animal.estimatedWorkerCount,
            queenCount: animal.queenCount,
            broodPresent: animal.broodPresent,
            swarmingDateEstimate: animal.swarmingDateEstimate,
            journalEntries: animal.journalEntries.map(makeObservationEntryDTO),
            reminders: animal.reminders.map(makeReminderDTO),
            measurements: animal.measurements.map(makeMeasurementDTO),
            videos: animal.videos.map(makeAnimalVideoDTO)
        )
    }

    private func makeAnimalVideoDTO(_ video: AnimalVideo) -> AnimalVideoDTO {
        AnimalVideoDTO(
            title: video.title,
            notes: video.notes,
            date: video.date,
            videoPath: video.videoPath
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

    private func makeCameraDTO(_ camera: Camera) -> CameraDTO {
        CameraDTO(
            name: camera.name,
            brand: camera.brand,
            model: camera.model,
            connectionType: camera.connectionType,
            streamURL: camera.streamURL,
            ipAddress: camera.ipAddress,
            username: camera.username,
            password: camera.password,
            notes: camera.notes,
            createdAt: camera.createdAt
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

        // Deleted individually rather than via the type-based batch delete API:
        // batch-deleting Animal while Terrarium still references it through the
        // nullify inverse relationship trips a CoreData constraint trigger violation.
        for terrarium in try context.fetch(FetchDescriptor<Terrarium>()) {
            context.delete(terrarium)
        }
        for animal in try context.fetch(FetchDescriptor<Animal>()) {
            context.delete(animal)
        }
        for customPreyType in try context.fetch(FetchDescriptor<CustomPreyType>()) {
            context.delete(customPreyType)
        }
        try context.save()

        for terrariumDTO in backup.terrariums {
            insert(terrariumDTO, into: context)
        }
        for animalDTO in backup.unassignedAnimals {
            insert(animalDTO, terrarium: nil, into: context)
        }
        for name in backup.customPreyTypeNames ?? [] {
            context.insert(CustomPreyType(name: name))
        }

        try context.save()
        ReminderService.shared.refreshWidgetSnapshot(context: context)
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
            mainPhotoOffsetX: dto.mainPhotoOffsetX ?? 0,
            mainPhotoOffsetY: dto.mainPhotoOffsetY ?? 0,
            wizLightIP: dto.wizLightIP,
            sensorModuleIP: dto.sensorModuleIP,
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

        for cameraDTO in dto.cameras {
            let camera = Camera(
                name: cameraDTO.name,
                brand: cameraDTO.brand,
                model: cameraDTO.model,
                connectionType: cameraDTO.connectionType,
                streamURL: cameraDTO.streamURL,
                ipAddress: cameraDTO.ipAddress,
                username: cameraDTO.username,
                password: cameraDTO.password,
                notes: cameraDTO.notes,
                createdAt: cameraDTO.createdAt,
                terrarium: terrarium
            )
            context.insert(camera)
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
            primaryPhotoOffsetX: dto.primaryPhotoOffsetX ?? 0,
            primaryPhotoOffsetY: dto.primaryPhotoOffsetY ?? 0,
            dashboardSortOrder: dto.dashboardSortOrder ?? 0,
            isHiddenFromDashboard: dto.isHiddenFromDashboard ?? false,
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

        for videoDTO in dto.videos ?? [] {
            let video = AnimalVideo(
                title: videoDTO.title,
                notes: videoDTO.notes,
                date: videoDTO.date,
                videoPath: videoDTO.videoPath,
                animal: animal
            )
            context.insert(video)
        }
    }
}
