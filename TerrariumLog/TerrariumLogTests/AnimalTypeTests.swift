import XCTest
@testable import TerrariumLog

final class AnimalTypeTests: XCTestCase {
    func testOnlyIndividuallyMoltingSpeciesTrackMolting() {
        XCTAssertTrue(AnimalType.jumpingSpider.tracksMolting)
        XCTAssertTrue(AnimalType.gecko.tracksMolting)
        XCTAssertTrue(AnimalType.insect.tracksMolting)
        XCTAssertFalse(AnimalType.antColony.tracksMolting)
        XCTAssertFalse(AnimalType.dendrobate.tracksMolting)
        XCTAssertFalse(AnimalType.other.tracksMolting)
    }

    func testOnlyAntColoniesTrackDiapause() {
        XCTAssertTrue(AnimalType.antColony.tracksDiapause)
        for type in AnimalType.allCases where type != .antColony {
            XCTAssertFalse(type.tracksDiapause, "\(type) should not track diapause")
        }
    }
}
