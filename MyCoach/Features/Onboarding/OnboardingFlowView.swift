import SwiftUI

struct OnboardingFlowView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    @State private var step: Step = .welcome
    @State private var draft = UserProfile.draft()
    @State private var heightUnitIsMetric = true
    @State private var heightCmText = "175"
    @State private var heightFeet = 5
    @State private var heightInches = 9.0
    @State private var currentWeightText = "80.0"
    @State private var desiredWeightText = "75.0"
    @State private var customFoodDraft = ""
    @State private var showMinorBlock = false
    @State private var trainingDayCountPreset: Int? = 4
    @State private var generateFoodsForMe = false

    private let cleanFoodSuggestions = [
        "Chicken breast", "Lean beef", "Rice", "Potatoes", "Pasta", "Oats",
        "Eggs", "Egg whites", "Greek yogurt", "Banana", "Apple", "Berries",
        "Vegetables", "Bread", "Peanut butter", "Olive oil"
    ]

    enum Step: Int, CaseIterable {
        case welcome
        case name
        case dob
        case sex
        case height
        case weight
        case desiredWeight
        case goal
        case trainingDays
        case activity
        case cleanFoods
        case allergies
        case trainingTime
        case generatePlan

        var title: String {
            switch self {
            case .welcome: return AppIdentity.displayName
            case .name: return "What should your coach call you?"
            case .dob: return "When were you born?"
            case .sex: return "Biological sex"
            case .height: return "How tall are you?"
            case .weight: return "Current weight"
            case .desiredWeight: return "What weight are you working toward?"
            case .goal: return "What is your goal?"
            case .trainingDays: return "How often do you train?"
            case .activity: return "Average daily steps"
            case .cleanFoods: return "What foods do you want to work with?"
            case .allergies: return "Do you have any food allergies?"
            case .trainingTime: return "When do you usually train?"
            case .generatePlan: return "Ready to build your plan"
            }
        }

        var progress: Double {
            Double(rawValue) / Double(Step.allCases.count - 1)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if step != .welcome {
                    MCProgressHeader(
                        title: step.title,
                        progress: step.progress,
                        stepLabel: "\(step.rawValue)/\(Step.allCases.count - 1)"
                    )
                    .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
                    .padding(.top, MCTheme.Spacing.md)
                }

                ScrollView {
                    stepContent
                        .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
                        .padding(.vertical, MCTheme.Spacing.lg)
                }

                footer
                    .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
                    .padding(.bottom, MCTheme.Spacing.lg)
                    .padding(.top, MCTheme.Spacing.sm)
            }
            .mcScreenBackground()
            .navigationBarBackButtonHidden(true)
            .toolbar {
                if step != .welcome {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            goBack()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }
            }
            .alert("My Coach is for adults", isPresented: $showMinorBlock) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This app is designed for adult gym users (18+). Please confirm an adult date of birth to continue.")
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            welcomeContent
        case .name:
            VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                TextField("Your name", text: $draft.displayName)
                    .textFieldStyle(.roundedBorder)
                    .font(MCTheme.Typography.title2)
                    .textContentType(.name)
                Text("Your coach will use this throughout the app.")
                    .font(MCTheme.Typography.subheadline)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            }
        case .dob:
            VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                DatePicker(
                    "Date of birth",
                    selection: Binding(
                        get: { draft.dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -25, to: Date())! },
                        set: { draft.dateOfBirth = $0 }
                    ),
                    in: ...Calendar.current.date(byAdding: .year, value: -13, to: Date())!,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                Text("Used only for energy estimates. My Coach is intended for adult gym users.")
                    .font(MCTheme.Typography.subheadline)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            }
        case .sex:
            VStack(spacing: MCTheme.Spacing.sm) {
                Text("This helps estimate energy needs. You can choose Prefer not to say.")
                    .font(MCTheme.Typography.subheadline)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(BiologicalSex.allCases) { sex in
                    MCSelectableRow(
                        title: sex.displayName,
                        isSelected: draft.biologicalSex == sex
                    ) {
                        draft.biologicalSex = sex
                    }
                }
            }
        case .height:
            VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                Picker("Unit", selection: $heightUnitIsMetric) {
                    Text("cm").tag(true)
                    Text("ft/in").tag(false)
                }
                .pickerStyle(.segmented)

                if heightUnitIsMetric {
                    TextField("Height (cm)", text: $heightCmText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .font(MCTheme.Typography.title)
                } else {
                    HStack {
                        Stepper("Feet: \(heightFeet)", value: $heightFeet, in: 4...7)
                        Stepper(
                            "Inches: \(heightInches, specifier: "%.0f")",
                            value: $heightInches,
                            in: 0...11,
                            step: 1
                        )
                    }
                }
            }
        case .weight:
            weightFields(title: "Current weight", text: $currentWeightText)
        case .desiredWeight:
            weightFields(title: "Desired weight", text: $desiredWeightText)
        case .goal:
            VStack(spacing: MCTheme.Spacing.sm) {
                ForEach([GoalPhase.cut, GoalPhase.gain]) { goal in
                    MCSelectableRow(
                        title: goal.displayName,
                        subtitle: goal.subtitle,
                        isSelected: draft.goalPhase == goal
                    ) {
                        draft.goalPhase = goal
                    }
                }
            }
        case .trainingDays:
            trainingDaysContent
        case .activity:
            VStack(spacing: MCTheme.Spacing.sm) {
                Text("About how many steps do you take on an average day?")
                    .font(MCTheme.Typography.subheadline)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(ActivityBand.allCases) { band in
                    MCSelectableRow(
                        title: band.displayName,
                        isSelected: draft.activityBand == band
                    ) {
                        draft.activityBand = band
                        draft.stepTarget = band.initialStepTarget
                    }
                }
            }
        case .cleanFoods:
            cleanFoodsContent
        case .allergies:
            allergiesContent
        case .trainingTime:
            VStack(spacing: MCTheme.Spacing.sm) {
                ForEach(TrainingTimePreference.allCases) { time in
                    MCSelectableRow(
                        title: time.displayName,
                        isSelected: draft.trainingTime == time
                    ) {
                        draft.trainingTime = time
                    }
                }
            }
        case .generatePlan:
            VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                Text("We'll estimate starting calories and macros from your profile. Targets adapt after consistent weigh-ins — the first number is never treated as perfect.")
                    .font(MCTheme.Typography.body)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                summaryCard
            }
        }
    }

    private var welcomeContent: some View {
        VStack(spacing: MCTheme.Spacing.xl) {
            Spacer(minLength: 40)
            Image("AppLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: 112, height: 112)
                .shadow(color: MCTheme.ColorToken.navy.opacity(0.25), radius: 16, y: 8)
                .accessibilityLabel("\(AppIdentity.displayName) logo")
            VStack(spacing: MCTheme.Spacing.sm) {
                Text(AppIdentity.displayName)
                    .font(MCTheme.Typography.hero)
                    .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                Text("Your physique. Your plan. Your coach.")
                    .font(MCTheme.Typography.title2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                Text("Structured nutrition and coaching built around your progress.")
                    .font(MCTheme.Typography.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var trainingDaysContent: some View {
        VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
            Text("Select how many days, then mark your training days.")
                .font(MCTheme.Typography.subheadline)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach([2, 3, 4, 5, 6], id: \.self) { count in
                        Button("\(count) days") {
                            trainingDayCountPreset = count
                            applyTrainingPreset(count)
                        }
                        .font(MCTheme.Typography.callout)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                trainingDayCountPreset == count
                                    ? MCTheme.ColorToken.primary
                                    : MCTheme.Surface.secondaryFill(colorScheme)
                            )
                        )
                        .foregroundStyle(trainingDayCountPreset == count ? .white : MCTheme.Surface.primaryText(colorScheme))
                    }
                    Button("Custom") {
                        trainingDayCountPreset = nil
                    }
                    .font(MCTheme.Typography.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(MCTheme.Surface.secondaryFill(colorScheme)))
                }
            }

            ForEach(Weekday.allCases) { day in
                let selected = draft.trainingSchedule.trainingDays.contains(day)
                Button {
                    trainingDayCountPreset = nil
                    var days = draft.trainingSchedule.trainingDays
                    if selected { days.remove(day) } else { days.insert(day) }
                    draft.trainingSchedule.trainingDays = days
                } label: {
                    HStack {
                        Text(day.fullLabel)
                            .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                        Spacer()
                        Text(selected ? "Training" : "Rest")
                            .font(MCTheme.Typography.caption)
                            .foregroundStyle(selected ? MCTheme.ColorToken.primary : MCTheme.Surface.secondaryText(colorScheme))
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected ? MCTheme.ColorToken.primary : MCTheme.ColorToken.grey400)
                    }
                    .padding(MCTheme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: MCTheme.Radius.md, style: .continuous)
                            .fill(MCTheme.Surface.elevated(colorScheme))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cleanFoodsContent: some View {
        VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
            Text("Tell your coach what foods you actually enjoy eating.")
                .font(MCTheme.Typography.subheadline)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))

            FlowChips(
                items: cleanFoodSuggestions,
                selected: Set(draft.preferredFoods),
                onToggle: { food in
                    if draft.preferredFoods.contains(food) {
                        draft.preferredFoods.removeAll { $0 == food }
                    } else {
                        draft.preferredFoods.append(food)
                    }
                }
            )

            HStack {
                TextField("Add food", text: $customFoodDraft)
                    .textFieldStyle(.roundedBorder)
                Button("Add Food") {
                    let trimmed = customFoodDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    if !draft.preferredFoods.contains(trimmed) {
                        draft.preferredFoods.append(trimmed)
                    }
                    customFoodDraft = ""
                }
                .foregroundStyle(MCTheme.ColorToken.primary)
            }

            if !draft.preferredFoods.isEmpty {
                Text("Selected: \(draft.preferredFoods.joined(separator: ", "))")
                    .font(MCTheme.Typography.caption)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            }

            MCSecondaryButton(title: "Generate My Foods For Me") {
                generateFoodsForMe = true
                draft.preferredFoods = Array(cleanFoodSuggestions.prefix(10))
            }

            if generateFoodsForMe {
                TextField("Foods you dislike (comma separated)", text: Binding(
                    get: { draft.dislikedFoods.joined(separator: ", ") },
                    set: { draft.dislikedFoods = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var allergiesContent: some View {
        VStack(spacing: MCTheme.Spacing.sm) {
            ForEach(FoodAllergy.allCases) { allergy in
                let selected = draft.allergies.contains(allergy)
                MCSelectableRow(title: allergy.displayName, isSelected: selected) {
                    if allergy == .none {
                        draft.allergies = [.none]
                    } else {
                        var next = draft.allergies
                        next.remove(.none)
                        if selected { next.remove(allergy) } else { next.insert(allergy) }
                        if next.isEmpty { next = [.none] }
                        draft.allergies = next
                    }
                }
            }
            if draft.allergies.contains(.other) {
                TextField("Describe other allergies", text: $draft.customAllergyNotes)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var summaryCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
                summaryRow("Name", draft.displayName)
                summaryRow("Goal", draft.goalPhase.displayName)
                summaryRow("Training", "\(draft.trainingSchedule.trainingDaysPerWeek) days / week")
                summaryRow("Meals", "\(CoachingConfig.requiredMealCount) / day")
                summaryRow("Steps target", "\(draft.stepTarget)")
                summaryRow("Foods", "\(draft.preferredFoods.count) selected")
            }
        }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            Spacer()
            Text(value).fontWeight(.semibold).foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
        }
        .font(MCTheme.Typography.callout)
    }

    private func weightFields(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
            Picker("Unit", selection: $draft.weightUnit) {
                Text("kg").tag(WeightUnit.kilogram)
                Text("lb").tag(WeightUnit.pound)
            }
            .pickerStyle(.segmented)
            HStack(alignment: .firstTextBaseline) {
                TextField(title, text: text)
                    .keyboardType(.decimalPad)
                    .font(MCTheme.Typography.numeric)
                    .textFieldStyle(.roundedBorder)
                Text(draft.weightUnit.shortLabel)
                    .font(MCTheme.Typography.title2)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch step {
        case .welcome:
            VStack(spacing: MCTheme.Spacing.sm) {
                MCPrimaryButton(title: "Get Started") { advance() }
                MCSecondaryButton(title: "I Already Have an Account") {
                    // Local-first: continue into onboarding without forcing account creation.
                    advance()
                }
            }
        case .generatePlan:
            MCPrimaryButton(title: "Generate My Plan") { finish() }
        default:
            MCPrimaryButton(title: "Continue", isEnabled: canContinue) { advance() }
        }
    }

    private var canContinue: Bool {
        switch step {
        case .welcome, .generatePlan: true
        case .name: !draft.displayName.trimmingCharacters(in: .whitespaces).isEmpty
        case .dob: draft.dateOfBirth != nil
        case .sex: true
        case .height: heightUnitIsMetric ? Double(heightCmText) != nil : true
        case .weight: Double(currentWeightText.replacingOccurrences(of: ",", with: ".")) != nil
        case .desiredWeight: Double(desiredWeightText.replacingOccurrences(of: ",", with: ".")) != nil
        case .goal: true
        case .trainingDays: !draft.trainingSchedule.trainingDays.isEmpty
        case .activity: true
        case .cleanFoods: !draft.preferredFoods.isEmpty
        case .allergies: !draft.allergies.isEmpty
        case .trainingTime: true
        }
    }

    private func advance() {
        syncDraftNumbers()
        if step == .dob, draft.isMinor {
            showMinorBlock = true
            return
        }
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        withAnimation(MCTheme.Motion.standard) { step = next }
    }

    private func goBack() {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        withAnimation(MCTheme.Motion.standard) { step = prev }
    }

    private func finish() {
        syncDraftNumbers()
        draft.hasCompletedOnboarding = true
        draft.updatedAt = Date()
        env.profile = draft
        env.completeOnboarding()
    }

    private func syncDraftNumbers() {
        if heightUnitIsMetric, let cm = Double(heightCmText.replacingOccurrences(of: ",", with: ".")) {
            draft.heightCm = cm
        } else if !heightUnitIsMetric {
            draft.heightCm = UnitConversion.centimeters(feet: Double(heightFeet), inches: heightInches)
        }
        if let w = Double(currentWeightText.replacingOccurrences(of: ",", with: ".")) {
            draft.currentWeightKg = UnitConversion.kilograms(from: w, unit: draft.weightUnit)
        }
        if let d = Double(desiredWeightText.replacingOccurrences(of: ",", with: ".")) {
            draft.desiredWeightKg = UnitConversion.kilograms(from: d, unit: draft.weightUnit)
        }
        draft.stepTarget = min(draft.activityBand.initialStepTarget, CoachingConfig.maxStepTarget)
        draft.mealCount = CoachingConfig.requiredMealCount
    }

    private func applyTrainingPreset(_ count: Int) {
        let ordered = Array(Weekday.allCases)
        let defaults: [Weekday]
        switch count {
        case 2: defaults = [.monday, .thursday]
        case 3: defaults = [.monday, .wednesday, .friday]
        case 4: defaults = [.monday, .tuesday, .thursday, .friday]
        case 5: defaults = [.monday, .tuesday, .wednesday, .friday, .saturday]
        case 6: defaults = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        default: defaults = Array(ordered.prefix(count))
        }
        draft.trainingSchedule.trainingDays = Set(defaults)
    }
}

private struct FlowChips: View {
    let items: [String]
    let selected: Set<String>
    let onToggle: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        FlexibleChipWrap(items: items, selected: selected, onToggle: onToggle)
    }
}

private struct FlexibleChipWrap: View {
    let items: [String]
    let selected: Set<String>
    let onToggle: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { item in
                        Button(item) { onToggle(item) }
                            .font(MCTheme.Typography.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(
                                    selected.contains(item)
                                        ? MCTheme.ColorToken.primary
                                        : Color.secondary.opacity(0.12)
                                )
                            )
                            .foregroundStyle(selected.contains(item) ? .white : .primary)
                    }
                }
            }
        }
    }

    private var rows: [[String]] {
        var result: [[String]] = []
        var current: [String] = []
        var width = 0
        for item in items {
            let estimate = item.count + 4
            if width + estimate > 34, !current.isEmpty {
                result.append(current)
                current = [item]
                width = estimate
            } else {
                current.append(item)
                width += estimate
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}

#Preview {
    OnboardingFlowView()
        .environment(AppEnvironment())
}
