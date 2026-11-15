import Foundation

/// Post-workout review: what progressed vs last time, the streak, and the messages shown on the
/// Workout Complete screens. Port of `web/src/engines/workoutReview.ts` (keep the strings identical).
enum WorkoutReview {
    enum Status: String, Sendable {
        case progressed, same, less, new

        var label: String {
            switch self {
            case .progressed: return "Progressed"
            case .same: return "Same as last week"
            case .less: return "A bit less than last week"
            case .new: return "New baseline"
            }
        }
    }

    struct ExerciseReview: Identifiable, Equatable, Sendable {
        var id: String
        var name: String
        var status: Status
        var detail: String
    }

    struct Summary: Equatable, Sendable {
        var exercises: [ExerciseReview]
        var progressed: Int
        var headline: String
        var subline: String
        /// Shown when nothing went up — progress isn't linear.
        var encouragement: String?
    }

    struct Stats: Equatable, Sendable {
        var durationSeconds: Int
        var sets: Int
        var volumeKg: Double
        var exercises: Int
    }

    /// Up to one decimal, no trailing ".0".
    static func fmtKg(_ x: Double) -> String {
        let r = (x * 10).rounded() / 10
        return r == r.rounded() ? String(Int(r)) : String(format: "%.1f", r)
    }

    private static let tolerance = 0.05

    private static func repsAt(_ e: WorkoutExerciseLog, _ weight: Double) -> Int {
        e.sets.filter { abs(($0.weightKg ?? 0) - weight) <= tolerance }.map(\.reps).max() ?? 0
    }

    /// Compare one exercise with the previous session of the same workout. Skipped exercises → nil.
    static func reviewExercise(previous: WorkoutExerciseLog?, current: WorkoutExerciseLog) -> ExerciseReview? {
        guard !current.sets.isEmpty else { return nil }
        func r(_ status: Status, _ detail: String) -> ExerciseReview {
            ExerciseReview(id: current.id, name: current.name, status: status, detail: detail)
        }
        guard let previous, !previous.sets.isEmpty else { return r(.new, "First time — baseline set") }

        if current.isBodyweightMaxReps {
            let cr = current.bestReps
            let pr = previous.bestReps
            if cr > pr { return r(.progressed, "+\(cr - pr) reps (\(pr) → \(cr))") }
            if cr == pr { return r(.same, "\(cr) reps again") }
            return r(.less, "\(pr) → \(cr) reps")
        }
        let cw = current.bestWeightKg
        let pw = previous.bestWeightKg
        let cv = current.totalVolume
        let pv = previous.totalVolume
        if cw > pw + tolerance {
            return r(.progressed, "+\(fmtKg(cw - pw)) kg on your top set (\(fmtKg(pw)) → \(fmtKg(cw)) kg)")
        }
        if abs(cw - pw) <= tolerance {
            let crt = repsAt(current, cw)
            let prt = repsAt(previous, pw)
            if crt > prt { return r(.progressed, "+\(crt - prt) reps at \(fmtKg(cw)) kg") }
            if crt == prt {
                if cv > pv + 0.5 {
                    return r(.progressed, "More total volume (\(Int(pv.rounded())) → \(Int(cv.rounded())) kg)")
                }
                if cv < pv - 0.5 { return r(.less, "Slightly less total volume") }
                return r(.same, "\(fmtKg(cw)) kg × \(crt) again")
            }
            return r(.less, "\(prt) → \(crt) reps at \(fmtKg(cw)) kg")
        }
        if cv > pv + 0.5 { return r(.progressed, "More total volume at a lighter weight") }
        return r(.less, "Top set \(fmtKg(pw)) → \(fmtKg(cw)) kg")
    }

    /// Original coach lines (no attributions) — progress isn't linear.
    static let nonLinearLines = [
        "Progress isn't a straight line — it's a staircase with a few landings.",
        "Strength is built over months, not single sessions. Showing up today was the win.",
        "Some days you lift the weight, some days the weight teaches you. Both count.",
        "Plateaus are where your body consolidates the work. Keep stacking sessions.",
        "Sleep, food and stress all show up in the gym. One quieter session changes nothing.",
        "Consistency beats intensity. You trained — that's what moves the needle.",
    ]

    static func review(
        previous: WorkoutSession?,
        current: WorkoutSession,
        calendar: CoachingCalendar = CoachingCalendar()
    ) -> Summary {
        let exercises = current.exercises.compactMap { e in
            reviewExercise(previous: previous?.exercises.first { $0.id == e.id }, current: e)
        }
        let progressed = exercises.filter { $0.status == .progressed }.count
        if progressed > 0 {
            return Summary(
                exercises: exercises,
                progressed: progressed,
                headline: "Well done!",
                subline: "You progressed on \(progressed) \(progressed == 1 ? "movement" : "movements")."
            )
        }
        if !exercises.isEmpty, exercises.allSatisfy({ $0.status == .new }) {
            return Summary(
                exercises: exercises,
                progressed: 0,
                headline: "Baseline set!",
                subline: "Next time you'll have numbers to beat."
            )
        }
        let c = calendar.calendar.dateComponents([.year, .month, .day], from: current.localDate)
        let n = QuoteOfTheDay.dayNumber(year: c.year ?? 2026, month: c.month ?? 1, day: c.day ?? 1)
        let line = nonLinearLines[((n % nonLinearLines.count) + nonLinearLines.count) % nonLinearLines.count]
        return Summary(
            exercises: exercises,
            progressed: 0,
            headline: "Solid work",
            subline: "Same as last time or a touch under — and that's completely normal.",
            encouragement: "\(line) Don't worry — progress isn't linear."
        )
    }

    /// Workouts completed in a row without missing a planned training day. Emergency rest days (and other
    /// rest days) never break it; today doesn't count as missed until it's over.
    static func streak(
        trainingDays: Set<Weekday>,
        overrides: [DayOverride],
        sessions: [WorkoutSession],
        today: Date = Date(),
        calendar: CoachingCalendar = CoachingCalendar()
    ) -> Int {
        let done = sessions.filter(\.isCompleted)
        guard !done.isEmpty else { return 0 }
        let cal = calendar.calendar
        var perDay: [Date: Int] = [:]
        for s in done { perDay[calendar.localDate(for: s.localDate), default: 0] += 1 }
        let first = perDay.keys.min()!
        let start = calendar.localDate(for: today)
        let plan = DayPlanEngine(calendar: calendar)
        var count = 0
        var d = start
        while d >= first {
            let n = perDay[d] ?? 0
            if n > 0 {
                count += n
            } else if d < start, plan.dayType(trainingDays: trainingDays, overrides: overrides, on: d) == .training {
                break
            }
            guard let prev = cal.date(byAdding: .day, value: -1, to: d) else { break }
            d = cal.startOfDay(for: prev)
        }
        return count
    }

    static func streakMessage(_ streak: Int) -> (title: String, subtitle: String) {
        if streak <= 1 { return ("Great start!", "Every streak starts with one.") }
        if streak <= 3 { return ("Keep it up!", "You're building a habit.") }
        if streak <= 6 { return ("You are on fire!", "Nothing's stopping you now.") }
        if streak <= 13 { return ("Unstoppable!", "This is what consistency looks like.") }
        return ("Legend in the making!", "Weeks of showing up — incredible.")
    }

    static func stats(_ s: WorkoutSession) -> Stats {
        Stats(
            durationSeconds: s.durationSeconds,
            sets: s.exercises.reduce(0) { $0 + $1.sets.count },
            volumeKg: s.exercises.reduce(0) { $0 + $1.totalVolume },
            exercises: s.exercises.filter { !$0.sets.isEmpty }.count
        )
    }
}
