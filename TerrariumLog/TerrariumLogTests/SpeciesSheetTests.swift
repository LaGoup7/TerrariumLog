import XCTest
@testable import TerrariumLog

final class SpeciesSheetTests: XCTestCase {
    private let sampleBlock = """
    - Nom scientifique : Phidippus regius “Soroa”
    - Nom commun : Araignée sauteuse royale “Soroa”
    - Classification : Arachnida, Araneae, Salticidae
    - Origine géographique : Caraïbes
    - Biotope naturel : Milieux ouverts tropicaux
    - Taille adulte : Femelle env. 12–22 mm
    - Espérance de vie : Femelle 2–3 ans
    - Température : 22–28 °C, avec un optimum courant autour de 24–26 °C
    - Hygrométrie : 60–75 %, avec excellente ventilation
    - Terrarium (taille minimale) : 15 × 15 × 20 cm minimum
    - Substrat : Fibre de coco
    - Aménagements : Branches fines
    - Nourriture : Drosophiles, mouches
    - Fréquence de nourrissage : 1 à 3 repas par semaine
    - Eau : Brumisation légère
    - Comportement : Diurne et curieuse
    - Reproduction : Cocon de ponte
    - Difficulté d’élevage : Facile à intermédiaire
    - Remarques importantes : Ventilation essentielle.
    - Image : images/01_phidippus_regius_soroa.jpg

    - Nom scientifique : Lasius niger
    - Nom commun : Fourmi noire des jardins
    - Température : 21–26 °C
    - Hygrométrie : 50–65 %
    - Difficulté d'élevage : Facile
    - Image :
    """

    func testParsesBlocksAndFields() {
        let sheets = SpeciesSheet.parse(sampleBlock)
        XCTAssertEqual(sheets.count, 2)

        let regius = sheets[0]
        XCTAssertEqual(regius.commonName, "Araignée sauteuse royale “Soroa”")
        XCTAssertEqual(regius.classification, "Arachnida, Araneae, Salticidae")
        // Apostrophe typographique dans le libellé « Difficulté d’élevage ».
        XCTAssertEqual(regius.difficulty, "Facile à intermédiaire")
        XCTAssertEqual(regius.imageName, "01_phidippus_regius_soroa.jpg")

        let niger = sheets[1]
        XCTAssertEqual(niger.difficulty, "Facile")
        XCTAssertNil(niger.imageName)
    }

    func testTemperatureAndHumidityRanges() {
        let sheets = SpeciesSheet.parse(sampleBlock)
        let regius = sheets[0]
        XCTAssertEqual(regius.temperatureRange?.min, 22)
        XCTAssertEqual(regius.temperatureRange?.max, 28)
        XCTAssertEqual(regius.humidityRange?.min, 60)
        XCTAssertEqual(regius.humidityRange?.max, 75)
    }

    func testFirstRangeParsing() {
        XCTAssertEqual(SpeciesSheet.firstRange(in: "22–28 °C")?.min, 22)
        XCTAssertEqual(SpeciesSheet.firstRange(in: "20-25 °C")?.max, 25)
        XCTAssertEqual(SpeciesSheet.firstRange(in: "environ 24,5–26,5 °C")?.min, 24.5)
        XCTAssertNil(SpeciesSheet.firstRange(in: "température ambiante"))
    }
}
