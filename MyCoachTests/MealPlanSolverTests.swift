import XCTest
@testable import MyCoach

final class MealPlanSolverTests: XCTestCase {
    private let solver = MealPlanSolver()

    func testAllergenHardBlock() {
        let peanutButter = FoodItem(
            name: "Peanut butter",
            source: .bundledGeneric,
            servingDescription: "100 g",
            servingGrams: 100,
            calories: 588,
            proteinGrams: 25,
            carbohydrateGrams: 20,
            fatGrams: 50,
            measurementState: .prepared,
            allergenTags: [.peanuts]
        )
        let item = MealItem(
            food: peanutButter,
            grams: 30,
            calories: 176.4,
            macros: MacroGrams(protein: 7.5, carbohydrates: 6, fat: 15)
        )
        let meal = Meal(slot: .breakfast, items: [item])
        let target = DailyNutritionTarget(
            calories: 2_200,
            macros: MacroGrams(protein: 160, carbohydrates: 220, fat: 60),
            isTrainingDay: true,
            stepTarget: 8_000
        )

        let result = solver.solve(
            MealPlanSolver.Request(
                target: target,
                meals: [meal],
                bannedAllergies: [.peanuts]
            )
        )

        XCTAssertTrue(result.blockedByAllergen)
        XCTAssertFalse(result.withinTolerance)
        XCTAssertEqual(
            result.message,
            "A selected food conflicts with your allergy constraints and was not adjusted."
        )
    }

    func testCustomFoodRescaleMessage() {
        let rice = FoodItem(
            name: "Custom Rice",
            source: .customUser,
            servingDescription: "100 g dry",
            servingGrams: 100,
            calories: 343,
            proteinGrams: 7,
            carbohydrateGrams: 76,
            fatGrams: 0.5,
            measurementState: .dry,
            isCustom: true
        )
        let item = MealItem(
            food: rice,
            grams: 100,
            calories: 343,
            macros: MacroGrams(protein: 7, carbohydrates: 76, fat: 0.5)
        )

        let scaled = solver.rescaleItem(
            item,
            targetCalories: 300,
            siblingFlexibleItems: [],
            mealMacroTarget: nil,
            bannedAllergies: []
        )

        XCTAssertEqual(
            scaled.message,
            "Updated to match your custom rice's nutrition label."
        )
        XCTAssertEqual(scaled.item.grams!, 300.0 / 3.43, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(scaled.item.grams!, CoachingConfig.minimumPracticalFoodGrams)
        XCTAssertLessThanOrEqual(scaled.item.grams!, CoachingConfig.maximumPracticalFoodGrams)
    }

    func testPracticalPortionBoundsRejectAbsurdTinyChicken() {
        let chicken = FoodItem(
            name: "Chicken breast",
            source: .bundledGeneric,
            servingDescription: "100 g raw",
            servingGrams: 100,
            calories: 110,
            proteinGrams: 23,
            carbohydrateGrams: 0,
            fatGrams: 1.2,
            measurementState: .raw,
            isVerified: true
        )
        // ~3 g would be absurd; solver clamps to minimumPracticalFoodGrams (10).
        let tiny = MealItem(
            food: chicken,
            grams: 3,
            isLocked: false,
            calories: 3.3,
            macros: MacroGrams(protein: 0.69, carbohydrates: 0, fat: 0.036)
        )
        let meal = Meal(slot: .lunch, items: [tiny])
        let target = DailyNutritionTarget(
            calories: 2_200,
            macros: MacroGrams(protein: 160, carbohydrates: 220, fat: 60),
            isTrainingDay: true,
            stepTarget: 8_000
        )

        let result = solver.solve(MealPlanSolver.Request(target: target, meals: [meal]))
        let grams = result.meals.flatMap(\.items).compactMap(\.grams)
        XCTAssertFalse(grams.isEmpty)
        for value in grams {
            XCTAssertGreaterThanOrEqual(value, CoachingConfig.minimumPracticalFoodGrams)
            XCTAssertNotEqual(value, 3, accuracy: 0.01)
            XCTAssertLessThanOrEqual(value, CoachingConfig.maximumPracticalFoodGrams)
        }
    }
}
