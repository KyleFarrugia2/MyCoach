import XCTest
@testable import MyCoach

/// Mirrors web/tests/barcode.test.ts — same Open Food Facts sample (web/tests/fixtures/off-nutella.json).
final class BarcodeLookupTests: XCTestCase {
    private let nutella = #"{"code":"3017620422003","status":1,"status_verbose":"product found","product":{"allergens_tags":["en:milk","en:nuts","en:soybeans"],"brands":"Ferrero, Nutella","generic_name":"Hazelnut And Cocoa Spread","product_name":"Nutella","product_name_en":"Nutella","nutriments":{"carbohydrates_100g":57.5,"energy-kcal_100g":539,"energy-kj_100g":2252,"energy_100g":2252,"fat_100g":30.9,"fiber_100g":0,"proteins_100g":6.3}}}"#

    func testCheckDigitValidation() {
        XCTAssertTrue(BarcodeLookup.isValidGTIN("3017620422003"))
        XCTAssertTrue(BarcodeLookup.isValidGTIN("96385074"))
        XCTAssertTrue(BarcodeLookup.isValidGTIN("036000291452"))
        XCTAssertFalse(BarcodeLookup.isValidGTIN("3017620422004"))
        XCTAssertEqual(BarcodeLookup.normalize(" 3017-6204-22003 "), "3017620422003")
        XCTAssertNil(BarcodeLookup.normalize("12345"))
    }

    func testParsesOpenFoodFactsProductPer100g() throws {
        let parsed = try XCTUnwrap(BarcodeLookup.parseOpenFoodFacts(Data(nutella.utf8), barcode: "3017620422003"))
        XCTAssertTrue(parsed.complete)
        let food = parsed.food
        XCTAssertEqual(food.name, "Nutella")
        XCTAssertEqual(food.brand, "Ferrero")
        XCTAssertEqual(food.servingGrams, 100)
        XCTAssertEqual(food.calories, 539)
        XCTAssertEqual(food.proteinGrams, 6.3)
        XCTAssertEqual(food.carbohydrateGrams, 57.5)
        XCTAssertEqual(food.fatGrams, 30.9)
        XCTAssertEqual(food.source, .barcode)
        XCTAssertEqual(food.barcode, "3017620422003")
        XCTAssertFalse(food.isVerified)
        XCTAssertEqual(food.allergenTags, [.dairy, .soy, .treeNuts])
    }

    func testDerivesKcalFromKilojoulesAndFlagsMissingMacros() throws {
        let json = #"{"status":1,"product":{"product_name":"Bar","nutriments":{"energy_100g":"418.4","proteins_100g":"10"}}}"#
        let parsed = try XCTUnwrap(BarcodeLookup.parseOpenFoodFacts(Data(json.utf8), barcode: "96385074"))
        XCTAssertEqual(try XCTUnwrap(parsed.food.calories), 100, accuracy: 1e-9)
        XCTAssertEqual(parsed.food.proteinGrams, 10)
        XCTAssertFalse(parsed.complete)
    }

    func testUnknownProductReturnsNil() {
        let json = #"{"status":0,"status_verbose":"product not found"}"#
        XCTAssertNil(BarcodeLookup.parseOpenFoodFacts(Data(json.utf8), barcode: "96385074"))
    }

    @MainActor
    func testRescanReplacesFoodWithSameBarcode() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let env = AppEnvironment(persistenceDirectory: dir)
        let first = try XCTUnwrap(BarcodeLookup.parseOpenFoodFacts(Data(nutella.utf8), barcode: "3017620422003")).food
        env.saveCustomFood(first)
        var rescanned = try XCTUnwrap(BarcodeLookup.parseOpenFoodFacts(Data(nutella.utf8), barcode: "3017620422003")).food
        rescanned.calories = 540
        env.saveCustomFood(rescanned)
        XCTAssertEqual(env.customFoods.filter { $0.barcode == "3017620422003" }.count, 1)
        XCTAssertEqual(env.customFood(barcode: "3017620422003")?.calories, 540)
        env.deleteCustomFood(rescanned)
        XCTAssertNil(env.customFood(barcode: "3017620422003"))
    }
}
