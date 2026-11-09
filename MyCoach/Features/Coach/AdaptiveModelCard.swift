import SwiftUI

/// "Your Metabolism Model" — what the personal adaptive model has learned and what it recommends.
struct AdaptiveModelCard: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showPaywall: Bool
    @State private var showDetails = false

    var body: some View {
        let model = env.adaptiveModel
        let rec = env.adaptiveRecommendation
        MCCard {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
                HStack {
                    Label("Your Metabolism Model", systemImage: "sparkles")
                        .font(MCTheme.Typography.headline)
                        .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                    Spacer()
                    Text(badgeText(model))
                        .font(MCTheme.Typography.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(MCTheme.ColorToken.primary.opacity(0.12)))
                        .foregroundStyle(MCTheme.ColorToken.primary)
                }

                if let model {
                    HStack(alignment: .top, spacing: MCTheme.Spacing.md) {
                        stat(
                            title: "Learned maintenance",
                            value: "\(Int(model.maintenanceKcal.rounded())) kcal",
                            detail: "± \(Int(model.maintenanceSD.rounded())) · formula \(Int(model.priorMaintenanceKcal.rounded()))"
                        )
                        if let rec {
                            stat(
                                title: "Predicted on plan",
                                value: "\(signed(rec.predictedCurrent.meanKgPerWeek)) kg/wk",
                                detail: "± \(String(format: "%.2f", rec.predictedCurrent.sdKgPerWeek)) · goal \(signed(rec.targetKgPerWeek))"
                            )
                        }
                    }

                    if !env.hasCoachAccess {
                        Text("Your model is learning from your logs. Coach AI uses it to adjust your calories automatically.")
                            .font(MCTheme.Typography.subheadline)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                        MCSecondaryButton(title: "Unlock Personal Adjustments") { showPaywall = true }
                    } else if let rec {
                        Text(rec.summary)
                            .font(MCTheme.Typography.subheadline)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                        if rec.shouldAdjust {
                            Text(autoStatus)
                                .font(MCTheme.Typography.caption)
                                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                            if !env.preferences.adaptiveAutoAdjust || isWaiting {
                                MCPrimaryButton(title: "Apply \(rec.deltaKcal > 0 ? "+" : "−")\(abs(rec.deltaKcal)) kcal/day") {
                                    env.applyAdaptiveRecommendation(auto: false)
                                }
                            }
                        }
                    }

                    Button("How it works & what it learned") { showDetails = true }
                        .font(MCTheme.Typography.callout)
                        .foregroundStyle(MCTheme.ColorToken.primary)
                } else {
                    Text("Log your morning weight and food each day. Your coach trains a personal model of how your body responds to calories.")
                        .font(MCTheme.Typography.subheadline)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                }
            }
        }
        .sheet(isPresented: $showDetails) {
            if let model {
                AdaptiveModelDetailView(model: model, adjustments: env.planAdjustments.filter { $0.source == .adaptiveModel })
            }
        }
    }

    private var isWaiting: Bool {
        guard let next = env.nextAdaptiveAdjustmentDate else { return false }
        return next > Date()
    }

    private var autoStatus: String {
        guard env.preferences.adaptiveAutoAdjust else { return "Auto-adjust is off — apply it yourself when ready." }
        if isWaiting, let next = env.nextAdaptiveAdjustmentDate {
            return "Auto-adjust is on — next change allowed \(next.formatted(.dateTime.weekday(.abbreviated).month().day())) (max one change per week)."
        }
        return "Auto-adjust is on — this will apply automatically."
    }

    private func badgeText(_ model: AdaptiveModelSnapshot?) -> String {
        guard let model else { return "No data yet" }
        switch model.confidence {
        case .low: return "Learning"
        case .medium: return "Medium confidence"
        case .high: return "High confidence"
        }
    }

    private func stat(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(MCTheme.Typography.caption)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            Text(value)
                .font(MCTheme.Typography.numericMedium)
                .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(detail)
                .font(MCTheme.Typography.caption2)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func signed(_ v: Double) -> String {
        "\(v >= 0 ? "+" : "−")\(String(format: "%.2f", abs(v)))"
    }
}

private struct AdaptiveModelDetailView: View {
    let model: AdaptiveModelSnapshot
    let adjustments: [PlanAdjustment]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("What it learned") {
                    LabeledContent(
                        "Maintenance at current habits",
                        value: "\(Int(model.maintenanceKcal.rounded())) ± \(Int(model.maintenanceSD.rounded())) kcal"
                    )
                    LabeledContent("Base maintenance (8,000 steps)", value: "\(Int(model.theta[0].rounded())) kcal")
                    LabeledContent("Each extra 1,000 steps burns", value: "\(Int(model.theta[1].rounded())) kcal")
                    LabeledContent(
                        "Expenditure per +1,000 kcal eaten",
                        value: "\(model.theta[2] >= 0 ? "+" : "−")\(Int(abs(model.theta[2]).rounded())) kcal"
                    )
                    if let trend = model.trend {
                        LabeledContent(
                            "Trend weight · rate",
                            value: String(format: "%.1f kg · %+.2f kg/wk", trend.levelKg, trend.slopeKgPerWeek)
                        )
                    }
                }
                Section("Training data") {
                    LabeledContent("Training weeks used", value: "\(model.observations)")
                    LabeledContent("Complete food-log days", value: "\(model.loggedIntakeDays)")
                    LabeledContent("Weigh-ins", value: "\(model.weighIns)")
                    if let rmse = model.rmseKcal {
                        LabeledContent("Prediction error (RMSE)", value: "\(Int(rmse.rounded())) kcal/day")
                    }
                }
                if !adjustments.isEmpty {
                    Section("Model adjustments") {
                        ForEach(adjustments.prefix(6)) { adjustment in
                            LabeledContent(
                                adjustment.date.formatted(date: .abbreviated, time: .omitted),
                                value: "\(adjustment.oldCalories) → \(adjustment.newCalories)"
                            )
                        }
                    }
                }
                Section {
                    Text("Your coach runs a Kalman filter that smooths daily weigh-ins into a true trend. A Bayesian regression then learns your own energy expenditure: what you logged eating minus the energy stored or lost as weight. It starts from the standard formula and updates every time you log, giving more weight to recent weeks so it follows metabolic adaptation. Food-log days only count when they look complete (marked done, or at least half your target). Changes are capped at \(Int(AdaptiveConfig.maxAdjustmentKcal)) kcal, made at most once a week, and never go below safety minimums.")
                        .font(MCTheme.Typography.caption)
                }
            }
            .navigationTitle("Your Metabolism Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
