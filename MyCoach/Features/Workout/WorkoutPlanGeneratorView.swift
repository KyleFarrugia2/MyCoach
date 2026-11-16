import SwiftUI

struct WorkoutPlanGeneratorView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var step = 0
    @State private var volume: TrainingVolume
    @State private var goal: TrainingGoal
    @State private var equipment: Set<GymEquipment>
    @State private var preview: GeneratedWorkoutPlan?

    init() {
        _volume = State(initialValue: .high)
        _goal = State(initialValue: .bodybuilding)
        _equipment = State(initialValue: GymEquipment.typicalGym)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.lg) {
                progress
                switch step {
                case 0: volumeStep
                case 1: goalStep
                case 2: equipmentStep
                default: previewStep
                }
            }
            .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
            .padding(.vertical, MCTheme.Spacing.md)
        }
        .mcScreenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(step == 0 ? "Close" : "Back") {
                    if step == 0 { dismiss() } else { withAnimation { step -= 1 } }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .onAppear {
            volume = env.preferences.resolvedTrainingVolume
            goal = env.preferences.resolvedTrainingGoal
            equipment = Set(env.preferences.resolvedGymEquipment)
        }
    }

    private var title: String {
        switch step {
        case 0: "Volume"
        case 1: "Your goal"
        case 2: "Equipment"
        default: "Your plan"
        }
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? MCTheme.ColorToken.primary : MCTheme.Surface.border(colorScheme))
                    .frame(height: 4)
            }
        }
    }

    private var volumeStep: some View {
        question(
            "Do you want high volume or low volume?",
            "High volume means more sets and extra isolation. Low volume keeps sessions shorter."
        ) {
            ForEach(TrainingVolume.allCases) { option in
                choiceCard(
                    title: option.displayName,
                    subtitle: option.subtitle,
                    selected: volume == option
                ) { volume = option }
            }
        }
    }

    private var goalStep: some View {
        question(
            "What are you training for?",
            "This decides the split, how heavy the compounds are, and how much isolation you get."
        ) {
            ForEach(TrainingGoal.allCases) { option in
                choiceCard(
                    title: option.displayName,
                    subtitle: option.subtitle,
                    selected: goal == option,
                    systemImage: option.systemImage
                ) { goal = option }
            }
        }
    }

    private var equipmentStep: some View {
        question(
            "What equipment do you have?",
            "Pick everything you can use. If a plan includes a machine you don’t have, you can swap it later."
        ) {
            HStack(spacing: 8) {
                presetChip("Full gym", GymEquipment.typicalGym)
                presetChip("Free weights", [.barbell, .dumbbells])
                presetChip("Machines", [.machines, .cables])
                presetChip("Home", [.bodyweight, .dumbbells])
            }
            .padding(.bottom, 4)
            ForEach(GymEquipment.allCases) { option in
                let on = equipment.contains(option)
                choiceCard(
                    title: option.displayName,
                    subtitle: option.subtitle,
                    selected: on
                ) {
                    if on {
                        if equipment.count > 1 { equipment.remove(option) }
                    } else {
                        equipment.insert(option)
                    }
                }
            }
        }
    }

    private var previewStep: some View {
        VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
            if let preview {
                MCBrief(tint: .training) {
                    MCEyebrow("Generated plan", onInk: true)
                    Text(preview.goal.displayName)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                    Text(preview.summaryLine)
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(Color.white.opacity(0.75))
                    Text("Not happy? Regenerate and we’ll shuffle different exercises that still match your answers.")
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                ForEach(preview.days) { day in
                    MCSection(label: day.templateID.displayName) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(day.exercises) { exercise in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exercise.name)
                                            .font(MCTheme.Typography.headline)
                                        Text("\(exercise.muscle.displayName) · \(exercise.equipment.displayName) · \(exercise.defaultSets) sets")
                                            .font(MCTheme.Typography.caption)
                                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if step < 3 {
                MCPrimaryButton(title: "Continue", isEnabled: step != 2 || !equipment.isEmpty) {
                    if step == 2 { buildPreview(regenerate: false) }
                    withAnimation { step += 1 }
                }
            } else {
                MCPrimaryButton(title: "Use this plan") {
                    if let preview {
                        env.applyGeneratedPlan(preview)
                    }
                    dismiss()
                }
                MCSecondaryButton(title: "Regenerate") {
                    buildPreview(regenerate: true)
                }
            }
        }
        .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(MCTheme.Surface.grouped(colorScheme).opacity(0.96))
    }

    private func buildPreview(regenerate: Bool) {
        let blocked = env.generatedWorkoutPlan?.blockedExerciseIDs ?? []
        let seed: Int
        if regenerate {
            seed = (preview?.seed ?? env.generatedWorkoutPlan?.seed ?? 0) + 1
        } else {
            seed = 1
        }
        preview = WorkoutPlanGenerator.generate(
            seed: max(1, seed),
            volume: volume,
            goal: goal,
            equipment: Array(equipment),
            daysPerWeek: env.profile.trainingSchedule.trainingDaysPerWeek,
            blockedIDs: blocked
        )
    }

    private func question<Content: View>(_ title: String, _ subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
            Text(title)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
            Text(subtitle)
                .font(MCTheme.Typography.subheadline)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            content()
        }
    }

    private func choiceCard(title: String, subtitle: String, selected: Bool, systemImage: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(selected ? Color.white : MCTheme.ColorToken.primary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(selected ? MCTheme.ColorToken.primary : MCTheme.ColorToken.primary.opacity(0.12)))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(MCTheme.Typography.headline)
                        .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                    Text(subtitle)
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? MCTheme.ColorToken.primary : MCTheme.ColorToken.grey400)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: MCTheme.Radius.lg, style: .continuous)
                    .fill(MCTheme.Surface.elevated(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: MCTheme.Radius.lg, style: .continuous)
                    .strokeBorder(selected ? MCTheme.ColorToken.primary.opacity(0.55) : MCTheme.Surface.border(colorScheme))
            )
        }
        .buttonStyle(SoundPlainButtonStyle())
    }

    private func presetChip(_ title: String, _ set: Set<GymEquipment>) -> some View {
        Button {
            equipment = set
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(equipment == set ? MCTheme.ColorToken.primary : MCTheme.ColorToken.primary.opacity(0.12)))
                .foregroundStyle(equipment == set ? Color.white : MCTheme.ColorToken.primary)
        }
        .buttonStyle(SoundPlainButtonStyle())
    }
}

struct ExerciseReplacementView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let templateID: WorkoutTemplateID
    let exerciseID: String

    var body: some View {
        let options = env.replacementOptions(templateID: templateID, exerciseID: exerciseID)
        let current = currentExercise
        ScrollView {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                if let current {
                    Text("Pick something else for \(current.resolvedMuscle?.displayName ?? "this muscle").")
                        .font(MCTheme.Typography.subheadline)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                }
                if options.isEmpty {
                    Text("No alternatives for this muscle with your equipment. Generate a new plan or add more equipment.")
                        .font(MCTheme.Typography.subheadline)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                } else {
                    ForEach(options) { option in
                        Button {
                            env.replaceExercise(templateID: templateID, exerciseID: exerciseID, with: option.id)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(option.name)
                                        .font(MCTheme.Typography.headline)
                                        .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                                    Text("\(option.muscle.displayName) · \(option.equipment.displayName)")
                                        .font(MCTheme.Typography.caption)
                                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                                }
                                Spacer()
                                Image(systemName: "arrow.left.arrow.right")
                                    .foregroundStyle(MCTheme.ColorToken.primary)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: MCTheme.Radius.lg, style: .continuous)
                                    .fill(MCTheme.Surface.elevated(colorScheme))
                            )
                        }
                        .buttonStyle(SoundPlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
            .padding(.vertical, MCTheme.Spacing.md)
        }
        .mcScreenBackground()
        .navigationTitle("I don’t have this")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    private var currentExercise: WorkoutExerciseBlueprint? {
        env.resolvedTemplate(id: templateID).exercises.first { $0.id == exerciseID }
    }
}

struct ExerciseSwapRequest: Identifiable, Hashable {
    var templateID: WorkoutTemplateID
    var exerciseID: String
    var id: String { "\(templateID.rawValue)|\(exerciseID)" }
}
