import XCTest
import SwiftData
@testable import TerrariumLog

final class LightScheduleEngineTests: XCTestCase {

    // MARK: Photopériode fixe

    /// 9 h 00 → 21 h 00, plein jour à 15 h 00 : plateau lumineux, blanc froid.
    func testFixedStateMiddayIsBrightest() {
        let state = LightScheduleEngine.fixedState(
            minutesSinceMidnight: 15 * 60,
            dayStartMinutes: 9 * 60,
            dayEndMinutes: 21 * 60,
            dayBrightness: 100
        )
        XCTAssertTrue(state.isDaylight)
        XCTAssertGreaterThanOrEqual(state.brightness, 90)
        XCTAssertGreaterThanOrEqual(state.colorTemperature, 4800)
    }

    /// Juste après le lever : aube faible et chaude (pas d'allumage brutal).
    func testFixedStateDawnIsDimAndWarm() {
        let state = LightScheduleEngine.fixedState(
            minutesSinceMidnight: 9 * 60 + 10,
            dayStartMinutes: 9 * 60,
            dayEndMinutes: 21 * 60,
            dayBrightness: 100
        )
        XCTAssertTrue(state.isDaylight)
        XCTAssertLessThan(state.brightness, 60)
        XCTAssertLessThan(state.colorTemperature, 4000)
    }

    /// Avant le lever et après le coucher : nuit.
    func testFixedStateNightOutsidePhotoperiod() {
        let before = LightScheduleEngine.fixedState(
            minutesSinceMidnight: 8 * 60,
            dayStartMinutes: 9 * 60,
            dayEndMinutes: 21 * 60,
            dayBrightness: 100
        )
        XCTAssertFalse(before.isDaylight)

        let after = LightScheduleEngine.fixedState(
            minutesSinceMidnight: 22 * 60,
            dayStartMinutes: 9 * 60,
            dayEndMinutes: 21 * 60,
            dayBrightness: 100
        )
        XCTAssertFalse(after.isDaylight)
    }

    /// L'intensité du plateau est plafonnée par `dayBrightness`.
    func testFixedStateRespectsDayBrightness() {
        let state = LightScheduleEngine.fixedState(
            minutesSinceMidnight: 15 * 60,
            dayStartMinutes: 9 * 60,
            dayEndMinutes: 21 * 60,
            dayBrightness: 60
        )
        XCTAssertTrue(state.isDaylight)
        XCTAssertLessThanOrEqual(state.brightness, 60)
        XCTAssertGreaterThanOrEqual(state.brightness, 40)
    }

    /// La courbe monte le matin et descend le soir (aube < midi > crépuscule).
    func testFixedStateCurveIsSymmetricAroundMidday() {
        func brightness(at minutes: Int) -> Int {
            LightScheduleEngine.fixedState(
                minutesSinceMidnight: minutes,
                dayStartMinutes: 9 * 60,
                dayEndMinutes: 21 * 60,
                dayBrightness: 100
            ).brightness
        }
        let morning = brightness(at: 10 * 60)
        let midday = brightness(at: 15 * 60)
        let evening = brightness(at: 20 * 60)
        XCTAssertLessThan(morning, midday)
        XCTAssertLessThan(evening, midday)
    }

    /// Photopériode inversée (21 h 00 → 9 h 00, espèces nocturnes) : jour à
    /// 2 h 00 du matin, nuit à 15 h 00.
    func testFixedStateOvernightPhotoperiod() {
        let night = LightScheduleEngine.fixedState(
            minutesSinceMidnight: 15 * 60,
            dayStartMinutes: 21 * 60,
            dayEndMinutes: 9 * 60,
            dayBrightness: 100
        )
        XCTAssertFalse(night.isDaylight)

        let day = LightScheduleEngine.fixedState(
            minutesSinceMidnight: 2 * 60,
            dayStartMinutes: 21 * 60,
            dayEndMinutes: 9 * 60,
            dayBrightness: 100
        )
        XCTAssertTrue(day.isDaylight)
        XCTAssertGreaterThan(day.brightness, 50)
    }

    // MARK: Consigne selon le mode

    func testTargetStateManualModeReturnsNil() {
        let light = Light(name: "Test", ipAddress: "192.168.1.10")
        light.scheduleMode = .manual
        XCTAssertNil(LightScheduleEngine.targetState(for: light))
    }

    func testTargetStateBiotopeWithoutPresetReturnsNil() {
        let light = Light(name: "Test", ipAddress: "192.168.1.10")
        light.scheduleMode = .biotope
        light.biotopePresetID = nil
        XCTAssertNil(LightScheduleEngine.targetState(for: light))
    }

    func testTargetStateFixedModeReturnsState() {
        let light = Light(name: "Test", ipAddress: "192.168.1.10")
        light.scheduleMode = .fixed
        XCTAssertNotNil(LightScheduleEngine.targetState(for: light))
    }

    // MARK: Migration de l'ancien champ Terrarium.wizLightIP

    @MainActor
    func testMigrationCreatesLightFromLegacyIP() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext

        let terrarium = Terrarium(name: "Ancien bac", type: .terrarium, wizLightIP: "192.168.1.42")
        context.insert(terrarium)
        try context.save()

        LightScheduleEngine.migrateLegacyTerrariumLights(context: context)

        let lights = try context.fetch(FetchDescriptor<Light>())
        XCTAssertEqual(lights.count, 1)
        XCTAssertEqual(lights.first?.ipAddress, "192.168.1.42")
        XCTAssertEqual(lights.first?.brand, .wiz)
        XCTAssertEqual(lights.first?.terrarium?.name, "Ancien bac")
        XCTAssertNil(terrarium.wizLightIP, "Le champ hérité doit être vidé après migration")
    }

    @MainActor
    func testMigrationSkipsAlreadyKnownIP() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext

        let terrarium = Terrarium(name: "Bac", type: .terrarium, wizLightIP: "192.168.1.42")
        context.insert(terrarium)
        let existing = Light(name: "Déjà déclarée", ipAddress: "192.168.1.42", terrarium: terrarium)
        context.insert(existing)
        try context.save()

        LightScheduleEngine.migrateLegacyTerrariumLights(context: context)

        let lights = try context.fetch(FetchDescriptor<Light>())
        XCTAssertEqual(lights.count, 1, "Pas de doublon quand la lampe existe déjà")
        XCTAssertNil(terrarium.wizLightIP)
    }

    @MainActor
    func testMigrationIsIdempotent() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext

        let terrarium = Terrarium(name: "Bac", type: .terrarium, wizLightIP: "192.168.1.42")
        context.insert(terrarium)
        try context.save()

        LightScheduleEngine.migrateLegacyTerrariumLights(context: context)
        LightScheduleEngine.migrateLegacyTerrariumLights(context: context)

        let lights = try context.fetch(FetchDescriptor<Light>())
        XCTAssertEqual(lights.count, 1)
    }
}
