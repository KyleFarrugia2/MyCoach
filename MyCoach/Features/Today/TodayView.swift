import SwiftUI

struct TodayView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    @State private var weightText = ""
    @State private var showSettings = false
    @State private var stepsText = ""
    @State private var showStepsEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MCTheme.Spacing.md) {
                    header
                    weightCard
                    planCard
                    stepsCard
                    mealsCard
                    coachCard
                }
                .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
                .padding(.vertical, MCTheme.Spacing.md)
            }
            .mcScreenBackground()
            .navigationTitle(AppIdentity.displayName)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(MCTheme.ColorToken.primary)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
            }
            .onAppear {
                if let entry = env.todayWeightEntry {
                    let display = UnitConversion.displayWeight(kg: entry.weightKg, unit: env.profile.weightUnit)
                    weightText = String(format: "%.1f", display)
                } else {
                    let display = UnitConversion.displayWeight(kg: env.profile.currentWeightKg, unit: env.profile.weightUnit)
                    weightText = String(format: "%.1f", display)
                }
                stepsText = "\(env.todaySteps?.steps ?? 0)"
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(env.greeting)
                .font(MCTheme.Typography.largeTitle)
                .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
            Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                .font(MCTheme.Typography.subheadline)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weightCard: some View {
        MCWeightEntryCard(
            weightText: $weightText,
            unitLabel: env.profile.weightUnit.shortLabel,
            isLogged: env.todayWeightEntry != nil,
            loggedValue: env.todayWeightEntry.map { env.displayWeight($0.weightKg) },
            onLog: {
                let normalized = weightText.replacingOccurrences(of: ",", with: ".")
                guard let value = Double(normalized) else { return }
                env.logMorningWeight(value, unit: env.profile.weightUnit)
            }
        )
    }

    @ViewBuilder
    private var planCard: some View {
        if let target = env.todayTarget {
            MCCard {
                VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                    HStack {
                        Text("Today's Plan")
                            .font(MCTheme.Typography.headline)
                            .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                        Spacer()
                        MCDayTypeBadge(isTrainingDay: target.isTrainingDay)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(target.calories)")
                            .font(MCTheme.Typography.numeric)
                            .foregroundStyle(MCTheme.ColorToken.calories)
                        Text("kcal")
                            .font(MCTheme.Typography.callout)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    }

                    HStack(spacing: MCTheme.Spacing.sm) {
                        macroPill(.protein, target.macros.protein)
                        macroPill(.carbohydrates, target.macros.carbohydrates)
                        macroPill(.fat, target.macros.fat)
                    }
                }
            }
        } else {
            MCEmptyState(
                title: "No plan yet",
                message: "Your coach hasn't built today's nutrition targets.",
                systemImage: "fork.knife",
                actionTitle: "Generate Meal Plan"
            ) {
                env.rebuildTargetsFromProfile()
                env.generateMealPlan(forWeekContaining: env.today)
            }
        }
    }

    private func macroPill(_ kind: MCTheme.MacroKind, _ grams: Double) -> some View {
        VStack(spacing: 2) {
            Text(kind.label)
                .font(MCTheme.Typography.caption2)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            Text("\(Int(grams.rounded())) g")
                .font(MCTheme.Typography.numericSmall)
                .foregroundStyle(kind.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: MCTheme.Radius.sm).fill(kind.color.opacity(0.12)))
        .accessibilityLabel("\(kind.label) \(Int(grams.rounded())) grams")
    }

    private var stepsCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
                HStack {
                    Text("Steps")
                        .font(MCTheme.Typography.headline)
                    Spacer()
                    Button("Edit") { showStepsEditor = true }
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(MCTheme.ColorToken.primary)
                }
                let current = env.todaySteps?.steps ?? 0
                let target = env.todayTarget?.stepTarget ?? env.profile.stepTarget
                Text("\(current.formatted()) / \(target.formatted())")
                    .font(MCTheme.Typography.numericMedium)
                    .foregroundStyle(MCTheme.ColorToken.primary)
                ProgressView(value: Double(min(current, target)), total: Double(max(target, 1)))
                    .tint(MCTheme.ColorToken.primary)
            }
        }
        .alert("Log Steps", isPresented: $showStepsEditor) {
            TextField("Steps", text: $stepsText)
                .keyboardType(.numberPad)
            Button("Save") {
                if let steps = Int(stepsText) {
                    env.logSteps(min(steps, CoachingConfig.maxStepTarget))
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var mealsCard: some View {
        let slots = MealSlot.slots(isTrainingDay: env.todayTarget?.isTrainingDay ?? false)
        let planMeals = env.todayMealPlan?.meals.count ?? slots.count
        let loggedSlots = Set(env.todayDiary.entries.map(\.mealSlot))
        let complete = slots.filter { slot in
            loggedSlots.contains(slot) || (slot == .preWorkout && loggedSlots.contains(.intraWorkout))
        }.count
        return MCCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Meals")
                        .font(MCTheme.Typography.headline)
                    Text("\(complete) / \(max(planMeals, CoachingConfig.requiredMealCount)) logged")
                        .font(MCTheme.Typography.subheadline)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                }
                Spacer()
                Button("Open Log") { env.selectedTab = .log }
                    .font(MCTheme.Typography.callout)
                    .foregroundStyle(MCTheme.ColorToken.primary)
            }
        }
    }

    private var coachCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
                Text("Coach")
                    .font(MCTheme.Typography.headline)
                Text(env.coachStatusMessage)
                    .font(MCTheme.Typography.body)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                Button("View Coach Analysis") { env.selectedTab = .coach }
                    .font(MCTheme.Typography.callout)
                    .foregroundStyle(MCTheme.ColorToken.primary)
            }
        }
    }
}

#Preview {
    TodayView()
        .environment(AppEnvironment())
}
