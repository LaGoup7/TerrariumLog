import XCTest
@testable import TerrariumLog

final class ObservationCategoryTests: XCTestCase {

    func testEventTypesMapToExpectedCategories() {
        XCTAssertEqual(ObservationEventType.feeding.category, .feeding)
        XCTAssertEqual(ObservationEventType.foodRefusal.category, .feeding)
        XCTAssertEqual(ObservationEventType.molt.category, .molting)
        XCTAssertEqual(ObservationEventType.premoltStart.category, .molting)
        XCTAssertEqual(ObservationEventType.weighing.category, .health)
        XCTAssertEqual(ObservationEventType.injury.category, .health)
        XCTAssertEqual(ObservationEventType.waterRefill.category, .maintenance)
        XCTAssertEqual(ObservationEventType.cleaning.category, .maintenance)
        XCTAssertEqual(ObservationEventType.cameraInstalled.category, .environment)
        XCTAssertEqual(ObservationEventType.firmwareUpdate.category, .environment)
        XCTAssertEqual(ObservationEventType.arrival.category, .lifecycle)
        XCTAssertEqual(ObservationEventType.webBuilding.category, .behavior)
        XCTAssertEqual(ObservationEventType.other.category, .note)
    }

    func testEveryEventTypeHasANonEmptyIconAndName() {
        for type in ObservationEventType.allCases {
            XCTAssertFalse(type.symbolName.isEmpty, "\(type) sans icône")
            XCTAssertFalse(type.displayName.isEmpty, "\(type) sans libellé")
        }
    }

    // MARK: Disponibilité par espèce

    func testMoltingOnlyForSpeciesThatMolt() {
        XCTAssertTrue(ObservationEventType.molt.isAvailable(for: .jumpingSpider))
        XCTAssertTrue(ObservationEventType.molt.isAvailable(for: .gecko))
        XCTAssertTrue(ObservationEventType.molt.isAvailable(for: .insect))
        XCTAssertTrue(ObservationEventType.molt.isAvailable(for: .other))
        XCTAssertFalse(ObservationEventType.molt.isAvailable(for: .antColony))
        XCTAssertFalse(ObservationEventType.molt.isAvailable(for: .dendrobate))
    }

    func testSpiderSpecificBehaviorsRestrictedToSpiders() {
        XCTAssertTrue(ObservationEventType.webBuilding.isAvailable(for: .jumpingSpider))
        XCTAssertTrue(ObservationEventType.eggSac.isAvailable(for: .jumpingSpider))
        XCTAssertFalse(ObservationEventType.webBuilding.isAvailable(for: .gecko))
        XCTAssertFalse(ObservationEventType.hammockBuilt.isAvailable(for: .antColony))
    }

    func testColonyLifeEventsRestrictedToAntColony() {
        XCTAssertTrue(ObservationEventType.larvae.isAvailable(for: .antColony))
        XCTAssertTrue(ObservationEventType.firstWorkers.isAvailable(for: .antColony))
        XCTAssertTrue(ObservationEventType.queenLaidEggs.isAvailable(for: .antColony))
        XCTAssertFalse(ObservationEventType.larvae.isAvailable(for: .jumpingSpider))
    }

    func testHealthMaintenanceEnvironmentAreUniversal() {
        for animalType in AnimalType.allCases {
            XCTAssertTrue(ObservationEventType.weighing.isAvailable(for: animalType), "pesée indisponible pour \(animalType)")
            XCTAssertTrue(ObservationEventType.cleaning.isAvailable(for: animalType), "nettoyage indisponible pour \(animalType)")
            XCTAssertTrue(ObservationEventType.cameraInstalled.isAvailable(for: animalType), "caméra indisponible pour \(animalType)")
        }
    }

    /// Garantit qu'aucune disponibilité historique n'a été retirée par la refonte.
    func testLegacyAvailabilityPreserved() {
        XCTAssertTrue(ObservationEventType.feeding.isAvailable(for: .jumpingSpider))
        XCTAssertTrue(ObservationEventType.capture.isAvailable(for: .antColony))
        XCTAssertTrue(ObservationEventType.laying.isAvailable(for: .dendrobate))
        XCTAssertTrue(ObservationEventType.hibernationStart.isAvailable(for: .antColony))
        XCTAssertFalse(ObservationEventType.hibernationStart.isAvailable(for: .jumpingSpider))
    }
}
