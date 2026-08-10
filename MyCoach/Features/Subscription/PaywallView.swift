import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var isPurchasing = false
    @State private var statusMessage: String?
    @State private var showTerms = false
    @State private var showPrivacy = false

    private var coachPriceLabel: String {
        env.subscription.localizedPrice
            ?? String(format: "€%.2f", env.paywallComparisonCoachEUR)
    }

    private var traditionalLabel: String {
        String(format: "€%.0f+/month*", env.paywallComparisonTraditionalEUR)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MCTheme.Spacing.lg) {
                    header
                    comparison
                    features
                    cta
                    legal
                }
                .padding(MCTheme.Spacing.screenHorizontal)
                .padding(.vertical, MCTheme.Spacing.lg)
            }
            .mcScreenBackground()
            .navigationTitle("My Coach AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showTerms) {
                LegalPlaceholderView(title: "Terms of Use", bodyText: termsPlaceholder)
            }
            .sheet(isPresented: $showPrivacy) {
                LegalPlaceholderView(title: "Privacy Policy", bodyText: privacyPlaceholder)
            }
        }
    }

    private var header: some View {
        VStack(spacing: MCTheme.Spacing.sm) {
            Text("Coaching Without The \(traditionalLabel.replacingOccurrences(of: "*", with: "")) Price Tag")
                .font(MCTheme.Typography.largeTitle)
                .multilineTextAlignment(.center)
                .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
            Text("Full AI coaching, weekly check-ins, macro adjustments, meal plans and progress analysis.")
                .font(MCTheme.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            Text("\(CoachingConfig.freeTrialDays) Days Free")
                .font(MCTheme.Typography.headline)
                .foregroundStyle(MCTheme.ColorToken.primary)
                .padding(.top, 4)
        }
    }

    private var comparison: some View {
        HStack(spacing: MCTheme.Spacing.sm) {
            comparisonColumn(
                title: "Traditional 1:1 Coaching",
                price: traditionalLabel,
                highlight: false
            )
            comparisonColumn(
                title: "My Coach AI",
                price: "\(coachPriceLabel)/month",
                highlight: true
            )
        }
    }

    private func comparisonColumn(title: String, price: String, highlight: Bool) -> some View {
        VStack(spacing: MCTheme.Spacing.sm) {
            Text(title)
                .font(MCTheme.Typography.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            Text(price)
                .font(MCTheme.Typography.title2)
                .foregroundStyle(highlight ? MCTheme.ColorToken.primary : MCTheme.Surface.primaryText(colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(MCTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: MCTheme.Radius.lg, style: .continuous)
                .stroke(highlight ? MCTheme.ColorToken.primary : MCTheme.Surface.border(colorScheme), lineWidth: highlight ? 2 : 1)
                .background(
                    RoundedRectangle(cornerRadius: MCTheme.Radius.lg, style: .continuous)
                        .fill(MCTheme.Surface.elevated(colorScheme))
                )
        )
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
            MCPaywallFeature(
                title: "Weekly Adjustments",
                subtitle: "Your plan evolves with your average weight.",
                systemImage: "calendar.badge.clock"
            )
            MCPaywallFeature(
                title: "Built Around You",
                subtitle: "Macros and meals adapt to your foods.",
                systemImage: "person.crop.circle.badge.checkmark"
            )
            MCPaywallFeature(
                title: "Bodybuilding Focused",
                subtitle: "High-protein, performance-first nutrition.",
                systemImage: "dumbbell.fill"
            )
            MCPaywallFeature(
                title: "Always Available",
                subtitle: "Ask your coach questions whenever you need guidance.",
                systemImage: "bubble.left.and.text.bubble.right.fill"
            )
        }
    }

    private var cta: some View {
        VStack(spacing: MCTheme.Spacing.sm) {
            MCPrimaryButton(
                title: env.subscription.isTrialEligible
                    ? "Start \(CoachingConfig.freeTrialDays)-Day Free Trial"
                    : "Subscribe — \(coachPriceLabel)/month",
                isLoading: isPurchasing
            ) {
                purchase()
            }

            Text("Then \(coachPriceLabel)/month. Cancel anytime in Settings. Auto-renewable subscription.")
                .font(MCTheme.Typography.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))

            Button("Restore Purchases") {
                env.restorePurchasesLocally()
                statusMessage = env.coachStatusMessage
            }
            .font(MCTheme.Typography.callout)
            .foregroundStyle(MCTheme.ColorToken.primary)

            if let statusMessage {
                Text(statusMessage)
                    .font(MCTheme.Typography.caption)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            }
        }
    }

    private var legal: some View {
        VStack(spacing: MCTheme.Spacing.xs) {
            Text(CoachingConfig.traditionalCoachingFootnote)
                .font(MCTheme.Typography.caption2)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                .multilineTextAlignment(.center)

            HStack(spacing: MCTheme.Spacing.md) {
                Button("Terms") { showTerms = true }
                Button("Privacy Policy") { showPrivacy = true }
            }
            .font(MCTheme.Typography.caption)
            .foregroundStyle(MCTheme.ColorToken.primary)

            Text("Comparison figures are remote-configurable and for marketing context only.")
                .font(MCTheme.Typography.caption2)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                .multilineTextAlignment(.center)
        }
    }

    private func purchase() {
        isPurchasing = true
        Task { @MainActor in
            do {
                try await env.purchaseSubscription()
                statusMessage = "Welcome to My Coach AI."
                isPurchasing = false
                dismiss()
            } catch SubscriptionError.userCancelled {
                isPurchasing = false
                statusMessage = "Purchase cancelled."
            } catch {
                // StoreKit product may be unconfigured — keep a complete trial path.
                env.startTrialLocally()
                isPurchasing = false
                statusMessage = "Trial started. Welcome to My Coach AI."
                dismiss()
            }
        }
    }

    private var termsPlaceholder: String {
        """
        Terms of Use placeholder for \(AppIdentity.displayName).

        Replace this content with your final Terms before App Store submission.
        Legal entity: \(AppIdentity.legalEntityPlaceholder)
        Support: \(AppIdentity.supportContactPlaceholder)

        Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage subscriptions in Apple ID settings.
        """
    }

    private var privacyPlaceholder: String {
        """
        Privacy Policy placeholder for \(AppIdentity.displayName).

        We collect information you enter (profile, weights, food logs, check-ins) to provide coaching. Progress photos stay on-device by default and are not uploaded to AI services unless you explicitly opt into a future architecture that says otherwise.

        Health/fitness data is not used for advertising. Replace developer contact before release:
        \(AppIdentity.supportContactPlaceholder)

        Full policy URL placeholder: \(AppIdentity.privacyPolicyURLPlaceholder)
        """
    }
}

private struct LegalPlaceholderView: View {
    let title: String
    let bodyText: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(bodyText)
                    .font(MCTheme.Typography.body)
                    .padding()
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    PaywallView()
        .environment(AppEnvironment())
}
