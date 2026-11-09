import Foundation

struct UserProfile: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var displayName: String
    var dateOfBirth: Date?
    var biologicalSex: BiologicalSex
    var heightCm: Double
    var currentWeightKg: Double
    var desiredWeightKg: Double
    var weightUnit: WeightUnit
    var goalPhase: GoalPhase
    var trainingSchedule: TrainingSchedule
    var activityBand: ActivityBand
    var stepTarget: Int
    var mealCount: Int
    var trainingTime: TrainingTimePreference
    var allergies: Set<FoodAllergy>
    var customAllergyNotes: String
    var dislikedFoods: [String]
    var preferredFoods: [String]
    var dietaryRestrictions: [String]
    var intraWorkoutEnabled: Bool
    var appearance: AppearancePreference
    var hasCompletedOnboarding: Bool
    var createdAt: Date
    var updatedAt: Date

    var ageYears: Int? {
        guard let dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year
    }

    var isMinor: Bool {
        (ageYears ?? 18) < 18
    }

    static func draft() -> UserProfile {
        UserProfile(
            id: UUID(),
            displayName: "",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -25, to: Date()),
            biologicalSex: .preferNotToSay,
            heightCm: 175,
            currentWeightKg: 80,
            desiredWeightKg: 75,
            weightUnit: .kilogram,
            goalPhase: .cut,
            trainingSchedule: .default,
            activityBand: .sixToEight,
            stepTarget: ActivityBand.sixToEight.initialStepTarget,
            mealCount: CoachingConfig.requiredMealCount,
            trainingTime: .evening,
            allergies: [.none],
            customAllergyNotes: "",
            dislikedFoods: [],
            preferredFoods: [],
            dietaryRestrictions: [],
            intraWorkoutEnabled: true,
            appearance: .system,
            hasCompletedOnboarding: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

struct NotificationSettings: Codable, Equatable, Sendable {
    var morningWeighInEnabled: Bool = true
    var morningWeighInHour: Int = 7
    var morningWeighInMinute: Int = 0
    var mealRemindersEnabled: Bool = false
    var stepRemindersEnabled: Bool = true
    var weeklyCheckInEnabled: Bool = true
    var progressPhotosEnabled: Bool = true
}

struct UserPreferences: Codable, Equatable, Sendable {
    /// Keys are `MealSlot.rawValue` for reliable Codable round-trips.
    var customMealNames: [String: String] = [:]
    var notifications: NotificationSettings = NotificationSettings()
    var showEstimatedDirection: Bool = true
    /// Optional so snapshots saved before this setting existed still decode. Use `adaptiveAutoAdjust`.
    var adaptiveAutoAdjustSetting: Bool?

    /// Let the personal adaptive model change calorie targets automatically (at most weekly). Default on.
    var adaptiveAutoAdjust: Bool {
        get { adaptiveAutoAdjustSetting ?? true }
        set { adaptiveAutoAdjustSetting = newValue }
    }

    func mealName(for slot: MealSlot) -> String {
        customMealNames[slot.rawValue] ?? slot.displayName
    }

    mutating func setMealName(_ name: String, for slot: MealSlot) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            customMealNames.removeValue(forKey: slot.rawValue)
        } else {
            customMealNames[slot.rawValue] = trimmed
        }
    }
}

struct StepEntry: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var localDate: Date
    var steps: Int
    var source: StepSource
    var createdAt: Date
    var updatedAt: Date

    enum StepSource: String, Codable, Sendable {
        case manual
        case healthKit
    }

    init(
        id: UUID = UUID(),
        localDate: Date,
        steps: Int,
        source: StepSource,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.localDate = localDate
        self.steps = max(0, steps)
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ProgressPhotoSet: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var weekStart: Date
    var frontLocalPath: String?
    var sideLocalPath: String?
    var backLocalPath: String?
    var createdAt: Date
    var notes: String

    init(
        id: UUID = UUID(),
        weekStart: Date,
        frontLocalPath: String? = nil,
        sideLocalPath: String? = nil,
        backLocalPath: String? = nil,
        createdAt: Date = Date(),
        notes: String = ""
    ) {
        self.id = id
        self.weekStart = weekStart
        self.frontLocalPath = frontLocalPath
        self.sideLocalPath = sideLocalPath
        self.backLocalPath = backLocalPath
        self.createdAt = createdAt
        self.notes = notes
    }
}

struct PlanAdjustment: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var date: Date
    var oldCalories: Int
    var newCalories: Int
    var oldMacros: MacroGrams
    var newMacros: MacroGrams
    var oldSteps: Int
    var newSteps: Int
    var reason: String
    var source: TargetSource
    var userApproved: Bool

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        oldCalories: Int,
        newCalories: Int,
        oldMacros: MacroGrams,
        newMacros: MacroGrams,
        oldSteps: Int,
        newSteps: Int,
        reason: String,
        source: TargetSource,
        userApproved: Bool
    ) {
        self.id = id
        self.date = date
        self.oldCalories = oldCalories
        self.newCalories = newCalories
        self.oldMacros = oldMacros
        self.newMacros = newMacros
        self.oldSteps = oldSteps
        self.newSteps = newSteps
        self.reason = reason
        self.source = source
        self.userApproved = userApproved
    }
}
