import Foundation

struct WeightEntry: Codable, Equatable, Sendable, Identifiable, Hashable {
    var id: UUID
    var timestamp: Date
    /// Local calendar day of the morning check-in (start-of-day).
    var localDate: Date
    var weightKg: Double
    var inputUnit: WeightUnit
    var isOfficialMorningCheckIn: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        localDate: Date,
        weightKg: Double,
        inputUnit: WeightUnit,
        isOfficialMorningCheckIn: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.timestamp = timestamp
        self.localDate = localDate
        self.weightKg = weightKg
        self.inputUnit = inputUnit
        self.isOfficialMorningCheckIn = isOfficialMorningCheckIn
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum WeekCompleteness: String, Codable, Sendable {
    case empty
    case partial
    case complete
    case insufficientForAdjustment
    case sufficientForAdjustment
}

struct CoachingWeek: Equatable, Sendable, Identifiable {
    var id: Date { startDate }
    var startDate: Date
    var endDate: Date
    var entries: [WeightEntry]
    var averageKg: Double?
    var entryCount: Int
    var completeness: WeekCompleteness

    var weighInSummary: String {
        "\(entryCount) / 7 weigh-ins"
    }
}

struct WeeklyRateOfChange: Equatable, Sendable {
    var previousAverageKg: Double
    var currentAverageKg: Double
    var absoluteChangeKg: Double
    var percentChange: Double

    var isExtreme: Bool {
        abs(absoluteChangeKg) > CoachingConfig.extremeWeeklyChangeKg
    }

    var meetsExtremeThresholdInclusive: Bool {
        abs(absoluteChangeKg) >= CoachingConfig.extremeWeeklyChangeKg
    }
}

enum WeightAnalytics {
    /// Average of valid morning check-ins only — never fabricate missing days.
    static func weeklyAverage(entries: [WeightEntry]) -> Double? {
        let valid = entries.filter(\.isOfficialMorningCheckIn)
        guard !valid.isEmpty else { return nil }
        let sum = valid.reduce(0.0) { $0 + $1.weightKg }
        return sum / Double(valid.count)
    }

    static func makeWeek(
        containing date: Date,
        entries: [WeightEntry],
        calendar: CoachingCalendar = CoachingCalendar(),
        minimumForAdjustment: Int = CoachingConfig.minimumWeighInsForAdjustment
    ) -> CoachingWeek {
        let start = calendar.weekStart(containing: date)
        let end = calendar.weekEnd(containing: date)
        let inWeek = entries.filter { entry in
            entry.isOfficialMorningCheckIn
                && entry.localDate >= start
                && entry.localDate <= end
        }
        // One official entry per local day (latest wins if duplicates slipped through).
        var byDay: [Date: WeightEntry] = [:]
        for entry in inWeek.sorted(by: { $0.timestamp < $1.timestamp }) {
            byDay[calendar.localDate(for: entry.localDate)] = entry
        }
        let unique = Array(byDay.values).sorted { $0.localDate < $1.localDate }
        let average = weeklyAverage(entries: unique)
        let count = unique.count
        let completeness: WeekCompleteness
        if count == 0 {
            completeness = .empty
        } else if count < minimumForAdjustment {
            completeness = .insufficientForAdjustment
        } else if count < 7 {
            completeness = .sufficientForAdjustment
        } else {
            completeness = .complete
        }
        return CoachingWeek(
            startDate: start,
            endDate: end,
            entries: unique,
            averageKg: average,
            entryCount: count,
            completeness: completeness
        )
    }

    static func rateOfChange(previous: CoachingWeek, current: CoachingWeek) -> WeeklyRateOfChange? {
        guard let prev = previous.averageKg, let curr = current.averageKg, prev != 0 else {
            return nil
        }
        let absolute = curr - prev
        let percent = (absolute / prev) * 100.0
        return WeeklyRateOfChange(
            previousAverageKg: prev,
            currentAverageKg: curr,
            absoluteChangeKg: absolute,
            percentChange: percent
        )
    }
}
