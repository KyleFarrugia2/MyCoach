import XCTest
@testable import MyCoach

/// Mirrors web/tests/workoutReview.test.ts — progress review, streak and messages after a workout.
final class WorkoutReviewTests: XCTestCase {
    // WorkoutSession normalises localDate with Calendar.current, so the tests use the current time zone too.
    private let calendar = CoachingCalendar()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private func ex(_ sets: [(Double?, Int)], bodyweight: Bool = false) -> WorkoutExerciseLog {
        WorkoutExerciseLog(
            id: "press",
            name: "Flat chest press",
            plannedSets: max(1, sets.count),
            isBodyweightMaxReps: bodyweight,
            sets: sets.enumerated().map { LoggedSet(setNumber: $0.offset + 1, weightKg: $0.element.0, reps: $0.element.1) }
        )
    }

    private func session(_ day: Date, _ exercises: [WorkoutExerciseLog]? = nil) -> WorkoutSession {
        WorkoutSession(
            templateID: WorkoutTemplateID.allCases[0],
            templateName: "Push A",
            localDate: day,
            startedAt: day,
            completedAt: day.addingTimeInterval(3600),
            exercises: exercises ?? [ex([(40, 10)])]
        )
    }

    func testExerciseStatuses() {
        func review(_ p: WorkoutExerciseLog?, _ c: WorkoutExerciseLog) -> (WorkoutReview.Status?, String?) {
            let r = WorkoutReview.reviewExercise(previous: p, current: c)
            return (r?.status, r?.detail)
        }
        XCTAssertTrue(review(ex([(40, 10)]), ex([(42.5, 8)])) == (.progressed, "+2.5 kg on your top set (40 → 42.5 kg)"))
        XCTAssertTrue(review(ex([(40, 10)]), ex([(40, 12)])) == (.progressed, "+2 reps at 40 kg"))
        XCTAssertTrue(review(ex([(40, 10)]), ex([(40, 10), (40, 8)])) == (.progressed, "More total volume (400 → 720 kg)"))
        XCTAssertTrue(review(ex([(40, 10)]), ex([(40, 10)])) == (.same, "40 kg × 10 again"))
        XCTAssertTrue(review(ex([(40, 10)]), ex([(40, 8)])) == (.less, "10 → 8 reps at 40 kg"))
        XCTAssertTrue(review(ex([(40, 10)]), ex([(35, 10)])) == (.less, "Top set 40 → 35 kg"))
        XCTAssertEqual(review(nil, ex([(40, 10)])).0, .new)
        XCTAssertNil(WorkoutReview.reviewExercise(previous: ex([(40, 10)]), current: ex([])))
    }

    func testBodyweightAndFormatting() {
        let up = WorkoutReview.reviewExercise(previous: ex([(nil, 12)], bodyweight: true), current: ex([(nil, 15)], bodyweight: true))
        XCTAssertEqual(up?.status, .progressed)
        XCTAssertEqual(up?.detail, "+3 reps (12 → 15)")
        XCTAssertEqual(
            WorkoutReview.reviewExercise(previous: ex([(nil, 12)], bodyweight: true), current: ex([(nil, 12)], bodyweight: true))?.status,
            .same
        )
        XCTAssertEqual(WorkoutReview.fmtKg(40), "40")
        XCTAssertEqual(WorkoutReview.fmtKg(42.5), "42.5")
        XCTAssertEqual(WorkoutReview.fmtKg(2.25), "2.3")
    }

    func testSummaryHeadlines() {
        let up = WorkoutReview.review(previous: session(date(2026, 11, 8)), current: session(date(2026, 11, 15), [ex([(42.5, 10)])]))
        XCTAssertEqual(up.headline, "Well done!")
        XCTAssertNil(up.encouragement)
        let flat = WorkoutReview.review(previous: session(date(2026, 11, 8)), current: session(date(2026, 11, 15), [ex([(40, 9)])]))
        XCTAssertEqual(flat.headline, "Solid work")
        XCTAssertTrue(flat.encouragement?.contains("progress isn't linear") ?? false)
        XCTAssertEqual(WorkoutReview.review(previous: nil, current: session(date(2026, 11, 15))).headline, "Baseline set!")
    }

    func testStreak() {
        let mwf: Set<Weekday> = [.monday, .wednesday, .friday]
        func streak(_ s: [WorkoutSession], _ overrides: [DayOverride] = [], today: Date) -> Int {
            WorkoutReview.streak(trainingDays: mwf, overrides: overrides, sessions: s, today: today, calendar: calendar)
        }
        let all = [session(date(2026, 11, 9)), session(date(2026, 11, 11)), session(date(2026, 11, 13))]
        XCTAssertEqual(streak(all, today: date(2026, 11, 15)), 3)
        let missedWed = [session(date(2026, 11, 9)), session(date(2026, 11, 13))]
        XCTAssertEqual(streak(missedWed, today: date(2026, 11, 15)), 1)
        let rest = [DayOverride(day: calendar.localDate(for: date(2026, 11, 11)), type: .rest, reason: .emergencyRest, linkedDay: nil)]
        XCTAssertEqual(streak(missedWed, rest, today: date(2026, 11, 15)), 2)
        XCTAssertEqual(streak([session(date(2026, 11, 11))], today: date(2026, 11, 13)), 1)
        XCTAssertEqual(streak([], today: date(2026, 11, 15)), 0)
    }

    func testStreakMessages() {
        XCTAssertEqual(WorkoutReview.streakMessage(1).title, "Great start!")
        XCTAssertEqual(WorkoutReview.streakMessage(2).title, "Keep it up!")
        XCTAssertEqual(WorkoutReview.streakMessage(5).title, "You are on fire!")
        XCTAssertEqual(WorkoutReview.streakMessage(9).title, "Unstoppable!")
        XCTAssertEqual(WorkoutReview.streakMessage(20).title, "Legend in the making!")
    }

    func testNonLinearLinesMatchWeb() {
        XCTAssertEqual(WorkoutReview.nonLinearLines.count, 6)
    }
}
