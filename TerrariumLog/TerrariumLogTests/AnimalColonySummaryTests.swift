import XCTest
@testable import TerrariumLog

final class AnimalColonySummaryTests: XCTestCase {
    private func makeAnimal(type: AnimalType, workers: Int? = nil, queens: Int? = nil) -> Animal {
        Animal(
            name: "Test",
            species: "Test species",
            type: type,
            origin: .captured,
            arrivalDate: .now,
            currentStage: "",
            status: .normal,
            notes: "",
            estimatedWorkerCount: workers,
            queenCount: queens
        )
    }

    func testNonColonyAnimalHasNoSummary() {
        let animal = makeAnimal(type: .jumpingSpider, workers: 5, queens: 1)
        XCTAssertNil(animal.colonySummary)
    }

    func testColonyWithNoCountsHasNoSummary() {
        let animal = makeAnimal(type: .antColony)
        XCTAssertNil(animal.colonySummary)
    }

    func testColonyWithWorkersAndQueensFormatsBoth() {
        let animal = makeAnimal(type: .antColony, workers: 12, queens: 1)
        XCTAssertEqual(animal.colonySummary, "12 ouvrières · 1 reine")
    }

    func testColonyWithOnlyWorkersOmitsQueens() {
        let animal = makeAnimal(type: .antColony, workers: 1)
        XCTAssertEqual(animal.colonySummary, "1 ouvrière")
    }
}
