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
        env.isTrainingDay(on: selectedDate)
    }

    private var mealSlots: [MealSlot] {
        MealSlot.slots(isTrainingDay: isSelectedDateTraining)
    }

    private var diary: DailyFoodDiary {
        env.diary(for: selectedDate)
    }

    private var target: DailyNutritionTarget? {
        guard let targets = env.targets else { return nil }
        let training = env.isTrainingDay(on: selectedDate)
        return targets.target(isTrainingDay: training)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                    dayPicker
                    summary
                    mealsSection
                    utilities
                }
                .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
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

    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    private func shift(_ days: Int) {
        guard let next = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            selectedDate = Calendar.current.startOfDay(for: next)
        }
    }

    private var dayPicker: some View {
        let dateText = selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide))
        return VStack(alignment: .leading, spacing: 6) {
            MCWeekStrip(
                days: CoachingCalendar().datesInWeek(containing: selectedDate),
                selected: $selectedDate,
                mark: { day in
                    let d = env.diary(for: day)
                    if d.markedComplete { return .done }
                    return d.entries.isEmpty ? .blank : .partial
                },
                onPrevious: { shift(-7) },
                onNext: { shift(7) }
            )
            HStack {
                MCEyebrow(isToday ? "Today · \(dateText)" : dateText)
                Spacer(minLength: 8)
                if !isToday {
                    Button("Jump to today") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { selectedDate = env.today }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MCTheme.ColorToken.primary)
                }
            }
            .frame(minHeight: 24)
        }
    }

    private var summary: some View {
        MCBrief(tint: isSelectedDateTraining ? .training : .rest) {
            HStack {
                MCEyebrow(isSelectedDateTraining ? "Training day budget" : "Rest day budget", onInk: true)
                Spacer(minLength: 8)
                if diary.markedComplete {
                    MCBriefTag(text: "Complete", systemImage: "checkmark", positive: true)
                        .padding(.trailing, 20)
                }
            }
            if let target {
                MCFuel(
                    calories: diary.totalCalories,
                    target: Double(target.calories),
                    macros: diary.totalMacros,
                    targetMacros: target.macros,
                    flush: true
                )
            } else {
                Text("\(Int(diary.totalCalories.rounded()).formatted()) kcal eaten")
                    .font(.system(size: 17, weight: .bold))
                Text("No targets yet — finish setup to see what's left for the day.")
                    .font(.system(size: 14))
                    .foregroundStyle(MCInk.soft)
            }
        }
    }

    private func entries(for slot: MealSlot) -> [FoodLogEntry] {
        diary.entries.filter {
            $0.mealSlot == slot
                || (slot == .preWorkout && $0.mealSlot == .intraWorkout)
                || (slot == .afternoonSnack && $0.mealSlot == .custom)
        }
    }

    private var mealsSection: some View {
        let slots = mealSlots
        let logged = slots.filter { !entries(for: $0).isEmpty }.count
        return MCSection(label: "Meals") {
            MCSectionCount(text: "\(logged) of \(slots.count) logged", complete: logged == slots.count)
        } content: {
            VStack(spacing: 0) {
                ForEach(Array(slots.enumerated()), id: \.element) { index, slot in
                    let slotEntries = entries(for: slot)
                    MCRailItem(
                        number: index + 1,
                        filled: !slotEntries.isEmpty,
                        muted: slotEntries.isEmpty,
                        isLast: index == slots.count - 1
                    ) {
                        mealBody(slot, slotEntries)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func mealBody(_ slot: MealSlot, _ slotEntries: [FoodLogEntry]) -> some View {
        let name = env.preferences.mealName(for: slot)
        if slotEntries.isEmpty {
            HStack {
                Text(name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                Spacer(minLength: 8)
                MCTintButton(title: "Add food", systemImage: "plus", clear: true, label: "Add food to \(name)") {
                    addSlot = slot
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(MCTheme.Surface.border(colorScheme), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
        } else {
            let kcal = slotEntries.reduce(0) { $0 + $1.loggedCalories }
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                    Spacer(minLength: 8)
                    Text("\(Int(kcal.rounded()))")
                        .font(.system(size: 16, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(MCTheme.ColorToken.primary)
                    Text("kcal")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                }
                MCMacroChips(macros: slotEntries.reduce(.zero) { $0 + $1.loggedMacros })
                VStack(spacing: 0) {
                    ForEach(slotEntries) { entry in
                        Divider()
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.food.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                                    .lineLimit(1)
                                Text(amountLabel(for: entry))
                                    .font(MCTheme.Typography.caption2)
                                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Text("\(Int(entry.loggedCalories.rounded())) kcal")
                                .font(.system(size: 14, weight: .bold).monospacedDigit())
                                .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                            MCToolButton(systemImage: "trash", plain: true, label: "Delete \(entry.food.name)") {
                                withAnimation { env.deleteFoodEntry(entry) }
                            }
                        }
                        .padding(.vertical, 7)
                    }
                }
                MCTintButton(title: "Add food", systemImage: "plus", fullWidth: true, label: "Add food to \(name)") {
                    addSlot = slot
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .mcSurface()
        }
    }

    private var utilities: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                pairButton("Copy Yesterday", systemImage: "doc.on.doc", done: false) {
                    env.copyYesterday(to: selectedDate)
                }
                pairButton(
                    diary.markedComplete ? "Day complete" : "Mark day complete",
                    systemImage: "checkmark",
                    done: diary.markedComplete
                ) {
                    var d = diary
                    d.markedComplete.toggle()
                    withAnimation { env.upsertDiary(d) }
                }
            }
            Text("Food logging is free forever — no subscription required.")
                .font(MCTheme.Typography.caption)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                .frame(maxWidth: .infinity)
        }
        .padding(.bottom, MCTheme.Spacing.lg)
    }

    private func pairButton(_ title: String, systemImage: String, done: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 46)
                .foregroundStyle(done ? MCTheme.ColorToken.success : MCTheme.ColorToken.primary)
                .background(
                    RoundedRectangle(cornerRadius: MCTheme.Radius.md, style: .continuous)
                        .fill(done ? MCTheme.ColorToken.success.opacity(0.16) : MCTheme.Surface.secondaryFill(colorScheme))
                )
        }
        .buttonStyle(MCPressStyle())
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
