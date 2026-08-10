import Combine
import Foundation
import StoreKit

// MARK: - Protocol

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

// MARK: - StoreKit 2 manager

@MainActor
final class SubscriptionManager: ObservableObject, SubscriptionProviding {
    @Published private(set) var entitlement: SubscriptionEntitlement
    @Published private(set) var localizedPrice: String?
    @Published private(set) var product: Product?

    let isMock = false
    let productID: String

    var hasCoachAIAccess: Bool { entitlement.hasCoachAIAccess }

    private var updatesTask: Task<Void, Never>?
    private let onEntitlementChange: ((SubscriptionEntitlement) -> Void)?

    init(
        productID: String = CoachingConfig.coachProductID,
        initial: SubscriptionEntitlement? = nil,
        onEntitlementChange: ((SubscriptionEntitlement) -> Void)? = nil
    ) {
        self.productID = productID
        self.onEntitlementChange = onEntitlementChange
        self.entitlement = initial ?? SubscriptionEntitlement(
            productID: productID,
            status: .notSubscribed,
            expirationDate: nil,
            isTrialEligible: true,
            localizedPrice: nil
        )
        updatesTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async throws {
        let products = try await Product.products(for: [productID])
        guard let match = products.first(where: { $0.id == productID }) else {
            localizedPrice = nil
            product = nil
            return
        }
        product = match
        localizedPrice = match.displayPrice
        var next = entitlement
        next.localizedPrice = match.displayPrice
        next.productID = match.id
        apply(next)
    }

    func purchase() async throws -> SubscriptionEntitlement {
        if product == nil {
            try await loadProducts()
        }
        guard let product else {
            throw SubscriptionError.productUnavailable
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await transaction.finish()
            return await refreshEntitlement()
        case .userCancelled:
            throw SubscriptionError.userCancelled
        case .pending:
            var pending = entitlement
            pending.status = .pending
            apply(pending)
            return pending
        @unknown default:
            throw SubscriptionError.unknown
        }
    }

    func restore() async throws -> SubscriptionEntitlement {
        try await AppStore.sync()
        return await refreshEntitlement()
    }

    /// Entitlement is derived from verified StoreKit transactions — never a local bool alone.
    @discardableResult
    func refreshEntitlement() async -> SubscriptionEntitlement {
        var latest: Transaction?
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(result) else { continue }
            guard transaction.productID == productID else { continue }
            if latest == nil || transaction.purchaseDate > latest!.purchaseDate {
                latest = transaction
            }
        }

        let next: SubscriptionEntitlement
        if let latest {
            next = Self.entitlement(from: latest, localizedPrice: localizedPrice ?? product?.displayPrice)
        } else {
            // Expired / never subscribed — retain local app data; only gate Coach AI.
            next = SubscriptionEntitlement(
                productID: productID,
                status: entitlement.status == .notSubscribed ? .notSubscribed : .expired,
                expirationDate: entitlement.expirationDate,
                isTrialEligible: entitlement.isTrialEligible,
                localizedPrice: localizedPrice ?? product?.displayPrice
            )
        }
        apply(next)
        return next
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard let transaction = try? Self.checkVerified(result) else { continue }
            await transaction.finish()
            if transaction.productID == productID {
                _ = await refreshEntitlement()
            }
        }
    }

    private func apply(_ entitlement: SubscriptionEntitlement) {
        self.entitlement = entitlement
        if let price = entitlement.localizedPrice {
            localizedPrice = price
        }
        onEntitlementChange?(entitlement)
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    private static func entitlement(
        from transaction: Transaction,
        localizedPrice: String?
    ) -> SubscriptionEntitlement {
        let status: SubscriptionEntitlementStatus
        if let revocation = transaction.revocationDate, revocation <= Date() {
            status = .expired
        } else if let expiration = transaction.expirationDate, expiration <= Date() {
            status = .expired
        } else if transaction.offerType == .introductory {
            status = .trial
        } else {
            status = .active
        }

        return SubscriptionEntitlement(
            productID: transaction.productID,
            status: status,
            expirationDate: transaction.expirationDate,
            isTrialEligible: false,
            localizedPrice: localizedPrice
        )
    }
}

enum SubscriptionError: Error, LocalizedError, Sendable {
    case productUnavailable
    case userCancelled
    case unknown

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            "The coaching subscription product is not available right now."
        case .userCancelled:
            "Purchase cancelled."
        case .unknown:
            "An unknown subscription error occurred."
        }
    }
}

// MARK: - Preview / test mock

/// Explicitly labeled mock for SwiftUI previews and unit tests — not for production purchases.
@MainActor
final class MockSubscriptionManager: ObservableObject, SubscriptionProviding {
    /// Always `true` so UI and tests can detect non-StoreKit paths.
    let isMock = true

    @Published private(set) var entitlement: SubscriptionEntitlement
    @Published var localizedPrice: String?

    var hasCoachAIAccess: Bool { entitlement.hasCoachAIAccess }

    init(
        status: SubscriptionEntitlementStatus = .active,
        localizedPrice: String? = "€12.99",
        expirationDate: Date? = Calendar.current.date(byAdding: .month, value: 1, to: Date())
    ) {
        self.localizedPrice = localizedPrice
        self.entitlement = SubscriptionEntitlement(
            productID: CoachingConfig.coachProductID,
            status: status,
            expirationDate: expirationDate,
            isTrialEligible: status == .notSubscribed,
            localizedPrice: localizedPrice
        )
    }

    /// Convenience for expired-state previews: Coach AI gated off, user data retained elsewhere.
    static func expiredPreview() -> MockSubscriptionManager {
        MockSubscriptionManager(
            status: .expired,
            localizedPrice: "€12.99",
            expirationDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())
        )
    }

    func loadProducts() async throws {
        // no-op for mock
    }

    func purchase() async throws -> SubscriptionEntitlement {
        entitlement = SubscriptionEntitlement(
            productID: CoachingConfig.coachProductID,
            status: .trial,
            expirationDate: Calendar.current.date(byAdding: .day, value: CoachingConfig.freeTrialDays, to: Date()),
            isTrialEligible: false,
            localizedPrice: localizedPrice
        )
        return entitlement
    }

    func restore() async throws -> SubscriptionEntitlement {
        entitlement
    }

    func refreshEntitlement() async -> SubscriptionEntitlement {
        entitlement
    }

    func setStatus(_ status: SubscriptionEntitlementStatus) {
        // Expired / not subscribed → hasCoachAIAccess false; app data stays in AppDataStore.
        entitlement = SubscriptionEntitlement(
            productID: CoachingConfig.coachProductID,
            status: status,
            expirationDate: entitlement.expirationDate,
            isTrialEligible: status == .notSubscribed,
            localizedPrice: localizedPrice
        )
    }
}
