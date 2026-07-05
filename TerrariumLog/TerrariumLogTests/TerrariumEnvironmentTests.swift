import XCTest
@testable import TerrariumLog

final class TerrariumEnvironmentTests: XCTestCase {
    func testStatusWithFullRange() {
        XCTAssertEqual(Terrarium.status(25, min: 24, max: 28), .inRange)
        XCTAssertEqual(Terrarium.status(24, min: 24, max: 28), .inRange)
        XCTAssertEqual(Terrarium.status(28, min: 24, max: 28), .inRange)
        XCTAssertEqual(Terrarium.status(23.9, min: 24, max: 28), .belowRange)
        XCTAssertEqual(Terrarium.status(28.1, min: 24, max: 28), .aboveRange)
    }

    func testStatusWithHalfOpenRanges() {
        XCTAssertEqual(Terrarium.status(50, min: 60, max: nil), .belowRange)
        XCTAssertEqual(Terrarium.status(75, min: 60, max: nil), .inRange)
        XCTAssertEqual(Terrarium.status(90, min: nil, max: 80), .aboveRange)
        XCTAssertEqual(Terrarium.status(70, min: nil, max: 80), .inRange)
    }

    func testStatusWithoutTargets() {
        XCTAssertEqual(Terrarium.status(25, min: nil, max: nil), .noTarget)
    }

    func testTargetLabels() {
        XCTAssertEqual(Terrarium.targetLabel(min: 24, max: 28), "24–28")
        XCTAssertEqual(Terrarium.targetLabel(min: 60, max: nil), "≥ 60")
        XCTAssertEqual(Terrarium.targetLabel(min: nil, max: 80), "≤ 80")
        XCTAssertEqual(Terrarium.targetLabel(min: 24.5, max: nil), "≥ 24.5")
        XCTAssertNil(Terrarium.targetLabel(min: nil, max: nil))
    }
}
