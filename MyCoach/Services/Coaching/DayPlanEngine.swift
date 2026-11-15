import Foundation

/// Training/rest schedule with user overrides — the coach works around the user.
/// Port of `web/src/engines/dayPlan.ts` (keep in sync).
///
///  - The weekly schedule (Settings) says which weekdays are training days.
///  - An emergency rest day turns a day into a rest day; the missed session moves to the next rest day later
///    that week (Mon–Sun), preferring no more than 2 training days in a row, accepting 3, never 4+ — or is
///    dropped if nothing fits.
///  - Undo restores both days.
struct DayPlanEngine: Sendable {
    let calendar: CoachingCalendar

    init(calendar: CoachingCalendar = CoachingCalendar()) {
        self.calendar = calendar
    }

    /// Default weekdays for a chosen number of training days (spread out, Monday first).
    static let presets: [Int: [Weekday]] = [
        1: [.wednesday],
        2: [.monday, .thursday],
        3: [.monday, .wednesday, .friday],
        4: [.monday, .tuesday, .thursday, .friday],
        5: [.monday, .tuesday, .wednesday, .friday, .saturday],
        6: [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday],
        7: Weekday.allCases,
    ]

    func weekday(for date: Date) -> Weekday {
        switch calendar.calendar.component(.weekday, from: date) {
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .sunday
        }
    }

    private func addDays(_ date: Date, _ n: Int) -> Date {
        calendar.calendar.date(byAdding: .day, value: n, to: calendar.localDate(for: date)) ?? date
    }

    func override(in overrides: [DayOverride], on date: Date) -> DayOverride? {
        overrides.first { calendar.isSameLocalDay($0.day, date) }
    }

    func dayType(trainingDays: Set<Weekday>, overrides: [DayOverride], on date: Date) -> DayType {
        if let o = override(in: overrides, on: date) { return o.type }
        return trainingDays.contains(weekday(for: date)) ? .training : .rest
    }

    /// Turn `date` into a rest day and move its session to the best remaining rest day this week.
    func takeEmergencyRest(
        trainingDays: Set<Weekday>,
        overrides: [DayOverride],
        on date: Date
    ) -> (overrides: [DayOverride], movedTo: Date?) {
        let day = calendar.localDate(for: date)
        guard dayType(trainingDays: trainingDays, overrides: overrides, on: day) == .training else {
            return (overrides, nil)
        }
        let base = overrides.filter { !calendar.isSameLocalDay($0.day, day) }
        func typeOf(_ d: Date) -> DayType {
            calendar.isSameLocalDay(d, day) ? .rest : dayType(trainingDays: trainingDays, overrides: base, on: d)
        }
        // Length of the consecutive training run `d` would sit in if it became a training day.
        func runIfTraining(_ d: Date) -> Int {
            var run = 1
            var x = addDays(d, -1)
            while run < 8, typeOf(x) == .training {
                run += 1
                x = addDays(x, -1)
            }
            x = addDays(d, 1)
            while run < 8, typeOf(x) == .training {
                run += 1
                x = addDays(x, 1)
            }
            return run
        }
        let end = calendar.weekEnd(containing: day)
        var candidates: [Date] = []
        var d = addDays(day, 1)
        while d <= end {
            if typeOf(d) == .rest, override(in: base, on: d) == nil { candidates.append(d) }
            d = addDays(d, 1)
        }
        // Prefer no more than 2 training days in a row; accept 3 if nothing better; never 4+.
        let movedTo = candidates.first { runIfTraining($0) <= 2 } ?? candidates.first { runIfTraining($0) <= 3 }
        var next = base
        next.append(DayOverride(day: day, type: .rest, reason: .emergencyRest, linkedDay: movedTo))
        if let movedTo {
            next.append(DayOverride(day: movedTo, type: .training, reason: .movedSession, linkedDay: day))
        }
        return (next, movedTo)
    }

    /// Undo an emergency rest day (and the session it moved).
    func undoEmergencyRest(overrides: [DayOverride], on date: Date) -> [DayOverride] {
        guard let o = override(in: overrides, on: date), o.reason == .emergencyRest else { return overrides }
        return overrides.filter { x in
            if calendar.isSameLocalDay(x.day, date) { return false }
            if x.reason == .movedSession, let linked = x.linkedDay, calendar.isSameLocalDay(linked, date) { return false }
            return true
        }
    }
}
