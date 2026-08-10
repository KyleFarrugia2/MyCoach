import XCTest
@testable import MyCoach

final class CoachingDecisionEngineTests: XCTestCase {
    private let engine = CoachingDecisionEngine()
    private let timeZone = TimeZone(identifier: "Europe/Malta")!

    func testPoorAdherenceReviewsWithoutPrimaryCalorieChange() {
        let decision = evaluate(
            goal: .cut,
            absoluteChangeKg: -0.6,
            adherence: .fiftyTo69,
            stepTarget: 8_000
        )

        XCTAssertEqual(decision.action, .reviewAdherence)
        XCTAssertTrue(decision.reasons.contains(.poorAdherence))
        if case .increaseCalories = decision.action {
            XCTFail("Poor adherence must not primary-recommend calorie increase")
        }
        if case .decreaseCalories = decision.action {
            XCTFail("Poor adherence must not primary-recommend calorie decrease")
        }
        XCTAssertNil(decision.suggestedTrainingCalories)
        XCTAssertTrue(decision.secondaryActions.isEmpty)
    }

    func testOnTargetCutMaintains() {
        let decision = evaluate(
            goal: .cut,
            absoluteChangeKg: -0.5,
            adherence: .ninetyFiveTo100,
            stepTarget: 8_000
        )

        XCTAssertEqual(decision.action, .maintain)
        XCTAssertTrue(decision.reasons.contains(.rateOnTarget))
        XCTAssertEqual(decision.suggestedTrainingCalories, 2_400)
        XCTAssertEqual(decision.confidence, .high)
        XCTAssertTrue(decision.summary.contains("No calorie adjustment") || decision.summary.lowercased().contains("on target"))
    }

    func testStepIncreaseCappedAt12000() {
        XCTAssertEqual(CoachingConfig.maxStepTarget, 12_000)

        // Flat/up trend with high adherence prefers steps before cutting food.
        let nearCap = evaluate(
            goal: .cut,
            absoluteChangeKg: 0.35,
            adherence: .ninetyFiveTo100,
            stepTarget: 11_800
        )
        if case .increaseSteps(let delta) = nearCap.action {
            XCTAssertEqual(delta, CoachingConfig.defaultStepIncrement)
        } else {
            XCTFail("Expected increaseSteps, got \(nearCap.action)")
        }
        XCTAssertEqual(nearCap.suggestedSteps, 12_000)

        let atCap = evaluate(
            goal: .cut,
            absoluteChangeKg: 0.35,
            adherence: .ninetyFiveTo100,
            stepTarget: 12_000
        )
        XCTAssertNotEqual(atCap.suggestedSteps ?? 0, 12_500)
        XCTAssertLessThanOrEqual(atCap.suggestedSteps ?? 0, CoachingConfig.maxStepTarget)
        if case .increaseSteps = atCap.action {
            XCTFail("At step cap, engine should not keep recommending uncapped step growth")
        }
        if case .decreaseCalories = atCap.action {
            XCTAssertTrue(atCap.reasons.contains(.stepCapReached))
        } else {
            XCTFail("Expected decreaseCalories once step cap is reached, got \(atCap.action)")
        }
    }

    // MARK: - Helpers

    private func evaluate(
        goal: GoalPhase,
        absoluteChangeKg: Double,
        adherence: AdherenceBand,
        stepTarget: Int
    ) -> CoachDecision {
        let previousAverage = 80.0
        let currentAverage = previousAverage + absoluteChangeKg
        let previous = CoachingWeek(
            startDate: date(year: 2026, month: 8, day: 3),
            endDate: date(year: 2026, month: 8, day: 9),
            entries: [],
            averageKg: previousAverage,
            entryCount: 7,
            completeness: .complete
        )
        let current = CoachingWeek(
            startDate: date(year: 2026, month: 8, day: 10),
            endDate: date(year: 2026, month: 8, day: 16),
            entries: [],
            averageKg: currentAverage,
            entryCount: 7,
            completeness: .complete
        )
        let rate = WeeklyRateOfChange(
            previousAverageKg: previousAverage,
            currentAverageKg: currentAverage,
            absoluteChangeKg: absoluteChangeKg,
            percentChange: (absoluteChangeKg / previousAverage) * 100
        )
        return engine.evaluate(
            CoachingDecisionEngine.Input(
                goal: goal,
                previousWeek: previous,
                currentWeek: current,
                rate: rate,
                currentTrainingCalories: 2_400,
                currentRestCalories: 1_900,
                currentMacros: MacroGrams(protein: 176, carbohydrates: 250, fat: 55),
                stepTarget: stepTarget,
                adherence: adherence,
                performance: .same,
                appearance: .aboutTheSame,
                hunger: 3,
                energy: 3,
                weightKg: 80,
                sex: .male,
                recentRefeed: false
            )
        )
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 8
        components.timeZone = timeZone
        return Calendar(identifier: .gregorian).date(from: components)!
    }
}
