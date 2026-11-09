import XCTest
@testable import MyCoach

/// The Swift adaptive model must match the TypeScript reference (web/src/engines/adaptive.ts) exactly.
/// `AdaptiveModelFixture` is generated from the TypeScript implementation by `npm run fixtures` in web/.
final class AdaptiveModelTests: XCTestCase {
    private struct Fixture: Decodable {
        var cases: [Case]
    }

    private struct Case: Decodable {
        var name: String
        var input: Input
        var goal: String
        var desiredWeightKg: Double
        var plan: Plan
        var expected: Expected
    }

    private struct Input: Decodable {
        var days: [AdaptiveDay]
        var priorMaintenanceKcal: Double
        var bodyWeightKg: Double
        var fallbackSteps: Double
        var fallbackIntakeKcal: Double
    }

    private struct Plan: Decodable {
        var trainingKcal: Double
        var restKcal: Double
        var trainingDaysPerWeek: Int
    }

    private struct Prediction: Decodable {
        var meanKgPerWeek: Double
        var sdKgPerWeek: Double
        var expenditureKcal: Double
    }

    private struct Recommendation: Decodable {
        var targetKgPerWeek: Double
        var deltaKcal: Int
        var shouldAdjust: Bool
        var requiredAverageIntake: Double
    }

    private struct Expected: Decodable {
        var observations: Int
        var loggedIntakeDays: Int
        var weighIns: Int
        var theta: [Double]
        var covariance: [[Double]]
        var maintenanceKcal: Double
        var maintenanceSD: Double
        var currentSteps: Double
        var currentIntakeKcal: Double
        var confidence: String
        var rmseKcal: Double?
        var trendLevelKg: Double?
        var trendSlopeKgPerWeek: Double?
        var trendSlopeSDKgPerWeek: Double?
        var predictAt2000: Prediction
        var requiredForMinusHalf: Double
        var recommendation: Recommendation
    }

    private func loadFixture() throws -> Fixture {
        try JSONDecoder().decode(Fixture.self, from: Data(AdaptiveModelFixture.json.utf8))
    }

    private func assertClose(_ a: Double?, _ b: Double?, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        switch (a, b) {
        case (nil, nil):
            return
        case let (x?, y?):
            let tolerance = 1e-6 * max(1, abs(y))
            XCTAssertEqual(x, y, accuracy: tolerance, label, file: file, line: line)
        default:
            XCTFail("\(label): \(String(describing: a)) vs \(String(describing: b))", file: file, line: line)
        }
    }

    // MARK: - Cross-platform parity

    func testMatchesTypeScriptReferenceOnAllFixtureCases() throws {
        let fixture = try loadFixture()
        XCTAssertFalse(fixture.cases.isEmpty)
        for c in fixture.cases {
            let input = AdaptiveFitInput(
                days: c.input.days,
                priorMaintenanceKcal: c.input.priorMaintenanceKcal,
                bodyWeightKg: c.input.bodyWeightKg,
                fallbackSteps: c.input.fallbackSteps,
                fallbackIntakeKcal: c.input.fallbackIntakeKcal
            )
            let model = AdaptiveModel.fit(input)
            let e = c.expected
            let tag = c.name

            XCTAssertEqual(model.observations, e.observations, "\(tag) observations")
            XCTAssertEqual(model.loggedIntakeDays, e.loggedIntakeDays, "\(tag) loggedIntakeDays")
            XCTAssertEqual(model.weighIns, e.weighIns, "\(tag) weighIns")
            XCTAssertEqual(model.confidence.rawValue, e.confidence, "\(tag) confidence")
            for i in 0..<3 {
                assertClose(model.theta[i], e.theta[i], "\(tag) theta[\(i)]")
                for j in 0..<3 {
                    assertClose(model.covariance[i][j], e.covariance[i][j], "\(tag) cov[\(i)][\(j)]")
                }
            }
            assertClose(model.maintenanceKcal, e.maintenanceKcal, "\(tag) maintenance")
            assertClose(model.maintenanceSD, e.maintenanceSD, "\(tag) maintenanceSD")
            assertClose(model.currentSteps, e.currentSteps, "\(tag) currentSteps")
            assertClose(model.currentIntakeKcal, e.currentIntakeKcal, "\(tag) currentIntake")
            assertClose(model.rmseKcal, e.rmseKcal, "\(tag) rmse")
            assertClose(model.trend?.levelKg, e.trendLevelKg, "\(tag) trend level")
            assertClose(model.trend?.slopeKgPerWeek, e.trendSlopeKgPerWeek, "\(tag) trend slope")
            assertClose(model.trend?.slopeSDKgPerWeek, e.trendSlopeSDKgPerWeek, "\(tag) trend slope SD")

            let p = AdaptiveModel.predictWeeklyRate(model, intakeKcal: 2000, steps: 8000)
            assertClose(p.meanKgPerWeek, e.predictAt2000.meanKgPerWeek, "\(tag) predict mean")
            assertClose(p.sdKgPerWeek, e.predictAt2000.sdKgPerWeek, "\(tag) predict sd")
            assertClose(p.expenditureKcal, e.predictAt2000.expenditureKcal, "\(tag) predict tdee")
            assertClose(
                AdaptiveModel.requiredIntake(model, targetKgPerWeek: -0.5, steps: 9000),
                e.requiredForMinusHalf,
                "\(tag) required intake"
            )

            let goal = try XCTUnwrap(GoalPhase(rawValue: c.goal))
            let rec = AdaptiveModel.recommend(
                model,
                plan: AdaptivePlanCalories(
                    trainingKcal: c.plan.trainingKcal,
                    restKcal: c.plan.restKcal,
                    trainingDaysPerWeek: c.plan.trainingDaysPerWeek
                ),
                goal: goal,
                desiredWeightKg: c.desiredWeightKg,
                steps: model.currentSteps
            )
            assertClose(rec.targetKgPerWeek, e.recommendation.targetKgPerWeek, "\(tag) target rate")
            assertClose(rec.requiredAverageIntake, e.recommendation.requiredAverageIntake, "\(tag) required avg")
            XCTAssertEqual(rec.deltaKcal, e.recommendation.deltaKcal, "\(tag) delta")
            XCTAssertEqual(rec.shouldAdjust, e.recommendation.shouldAdjust, "\(tag) shouldAdjust")
        }
    }

    // MARK: - Behaviour

    func testLongHistoryLearnsConfidentlyAndBeatsTheFormula() throws {
        let fixture = try loadFixture()
        let c = try XCTUnwrap(fixture.cases.first { $0.name == "cut-13-weeks" })
        let full = AdaptiveModel.fit(
            AdaptiveFitInput(
                days: c.input.days,
                priorMaintenanceKcal: c.input.priorMaintenanceKcal,
                bodyWeightKg: c.input.bodyWeightKg,
                fallbackSteps: c.input.fallbackSteps,
                fallbackIntakeKcal: c.input.fallbackIntakeKcal
            )
        )
        let early = AdaptiveModel.fit(
            AdaptiveFitInput(
                days: Array(c.input.days.prefix(21)),
                priorMaintenanceKcal: c.input.priorMaintenanceKcal,
                bodyWeightKg: c.input.bodyWeightKg,
                fallbackSteps: c.input.fallbackSteps,
                fallbackIntakeKcal: c.input.fallbackIntakeKcal
            )
        )
        // Continuous learning: more data → more observations and a tighter posterior.
        XCTAssertGreaterThan(full.observations, early.observations)
        XCTAssertLessThan(full.maintenanceSD, early.maintenanceSD)
        XCTAssertEqual(full.confidence, .high)
        // Simulated person's true maintenance is ~2650 at reference intake vs the 2350 formula prior.
        XCTAssertGreaterThan(full.theta[0], c.input.priorMaintenanceKcal + 150)
    }

    func testControllerInvertsThePrediction() throws {
        let fixture = try loadFixture()
        let c = try XCTUnwrap(fixture.cases.first)
        let model = AdaptiveModel.fit(
            AdaptiveFitInput(
                days: c.input.days,
                priorMaintenanceKcal: c.input.priorMaintenanceKcal,
                bodyWeightKg: c.input.bodyWeightKg,
                fallbackSteps: c.input.fallbackSteps,
                fallbackIntakeKcal: c.input.fallbackIntakeKcal
            )
        )
        let intake = AdaptiveModel.requiredIntake(model, targetKgPerWeek: -0.6, steps: 8500)
        let predicted = AdaptiveModel.predictWeeklyRate(model, intakeKcal: intake, steps: 8500)
        XCTAssertEqual(predicted.meanKgPerWeek, -0.6, accuracy: 1e-9)
    }

    func testEmptyHistoryStaysAtPriorWithLowConfidence() {
        let model = AdaptiveModel.fit(
            AdaptiveFitInput(
                days: [AdaptiveDay(weightKg: 82, intakeKcal: nil, steps: nil)],
                priorMaintenanceKcal: 2400,
                bodyWeightKg: 82,
                fallbackSteps: 8000,
                fallbackIntakeKcal: 2400
            )
        )
        XCTAssertEqual(model.observations, 0)
        XCTAssertEqual(model.confidence, .low)
        XCTAssertEqual(model.theta[0], 2400, accuracy: 1e-9)
        let rec = AdaptiveModel.recommend(
            model,
            plan: AdaptivePlanCalories(trainingKcal: 2200, restKcal: 1700, trainingDaysPerWeek: 4),
            goal: .cut,
            desiredWeightKg: 75,
            steps: 8000
        )
        XCTAssertFalse(rec.shouldAdjust)
    }

    func testGoalRateScalesClampsAndTapers() {
        XCTAssertEqual(AdaptiveModel.targetWeeklyRate(goal: .cut, trendWeightKg: 100, desiredWeightKg: nil), -0.7, accuracy: 1e-12)
        XCTAssertEqual(AdaptiveModel.targetWeeklyRate(goal: .cut, trendWeightKg: 40, desiredWeightKg: nil), -0.35, accuracy: 1e-12)
        XCTAssertEqual(AdaptiveModel.targetWeeklyRate(goal: .gain, trendWeightKg: 80, desiredWeightKg: nil), 0.2, accuracy: 1e-12)
        XCTAssertEqual(AdaptiveModel.targetWeeklyRate(goal: .cut, trendWeightKg: 76, desiredWeightKg: 75), -0.25, accuracy: 1e-12)
        XCTAssertEqual(AdaptiveModel.targetWeeklyRate(goal: .cut, trendWeightKg: 74, desiredWeightKg: 75), 0)
        XCTAssertEqual(AdaptiveModel.targetWeeklyRate(goal: .maintenance, trendWeightKg: 80, desiredWeightKg: nil), 0)
    }

    // MARK: - Persistence compatibility

    func testPreferencesSavedBeforeAdaptiveModelStillDecode() throws {
        let legacy = #"{"customMealNames":{},"notifications":{"morningWeighInEnabled":true,"morningWeighInHour":7,"morningWeighInMinute":0,"mealRemindersEnabled":false,"stepRemindersEnabled":true,"weeklyCheckInEnabled":true,"progressPhotosEnabled":true},"showEstimatedDirection":true}"#
        let prefs = try JSONDecoder().decode(UserPreferences.self, from: Data(legacy.utf8))
        XCTAssertTrue(prefs.adaptiveAutoAdjust, "Auto-adjust defaults on for existing users")
        var changed = prefs
        changed.adaptiveAutoAdjust = false
        let roundTrip = try JSONDecoder().decode(UserPreferences.self, from: JSONEncoder().encode(changed))
        XCTAssertFalse(roundTrip.adaptiveAutoAdjust)
    }

    func testModelTargetSourceRoundTrips() throws {
        let data = try JSONEncoder().encode([TargetSource.adaptiveModel])
        XCTAssertEqual(try JSONDecoder().decode([TargetSource].self, from: data), [.adaptiveModel])
    }
}
