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
}
