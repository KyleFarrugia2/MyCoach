import SwiftUI

struct WorkoutHomeView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    @State private var monthAnchor = Date()
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var previewTemplate: WorkoutTemplateID?
    @State private var showActiveWorkout = false
    @State private var showStagnationAlert = false
    @State private var stagnationMessage = ""

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MCTheme.Spacing.md) {
                    if env.activeWorkout != nil {
                        activeBanner
                    }
                    calendarCard
                    dayDetail
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
        .buttonStyle(.plain)
        .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
    }

    private var calendarCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
                HStack {
                    Button {
                        monthAnchor = calendar.date(byAdding: .month, value: -1, to: monthAnchor) ?? monthAnchor
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    Spacer()
                    Text(monthAnchor, format: .dateTime.month(.wide).year())
                        .font(MCTheme.Typography.headline)
                    Spacer()
                    Button {
                        monthAnchor = calendar.date(byAdding: .month, value: 1, to: monthAnchor) ?? monthAnchor
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }
                .foregroundStyle(MCTheme.ColorToken.primary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                    ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, label in
                        Text(label)
                            .font(MCTheme.Typography.caption2)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(daysInMonth, id: \.self) { day in
                        if let day {
                            let key = calendar.startOfDay(for: day)
                            let hasWorkout = !env.sessions(on: key).isEmpty
                            let selected = calendar.isDate(key, inSameDayAs: selectedDay)
                            Button {
                                selectedDay = key
                            } label: {
                                VStack(spacing: 4) {
                                    Text("\(calendar.component(.day, from: day))")
                                        .font(MCTheme.Typography.callout)
                                        .fontWeight(selected ? .bold : .regular)
                                    Circle()
                                        .fill(hasWorkout ? MCTheme.ColorToken.primary : .clear)
                                        .frame(width: 6, height: 6)
                                }
                                .foregroundStyle(
                                    selected
                                        ? MCTheme.ColorToken.primary
                                        : MCTheme.Surface.primaryText(colorScheme)
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: MCTheme.Radius.sm, style: .continuous)
                                        .fill(selected ? MCTheme.ColorToken.primary.opacity(0.12) : .clear)
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear.frame(height: 36)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
    }

    private var dayDetail: some View {
        let sessions = env.sessions(on: selectedDay)
        return VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
            Text(selectedDay, format: .dateTime.weekday(.wide).month().day())
                .font(MCTheme.Typography.headline)
                .padding(.horizontal, MCTheme.Spacing.screenHorizontal)

            if sessions.isEmpty {
                Text("No workouts logged this day.")
                    .font(MCTheme.Typography.subheadline)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
            } else {
                ForEach(sessions) { session in
                    MCCard {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(session.templateName)
                                    .font(MCTheme.Typography.headline)
                                Spacer()
                                Text(session.isCompleted ? "Done" : "Open")
                                    .font(MCTheme.Typography.caption)
                                    .foregroundStyle(MCTheme.ColorToken.success)
                            }
                            Text("\(session.completedSets) sets · \(formatDuration(session.durationSeconds))")
                                .font(MCTheme.Typography.subheadline)
                                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                            ForEach(session.exercises.filter { !$0.sets.isEmpty }) { exercise in
                                HStack {
                                    Text(exercise.name)
                                        .font(MCTheme.Typography.caption)
                                    Spacer()
                                    Text(exercise.lastSetSummary)
                                        .font(MCTheme.Typography.caption)
                                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
                }
            }
        }
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
                .buttonStyle(.plain)
                .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
            }
        }
    }

    private var daysInMonth: [Date?] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthAnchor)),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }
        // Monday-first padding
        let weekday = calendar.component(.weekday, from: monthStart)
        let mondayIndexed = (weekday + 5) % 7
        var days: [Date?] = Array(repeating: nil, count: mondayIndexed)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
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
