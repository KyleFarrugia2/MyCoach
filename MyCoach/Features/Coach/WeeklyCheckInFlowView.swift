import PhotosUI
import SwiftUI
import UIKit

struct WeeklyCheckInFlowView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    enum Step: Int, CaseIterable {
        case photos, appearance, adherence, performance, hunger, energy, digestion, result
    }

    @State private var step: Step = .photos
    @State private var appearance: AppearanceFeedback = .aboutTheSame
    @State private var adherence: AdherenceBand = .seventyTo84
    @State private var performance: TrainingPerformance = .same
    @State private var hunger = 3
    @State private var energy = 3
    @State private var digestion: DigestionFeedback = .okay
    @State private var notes = ""
    @State private var decision: CoachDecision?
    @State private var frontItem: PhotosPickerItem?
    @State private var sideItem: PhotosPickerItem?
    @State private var backItem: PhotosPickerItem?
    @State private var savedPhotoSetID: UUID?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MCProgressHeader(
                    title: stepTitle,
                    progress: Double(step.rawValue) / Double(Step.allCases.count - 1),
                    stepLabel: "\(step.rawValue + 1)/\(Step.allCases.count)"
                )
                .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
                .padding(.top, MCTheme.Spacing.md)

                ScrollView {
                    stepContent
                        .padding(MCTheme.Spacing.screenHorizontal)
                        .padding(.vertical, MCTheme.Spacing.lg)
                }

                footer
                    .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
                    .padding(.bottom, MCTheme.Spacing.lg)
            }
            .mcScreenBackground()
            .navigationTitle("Weekly Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if step != .photos && step != .result {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") { goBack() }
                    }
                }
            }
        }
    }

    private var stepTitle: String {
        switch step {
        case .photos: "Progress Photos"
        case .appearance: "How do you feel you look?"
        case .adherence: "How closely did you follow your plan?"
        case .performance: "How was training performance?"
        case .hunger: "How was hunger?"
        case .energy: "How were energy levels?"
        case .digestion: "How was digestion?"
        case .result: "Coach Check-In"
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .photos:
            VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                Text("Take these fasted in the morning under similar lighting and conditions. Photos are optional and stay private on your device.")
                    .font(MCTheme.Typography.subheadline)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                photoPicker("Front", item: $frontItem)
                photoPicker("Side", item: $sideItem)
                photoPicker("Back", item: $backItem)
            }
        case .appearance:
            VStack(spacing: MCTheme.Spacing.sm) {
                ForEach(AppearanceFeedback.allCases) { option in
                    MCSelectableRow(
                        title: option.title,
                        subtitle: option.subtitle,
                        isSelected: appearance == option
                    ) { appearance = option }
                }
            }
        case .adherence:
            VStack(spacing: MCTheme.Spacing.sm) {
                ForEach(AdherenceBand.allCases) { band in
                    MCSelectableRow(title: band.displayName, isSelected: adherence == band) {
                        adherence = band
                    }
                }
            }
        case .performance:
            VStack(spacing: MCTheme.Spacing.sm) {
                ForEach(TrainingPerformance.allCases) { option in
                    MCSelectableRow(title: option.displayName, isSelected: performance == option) {
                        performance = option
                    }
                }
            }
        case .hunger:
            scalePicker(value: $hunger, low: "Not hungry", high: "Very hungry")
        case .energy:
            scalePicker(value: $energy, low: "Low energy", high: "High energy")
        case .digestion:
            VStack(spacing: MCTheme.Spacing.sm) {
                ForEach(DigestionFeedback.allCases) { option in
                    MCSelectableRow(title: option.displayName, isSelected: digestion == option) {
                        digestion = option
                    }
                }
                TextField("Optional notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
            }
        case .result:
            resultCard
        }
    }

    private func photoPicker(_ title: String, item: Binding<PhotosPickerItem?>) -> some View {
        HStack {
            Text(title)
                .font(MCTheme.Typography.headline)
            Spacer()
            PhotosPicker(selection: item, matching: .images) {
                Label(item.wrappedValue == nil ? "Add" : "Added", systemImage: "camera")
                    .font(MCTheme.Typography.callout)
                    .foregroundStyle(MCTheme.ColorToken.primary)
            }
        }
        .padding(MCTheme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: MCTheme.Radius.md).fill(MCTheme.Surface.elevated(colorScheme)))
    }

    private func scalePicker(value: Binding<Int>, low: String, high: String) -> some View {
        VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
            HStack {
                ForEach(1...5, id: \.self) { n in
                    Button {
                        value.wrappedValue = n
                    } label: {
                        Text("\(n)")
                            .font(MCTheme.Typography.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: MCTheme.Radius.sm)
                                    .fill(value.wrappedValue == n ? MCTheme.ColorToken.primary : MCTheme.Surface.secondaryFill(colorScheme))
                            )
                            .foregroundStyle(value.wrappedValue == n ? .white : MCTheme.Surface.primaryText(colorScheme))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(n)")
                }
            }
            HStack {
                Text(low).font(MCTheme.Typography.caption2)
                Spacer()
                Text(high).font(MCTheme.Typography.caption2)
            }
            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
        }
    }

    @ViewBuilder
    private var resultCard: some View {
        if let decision {
            MCCard {
                VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                    Text("Progress")
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    if let prev = env.previousWeek.averageKg, let curr = env.currentWeek.averageKg {
                        Text("Average: \(String(format: "%.1f", prev)) → \(String(format: "%.1f", curr)) kg")
                            .font(MCTheme.Typography.headline)
                        if let rate = env.weeklyRate {
                            Text(String(format: "Change: %+.1f kg", rate.absoluteChangeKg))
                                .font(MCTheme.Typography.numericSmall)
                                .foregroundStyle(MCTheme.ColorToken.primary)
                        }
                    } else {
                        Text("Not enough weekly averages yet.")
                            .font(MCTheme.Typography.headline)
                    }

                    Divider()

                    Text("Assessment")
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    Text(decision.summary)
                        .font(MCTheme.Typography.body)

                    if let training = decision.suggestedTrainingCalories ?? env.targets?.training.calories,
                       let rest = decision.suggestedRestCalories ?? env.targets?.rest.calories {
                        Text("Training: \(training) kcal · Rest: \(rest) kcal")
                            .font(MCTheme.Typography.callout)
                            .foregroundStyle(MCTheme.ColorToken.calories)
                    }
                    Text("Steps: \(decision.suggestedSteps ?? env.profile.stepTarget) daily")
                        .font(MCTheme.Typography.callout)

                    if decision.refeed != nil {
                        Text("Refeed Available — a higher-carbohydrate day may help support training performance and adherence.")
                            .font(MCTheme.Typography.subheadline)
                            .foregroundStyle(MCTheme.ColorToken.primary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch step {
        case .result:
            VStack(spacing: MCTheme.Spacing.sm) {
                if let decision, shouldOfferApply(decision) {
                    MCPrimaryButton(title: "Apply Coach Recommendation") {
                        env.applyCoachDecision(decision)
                        dismiss()
                    }
                    MCSecondaryButton(title: "Keep Current Plan") { dismiss() }
                } else {
                    MCPrimaryButton(title: "Done") { dismiss() }
                }
                Button("Ask Coach") {
                    dismiss()
                    env.selectedTab = .coach
                }
                .font(MCTheme.Typography.callout)
                .foregroundStyle(MCTheme.ColorToken.primary)
            }
        case .digestion:
            MCPrimaryButton(title: "See Coach Analysis") { submit() }
        default:
            MCPrimaryButton(title: step == .photos ? "Continue" : "Next") { advance() }
        }
    }

    private func shouldOfferApply(_ decision: CoachDecision) -> Bool {
        switch decision.action {
        case .maintain, .requireMoreData, .reviewAdherence, .reviewRecovery, .suggestRefeed:
            false
        default:
            true
        }
    }

    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) {
            withAnimation(MCTheme.Motion.standard) { step = next }
        }
    }

    private func goBack() {
        if let prev = Step(rawValue: step.rawValue - 1) {
            withAnimation(MCTheme.Motion.standard) { step = prev }
        }
    }

    private func submit() {
        if frontItem != nil || sideItem != nil || backItem != nil {
            let set = ProgressPhotoSet(
                weekStart: CoachingCalendar().weekStart(containing: env.today),
                frontLocalPath: frontItem != nil ? "local://front" : nil,
                sideLocalPath: sideItem != nil ? "local://side" : nil,
                backLocalPath: backItem != nil ? "local://back" : nil
            )
            env.savePhotoSet(set)
            savedPhotoSetID = set.id
        }

        let draft = WeeklyCheckIn(
            weekStart: CoachingCalendar().weekStart(containing: env.today),
            appearance: appearance,
            adherence: adherence,
            adherencePercent: adherence.representativePercent,
            performance: performance,
            hunger: hunger,
            energy: energy,
            digestion: digestion,
            notes: notes,
            photoSetID: savedPhotoSetID
        )
        decision = env.submitWeeklyCheckIn(draft)
        withAnimation(MCTheme.Motion.standard) { step = .result }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

#Preview {
    WeeklyCheckInFlowView()
        .environment(AppEnvironment())
}
