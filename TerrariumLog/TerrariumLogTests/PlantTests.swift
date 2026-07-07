import XCTest
@testable import TerrariumLog

final class PlantTests: XCTestCase {

    func testWateringNotDueWithoutTracking() {
        let plant = Plant(name: "Mousse")
        XCTAssertNil(plant.wateringDueDate)
        XCTAssertFalse(plant.isWateringDue)
    }

    func testWateringDueAfterInterval() {
        let plant = Plant(
            name: "Fittonia",
            lastWatered: Calendar.current.date(byAdding: .day, value: -8, to: .now),
            wateringIntervalDays: 7
        )
        XCTAssertTrue(plant.isWateringDue)
    }

    func testWateringNotDueBeforeInterval() {
        let plant = Plant(
            name: "Fittonia",
            lastWatered: Calendar.current.date(byAdding: .day, value: -2, to: .now),
            wateringIntervalDays: 7
        )
        XCTAssertFalse(plant.isWateringDue)
    }

    /// Jamais arrosée : l'échéance court depuis la date d'ajout.
    func testNeverWateredCountsFromAddedDate() {
        let plant = Plant(
            name: "Épiphyte",
            addedDate: Calendar.current.date(byAdding: .day, value: -10, to: .now) ?? .now,
            wateringIntervalDays: 7
        )
        XCTAssertTrue(plant.isWateringDue)
    }

    func testMarkWateredResetsDueDate() {
        let plant = Plant(
            name: "Fittonia",
            lastWatered: Calendar.current.date(byAdding: .day, value: -8, to: .now),
            wateringIntervalDays: 7
        )
        XCTAssertTrue(plant.isWateringDue)
        plant.markWatered()
        XCTAssertFalse(plant.isWateringDue)
    }

    func testAdviceOnlyForProblemStatuses() {
        XCTAssertNil(PlantStatus.ok.advice)
        for status in PlantStatus.allCases where status != .ok {
            XCTAssertNotNil(status.advice, "\(status) doit proposer un conseil")
        }
    }
}
