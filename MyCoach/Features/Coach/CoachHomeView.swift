import SwiftUI

struct CoachHomeView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    @State private var showChat = false
    @State private var showCheckIn = false
    @State private var showPaywall = false

    private let prompts = [
        "How is my progress?",
        "Should we change food?",
        "Can I have a refeed?",
        "Why did my calories change?",
        "What should I eat before training?",
        "I'm eating out tonight.",
        "I missed my meal plan today.",
        "My weight jumped overnight.",
        "I'm feeling flat.",
        "I'm very hungry."
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MCTheme.Spacing.md) {
                    statusCard
                    AdaptiveModelCard(showPaywall: $showPaywall)
                    promptsSection
                    checkInCTA
                    recentMessages
                }
                .padding(.vertical, MCTheme.Spacing.md)
            }
            .mcScreenBackground()
            .navigationTitle("My Coach")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chat") {
                        if env.hasCoachAccess {
                            showChat = true
                        } else {
                            showPaywall = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showChat) {
                NavigationStack { CoachChatView() }
            }
            .sheet(isPresented: $showCheckIn) {
                WeeklyCheckInFlowView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private var statusCard: some View {
        MCCard {
            HStack(alignment: .top, spacing: MCTheme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [MCTheme.ColorToken.primary, MCTheme.ColorToken.navy],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(statusTitle)
                        .font(MCTheme.Typography.headline)
                        .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                    Text(env.coachStatusMessage)
                        .font(MCTheme.Typography.body)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    if !env.hasCoachAccess {
                        Button("Start 14-Day Free Trial") { showPaywall = true }
                            .font(MCTheme.Typography.callout)
                            .foregroundStyle(MCTheme.ColorToken.primary)
                    }
                }
            }
        }
        .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
    }

    private var statusTitle: String {
        if !env.hasCoachAccess { return "Coach AI Locked" }
        if env.currentWeek.completeness == .insufficientForAdjustment || env.currentWeek.completeness == .empty {
            return "Building Your Baseline"
        }
        return "Plan On Track"
    }

    private var promptsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            MCSectionHeader(title: "Suggested Prompts")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MCTheme.Spacing.sm) {
                    ForEach(prompts, id: \.self) { prompt in
                        Button(prompt) {
                            if env.hasCoachAccess {
                                env.sendCoachMessage(prompt)
                                showChat = true
                            } else {
                                showPaywall = true
                            }
                        }
                        .font(MCTheme.Typography.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(MCTheme.Surface.elevated(colorScheme))
                                .shadow(color: MCTheme.ColorToken.navy.opacity(0.06), radius: 6, y: 2)
                        )
                        .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                    }
                }
                .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
            }
        }
    }

    private var checkInCTA: some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
                Text("Weekly Check-In")
                    .font(MCTheme.Typography.headline)
                Text("Review photos, appearance, adherence and performance. Your coach uses Monday–Sunday averages — never one noisy weigh-in.")
                    .font(MCTheme.Typography.subheadline)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                MCPrimaryButton(title: "Start Weekly Check-In") {
                    if env.hasCoachAccess {
                        showCheckIn = true
                    } else {
                        showPaywall = true
                    }
                }
            }
        }
        .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
    }

    private var recentMessages: some View {
        VStack(alignment: .leading, spacing: 0) {
            MCSectionHeader(title: "Recent", actionTitle: "Open Chat") {
                if env.hasCoachAccess { showChat = true } else { showPaywall = true }
            }
            VStack(spacing: MCTheme.Spacing.sm) {
                ForEach(env.chatMessages.suffix(3)) { message in
                    MCCoachMessage(text: message.text, role: message.role, structured: message.structured)
                }
            }
            .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
        }
    }
}

#Preview {
    CoachHomeView()
        .environment(AppEnvironment())
}
