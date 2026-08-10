import XCTest
@testable import MyCoach

final class NutritionEngineTests: XCTestCase {
    private let engine = NutritionEngine()
    private let decisionEngine = CoachingDecisionEngine()

    private var maltaTimeZone: TimeZone {
        TimeZone(identifier: "Europe/Malta")!
    }

    private var maltaCalendar: CoachingCalendar {
        CoachingCalendar(timeZone: maltaTimeZone)
    }

    // MARK: - Weight analytics / weekly averages

    func testWeeklyAverageExactValues() {
        let monday = date(year: 2026, month: 8, day: 3)
        let weights = [80.0, 79.8, 80.2, 79.6, 79.7, 79.5, 79.4]
        let entries = weights.enumerated().map { index, kg in
            weightEntry(
                localDate: maltaCalendar.calendar.date(byAdding: .day, value: index, to: monday)!,
                kg: kg
            )
        }

        let average = WeightAnalytics.weeklyAverage(entries: entries)
        let expected = (80.0 + 79.8 + 80.2 + 79.6 + 79.7 + 79.5 + 79.4) / 7.0
        XCTAssertNotNil(average)
        XCTAssertEqual(average!, expected, accuracy: 1e-12)
        XCTAssertEqual(average!, 79.74285714285714, accuracy: 1e-10)
    }

    func testWeeklyChangeWeek1ToWeek2() {
        let week1Start = date(year: 2026, month: 8, day: 3)
        let week2Start = date(year: 2026, month: 8, day: 10)

        let previous = CoachingWeek(
            startDate: week1Start,
            endDate: maltaCalendar.weekEnd(containing: week1Start),
            entries: [],
            averageKg: 80.0,
            entryCount: 7,
            completeness: .complete
        )
        let current = CoachingWeek(
            startDate: week2Start,
            endDate: maltaCalendar.weekEnd(containing: week2Start),
            entries: [],
            averageKg: 79.2,
            entryCount: 7,
            completeness: .complete
        )

        let rate = WeightAnalytics.rateOfChange(previous: previous, current: current)
        XCTAssertEqual(rate?.absoluteChangeKg, -0.8)
        XCTAssertEqual(rate?.previousAverageKg, 80.0)
        XCTAssertEqual(rate?.currentAverageKg, 79.2)
    }

    func testMissingWeighInsUsesEntryCountNotSeven() {
        let monday = date(year: 2026, month: 8, day: 3)
        // Mon / Wed / Sat only
        let days = [0, 2, 5]
        let entries = days.map { offset in
            weightEntry(
                localDate: maltaCalendar.calendar.date(byAdding: .day, value: offset, to: monday)!,
                kg: 80.0 + Double(offset) * 0.1
            )
        }

        let week = WeightAnalytics.makeWeek(
            containing: monday,
            entries: entries,
            calendar: maltaCalendar,
            minimumForAdjustment: CoachingConfig.minimumWeighInsForAdjustment
        )

        XCTAssertEqual(week.entryCount, 3)
        let expectedAverage = WeightAnalytics.weeklyAverage(entries: entries)
        XCTAssertEqual(week.averageKg, expectedAverage)
        XCTAssertNotEqual(week.averageKg, entries.map(\.weightKg).reduce(0, +) / 7.0)
        XCTAssertEqual(CoachingConfig.minimumWeighInsForAdjustment, 4)
        XCTAssertEqual(week.completeness, .insufficientForAdjustment)
    }

    // MARK: - Extreme weekly change (via decision engine)

    func testExtremeCutDoesNotRecommendCalorieDecrease() {
        let decision = evaluateExtreme(
            goal: .cut,
            absoluteChangeKg: -1.7,
            adherence: .ninetyFiveTo100
        )
        XCTAssertEqual(decision.action, .recommendNutritionIncreaseReview)
        if case .decreaseCalories = decision.action {
            XCTFail("Extreme cut must not primary-recommend calorie decrease")
        }
        XCTAssertFalse(decision.secondaryActions.contains { adjustment in
            if case .decreaseCalories = adjustment { return true }
            return false
        })
        XCTAssertTrue(decision.reasons.contains(.extremeWeeklyChange))
        XCTAssertEqual(decision.confidence, .high)
    }

    func testExtremeGainRecommendsNutritionDecreaseReview() {
        let decision = evaluateExtreme(
            goal: .gain,
            absoluteChangeKg: 1.7,
            adherence: .ninetyFiveTo100
        )
        XCTAssertEqual(decision.action, .recommendNutritionDecreaseReview)
        XCTAssertTrue(decision.reasons.contains(.extremeWeeklyChange))
        XCTAssertEqual(decision.confidence, .high)
    }

    func testExactlyOnePointFiveKgThresholdTriggersExtremeReview() {
        let lossDecision = evaluateExtreme(goal: .cut, absoluteChangeKg: -1.5, adherence: .ninetyFiveTo100)
        XCTAssertEqual(lossDecision.action, .recommendNutritionIncreaseReview)
        XCTAssertTrue(lossDecision.reasons.contains(.extremeWeeklyChange))
        XCTAssertEqual(lossDecision.confidence, .medium)

        let gainDecision = evaluateExtreme(goal: .gain, absoluteChangeKg: 1.5, adherence: .ninetyFiveTo100)
        XCTAssertEqual(gainDecision.action, .recommendNutritionDecreaseReview)
        XCTAssertTrue(gainDecision.reasons.contains(.extremeWeeklyChange))
        XCTAssertEqual(gainDecision.confidence, .medium)

        XCTAssertEqual(CoachingConfig.extremeWeeklyChangeKg, 1.5)
        XCTAssertTrue(WeeklyRateOfChange(
            previousAverageKg: 80,
            currentAverageKg: 78.5,
            absoluteChangeKg: -1.5,
            percentChange: -1.875
        ).meetsExtremeThresholdInclusive)
    }

    func testGreaterThanOnePointFiveKgIsExtreme() {
        let decision = evaluateExtreme(goal: .cut, absoluteChangeKg: -1.5001, adherence: .eightyFiveTo94)
        XCTAssertEqual(decision.action, .recommendNutritionIncreaseReview)
        XCTAssertEqual(decision.confidence, .high)
        XCTAssertTrue(
            WeeklyRateOfChange(
                previousAverageKg: 80,
                currentAverageKg: 80 - 1.5001,
                absoluteChangeKg: -1.5001,
                percentChange: -1.875125
            ).isExtreme
        )
    }

    // MARK: - Steps / rest day / rescale

    func testStepCap13000Becomes12000() {
        XCTAssertEqual(CoachingConfig.maxStepTarget, 12_000)
        XCTAssertEqual(engine.cappedStepTarget(13_000), 12_000)
        XCTAssertEqual(engine.adjustedStepTarget(current: 13_000, delta: 0), 12_000)
    }

    func testRestDayPrimarilyReducesCarbsWithStableProtein() {
        let weightKg = 80.0
        let goal = GoalPhase.cut
        let trainingMacros = engine.macros(forCalories: 3_000, weightKg: weightKg, goal: goal)
        let training = DailyNutritionTarget(
            calories: 3_000,
            macros: trainingMacros,
            isTrainingDay: true,
            stepTarget: 8_000
        )
        let rest = engine.restDayTarget(
            fromTraining: training,
            weightKg: weightKg,
            goal: goal,
            sex: .male
        )

        XCTAssertEqual(rest.calories, 2_500)
        XCTAssertEqual(rest.macros.protein, training.macros.protein, accuracy: 0.001)
        XCTAssertFalse(rest.isTrainingDay)

        let calorieDrop = Double(training.calories - rest.calories)
        let carbDropCalories = (training.macros.carbohydrates - rest.macros.carbohydrates)
            * CoachingConfig.caloriesPerGramCarbohydrate
        let proteinDropCalories = abs(training.macros.protein - rest.macros.protein)
            * CoachingConfig.caloriesPerGramProtein
        let fatDropCalories = abs(training.macros.fat - rest.macros.fat)
            * CoachingConfig.caloriesPerGramFat

        XCTAssertEqual(calorieDrop, Double(CoachingConfig.restDayCalorieDeficit), accuracy: 1)
        XCTAssertGreaterThan(carbDropCalories, proteinDropCalories)
        XCTAssertGreaterThan(carbDropCalories, fatDropCalories)
        XCTAssertEqual(carbDropCalories, calorieDrop, accuracy: 5)
    }

    func testCustomRiceRescaleForThreeHundredCalories() {
        let grams = engine.rescaleGramsForCalories(targetCalories: 300, customCaloriesPer100g: 343)
        XCTAssertEqual(grams, 300.0 / 343.0 * 100.0, accuracy: 1e-9)
        XCTAssertEqual(grams, 87.46355685131195, accuracy: 0.01)
        XCTAssertEqual((grams * 10).rounded() / 10, 87.5, accuracy: 0.1)
    }

    // MARK: - Units & macro math

    func testUnitConversionKilogramsPoundsAndHeight() {
        let kg = 80.0
        let lb = UnitConversion.displayWeight(kg: kg, unit: .pound)
        XCTAssertEqual(lb, kg * UnitConversion.poundsPerKilogram, accuracy: 1e-9)
        XCTAssertEqual(UnitConversion.kilograms(from: lb, unit: .pound), kg, accuracy: 1e-9)
        XCTAssertEqual(UnitConversion.kilograms(from: kg, unit: .kilogram), kg)

        let cm = UnitConversion.centimeters(feet: 5, inches: 11)
        XCTAssertEqual(cm, ((5 * 12) + 11) * UnitConversion.cmPerInch, accuracy: 1e-9)
        let feetInches = UnitConversion.feetAndInches(fromCentimeters: cm)
        XCTAssertEqual(feetInches.feet, 5)
        XCTAssertEqual(feetInches.inches, 11, accuracy: 1e-9)
    }

    func testCalorieMacroMath() {
        let protein = 150.0
        let carbs = 200.0
        let fat = 60.0
        let calories = NutritionMath.calories(
            proteinGrams: protein,
            carbohydrateGrams: carbs,
            fatGrams: fat
        )
        XCTAssertEqual(
            calories,
            protein * 4 + carbs * 4 + fat * 9,
            accuracy: 1e-9
        )
        XCTAssertEqual(CoachingConfig.caloriesPerGramProtein, 4)
        XCTAssertEqual(CoachingConfig.caloriesPerGramCarbohydrate, 4)
        XCTAssertEqual(CoachingConfig.caloriesPerGramFat, 9)
    }

    // MARK: - Timezone coaching week

    func testCoachingWeekMondayToSundayWithExplicitTimeZone() {
        let calendar = CoachingCalendar(timeZone: maltaTimeZone)

        // Sunday 2026-08-09 23:30 Malta — still in the week that started Monday 2026-08-03.
        var sundayComponents = DateComponents()
        sundayComponents.year = 2026
        sundayComponents.month = 8
        sundayComponents.day = 9
        sundayComponents.hour = 23
        sundayComponents.minute = 30
        sundayComponents.timeZone = maltaTimeZone
        let sundayEvening = Calendar(identifier: .gregorian).date(from: sundayComponents)!

        let start = calendar.weekStart(containing: sundayEvening)
        let end = calendar.weekEnd(containing: sundayEvening)
        let days = calendar.datesInWeek(containing: sundayEvening)

        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(calendar.calendar.component(.weekday, from: start), 2) // Monday
        XCTAssertEqual(calendar.calendar.component(.weekday, from: end), 1) // Sunday
        XCTAssertTrue(calendar.isSameLocalDay(start, date(year: 2026, month: 8, day: 3)))
        XCTAssertTrue(calendar.isSameLocalDay(end, date(year: 2026, month: 8, day: 9)))

        // Early Monday UTC that is still Sunday in US Pacific should belong to prior week when using Pacific TZ.
        let pacific = TimeZone(identifier: "America/Los_Angeles")!
        let pacificCalendar = CoachingCalendar(timeZone: pacific)
        var utcMondayEarly = DateComponents()
        utcMondayEarly.year = 2026
        utcMondayEarly.month = 8
        utcMondayEarly.day = 10
        utcMondayEarly.hour = 6
        utcMondayEarly.minute = 0
        utcMondayEarly.timeZone = TimeZone(secondsFromGMT: 0)
        let instant = Calendar(identifier: .gregorian).date(from: utcMondayEarly)!
        // 06:00 UTC Monday = 23:00 Sunday Pacific (PDT)
        let pacificStart = pacificCalendar.weekStart(containing: instant)
        XCTAssertEqual(pacificCalendar.calendar.component(.weekday, from: pacificStart), 2)
        XCTAssertTrue(
            pacificCalendar.isSameLocalDay(
                pacificStart,
                pacificDate(year: 2026, month: 8, day: 3, timeZone: pacific)
            )
        )
    }

    // MARK: - Helpers

    private func evaluateExtreme(
        goal: GoalPhase,
        absoluteChangeKg: Double,
        adherence: AdherenceBand
    ) -> CoachDecision {
        let weekStart = date(year: 2026, month: 8, day: 10)
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
            startDate: weekStart,
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
        let macros = MacroGrams(protein: 176, carbohydrates: 250, fat: 55)
        return decisionEngine.evaluate(
            CoachingDecisionEngine.Input(
                goal: goal,
                previousWeek: previous,
                currentWeek: current,
                rate: rate,
                currentTrainingCalories: 2_400,
                currentRestCalories: 1_900,
                currentMacros: macros,
                stepTarget: 8_000,
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

    private func weightEntry(localDate: Date, kg: Double) -> WeightEntry {
        WeightEntry(
            timestamp: localDate,
            localDate: maltaCalendar.localDate(for: localDate),
            weightKg: kg,
            inputUnit: .kilogram,
            isOfficialMorningCheckIn: true
        )
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 8
        components.timeZone = maltaTimeZone
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    private func pacificDate(year: Int, month: Int, day: Int, timeZone: TimeZone) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        components.timeZone = timeZone
        return Calendar(identifier: .gregorian).date(from: components)!
    }
}
