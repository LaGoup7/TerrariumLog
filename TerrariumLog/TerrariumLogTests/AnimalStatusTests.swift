import XCTest
@testable import TerrariumLog

final class AnimalStatusTests: XCTestCase {
    func testCriticalStatusesMapToCriticalAlert() {
        XCTAssertEqual(AnimalStatus.sick.alertLevel, .critical)
        XCTAssertEqual(AnimalStatus.deceased.alertLevel, .critical)
    }

    func testWarningStatusesMapToWarningAlert() {
        XCTAssertEqual(AnimalStatus.premolt.alertLevel, .warning)
        XCTAssertEqual(AnimalStatus.stressed.alertLevel, .warning)
        XCTAssertEqual(AnimalStatus.pause.alertLevel, .warning)
    }

    func testOtherStatusesMapToOkAlert() {
        XCTAssertEqual(AnimalStatus.normal.alertLevel, .ok)
        XCTAssertEqual(AnimalStatus.adult.alertLevel, .ok)
        XCTAssertEqual(AnimalStatus.growth.alertLevel, .ok)
    }

    func testColonyLifecycleStatusesUnavailableForIndividualAnimals() {
        XCTAssertFalse(AnimalStatus.foundation.isAvailable(for: .jumpingSpider))
        XCTAssertFalse(AnimalStatus.growth.isAvailable(for: .gecko))
        XCTAssertTrue(AnimalStatus.foundation.isAvailable(for: .antColony))
    }

    func testMoltStatusesOnlyAvailableForMoltingSpecies() {
        XCTAssertTrue(AnimalStatus.premolt.isAvailable(for: .jumpingSpider))
        XCTAssertTrue(AnimalStatus.molting.isAvailable(for: .gecko))
        XCTAssertFalse(AnimalStatus.premolt.isAvailable(for: .antColony))
        XCTAssertFalse(AnimalStatus.molting.isAvailable(for: .dendrobate))
    }

    func testNormalIsAlwaysAvailable() {
        for type in AnimalType.allCases {
            XCTAssertTrue(AnimalStatus.normal.isAvailable(for: type), "\(type) should allow .normal")
        }
    }
}
