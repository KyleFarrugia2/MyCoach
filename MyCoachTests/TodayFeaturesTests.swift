import XCTest
@testable import MyCoach

/// Mirrors web/tests/today.test.ts — emergency rest days, cardio coach, quote of the day, sleep input.
final class TodayFeaturesTests: XCTestCase {
    private var engine: DayPlanEngine {
        DayPlanEngine(calendar: CoachingCalendar(timeZone: TimeZone(identifier: "UTC")!))
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: - Emergency rest days

    func testEmergencyRestMovesSessionToNextFreeDay() {
        let schedule: Set<Weekday> = [.monday, .tuesday, .thursday, .friday]
        let tue = date(2026, 11, 10)
        let r = engine.takeEmergencyRest(trainingDays: schedule, overrides: [], on: tue)
        XCTAssertEqual(engine.dayType(trainingDays: schedule, overrides: r.overrides, on: tue), .rest)
        XCTAssertEqual(r.movedTo, date(2026, 11, 11))
        XCTAssertEqual(engine.dayType(trainingDays: schedule, overrides: r.overrides, on: date(2026, 11, 11)), .training)
    }

    func testPrefersShortRunsAndNeverMakesLongStreaks() {
        let mwf: Set<Weekday> = [.monday, .wednesday, .friday]
        XCTAssertEqual(engine.takeEmergencyRest(trainingDays: mwf, overrides: [], on: date(2026, 11, 9)).movedTo, date(2026, 11, 10))
        let six: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        XCTAssertNil(engine.takeEmergencyRest(trainingDays: six, overrides: [], on: date(2026, 11, 13)).movedTo)
        let sunOnly: Set<Weekday> = [.sunday]
        let r = engine.takeEmergencyRest(trainingDays: sunOnly, overrides: [], on: date(2026, 11, 15))
        XCTAssertNil(r.movedTo)
        XCTAssertEqual(engine.dayType(trainingDays: sunOnly, overrides: r.overrides, on: date(2026, 11, 15)), .rest)
    }

    func testUndoRestoresBothDays() {
        let schedule: Set<Weekday> = [.monday, .tuesday, .thursday, .friday]
        let tue = date(2026, 11, 10)
        let r = engine.takeEmergencyRest(trainingDays: schedule, overrides: [], on: tue)
        XCTAssertTrue(engine.undoEmergencyRest(overrides: r.overrides, on: tue).isEmpty)
        XCTAssertTrue(engine.takeEmergencyRest(trainingDays: schedule, overrides: [], on: date(2026, 11, 11)).overrides.isEmpty)
    }

    // MARK: - Cardio coach

    private func cardio(
        goal: GoalPhase = .cut, training: Bool = false, emergency: Bool = false, sleep: Double? = nil,
        predicted: Double? = nil, target: Double? = nil
    ) -> CardioCoach.Recommendation {
        CardioCoach.recommend(
            CardioCoach.Input(
                goal: goal, isTrainingDay: training, emergencyRest: emergency, sleepHours: sleep,
                stepsSoFar: 4000, stepTarget: 9000, predictedKgPerWeek: predicted, targetKgPerWeek: target
            )
        )
    }

    func testCardioMatchesTypeScriptRules() {
        XCTAssertEqual(cardio(sleep: 4.5).tone, .recovery)
        XCTAssertEqual(cardio(emergency: true).tone, .recovery)
        XCTAssertEqual(cardio().minutes, 35)
        XCTAssertEqual(cardio(training: true).minutes, 20)
        XCTAssertEqual(cardio(goal: .gain, training: true).minutes, 0)
        XCTAssertEqual(cardio(predicted: -0.2, target: -0.6).minutes, 45)
        XCTAssertEqual(cardio(predicted: -1.1, target: -0.6).minutes, 25)
        XCTAssertEqual(cardio(sleep: 6).minutes, 25)
    }

    // MARK: - Quote of the day (values printed by web/tests/today.test.ts)

    func testMulberry32MatchesJavaScript() {
        var rng = QuoteOfTheDay.Mulberry32(seed: 20_261_115)
        XCTAssertEqual([rng.nextUInt32(), rng.nextUInt32(), rng.nextUInt32()], [1_173_115_838, 3_448_869_851, 372_080_731])
    }

    func testQuoteRotationMatchesAndroid() {
        XCTAssertEqual(QuoteOfTheDay.dayNumber(year: 2026, month: 1, day: 1), 0)
        XCTAssertEqual(QuoteOfTheDay.dayNumber(year: 2026, month: 11, day: 15), 318)
        let order = QuoteOfTheDay.shuffledOrder(count: 929)
        XCTAssertEqual(Set(order).count, 929)
        XCTAssertEqual(QuoteOfTheDay.index(year: 2026, month: 1, day: 1, count: 929, order: order), 241)
        XCTAssertEqual(QuoteOfTheDay.index(year: 2026, month: 11, day: 15, count: 929, order: order), 400)
        XCTAssertEqual(QuoteOfTheDay.index(year: 2027, month: 3, day: 1, count: 929, order: order), 0)
    }

    // MARK: - Sleep input

    func testSleepParsing() {
        XCTAssertEqual(UnitConversion.parseHours("7.5"), 7.5)
        XCTAssertEqual(UnitConversion.parseHours("7,5"), 7.5)
        XCTAssertEqual(UnitConversion.parseHours("7:30"), 7.5)
        XCTAssertEqual(UnitConversion.parseHours("6h45"), 6.75)
        XCTAssertEqual(UnitConversion.parseHours("8h"), 8)
        XCTAssertNil(UnitConversion.parseHours("25"))
        XCTAssertNil(UnitConversion.parseHours("7:75"))
        XCTAssertNil(UnitConversion.parseHours(""))
    }

    // MARK: - App state (AppEnvironment)

    @MainActor
    private func makeEnvironment() -> AppEnvironment {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let env = AppEnvironment(persistenceDirectory: dir, subscriptionProvider: MockSubscriptionManager(status: .notSubscribed))
        env.profile.currentWeightKg = 80
        env.profile.heightCm = 180
        env.profile.biologicalSex = .male
        env.profile.hasCompletedOnboarding = true
        env.rebuildTargetsFromProfile()
        return env
    }

    @MainActor
    func testEmergencyRestSwitchesTodayToRestTargetsAndUndoRestores() throws {
        let env = makeEnvironment()
        env.setTrainingDays([env.dayPlanWeekday(for: env.today)])
        XCTAssertTrue(env.isTrainingDay(on: env.today))
        let rest = try XCTUnwrap(env.targets?.rest.calories)
        env.takeEmergencyRestDay(on: env.today)
        XCTAssertFalse(env.isTrainingDay(on: env.today))
        XCTAssertEqual(env.target(on: env.today)?.calories, rest)
        env.undoEmergencyRestDay(on: env.today)
        XCTAssertTrue(env.isTrainingDay(on: env.today))
    }

    @MainActor
    func testBackfilledWeightDoesNotOverrideCurrentWeight() throws {
        let env = makeEnvironment()
        env.logMorningWeight(82, unit: .kilogram)
        let threeDaysAgo = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -3, to: env.today))
        env.logMorningWeight(84, unit: .kilogram, on: threeDaysAgo)
        XCTAssertEqual(env.profile.currentWeightKg, 82, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(env.weightEntry(on: threeDaysAgo)?.weightKg), 84, accuracy: 1e-9)
    }

    @MainActor
    func testSleepLoggingWithOptionalWakeUps() throws {
        let env = makeEnvironment()
        env.logSleep(hours: 4.5, wakeUps: nil)
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: env.today))
        env.logSleep(hours: 7.25, wakeUps: 2, on: yesterday)
        XCTAssertEqual(env.sleep(on: env.today)?.hours, 4.5)
        XCTAssertNil(env.sleep(on: env.today)?.wakeUps)
        XCTAssertEqual(env.sleep(on: yesterday)?.wakeUps, 2)
        env.logSleep(hours: 8, wakeUps: nil)
        XCTAssertEqual(env.sleepEntries.filter { Calendar.current.isDateInToday($0.localDate) }.count, 1)
    }

    @MainActor
    func testScheduleAndStepChangesKeepAdjustedCalories() throws {
        let env = makeEnvironment()
        let before = try XCTUnwrap(env.targets?.training.calories)
        env.setStepTarget(10_500)
        env.setTrainingDays([.monday, .wednesday, .friday])
        XCTAssertEqual(env.targets?.training.calories, before)
        XCTAssertEqual(env.targets?.training.stepTarget, 10_500)
        XCTAssertEqual(env.profile.trainingSchedule.trainingDays, [.monday, .wednesday, .friday])
    }

    func testSnapshotsWithoutNewFieldsStillDecode() throws {
        let legacy = #"{"customMealNames":{},"notifications":{"morningWeighInEnabled":true,"morningWeighInHour":7,"morningWeighInMinute":0,"mealRemindersEnabled":false,"stepRemindersEnabled":true,"weeklyCheckInEnabled":true,"progressPhotosEnabled":true},"showEstimatedDirection":true}"#
        let prefs = try JSONDecoder().decode(UserPreferences.self, from: Data(legacy.utf8))
        XCTAssertTrue(prefs.calmingMusic, "Music defaults on for existing users")
    }

    // MARK: - Button sounds (designated, not random)

    func testEveryTabHasItsOwnDesignatedSound() {
        let all = MainTab.allCases
        let sounds = all.map(ButtonSound.init(tab:))
        XCTAssertEqual(Set(sounds).count, all.count, "each tab has a distinct sound")
        XCTAssertFalse(sounds.contains(.nav), "the nav bar sound is reserved for the tab bar")
        XCTAssertEqual(ButtonSound(tab: .workout), .workout)
        XCTAssertEqual(ButtonSound.allCases.count, 9)
    }

    func testDockShowsSevenDestinationsWithoutMore() {
        XCTAssertEqual(MainTab.allCases.count, 7)
        XCTAssertEqual(Set(MainTab.allCases.map(\.shortTitle)).count, 7)
        XCTAssertFalse(MainTab.allCases.map(\.title).contains("More"))
        XCTAssertEqual(MainTab.mealPlan.shortTitle, "Plan")
        XCTAssertEqual(MainTab.foods.shortTitle, "Food")
        XCTAssertEqual(MainTab.workout.shortTitle, "Train")
        XCTAssertEqual(MainTab.progress.shortTitle, "Stats")
    }
}
