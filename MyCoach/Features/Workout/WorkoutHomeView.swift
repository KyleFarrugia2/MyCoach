import SwiftUI

struct WorkoutHomeView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    @State private var previewTemplate: WorkoutTemplateID?
    @State private var showActiveWorkout = false
    @State private var showStagnationAlert = false
    @State private var stagnationMessage = ""
    @State private var showProgramPicker = false
    @State private var showPlanGenerator = false


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MCTheme.Spacing.md) {
                    if env.activeWorkout != nil {
                        activeBanner
                    }
                    programBanner
                    templatesSection
                }
                .padding(.vertical, MCTheme.Spacing.md)
            }
            .mcScreenBackground()
            .navigationTitle("Workout")
            .onAppear {
                if env.activeWorkout != nil {
                    showActiveWorkout = true
                }
                presentStagnationIfNeeded()
            }
            .onChange(of: env.pendingStagnationAlerts) { _, _ in
                presentStagnationIfNeeded()
            }
            .fullScreenCover(isPresented: $showActiveWorkout) {
                ActiveWorkoutView(isPresented: $showActiveWorkout)
                    .environment(env)
                    .applyingAppearance(env.profile.appearance)
            }
            .sheet(isPresented: $showProgramPicker) {
                NavigationStack {
                    WorkoutProgramPicker()
                }
                .environment(env)
                .applyingAppearance(env.profile.appearance)
            }
            .sheet(isPresented: $showPlanGenerator) {
                NavigationStack {
                    WorkoutPlanGeneratorView()
                }
                .environment(env)
                .applyingAppearance(env.profile.appearance)
            }
            .sheet(item: $previewTemplate) { templateID in
                NavigationStack {
                    WorkoutTemplateDetailView(templateID: templateID) {
                        env.startWorkout(templateID: templateID)
                        previewTemplate = nil
                        showActiveWorkout = true
                    }
                }
                .environment(env)
                .applyingAppearance(env.profile.appearance)
            }
            .alert("No Progress", isPresented: $showStagnationAlert) {
                Button("Okay") {
                    env.acknowledgeStagnationAlerts()
                }
            } message: {
                Text(stagnationMessage)
            }
        }
    }

    private var activeBanner: some View {
        Button {
            showActiveWorkout = true
        } label: {
            MCCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Workout in progress")
                            .font(MCTheme.Typography.headline)
                        Text(env.activeWorkout?.templateName ?? "")
                            .font(MCTheme.Typography.subheadline)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    }
                    Spacer()
                    Text("Resume")
                        .font(MCTheme.Typography.callout)
                        .foregroundStyle(MCTheme.ColorToken.primary)
                }
            }
        }
        .buttonStyle(SoundPlainButtonStyle())
        .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
    }

    private var programBanner: some View {
        MCBrief(tint: .training) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: env.preferences.resolvedProgramID.systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.16)))
                VStack(alignment: .leading, spacing: 4) {
                    MCEyebrow(env.generatedWorkoutPlan == nil ? "Your program" : "Generated plan", onInk: true)
                    Text(env.generatedWorkoutPlan?.goal.displayName ?? env.preferences.resolvedProgramID.displayName)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                    Text(env.generatedWorkoutPlan?.summaryLine ?? "\(env.preferences.resolvedTrainingStyle.displayName) · \(env.preferences.resolvedProgramID.templateIDs.count) sessions")
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(Color.white.opacity(0.75))
                }
                Spacer(minLength: 0)
            }
            MCInkButton(title: "Generate a new plan") { showPlanGenerator = true }
            MCInkButton(title: "Change program or style", kind: .ghost) { showProgramPicker = true }
        }
        .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
    }

    private var templatesSection: some View {
        MCSection(label: "Start a workout") {
            VStack(spacing: 10) {
                ForEach(env.preferences.resolvedProgramID.templateIDs) { templateID in
                    WorkoutLaunchCard(
                        templateID: templateID,
                        template: env.resolvedTemplate(id: templateID),
                        last: env.lastCompletedSession(for: templateID),
                        isUpNext: env.nextWorkoutTemplate == templateID
                    ) {
                        previewTemplate = templateID
                    }
                }
            }
        }
        .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
    }

    private func presentStagnationIfNeeded() {
        guard !env.pendingStagnationAlerts.isEmpty else { return }
        let names = env.pendingStagnationAlerts.joined(separator: ", ")
        stagnationMessage = "No progress for 3 \(env.pendingStagnationAlerts.count == 1 ? "workout" : "workouts") in a row on: \(names). Keep form quality and consider a small load increase next time."
        showStagnationAlert = true
    }
}

// MARK: - Launch card

private struct WorkoutLaunchCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let templateID: WorkoutTemplateID
    let template: WorkoutTemplate
    let last: WorkoutSession?
    let isUpNext: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                MCHex(systemImage: templateID.systemImage, color: templateID.accent, solid: true, size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(template.name)
                            .font(MCTheme.Typography.headline)
                            .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                        if isUpNext {
                            Text("Up next")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(MCTheme.ColorToken.primary.opacity(0.16)))
                                .foregroundStyle(MCTheme.ColorToken.primary)
                        }
                    }
                    Text(templateID.focus)
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    HStack(spacing: 8) {
                        Text("\(template.exercises.count) moves · \(template.totalSets) sets")
                            .font(MCTheme.Typography.caption2)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                        if let last {
                            Text("Last \(last.localDate.formatted(.dateTime.month(.abbreviated).day()))")
                                .font(MCTheme.Typography.caption2)
                                .foregroundStyle(MCTheme.ColorToken.primary)
                        }
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(templateID.accent.opacity(0.8))
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: MCTheme.Radius.lg, style: .continuous)
                    .fill(MCTheme.Surface.elevated(colorScheme))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 10, y: 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: MCTheme.Radius.lg, style: .continuous)
                    .strokeBorder(
                        isUpNext ? MCTheme.ColorToken.primary.opacity(0.55) : templateID.accent.opacity(0.18),
                        lineWidth: isUpNext ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(SoundPlainButtonStyle())
        .accessibilityLabel("\(template.name). \(templateID.focus). \(template.exercises.count) exercises.")
    }
}

// MARK: - Template detail / start

struct WorkoutTemplateDetailView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let templateID: WorkoutTemplateID
    let onStart: () -> Void
    @State private var swap: ExerciseSwapRequest?

    var body: some View {
        let template = env.resolvedTemplate(id: templateID)
        let last = env.lastCompletedSession(for: templateID)
        ScrollView {
            VStack(spacing: MCTheme.Spacing.md) {
                MCBrief(tint: .training) {
                    HStack(alignment: .top, spacing: 12) {
                        MCHex(systemImage: templateID.systemImage, color: templateID.accent, solid: true, size: 54)
                        VStack(alignment: .leading, spacing: 4) {
                            MCEyebrow("Ready to train", onInk: true)
                            Text(template.name)
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                            Text(templateID.focus)
                                .font(MCTheme.Typography.callout)
                                .foregroundStyle(Color.white.opacity(0.78))
                        }
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 8) {
                        MCBriefTag(text: "\(template.exercises.count) exercises", systemImage: "list.bullet")
                        MCBriefTag(text: "\(template.totalSets) sets", systemImage: "square.stack.3d.up.fill")
                        if let last {
                            MCBriefTag(text: last.localDate.formatted(.dateTime.month(.abbreviated).day()), systemImage: "clock")
                        }
                    }
                    Text("A workout timer starts with you. Logging a set starts a 3-minute rest.")
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(Color.white.opacity(0.7))
                }

                MCSection(label: "Exercises", aside: { MCSectionCount(text: "\(template.exercises.count)") }) {
                    VStack(spacing: 10) {
                        ForEach(Array(template.exercises.enumerated()), id: \.element.id) { index, exercise in
                            exerciseCard(exercise, index: index, last: last)
                        }
                    }
                }
            }
            .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
            .padding(.top, MCTheme.Spacing.sm)
            .padding(.bottom, MCTheme.Spacing.md)
        }
        .mcScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .sheet(item: $swap) { request in
            NavigationStack {
                ExerciseReplacementView(templateID: request.templateID, exerciseID: request.exerciseID)
            }
            .environment(env)
        }
        .safeAreaInset(edge: .bottom) {
            MCPrimaryButton(title: "Start \(template.name)") { onStart() }
                .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(MCTheme.Surface.grouped(colorScheme).opacity(0.96))
        }
    }

    private func exerciseCard(_ exercise: WorkoutExerciseBlueprint, index: Int, last: WorkoutSession?) -> some View {
        let previous = last?.exercises.first(where: { $0.id == exercise.id })
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                MCHex(text: "\(index + 1)", color: templateID.accent, size: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name)
                        .font(MCTheme.Typography.headline)
                        .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                    if let previous, !previous.sets.isEmpty {
                        Text("Last: \(previous.sets.map(\.summaryLabel).joined(separator: " · "))")
                            .font(MCTheme.Typography.caption)
                            .foregroundStyle(MCTheme.ColorToken.primary)
                    } else {
                        Text(exercise.isBodyweightMaxReps ? "Bodyweight · max reps" : "No previous log")
                            .font(MCTheme.Typography.caption)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    }
                    if let muscle = exercise.resolvedMuscle {
                        Text(muscle.displayName)
                            .font(MCTheme.Typography.caption2)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    }
                }
                Spacer(minLength: 4)
                WorkoutSetStepper(
                    value: Binding(
                        get: { exercise.defaultSets },
                        set: { env.updatePlannedSets(templateID: templateID, exerciseID: exercise.id, sets: $0) }
                    )
                )
            }
            Button {
                swap = ExerciseSwapRequest(templateID: templateID, exerciseID: exercise.id)
            } label: {
                Text("I don’t have this")
                    .font(MCTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(MCTheme.ColorToken.primary)
            }
            .buttonStyle(SoundPlainButtonStyle())
        }
        .padding(12)
        .mcSurface(radius: MCTheme.Radius.md)
    }
}

private struct WorkoutSetStepper: View {
    @Binding var value: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            Button {
                value = max(1, value - 1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 32, height: 32)
            }
            .disabled(value <= 1)

            VStack(spacing: 0) {
                Text("\(value)")
                    .font(MCTheme.Typography.numericSmall)
                Text("sets")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            }
            .frame(width: 36)

            Button {
                value = min(12, value + 1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 32, height: 32)
            }
            .disabled(value >= 12)
        }
        .foregroundStyle(MCTheme.ColorToken.primary)
        .background(
            Capsule(style: .continuous)
                .fill(MCTheme.ColorToken.primary.opacity(0.1))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) sets")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(12, value + 1)
            case .decrement: value = max(1, value - 1)
            @unknown default: break
            }
        }
    }
}

private extension WorkoutTemplate {
    var totalSets: Int { exercises.reduce(0) { $0 + $1.defaultSets } }
}

extension WorkoutTemplateID {
    var accent: Color {
        switch self {
        case .pushA, .fwPush, .ulUpperA, .fbA, .bwFullA: MCTheme.ColorToken.primary
        case .pullA, .fwPull, .ulUpperB, .fbB, .bwFullB: Color(red: 0.22, green: 0.62, blue: 0.92)
        case .legsA, .fwLegs, .ulLowerA, .fbC, .bwFullC: MCTheme.ColorToken.warning
        case .upper, .ulLowerB: MCTheme.ColorToken.fat
        case .legsB: MCTheme.ColorToken.success
        }
    }
}
