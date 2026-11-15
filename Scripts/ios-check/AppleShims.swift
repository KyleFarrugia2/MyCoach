// Windows-only stand-ins for UIKit haptics, StoreKit subscriptions and AVFoundation audio, so
// AppEnvironment's own logic can be typechecked off-Apple. Not part of the app.
import Foundation

final class UINotificationFeedbackGenerator {
    enum FeedbackType { case success, warning, error }
    func notificationOccurred(_ type: FeedbackType) {}
}

final class UIImpactFeedbackGenerator {
    enum FeedbackStyle { case light, medium, heavy }
    init(style: FeedbackStyle) {}
    func impactOccurred() {}
}

@MainActor
protocol SubscriptionProviding: AnyObject {
    var entitlement: SubscriptionEntitlement { get }
    var hasCoachAIAccess: Bool { get }
    var localizedPrice: String? { get }
    var isMock: Bool { get }
    func loadProducts() async throws
    func purchase() async throws -> SubscriptionEntitlement
    func restore() async throws -> SubscriptionEntitlement
    func refreshEntitlement() async -> SubscriptionEntitlement
}

@MainActor
final class SubscriptionManager: SubscriptionProviding {
    var entitlement: SubscriptionEntitlement
    var localizedPrice: String?
    let isMock = false
    var hasCoachAIAccess: Bool { entitlement.hasCoachAIAccess }
    init(productID: String = CoachingConfig.coachProductID, initial: SubscriptionEntitlement? = nil,
         onEntitlementChange: ((SubscriptionEntitlement) -> Void)? = nil) {
        entitlement = initial ?? SubscriptionEntitlement(productID: productID, status: .notSubscribed, expirationDate: nil, isTrialEligible: true, localizedPrice: nil)
    }
    func loadProducts() async throws {}
    func purchase() async throws -> SubscriptionEntitlement { throw SubscriptionError.productUnavailable }
    func restore() async throws -> SubscriptionEntitlement { entitlement }
    func refreshEntitlement() async -> SubscriptionEntitlement { entitlement }
}

@MainActor
final class MockSubscriptionManager: SubscriptionProviding {
    var entitlement: SubscriptionEntitlement
    var localizedPrice: String?
    let isMock = true
    var hasCoachAIAccess: Bool { entitlement.hasCoachAIAccess }
    init(status: SubscriptionEntitlementStatus = .active) {
        entitlement = SubscriptionEntitlement(productID: CoachingConfig.coachProductID, status: status, expirationDate: nil, isTrialEligible: false, localizedPrice: nil)
    }
    func setStatus(_ status: SubscriptionEntitlementStatus) {
        entitlement.status = status
    }
    func loadProducts() async throws {}
    func purchase() async throws -> SubscriptionEntitlement { entitlement.status = .trial; return entitlement }
    func restore() async throws -> SubscriptionEntitlement { entitlement }
    func refreshEntitlement() async -> SubscriptionEntitlement { entitlement }
}

enum SubscriptionError: Error, Sendable {
    case productUnavailable, userCancelled, unknown
}

@MainActor
final class CalmMusicPlayer {
    func sync(enabled: Bool, workoutActive: Bool, appActive: Bool = true) {}
}
