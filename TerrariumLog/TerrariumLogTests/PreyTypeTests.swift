import XCTest
@testable import TerrariumLog

final class PreyTypeTests: XCTestCase {
    func testPredatorPreyUnavailableForAntColony() {
        XCTAssertFalse(PreyType.cricket.isAvailable(for: .antColony))
        XCTAssertFalse(PreyType.roach.isAvailable(for: .antColony))
        XCTAssertTrue(PreyType.sugarWater.isAvailable(for: .antColony))
        XCTAssertTrue(PreyType.seeds.isAvailable(for: .antColony))
    }

    func testColonyFoodUnavailableForPredators() {
        XCTAssertFalse(PreyType.sugarWater.isAvailable(for: .jumpingSpider))
        XCTAssertFalse(PreyType.seeds.isAvailable(for: .gecko))
        XCTAssertTrue(PreyType.cricket.isAvailable(for: .jumpingSpider))
    }

    func testDendrobateGetsSmallPreyOnly() {
        XCTAssertTrue(PreyType.drosophile.isAvailable(for: .dendrobate))
        XCTAssertTrue(PreyType.microCricket.isAvailable(for: .dendrobate))
        XCTAssertFalse(PreyType.roach.isAvailable(for: .dendrobate))
        XCTAssertFalse(PreyType.sugarWater.isAvailable(for: .dendrobate))
    }

    func testOtherIsAlwaysAvailable() {
        for type in AnimalType.allCases {
            XCTAssertTrue(PreyType.other.isAvailable(for: type), "\(type) should allow .other")
        }
    }
}
