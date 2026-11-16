import SwiftUI

/// Lets the user pick a training style and swap the workout program.
struct WorkoutProgramPicker: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var pendingProgram: TrainingProgramID?

    var body: some View {
        ScrollView {
            VStack(spacing: MCTheme.Spacing.lg) {
                MCSection(label: "Custom plan") {
                    Text("Answer a few questions and we’ll build a split from your volume, goal and equipment. You can regenerate until it feels right.")
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    Text("Open Generate a new plan from the Workout tab.")
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(MCTheme.ColorToken.primary)
                }
                MCSection(label: "Training style") {
                    VStack(spacing: 10) {
                        ForEach(TrainingStyle.allCases) { style in
                            styleCard(style)
                        }
                    }
                }
                MCSection(label: "Workout program") {
                    Text("Unhappy with the split? Switch anytime. Your old sessions stay in Progress.")
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    VStack(spacing: 10) {
                        ForEach(TrainingProgramID.allCases) { program in
                            programCard(program)
                        }
                    }
                }
            }
            .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
            .padding(.vertical, MCTheme.Spacing.md)
        }
        .mcScreenBackground()
        .navigationTitle("Your training")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .confirmationDialog(
            "Switch program?",
            isPresented: Binding(
                get: { pendingProgram != nil },
                set: { if !$0 { pendingProgram = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Switch Program", role: .destructive) {
                if let pendingProgram {
                    env.setTrainingProgram(pendingProgram)
                }
                pendingProgram = nil
            }
            Button("Cancel", role: .cancel) { pendingProgram = nil }
        } message: {
            Text("A workout is in progress. Switching programs discards that session.")
        }
    }

    private func styleCard(_ style: TrainingStyle) -> some View {
        let on = env.preferences.resolvedTrainingStyle == style
        return Button {
            env.setTrainingStyle(style)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: style.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(on ? Color.white : MCTheme.ColorToken.primary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(on ? MCTheme.ColorToken.primary : MCTheme.ColorToken.primary.opacity(0.12)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(style.displayName)
                        .font(MCTheme.Typography.headline)
                        .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                    Text(style.subtitle)
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if on {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(MCTheme.ColorToken.primary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: MCTheme.Radius.lg, style: .continuous)
                    .fill(MCTheme.Surface.elevated(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: MCTheme.Radius.lg, style: .continuous)
                    .strokeBorder(on ? MCTheme.ColorToken.primary.opacity(0.55) : MCTheme.Surface.border(colorScheme))
            )
        }
        .buttonStyle(SoundPlainButtonStyle())
    }

    private func programCard(_ program: TrainingProgramID) -> some View {
        let on = env.preferences.resolvedProgramID == program
        let days = env.profile.trainingSchedule.trainingDaysPerWeek
        let fit = program.recommendedDays == days
        return Button {
            choose(program)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: program.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(on ? Color.white : MCTheme.ColorToken.primary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(on ? MCTheme.ColorToken.primary : MCTheme.ColorToken.primary.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(program.displayName)
                            .font(MCTheme.Typography.headline)
                            .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                        Text("\(program.templateIDs.count) sessions · best at \(program.recommendedDays)× / week")
                            .font(MCTheme.Typography.caption)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    }
                    Spacer(minLength: 0)
                    if on {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(MCTheme.ColorToken.primary)
                    }
                }
                Text(program.subtitle)
                    .font(MCTheme.Typography.subheadline)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    Text(program.equipment)
                        .font(MCTheme.Typography.caption2)
                        .foregroundStyle(MCTheme.ColorToken.primary)
                    if fit {
                        Text("Matches your \(days)× week")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(MCTheme.ColorToken.success.opacity(0.16)))
                            .foregroundStyle(MCTheme.ColorToken.success)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: MCTheme.Radius.lg, style: .continuous)
                    .fill(MCTheme.Surface.elevated(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: MCTheme.Radius.lg, style: .continuous)
                    .strokeBorder(on ? MCTheme.ColorToken.primary.opacity(0.55) : MCTheme.Surface.border(colorScheme))
            )
        }
        .buttonStyle(SoundPlainButtonStyle())
    }

    private func choose(_ program: TrainingProgramID) {
        if env.preferences.resolvedProgramID == program { return }
        if let active = env.activeWorkout, !program.templateIDs.contains(active.templateID) {
            pendingProgram = program
        } else {
            env.setTrainingProgram(program)
        }
    }
}
