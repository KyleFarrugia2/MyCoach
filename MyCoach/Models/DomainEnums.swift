import Foundation

enum GoalPhase: String, Codable, CaseIterable, Sendable, Identifiable {
    case cut
    case gain
    /// Reserved for future use — not exposed in onboarding by default.
    case maintenance

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cut: "Lose Weight"
        case .gain: "Gain Weight"
        case .maintenance: "Maintain"
        }
    }

    var subtitle: String {
        switch self {
        case .cut:
            "Reduce body fat while maintaining as much muscle and training performance as possible."
        case .gain:
            "Build muscle using a controlled calorie surplus."
        case .maintenance:
            "Hold body weight while refining composition and performance."
        }
    }
}

enum BiologicalSex: String, Codable, CaseIterable, Sendable, Identifiable {
    case female
    case male
    case preferNotToSay

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .female: "Female"
        case .male: "Male"
        case .preferNotToSay: "Prefer not to say"
        }
    }
}

enum Weekday: Int, Codable, CaseIterable, Sendable, Identifiable, Comparable {
    case monday = 1
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .monday: "M"
        case .tuesday: "T"
        case .wednesday: "W"
        case .thursday: "T"
        case .friday: "F"
        case .saturday: "S"
        case .sunday: "S"
        }
    }

    var fullLabel: String {
        switch self {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }

    static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct TrainingSchedule: Codable, Equatable, Sendable {
    var trainingDays: Set<Weekday>

    var trainingDaysPerWeek: Int { trainingDays.count }

    func isTrainingDay(_ weekday: Weekday) -> Bool {
        trainingDays.contains(weekday)
    }

    static let `default` = TrainingSchedule(trainingDays: [.monday, .tuesday, .thursday, .friday])
}

enum ActivityBand: String, Codable, CaseIterable, Sendable, Identifiable {
    case under4000
    case fourToSix
    case sixToEight
    case eightToTen
    case tenPlus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .under4000: "Under 4,000"
        case .fourToSix: "4,000–6,000"
        case .sixToEight: "6,000–8,000"
        case .eightToTen: "8,000–10,000"
        case .tenPlus: "10,000+"
        }
    }

    var midpointSteps: Int {
        switch self {
        case .under4000: 3_000
        case .fourToSix: 5_000
        case .sixToEight: 7_000
        case .eightToTen: 9_000
        case .tenPlus: 11_000
        }
    }

    var initialStepTarget: Int {
        min(CoachingConfig.maxStepTarget, midpointSteps + 1_000)
    }
}

enum TrainingTimePreference: String, Codable, CaseIterable, Sendable, Identifiable {
    case morning
    case midday
    case afternoon
    case evening
    case variable

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morning: "Morning"
        case .midday: "Midday"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        case .variable: "Variable"
        }
    }
}

enum FoodAllergy: String, Codable, CaseIterable, Sendable, Identifiable, Hashable {
    case none
    case dairy
    case eggs
    case peanuts
    case treeNuts
    case fish
    case shellfish
    case glutenWheat
    case soy
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "None"
        case .dairy: "Dairy"
        case .eggs: "Eggs"
        case .peanuts: "Peanuts"
        case .treeNuts: "Tree nuts"
        case .fish: "Fish"
        case .shellfish: "Shellfish"
        case .glutenWheat: "Gluten/Wheat"
        case .soy: "Soy"
        case .other: "Other"
        }
    }
}

enum AppearanceFeedback: String, Codable, CaseIterable, Sendable, Identifiable {
    case softer
    case aboutTheSame
    case flatter
    case better
    case notSure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .softer: "Softer"
        case .aboutTheSame: "About The Same"
        case .flatter: "Flatter"
        case .better: "Better"
        case .notSure: "Not Sure"
        }
    }

    var subtitle: String {
        switch self {
        case .softer: "I look noticeably softer or smoother."
        case .aboutTheSame: "No major visual difference."
        case .flatter: "My muscles look flatter and less full."
        case .better: "I look tighter/full and progress looks good."
        case .notSure: "I'm not sure how to judge this week."
        }
    }
}

enum TrainingPerformance: String, Codable, CaseIterable, Sendable, Identifiable {
    case muchWorse
    case slightlyWorse
    case same
    case better
    case muchBetter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .muchWorse: "Much worse"
        case .slightlyWorse: "Slightly worse"
        case .same: "Same"
        case .better: "Better"
        case .muchBetter: "Much better"
        }
    }
}

enum DigestionFeedback: String, Codable, CaseIterable, Sendable, Identifiable {
    case poor
    case okay
    case good

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .poor: "Poor"
        case .okay: "Okay"
        case .good: "Good"
        }
    }
}

enum AdherenceBand: String, Codable, CaseIterable, Sendable, Identifiable {
    case under50
    case fiftyTo69
    case seventyTo84
    case eightyFiveTo94
    case ninetyFiveTo100

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .under50: "Under 50%"
        case .fiftyTo69: "50–69%"
        case .seventyTo84: "70–84%"
        case .eightyFiveTo94: "85–94%"
        case .ninetyFiveTo100: "95–100%"
        }
    }

    var representativePercent: Int {
        switch self {
        case .under50: 40
        case .fiftyTo69: 60
        case .seventyTo84: 77
        case .eightyFiveTo94: 90
        case .ninetyFiveTo100: 97
        }
    }

    var isHigh: Bool {
        switch self {
        case .eightyFiveTo94, .ninetyFiveTo100: true
        default: false
        }
    }

    var isPoor: Bool {
        switch self {
        case .under50, .fiftyTo69: true
        default: false
        }
    }
}

enum MeasurementState: String, Codable, CaseIterable, Sendable, Identifiable {
    case raw
    case cooked
    case dry
    case prepared
    case serving
    case package

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .raw: "Raw"
        case .cooked: "Cooked"
        case .dry: "Dry"
        case .prepared: "Prepared"
        case .serving: "Serving"
        case .package: "Package"
        }
    }
}

enum TargetSource: String, Codable, Sendable {
    case engine
    case coachRecommendation
    case userOverride
}

enum MealSlot: String, Codable, CaseIterable, Sendable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack
    case afternoonSnack
    case preWorkout
    case intraWorkout
    case postWorkout
    case custom

    var id: String { rawValue }

    /// Rest days: Meal 1–5.
    static let restDaySlots: [MealSlot] = [
        .breakfast,
        .snack,
        .lunch,
        .afternoonSnack,
        .dinner
    ]

    /// Training days: Meal 1, Meal 2, Pre/Intra, Post Workout, Meal 5.
    static let trainingDaySlots: [MealSlot] = [
        .breakfast,
        .snack,
        .preWorkout,
        .postWorkout,
        .dinner
    ]

    static func slots(isTrainingDay: Bool) -> [MealSlot] {
        isTrainingDay ? trainingDaySlots : restDaySlots
    }

    var displayName: String {
        switch self {
        case .breakfast: "Meal 1"
        case .snack: "Meal 2"
        case .lunch: "Meal 3"
        case .afternoonSnack: "Meal 4"
        case .dinner: "Meal 5"
        case .preWorkout: "Pre Workout / Intra Workout"
        case .intraWorkout: "Intra Workout"
        case .postWorkout: "Post Workout"
        case .custom: "Meal"
        }
    }
}

enum AppearancePreference: String, Codable, CaseIterable, Sendable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
