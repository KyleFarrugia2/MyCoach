import SwiftUI

struct MealPlanView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var swapItem: MealItem?
    @State private var showFoodPicker = false
    @State private var showPaywall = false

    private var weekDates: [Date] {
        CoachingCalendar().datesInWeek(containing: selectedDate)
    }

    private var plan: MealPlanDay? {
        env.mealPlanDays[Calendar.current.startOfDay(for: selectedDate)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                    header
                    daySelector
                    if let plan {
                        planContent(plan)
                    } else {
                        MCEmptyState(
                            title: "Your coach hasn't built a meal plan yet.",
                            message: "Generate a structured plan around your targets and preferred foods.",
                            systemImage: "fork.knife.circle",
                            actionTitle: env.hasCoachAccess ? "Generate Meal Plan" : "Unlock Meal Plans"
                        ) {
                            if env.hasCoachAccess {
                                generate()
                            } else {
                                showPaywall = true
                            }
                        }
                    }
                }
                .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
                .padding(.vertical, MCTheme.Spacing.md)
            }
            .mcScreenBackground()
            .navigationTitle("Meal Plan")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if env.hasCoachAccess {
                            generate()
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        if env.isGeneratingMealPlan {
                            ProgressView()
                        } else {
                            Text(plan == nil ? "Generate" : "Regenerate")
                        }
                    }
                    .disabled(env.isGeneratingMealPlan)
                }
            }
            .sheet(isPresented: $showFoodPicker) {
                if let swapItem {
                    FoodSwapPicker(item: swapItem) { food in
                        env.swapFood(itemID: swapItem.id, with: food, on: selectedDate)
                        showFoodPicker = false
                        self.swapItem = nil
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
        .onAppear {
            selectedDate = env.today
        }
    }

    private var header: some View {
        Text("Built around your targets and the foods you enjoy.")
            .font(MCTheme.Typography.subheadline)
            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var daySelector: some View {
        MCWeekStrip(
            days: weekDates,
            selected: $selectedDate,
            mark: { day in
                let planned = env.mealPlanDays[Calendar.current.startOfDay(for: day)]?.isTrainingDay
                return (planned ?? env.isTrainingDay(on: day)) ? .training : .rest
            }
        )
    }

    @ViewBuilder
    private func planContent(_ plan: MealPlanDay) -> some View {
        MCBrief(tint: plan.isTrainingDay ? .training : .rest) {
            VStack(alignment: .leading, spacing: 4) {
                MCEyebrow(plan.localDate.formatted(.dateTime.weekday(.wide).day().month(.wide)), onInk: true)
                Label(plan.isTrainingDay ? "Training Day" : "Rest Day", systemImage: plan.isTrainingDay ? "dumbbell.fill" : "sun.max.fill")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .accessibilityAddTraits(.isHeader)
            }
            MCFuel(
                calories: plan.totalCalories,
                target: Double(plan.target.calories),
                macros: plan.totalMacros,
                targetMacros: plan.target.macros,
                mode: .plan
            )
        }

        if let message = plan.solverMessage {
            Text(message)
                .font(MCTheme.Typography.caption)
                .foregroundStyle(MCTheme.ColorToken.warning)
                .fixedSize(horizontal: false, vertical: true)
        }

        MCSection(label: "\(plan.meals.count) meals") {
            MCSectionCount(text: "Weigh everything raw")
        } content: {
            VStack(spacing: 0) {
                ForEach(Array(plan.meals.enumerated()), id: \.element.id) { index, meal in
                    MCRailItem(number: index + 1, isLast: index == plan.meals.count - 1) {
                        mealCard(meal)
                    }
                }
            }
        }

        if plan.isTrainingDay {
            MCSection(label: "Around training") {
                intraCard
            }
        }

        VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
            Divider()
            HStack(alignment: .center, spacing: MCTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Can't Follow The Plan Today?")
                        .font(MCTheme.Typography.headline)
                        .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                    Text("You don't need your exact meal plan today. Aim to stay near your targets.")
                        .font(MCTheme.Typography.subheadline)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button {
                    env.selectedTab = .log
                } label: {
                    Text("Track Freely Instead")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MCTheme.ColorToken.primary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Capsule().fill(MCTheme.Surface.secondaryFill(colorScheme)))
                }
                .buttonStyle(MCPressStyle())
                .fixedSize()
            }
        }
        .padding(.bottom, MCTheme.Spacing.lg)
    }

    private func mealCard(_ meal: Meal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(meal.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                if let time = meal.timeLabel {
                    Text(time)
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                }
                Spacer(minLength: 8)
                Text("\(Int(meal.totalCalories.rounded()))")
                    .font(.system(size: 16, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(MCTheme.ColorToken.primary)
                Text("kcal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            }
            MCMacroChips(macros: meal.totalMacros)
            VStack(spacing: 0) {
                ForEach(meal.items) { item in
                    Divider()
                    itemRow(item)
                }
            }
            Divider()
            HStack {
                MCTintButton(title: "Log meal", systemImage: "checkmark") {
                    env.logPlannedMeal(meal, on: selectedDate)
                }
                Spacer(minLength: 8)
                if env.hasCoachAccess {
                    Button {
                        env.swapMeal(mealID: meal.id, on: selectedDate)
                    } label: {
                        Label("Swap meal", systemImage: "arrow.left.arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(MCTheme.ColorToken.primary)
                    }
                    .buttonStyle(MCPressStyle())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .mcSurface()
    }

    /// How much to weigh, split from what it is, so the scale number leads each row.
    private func split(_ item: MealItem) -> (quantity: String, name: String, state: String?) {
        if let grams = item.grams {
            let rounded = (grams * 10).rounded() / 10
            let state: String?
            switch item.food.measurementState {
            case .raw, .dry, .cooked: state = item.food.measurementState.displayName
            default: state = nil
            }
            return ("\(rounded.formatted(.number.precision(.fractionLength(0...1)))) g", item.food.name, state)
        }
        if let servings = item.servings {
            return ("\(servings.formatted(.number.precision(.fractionLength(0...2)))) ×", item.food.servingDescription, nil)
        }
        return ("", item.food.name, nil)
    }

    private func itemRow(_ item: MealItem) -> some View {
        let parts = split(item)
        // Supplements (e.g. intra-workout) can't be swapped or locked.
        let fixed = MealPlanner.spec(for: item.food).role == .supplement
        return HStack(alignment: .center, spacing: 10) {
            Text(parts.quantity)
                .font(.system(size: 15, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(MCTheme.ColorToken.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 54, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(parts.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                    if let state = parts.state {
                        Text(state.uppercased())
                            .font(.system(size: 9.5, weight: .heavy))
                            .tracking(0.7)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(MCTheme.ColorToken.primary.opacity(0.13)))
                            .foregroundStyle(MCTheme.ColorToken.primary)
                    }
                }
                Text("\(Int(item.calories.rounded())) kcal · P \(Int(item.macros.protein.rounded())) · C \(Int(item.macros.carbohydrates.rounded())) · F \(Int(item.macros.fat.rounded()))")
                    .font(MCTheme.Typography.caption2)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            }
            Spacer(minLength: 4)
            if !fixed {
                MCToolButton(
                    systemImage: item.isLocked ? "lock.fill" : "lock.open",
                    active: item.isLocked,
                    label: item.isLocked ? "Unlock \(item.food.name)" : "Lock \(item.food.name)"
                ) {
                    env.toggleLock(itemID: item.id, on: selectedDate)
                }
                MCToolButton(systemImage: "arrow.left.arrow.right", label: "Swap \(item.food.name)") {
                    swapItem = item
                    showFoodPicker = true
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }

    private var intraCard: some View {
        VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
            HStack {
                Text("Intra in Pre Workout Meal")
                    .font(MCTheme.Typography.headline)
                    .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { env.profile.intraWorkoutEnabled },
                    set: { env.setIntraWorkoutEnabled($0) }
                ))
                .labelsHidden()
            }
            Text("When on, dextrose and EAAs are included in Pre Workout / Intra Workout. They count toward your daily macros.")
                .font(MCTheme.Typography.caption)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            if env.profile.intraWorkoutEnabled {
                let intra = NutritionEngine().intraWorkoutTargets(
                    weightKg: env.profile.currentWeightKg,
                    goal: env.profile.goalPhase
                )
                Text("EAAs: \(Int(intra.eaaGrams)) g · Dextrose: \(Int(intra.dextroseGrams)) g · Water: \(intra.waterMillilitersRange.lowerBound)–\(intra.waterMillilitersRange.upperBound) mL")
                    .font(MCTheme.Typography.callout)
                    .foregroundStyle(MCTheme.ColorToken.primary)
                Text("Highly recommended for users prioritising gym performance — entirely optional.")
                    .font(MCTheme.Typography.caption2)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mcSurface()
    }

    private func generate() {
        if env.targets == nil { env.rebuildTargetsFromProfile() }
        env.generateMealPlan(forWeekContaining: selectedDate)
    }
}

/// Same-role, raw/dry, allergy-safe replacements; portions and day totals are re-fitted after the swap.
private struct FoodSwapPicker: View {
    @Environment(AppEnvironment.self) private var env
    let item: MealItem
    let onSelect: (FoodItem) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(MealPlanner.swapOptions(for: item, customFoods: env.customFoods, allergies: env.profile.allergies)) { food in
                        Button {
                            onSelect(food)
                        } label: {
                            MCFoodRow(food: food, showsChevron: true)
                        }
                    }
                } footer: {
                    Text("Same kind of food, weighed raw or dry. Portions and the day's totals are recalculated after the swap. Add your own foods in the Foods tab to see them here.")
                }
            }
            .navigationTitle("Swap \(item.food.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    MealPlanView()
        .environment(AppEnvironment())
}
