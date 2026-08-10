import Foundation

/// Static entitlement rules for free vs Coach AI features.
enum FeatureAccess {
    static let foodLoggingAlwaysFree = true

    static func canUseCoachAI(_ entitlement: SubscriptionEntitlement) -> Bool {
        entitlement.hasCoachAIAccess
    }

    static func canGenerateMealPlan(_ entitlement: SubscriptionEntitlement) -> Bool {
        entitlement.hasCoachAIAccess
    }
}
