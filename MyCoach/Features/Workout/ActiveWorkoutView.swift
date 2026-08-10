import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool

    @State private var now = Date()
    @State private var draftWeight: [String: String] = [:]
    @State private var draftReps: [String: String] = [:]
    @State private var showFinishConfirm = false
    @State private var showDiscardConfirm = false
    @State private var showStagnationAlert = false
    @State private var stagnationMessage = ""

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Group {
                if let session = env.activeWorkout {
                    content(session)
                } else {
                    ContentUnavailableView("No active workout", systemImage: "figure.strengthtraining.traditional")
                }
            }
            .mcScreenBackground()
            .navigationTitle(env.activeWorkout?.templateName ?? "Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Finish Workout", systemImage: "checkmark.circle") {
                            showFinishConfirm = true
                        }
                        Button("Discard", systemImage: "trash", role: .destructive) {
                            showDiscardConfirm = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onReceive(tick) { value in
                now = value
            }
            .confirmationDialog("Finish workout?", isPresented: $showFinishConfirm, titleVisibility: .visible) {
                Button("Save Workout") { finish() }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Discard workout?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
                Button("Discard", role: .destructive) {
                    env.discardActiveWorkout()
                    isPresented = false
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("No Progress", isPresented: $showStagnationAlert) {
                Button("Okay") {
                    env.acknowledgeStagnationAlerts()
                    isPresented = false
                }
            } message: {
                Text(stagnationMessage)
            }
            .safeAreaInset(edge: .top) {
                timersBar
            }
        }
    }

    private func content(_ session: WorkoutSession) -> some View {
        ScrollView {
            VStack(spacing: MCTheme.Spacing.md) {
                ForEach(session.exercises) { exercise in
                    exerciseCard(exercise, templateID: session.templateID)
                }
                MCPrimaryButton(title: "Finish Workout") {
                    showFinishConfirm = true
                }
                .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
                .padding(.bottom, MCTheme.Spacing.xl)
            }
            .padding(.top, MCTheme.Spacing.sm)
        }
    }

    private var timersBar: some View {
        VStack(spacing: 8) {
            HStack {
                Label(elapsedLabel, systemImage: "timer")
                    .font(MCTheme.Typography.headline)
                Spacer()
                if let restRemaining {
                    Label(formatClock(restRemaining), systemImage: "pause.circle.fill")
                        .font(MCTheme.Typography.headline)
                        .foregroundStyle(restRemaining > 0 ? MCTheme.ColorToken.warning : MCTheme.ColorToken.success)
                } else {
                    Text("Rest ready")
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                }
            }
            if restRemaining != nil {
                Button("Skip Rest") { env.skipRestTimer() }
                    .font(MCTheme.Typography.caption)
                    .foregroundStyle(MCTheme.ColorToken.primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
        .padding(.vertical, 12)
        .background(MCTheme.Surface.elevated(colorScheme).opacity(0.98))
    }

    private func exerciseCard(_ exercise: WorkoutExerciseLog, templateID: WorkoutTemplateID) -> some View {
        let previous = env.previousPerformance(templateID: templateID, exerciseID: exercise.id)
        return MCCard {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(MCTheme.Typography.headline)
                        Text("\(exercise.completedSetCount) / \(exercise.plannedSets) sets")
                            .font(MCTheme.Typography.caption)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    }
                    Spacer()
                    Stepper(
                        "",
                        value: Binding(
                            get: { exercise.plannedSets },
                            set: { env.updatePlannedSets(templateID: templateID, exerciseID: exercise.id, sets: $0) }
                        ),
                        in: 1...12
                    )
                    .labelsHidden()
                }

                if let previous, !previous.sets.isEmpty {
                    Text("Last time: \(previous.sets.map(\.summaryLabel).joined(separator: " · "))")
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(MCTheme.ColorToken.primary)
                }

                if !exercise.sets.isEmpty {
                    ForEach(exercise.sets) { set in
                        HStack {
                            Text("Set \(set.setNumber)")
                                .font(MCTheme.Typography.callout)
                            Spacer()
                            Text(set.summaryLabel)
                                .font(MCTheme.Typography.numericSmall)
                        }
                    }
                }

                if exercise.completedSetCount < exercise.plannedSets {
                    HStack(spacing: MCTheme.Spacing.sm) {
                        if !exercise.isBodyweightMaxReps {
                            TextField(
                                "kg",
                                text: Binding(
                                    get: { draftWeight[exercise.id] ?? previousWeightHint(previous) },
                                    set: { draftWeight[exercise.id] = $0 }
                                )
                            )
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 90)
                        }
                        TextField(
                            "reps",
                            text: Binding(
                                get: { draftReps[exercise.id] ?? previousRepsHint(previous) },
                                set: { draftReps[exercise.id] = $0 }
                            )
                        )
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 80)

                        Button("Log Set") {
                            log(exercise)
                        }
                        .font(MCTheme.Typography.callout)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: MCTheme.Radius.sm).fill(MCTheme.ColorToken.primary))
                    }
                } else {
                    Text("All sets logged")
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(MCTheme.ColorToken.success)
                }
            }
        }
        .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
    }

    private var elapsedLabel: String {
        guard let started = env.activeWorkout?.startedAt else { return "0:00" }
        return formatClock(max(0, Int(now.timeIntervalSince(started))))
    }

    private var restRemaining: Int? {
        guard let ends = env.workoutRestEndsAt else { return nil }
        return max(0, Int(ends.timeIntervalSince(now)))
    }

    private func formatClock(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func previousWeightHint(_ previous: WorkoutExerciseLog?) -> String {
        guard let weight = previous?.sets.last?.weightKg, weight > 0 else { return "" }
        return String(format: "%g", weight)
    }

    private func previousRepsHint(_ previous: WorkoutExerciseLog?) -> String {
        guard let reps = previous?.sets.last?.reps, reps > 0 else { return "" }
        return "\(reps)"
    }

    private func log(_ exercise: WorkoutExerciseLog) {
        let weightText = (draftWeight[exercise.id] ?? previousWeightHint(env.previousPerformance(
            templateID: env.activeWorkout?.templateID ?? .pushA,
            exerciseID: exercise.id
        ))).replacingOccurrences(of: ",", with: ".")
        let repsText = draftReps[exercise.id] ?? previousRepsHint(env.previousPerformance(
            templateID: env.activeWorkout?.templateID ?? .pushA,
            exerciseID: exercise.id
        ))
        let weight = Double(weightText)
        let reps = Int(repsText) ?? 0
        guard reps > 0 else { return }
        env.logSet(exerciseID: exercise.id, weightKg: weight, reps: reps)
    }

    private func finish() {
        let stagnant = env.finishActiveWorkout()
        if stagnant.isEmpty {
            isPresented = false
        } else {
            let names = stagnant.joined(separator: ", ")
            stagnationMessage = "No progress for 3 workouts in a row on: \(names)."
            showStagnationAlert = true
        }
    }
}
