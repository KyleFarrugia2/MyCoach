import Foundation

enum CoachAdjustment: Codable, Equatable, Sendable {
    case maintain
    case increaseCalories(Int)
    case decreaseCalories(Int)
    case increaseSteps(Int)
    case decreaseSteps(Int)
    case suggestRefeed
    case requireMoreData
    case reviewAdherence
    case reviewRecovery
    case recommendNutritionIncreaseReview
    case recommendNutritionDecreaseReview
}

enum CoachConfidence: String, Codable, Sendable {
    case low
    case medium
    case high
}

enum CoachReasonCode: String, Codable, Sendable {
    case rateOnTarget
    case rateTooFastLoss
    case rateTooFastGain
    case rateTooSlow
    case highAdherence
    case poorAdherence
    case insufficientWeighIns
    case performanceStable
    case performanceDeclining
    case appearanceFlat
    case appearanceSoft
    case appearanceImproving
    case extremeWeeklyChange
    case stepCapReached
    case userFeelingHungry
    case recoveryConcern
    /// The personal adaptive model chose the calorie change.
    case modelPrediction
}

struct CoachDecision: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var weekStart: Date
    var action: CoachAdjustment
    var secondaryActions: [CoachAdjustment]
    var confidence: CoachConfidence
    var reasons: [CoachReasonCode]
    var summary: String
    var suggestedTrainingCalories: Int?
    var suggestedRestCalories: Int?
    var suggestedMacros: MacroGrams?
    var suggestedSteps: Int?
    var refeed: RefeedPlan?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        weekStart: Date,
        action: CoachAdjustment,
        secondaryActions: [CoachAdjustment] = [],
        confidence: CoachConfidence,
        reasons: [CoachReasonCode],
        summary: String,
        suggestedTrainingCalories: Int? = nil,
        suggestedRestCalories: Int? = nil,
        suggestedMacros: MacroGrams? = nil,
        suggestedSteps: Int? = nil,
        refeed: RefeedPlan? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.weekStart = weekStart
        self.action = action
        self.secondaryActions = secondaryActions
        self.confidence = confidence
        self.reasons = reasons
        self.summary = summary
        self.suggestedTrainingCalories = suggestedTrainingCalories
        self.suggestedRestCalories = suggestedRestCalories
        self.suggestedMacros = suggestedMacros
        self.suggestedSteps = suggestedSteps
        self.refeed = refeed
        self.createdAt = createdAt
    }
}

struct WeeklyCheckIn: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var weekStart: Date
    var previousAverageKg: Double?
    var currentAverageKg: Double?
    var rateKg: Double?
    var ratePercent: Double?
    var appearance: AppearanceFeedback
    var adherence: AdherenceBand
    var adherencePercent: Int
    var performance: TrainingPerformance
    var hunger: Int
    var energy: Int
    var digestion: DigestionFeedback
    var notes: String
    var photoSetID: UUID?
    var decision: CoachDecision?
    var userApprovedAdjustment: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        weekStart: Date,
        previousAverageKg: Double? = nil,
        currentAverageKg: Double? = nil,
        rateKg: Double? = nil,
        ratePercent: Double? = nil,
        appearance: AppearanceFeedback = .notSure,
        adherence: AdherenceBand = .seventyTo84,
        adherencePercent: Int = 77,
        performance: TrainingPerformance = .same,
        hunger: Int = 3,
        energy: Int = 3,
        digestion: DigestionFeedback = .okay,
        notes: String = "",
        photoSetID: UUID? = nil,
        decision: CoachDecision? = nil,
        userApprovedAdjustment: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.weekStart = weekStart
        self.previousAverageKg = previousAverageKg
        self.currentAverageKg = currentAverageKg
        self.rateKg = rateKg
        self.ratePercent = ratePercent
        self.appearance = appearance
        self.adherence = adherence
        self.adherencePercent = adherencePercent
        self.performance = performance
        self.hunger = hunger
        self.energy = energy
        self.digestion = digestion
        self.notes = notes
        self.photoSetID = photoSetID
        self.decision = decision
        self.userApprovedAdjustment = userApprovedAdjustment
        self.createdAt = createdAt
    }
}

struct CoachAIContext: Codable, Equatable, Sendable {
    var goal: GoalPhase
    var weightKg: Double
    var previousWeeklyAverageKg: Double?
    var currentWeeklyAverageKg: Double?
    var weeklyRateKg: Double?
    var trainingCalories: Int
    var restCalories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var stepTarget: Int
    var adherence: Int?
    var performance: TrainingPerformance?
    var appearance: AppearanceFeedback?
    var targetSource: TargetSource
    /// Personal adaptive model summary, when one has been trained.
    var model: CoachAIModelContext? = nil
}

/// What the on-device adaptive model has learned — passed to the coach so it can explain (never invent) numbers.
struct CoachAIModelContext: Codable, Equatable, Sendable {
    var maintenanceKcal: Double
    var maintenanceSD: Double
    var confidence: AdaptiveModelConfidence
    var observations: Int
    var predictedKgPerWeek: Double
    var targetKgPerWeek: Double
    var recommendedDeltaKcal: Int
}

struct CoachAIStructuredResponse: Codable, Equatable, Sendable {
    var summary: String
    var recommendation: String
    var reasoning: [String]
    var userMessage: String
}

struct CoachChatMessage: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var role: Role
    var text: String
    var createdAt: Date
    var structured: CoachAIStructuredResponse?

    enum Role: String, Codable, Sendable {
        case user
        case coach
        case system
    }

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        createdAt: Date = Date(),
        structured: CoachAIStructuredResponse? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.structured = structured
    }
}

enum SubscriptionEntitlementStatus: String, Codable, Sendable {
    case notSubscribed
    case trial
    case active
    case expired
    case billingRetry
    case gracePeriod
    case pending
}

struct SubscriptionEntitlement: Codable, Equatable, Sendable {
    var productID: String
    var status: SubscriptionEntitlementStatus
    var expirationDate: Date?
    var isTrialEligible: Bool
    var localizedPrice: String?

    var hasCoachAIAccess: Bool {
        switch status {
        case .trial, .active, .gracePeriod, .billingRetry:
            true
        case .notSubscribed, .expired, .pending:
            false
        }
    }
}
