import XCTest
@testable import MyCoach

final class SubscriptionEntitlementTests: XCTestCase {
    func testHasCoachAIAccessForTrialActiveExpiredAndNotSubscribed() {
        XCTAssertTrue(entitlement(status: .trial).hasCoachAIAccess)
        XCTAssertTrue(entitlement(status: .active).hasCoachAIAccess)
        XCTAssertFalse(entitlement(status: .expired).hasCoachAIAccess)
        XCTAssertFalse(entitlement(status: .notSubscribed).hasCoachAIAccess)
    }

    func testFeatureAccessRules() {
        XCTAssertTrue(FeatureAccess.foodLoggingAlwaysFree)

        XCTAssertTrue(FeatureAccess.canUseCoachAI(entitlement(status: .trial)))
        XCTAssertTrue(FeatureAccess.canUseCoachAI(entitlement(status: .active)))
        XCTAssertFalse(FeatureAccess.canUseCoachAI(entitlement(status: .expired)))
        XCTAssertFalse(FeatureAccess.canUseCoachAI(entitlement(status: .notSubscribed)))

        XCTAssertTrue(FeatureAccess.canGenerateMealPlan(entitlement(status: .active)))
        XCTAssertFalse(FeatureAccess.canGenerateMealPlan(entitlement(status: .expired)))
    }

    func testGracePeriodAndBillingRetryStillHaveAccess() {
        XCTAssertTrue(entitlement(status: .gracePeriod).hasCoachAIAccess)
        XCTAssertTrue(entitlement(status: .billingRetry).hasCoachAIAccess)
        XCTAssertFalse(entitlement(status: .pending).hasCoachAIAccess)
    }

    private func entitlement(status: SubscriptionEntitlementStatus) -> SubscriptionEntitlement {
        SubscriptionEntitlement(
            productID: CoachingConfig.coachProductID,
            status: status,
            expirationDate: nil,
            isTrialEligible: status == .notSubscribed,
            localizedPrice: "€12.99"
        )
    }
}
