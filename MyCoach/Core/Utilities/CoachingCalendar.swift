import Foundation

/// Monday–Sunday coaching weeks in the user's local calendar/timezone.
struct CoachingCalendar: Sendable {
    let calendar: Calendar

    init(timeZone: TimeZone = .current, locale: Locale = .current) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        cal.locale = locale
        cal.firstWeekday = 2 // Monday
        self.calendar = cal
    }

    func localDate(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Monday 00:00 local of the coaching week containing `date`.
    func weekStart(containing date: Date) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        // Gregorian: Sunday=1 ... Saturday=7. Monday=2.
        let daysFromMonday: Int
        switch weekday {
        case 1: daysFromMonday = 6
        default: daysFromMonday = weekday - 2
        }
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
    }

    func weekEnd(containing date: Date) -> Date {
        let start = weekStart(containing: date)
        return calendar.date(byAdding: .day, value: 6, to: start) ?? start
    }

    func datesInWeek(containing date: Date) -> [Date] {
        let start = weekStart(containing: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    func isSameLocalDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }
}
