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
                VStack(spacing: MCTheme.Spacing.md) {
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
        VStack(alignment: .leading, spacing: 4) {
            Text("Built around your targets and the foods you enjoy.")
                .font(MCTheme.Typography.subheadline)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var daySelector: some View {
        HStack(spacing: 6) {
            ForEach(weekDates, id: \.self) { date in
                let weekday = env.weekday(for: date)
                let selected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                Button {
                    selectedDate = date
                } label: {
                    VStack(spacing: 4) {
                        Text(weekday.shortLabel)
                            .font(MCTheme.Typography.caption)
                        Circle()
                            .fill(selected ? MCTheme.ColorToken.primary : .clear)
                            .frame(width: 8, height: 8)
                    }
                    .foregroundStyle(selected ? MCTheme.ColorToken.primary : MCTheme.Surface.secondaryText(colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: MCTheme.Radius.sm, style: .continuous)
                            .fill(selected ? MCTheme.ColorToken.primary.opacity(0.12) : .clear)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(weekday.fullLabel)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
    }

    @ViewBuilder
    private func planContent(_ plan: MealPlanDay) -> some View {
        VStack(spacing: MCTheme.Spacing.md) {
            HStack {
                MCDayTypeBadge(isTrainingDay: plan.isTrainingDay)
                Spacer()
                Text(plan.localDate, format: .dateTime.weekday(.wide).month().day())
                    .font(MCTheme.Typography.caption)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            }
            .padding(.horizontal, MCTheme.Spacing.screenHorizontal)

            MCCard {
                VStack(spacing: MCTheme.Spacing.sm) {
                    HStack {
                        Text("\(plan.target.calories) kcal")
                            .font(MCTheme.Typography.numericMedium)
                            .foregroundStyle(MCTheme.ColorToken.calories)
                        Spacer()
                        Text("Plan \(Int(plan.totalCalories.rounded()))")
                            .font(MCTheme.Typography.caption)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    }
                    MCMacroBar(kind: .protein, current: plan.totalMacros.protein, target: plan.target.macros.protein)
                    MCMacroBar(kind: .carbohydrates, current: plan.totalMacros.carbohydrates, target: plan.target.macros.carbohydrates)
                    MCMacroBar(kind: .fat, current: plan.totalMacros.fat, target: plan.target.macros.fat)
                }
            }
            .padding(.horizontal, MCTheme.Spacing.screenHorizontal)

            if let message = plan.solverMessage {
                Text(message)
                    .font(MCTheme.Typography.caption)
                    .foregroundStyle(MCTheme.ColorToken.warning)
                    .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
            }

            ForEach(plan.meals) { meal in
                MCMealCard(
                    meal: meal,
                    onSwap: { item in
                        swapItem = item
                        showFoodPicker = true
                    },
                    onToggleLock: { item in
                        env.toggleLock(itemID: item.id, on: selectedDate)
                    },
                    onLogMeal: {
                        env.logPlannedMeal(meal, on: selectedDate)
                    },
                    onSwapMeal: env.hasCoachAccess ? {
                        env.swapMeal(mealID: meal.id, on: selectedDate)
                    } : nil
                )
                .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
            }

            if plan.isTrainingDay {
                intraCard
                    .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
            }

            MCCard {
                VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
                    Text("Can't Follow The Plan Today?")
                        .font(MCTheme.Typography.headline)
                    Text("You don't need your exact meal plan today. Aim to stay near your targets.")
                        .font(MCTheme.Typography.subheadline)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    MCSecondaryButton(title: "Track Freely Instead") {
                        env.selectedTab = .log
                    }
                }
            }
            .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
        }
    }

    private var intraCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
                HStack {
                    Text("Intra in Pre Workout Meal")
                        .font(MCTheme.Typography.headline)
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
        }
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
