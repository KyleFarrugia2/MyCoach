import SwiftUI

struct WorkoutHomeView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    @State private var previewTemplate: WorkoutTemplateID?
    @State private var showActiveWorkout = false
    @State private var showStagnationAlert = false
    @State private var stagnationMessage = ""


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MCTheme.Spacing.md) {
                    if env.activeWorkout != nil {
                        activeBanner
                    }
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
                if env.activeWorkout != nil {
                    ActiveWorkoutView(isPresented: $showActiveWorkout)
                }
            }
            .sheet(item: $previewTemplate) { templateID in
                NavigationStack {
                    WorkoutTemplateDetailView(templateID: templateID) {
                        env.startWorkout(templateID: templateID)
                        previewTemplate = nil
                        showActiveWorkout = true
                    }
                }
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

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
            Text("Start a Workout")
                .font(MCTheme.Typography.headline)
                .padding(.horizontal, MCTheme.Spacing.screenHorizontal)

            ForEach(WorkoutTemplateID.allCases) { templateID in
                let template = env.resolvedTemplate(id: templateID)
                let last = env.lastCompletedSession(for: templateID)
                Button {
                    previewTemplate = templateID
                } label: {
                    MCCard {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(template.name)
                                    .font(MCTheme.Typography.headline)
                                    .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                                Text("\(template.exercises.count) exercises · \(template.exercises.reduce(0) { $0 + $1.defaultSets }) sets")
                                    .font(MCTheme.Typography.subheadline)
                                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                                if let last {
                                    Text("Last: \(last.localDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(MCTheme.Typography.caption)
                                        .foregroundStyle(MCTheme.ColorToken.primary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(MCTheme.ColorToken.grey400)
                        }
                    }
                }
                .buttonStyle(SoundPlainButtonStyle())
                .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
            }
        }
    }

    private func presentStagnationIfNeeded() {
        guard !env.pendingStagnationAlerts.isEmpty else { return }
        let names = env.pendingStagnationAlerts.joined(separator: ", ")
        stagnationMessage = "No progress for 3 \(env.pendingStagnationAlerts.count == 1 ? "workout" : "workouts") in a row on: \(names). Keep form quality and consider a small load increase next time."
        showStagnationAlert = true
    }
}

// MARK: - Template detail / start

struct WorkoutTemplateDetailView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let templateID: WorkoutTemplateID
    let onStart: () -> Void

    var body: some View {
        let template = env.resolvedTemplate(id: templateID)
        let last = env.lastCompletedSession(for: templateID)

        List {
            Section {
                Text("Adjust sets below if you want. When you start, a workout timer runs and logging a set starts a 3-minute rest timer.")
                    .font(MCTheme.Typography.subheadline)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            }

            Section("Exercises") {
                ForEach(template.exercises) { exercise in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(exercise.name)
                                .font(MCTheme.Typography.headline)
                            Spacer()
                            Stepper(
                                "\(exercise.defaultSets) sets",
                                value: Binding(
                                    get: { exercise.defaultSets },
                                    set: { env.updatePlannedSets(templateID: templateID, exerciseID: exercise.id, sets: $0) }
                                ),
                                in: 1...12
                            )
                            .labelsHidden()
                            Text("\(exercise.defaultSets)")
                                .font(MCTheme.Typography.numericSmall)
                                .frame(width: 28, alignment: .trailing)
                        }
                        if let previous = last?.exercises.first(where: { $0.id == exercise.id }), !previous.sets.isEmpty {
                            Text("Last time: \(previous.sets.map(\.summaryLabel).joined(separator: " · "))")
                                .font(MCTheme.Typography.caption)
                                .foregroundStyle(MCTheme.ColorToken.primary)
                        } else {
                            Text(exercise.isBodyweightMaxReps ? "Bodyweight · max reps" : "No previous log")
                                .font(MCTheme.Typography.caption)
                                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(template.name)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Start") { onStart() }
                    .fontWeight(.semibold)
            }
        }
    }
}
