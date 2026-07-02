import XCTest
@testable import TerrariumLog

final class WidgetSnapshotTests: XCTestCase {
    func testWidgetSnapshotDataRoundTripsThroughJSON() throws {
        let snapshot = WidgetSnapshotData(
            reminders: [
                WidgetReminderSnapshot(title: "Nourrir Soroa", animalName: "Soroa", date: Date(timeIntervalSince1970: 1000))
            ],
            generatedAt: Date(timeIntervalSince1970: 2000)
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WidgetSnapshotData.self, from: data)

        XCTAssertEqual(decoded.reminders.count, 1)
        XCTAssertEqual(decoded.reminders.first?.title, "Nourrir Soroa")
        XCTAssertEqual(decoded.reminders.first?.animalName, "Soroa")
    }

    func testSaveAndLoadDoNotCrashWithoutAppGroupAccess() {
        // The XCTest process has no real App Group entitlement, so this should no-op
        // safely rather than crash - exactly the degraded-mode behavior the app relies
        // on when the App Group isn't available on-device either (see README).
        let snapshot = WidgetSnapshotData(reminders: [], generatedAt: .now)
        WidgetSnapshotStore.save(snapshot)
        _ = WidgetSnapshotStore.load()
    }
}
