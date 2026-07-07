import Foundation

struct BackupData: Codable {
    var exportedAt: Date
    var terrariums: [TerrariumDTO]
    var unassignedAnimals: [AnimalDTO]
    var customPreyTypeNames: [String]?
    var preyStocks: [PreyStockDTO]?
}

struct PreyStockDTO: Codable {
    var typeRawValue: String
    var quantity: Int
    var lowThreshold: Int
    var updatedAt: Date
}

struct TerrariumDTO: Codable {
    var name: String
    var type: TerrariumType
    var notes: String
    var dimensions: String
    var substrate: String
    var decor: String
    var createdAt: Date
    var mainPhotoPath: String?
    var mainPhotoOffsetX: Double?
    var mainPhotoOffsetY: Double?
    var wizLightIP: String?
    var sensorModuleIP: String?
    var targetTemperatureMin: Double?
    var targetTemperatureMax: Double?
    var targetHumidityMin: Double?
    var targetHumidityMax: Double?
    var animals: [AnimalDTO]
    var plants: [PlantDTO]
    var cameras: [CameraDTO]
    /// Observations/photos rattachées au terrarium (pas à un animal).
    /// Optionnel : absent des sauvegardes antérieures à cette évolution.
    var observations: [ObservationEntryDTO]?
}

struct AnimalDTO: Codable {
    var name: String
    var species: String
    var scientificName: String?
    var type: AnimalType
    var sex: AnimalSex
    var origin: AnimalOrigin
    var locality: String?
    var breeder: String?
    var purchasePrice: Double?
    var arrivalDate: Date
    var currentStage: String
    var status: AnimalStatus
    var notes: String
    var primaryPhotoPath: String?
    var primaryPhotoOffsetX: Double?
    var primaryPhotoOffsetY: Double?
    var dashboardSortOrder: Int?
    var isHiddenFromDashboard: Bool?
    var dietPreyRawValues: [String]?
    var estimatedWorkerCount: Int?
    var queenCount: Int?
    var broodPresent: Bool
    var swarmingDateEstimate: Date?
    var journalEntries: [ObservationEntryDTO]
    var reminders: [ReminderDTO]
    var measurements: [MeasurementEntryDTO]
    var videos: [AnimalVideoDTO]?
}

struct AnimalVideoDTO: Codable {
    var title: String
    var notes: String
    var date: Date
    var videoPath: String
}

struct ObservationEntryDTO: Codable {
    var date: Date
    var eventType: String
    var note: String
    var photoPaths: [String]
    var preyType: String?
    var preySize: String?
    var preyQuantity: Int?
    var eatenStatus: String?
    var captureTimeMinutes: Double?
    var previousStage: String?
    var newStage: String?
    var moltSuspectedStartDate: Date?
    var moltSizeMM: Double?
}

struct ReminderDTO: Codable {
    var title: String
    var reminderDate: Date
    var recurrence: ReminderRecurrence
    var category: ReminderCategory
    var notes: String
    var isCompleted: Bool
}

struct MeasurementEntryDTO: Codable {
    var date: Date
    var temperature: Double?
    var humidity: Double?
    var luminosity: Double?
    var waterLevel: Double?
    var note: String
}

struct PlantDTO: Codable {
    var name: String
    var species: String
    var addedDate: Date
    var lastWatered: Date?
    var status: PlantStatus
    var notes: String
}

struct CameraDTO: Codable {
    var name: String
    var brand: CameraBrand
    var model: String
    var connectionType: CameraConnectionType
    var streamURL: String?
    var ipAddress: String?
    var username: String?
    var password: String?
    var notes: String
    var createdAt: Date
}
