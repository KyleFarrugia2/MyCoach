import Foundation

/// Sleep logged on the day you wake up (i.e. "last night").
struct SleepEntry: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var localDate: Date
    var hours: Double
    /// Optional — users can skip it.
    var wakeUps: Int?

    init(id: UUID = UUID(), localDate: Date, hours: Double, wakeUps: Int? = nil) {
        self.id = id
        self.localDate = localDate
        self.hours = min(max(hours, 0), 24)
        self.wakeUps = wakeUps
    }
}

enum DayType: String, Codable, Sendable {
    case training
    case rest
}

/// A day where the coach changed the weekly schedule.
struct DayOverride: Codable, Equatable, Sendable {
    enum Reason: String, Codable, Sendable {
        case emergencyRest
        case movedSession
    }

    var day: Date
    var type: DayType
    var reason: Reason
    /// emergencyRest → where the session moved; movedSession → where it came from.
    var linkedDay: Date?
}
