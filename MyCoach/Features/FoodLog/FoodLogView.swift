import SwiftUI

struct FoodLogView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var addSlot: MealSlot?
    @State private var showQuickAdd = false
    @State private var showCustomFood = false
    @State private var quickMealSlot: MealSlot = .breakfast
    @State private var quickCalories = ""
    @State private var quickProtein = ""
    @State private var quickCarbs = ""
    @State private var quickFat = ""

    private var isSelectedDateTraining: Bool {
        env.profile.trainingSchedule.isTrainingDay(env.weekday(for: selectedDate))
    }

    private var mealSlots: [MealSlot] {
        MealSlot.slots(isTrainingDay: isSelectedDateTraining)
    }

    private var diary: DailyFoodDiary {
        env.diary(for: selectedDate)
    }

    private var target: DailyNutritionTarget? {
        guard let targets = env.targets else { return nil }
        let training = env.profile.trainingSchedule.isTrainingDay(env.weekday(for: selectedDate))
        return targets.target(isTrainingDay: training)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MCTheme.Spacing.md) {
                    dateSwitcher
                    summary
                    ForEach(mealSlots, id: \.self) { slot in
                        mealSection(slot)
                    }
                    utilities
                }
                .padding(.vertical, MCTheme.Spacing.md)
            }
            .mcScreenBackground()
            .navigationTitle("Food Log")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Add Food", systemImage: "plus") {
                            addSlot = .breakfast
                        }
                        Button("Quick Add", systemImage: "bolt.fill") {
                            showQuickAdd = true
                        }
                        Button("Create Food", systemImage: "square.and.pencil") {
                            showCustomFood = true
                        }
                        Button("Copy Yesterday", systemImage: "doc.on.doc") {
                            env.copyYesterday(to: selectedDate)
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(MCTheme.ColorToken.primary)
                    }
                }
            }
            .sheet(item: $addSlot) { slot in
                FoodSearchView(mealSlot: slot, date: selectedDate)
            }
            .sheet(isPresented: $showCustomFood) {
                CustomFoodEditorView { food in
                    env.saveCustomFood(food)
                }
            }
            .sheet(isPresented: $showQuickAdd) {
                NavigationStack {
                    Form {
                        Section("Calories & Macros") {
                            TextField("Calories", text: $quickCalories).keyboardType(.decimalPad)
                            TextField("Protein (g)", text: $quickProtein).keyboardType(.decimalPad)
                            TextField("Carbs (g)", text: $quickCarbs).keyboardType(.decimalPad)
                            TextField("Fat (g)", text: $quickFat).keyboardType(.decimalPad)
                        }
                        Section("Meal") {
                            Picker("Meal", selection: $quickMealSlot) {
                                ForEach(mealSlots, id: \.self) { slot in
                                    Text(slot.displayName).tag(slot)
                                }
                            }
                        }
                    }
                    .navigationTitle("Quick Add")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showQuickAdd = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                let cal = Double(quickCalories) ?? 0
                                let p = Double(quickProtein) ?? 0
                                let c = Double(quickCarbs) ?? 0
                                let f = Double(quickFat) ?? 0
                                env.quickAddCalories(
                                    calories: cal,
                                    protein: p,
                                    carbs: c,
                                    fat: f,
                                    mealSlot: quickMealSlot,
                                    on: selectedDate
                                )
                                showQuickAdd = false
                                quickCalories = ""; quickProtein = ""; quickCarbs = ""; quickFat = ""
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private var dateSwitcher: some View {
        HStack {
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(selectedDate, format: .dateTime.weekday(.wide).month().day())
                .font(MCTheme.Typography.headline)
            Spacer()
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .foregroundStyle(MCTheme.ColorToken.primary)
        .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
    }

    @ViewBuilder
    private var summary: some View {
        let consumed = diary.totalCalories
        let macros = diary.totalMacros
        let calorieTarget = Double(target?.calories ?? 0)
        let proteinTarget = target?.macros.protein ?? 0
        let carbTarget = target?.macros.carbohydrates ?? 0
        let fatTarget = target?.macros.fat ?? 0

        MCCard {
            VStack(spacing: MCTheme.Spacing.md) {
                HStack {
                    MCCalorieRing(consumed: consumed, target: max(calorieTarget, 1), size: 120)
                    VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
                        Text("Remaining")
                            .font(MCTheme.Typography.caption)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                        Text("\(Int((calorieTarget - consumed).rounded())) kcal")
                            .font(MCTheme.Typography.numericMedium)
                            .foregroundStyle(MCTheme.ColorToken.primary)
                        Text("Free forever — no subscription required.")
                            .font(MCTheme.Typography.caption2)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    }
                    Spacer(minLength: 0)
                }
                MCMacroBar(kind: .protein, current: macros.protein, target: max(proteinTarget, 1))
                MCMacroBar(kind: .carbohydrates, current: macros.carbohydrates, target: max(carbTarget, 1))
                MCMacroBar(kind: .fat, current: macros.fat, target: max(fatTarget, 1))
            }
        }
        .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
    }

    private func mealSection(_ slot: MealSlot) -> some View {
        let entries = diary.entries.filter {
            $0.mealSlot == slot
                || (slot == .preWorkout && $0.mealSlot == .intraWorkout)
                || (slot == .afternoonSnack && $0.mealSlot == .custom)
        }
        let name = env.preferences.mealName(for: slot)
        return VStack(alignment: .leading, spacing: 0) {
            MCSectionHeader(title: name, actionTitle: "Add Food +") {
                addSlot = slot
            }
            if entries.isEmpty {
                Text("Nothing logged yet.")
                    .font(MCTheme.Typography.subheadline)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
                    .padding(.bottom, MCTheme.Spacing.sm)
            } else {
                MCCard {
                    ForEach(entries) { entry in
                        HStack {
                            MCFoodRow(
                                food: entry.food,
                                amountLabel: amountLabel(for: entry),
                                calories: entry.loggedCalories,
                                macros: entry.loggedMacros
                            )
                            Button {
                                env.deleteFoodEntry(entry)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(MCTheme.ColorToken.danger)
                            }
                            .accessibilityLabel("Delete \(entry.food.name)")
                        }
                        if entry.id != entries.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
            }
        }
    }

    private var utilities: some View {
        VStack(spacing: MCTheme.Spacing.sm) {
            MCSecondaryButton(title: "Copy Yesterday") {
                env.copyYesterday(to: selectedDate)
            }
            Button {
                var d = diary
                d.markedComplete.toggle()
                env.upsertDiary(d)
            } label: {
                Text(diary.markedComplete ? "Day marked complete" : "Mark day complete")
                    .font(MCTheme.Typography.callout)
                    .foregroundStyle(MCTheme.ColorToken.primary)
            }
        }
        .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
        .padding(.bottom, MCTheme.Spacing.lg)
    }

    private func amountLabel(for entry: FoodLogEntry) -> String {
        if entry.amountIsServings {
            return "\(entry.amount.formatted(.number.precision(.fractionLength(0...2)))) × \(entry.food.servingDescription)"
        }
        return "\(entry.amount.formatted(.number.precision(.fractionLength(0...1)))) g \(entry.food.measurementState.displayName.lowercased())"
    }
}

#Preview {
    FoodLogView()
        .environment(AppEnvironment())
}
