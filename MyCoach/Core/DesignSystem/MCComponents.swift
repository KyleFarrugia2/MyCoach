import SwiftUI

// MARK: - Buttons

struct MCPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(MCTheme.Typography.headline)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, MCTheme.Spacing.md)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: MCTheme.Radius.md, style: .continuous)
                    .fill(isEnabled && !isLoading ? MCTheme.ColorToken.primary : MCTheme.ColorToken.grey400)
            )
        }
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(title)
    }
}

struct MCSecondaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MCTheme.Typography.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, MCTheme.Spacing.md)
                .foregroundStyle(MCTheme.ColorToken.primary)
                .background(
                    RoundedRectangle(cornerRadius: MCTheme.Radius.md, style: .continuous)
                        .stroke(MCTheme.ColorToken.primary.opacity(isEnabled ? 1 : 0.4), lineWidth: 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: MCTheme.Radius.md, style: .continuous)
                                .fill(MCTheme.Surface.elevated(colorScheme))
                        )
                )
        }
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }
}

// MARK: - Card container

struct MCCard<Content: View>: View {
    var padding: CGFloat = MCTheme.Spacing.md
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .mcCardStyle()
    }
}

// MARK: - Macro bar

struct MCMacroBar: View {
    let kind: MCTheme.MacroKind
    let current: Double
    let target: Double
    var showRemaining: Bool = true

    @Environment(\.colorScheme) private var colorScheme

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(max(current / target, 0), 1.25)
    }

    private var displayCurrent: String {
        kind == .calories
            ? "\(Int(current.rounded()))"
            : "\(Int(current.rounded()))"
    }

    private var displayTarget: String {
        kind == .calories
            ? "\(Int(target.rounded())) \(kind.unit)"
            : "\(Int(target.rounded())) \(kind.unit)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MCTheme.Spacing.xs) {
            HStack {
                Label {
                    Text(kind.label)
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                } icon: {
                    Circle()
                        .fill(kind.color)
                        .frame(width: 8, height: 8)
                }
                .labelStyle(.titleAndIcon)
                Spacer()
                Text("\(displayCurrent) / \(displayTarget)")
                    .font(MCTheme.Typography.numericSmall)
                    .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                    .accessibilityLabel("\(kind.label) \(displayCurrent) of \(displayTarget)")
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(MCTheme.Surface.secondaryFill(colorScheme))
                    Capsule()
                        .fill(kind.color)
                        .frame(width: max(6, geo.size.width * min(progress, 1)))
                }
            }
            .frame(height: 8)

            if showRemaining {
                let remaining = target - current
                Text(remaining >= 0
                     ? "\(Int(remaining.rounded())) \(kind.unit) remaining"
                     : "\(Int((-remaining).rounded())) \(kind.unit) over")
                    .font(MCTheme.Typography.caption2)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Calorie ring

struct MCCalorieRing: View {
    let consumed: Double
    let target: Double
    var lineWidth: CGFloat = 14
    var size: CGFloat = 140

    @Environment(\.colorScheme) private var colorScheme

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(consumed / target, 1)
    }

    private var remaining: Int {
        Int((target - consumed).rounded())
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(MCTheme.Surface.secondaryFill(colorScheme), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    MCTheme.ColorToken.calories,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(MCTheme.Motion.ring, value: progress)

            VStack(spacing: 2) {
                Text("\(Int(consumed.rounded()))")
                    .font(MCTheme.Typography.numeric)
                    .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                Text("of \(Int(target.rounded())) kcal")
                    .font(MCTheme.Typography.caption)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                Text(remaining >= 0 ? "\(remaining) left" : "\(-remaining) over")
                    .font(MCTheme.Typography.caption2)
                    .foregroundStyle(MCTheme.ColorToken.primary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calories \(Int(consumed.rounded())) of \(Int(target.rounded()))")
    }
}

// MARK: - Stat card

struct MCStatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var accent: Color = MCTheme.ColorToken.primary

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.xs) {
                Text(title)
                    .font(MCTheme.Typography.caption)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                Text(value)
                    .font(MCTheme.Typography.numericMedium)
                    .foregroundStyle(accent)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(MCTheme.Typography.caption2)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Weight entry

struct MCWeightEntryCard: View {
    @Binding var weightText: String
    let unitLabel: String
    var isLogged: Bool
    var loggedValue: String?
    let onLog: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focused: Bool

    var body: some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                HStack {
                    Text("Morning Weight")
                        .font(MCTheme.Typography.headline)
                        .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                    Spacer()
                    if isLogged {
                        Label("Logged", systemImage: "checkmark.circle.fill")
                            .font(MCTheme.Typography.caption)
                            .foregroundStyle(MCTheme.ColorToken.success)
                    }
                }

                if isLogged, let loggedValue {
                    Text(loggedValue)
                        .font(MCTheme.Typography.numeric)
                        .foregroundStyle(MCTheme.ColorToken.primary)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: MCTheme.Spacing.xs) {
                        TextField("0.0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .font(MCTheme.Typography.numeric)
                            .focused($focused)
                            .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                        Text(unitLabel)
                            .font(MCTheme.Typography.title2)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    }
                }

                Text("For the most consistent readings, weigh yourself under similar morning conditions.")
                    .font(MCTheme.Typography.caption)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))

                MCPrimaryButton(
                    title: isLogged ? "Update Weight" : "Log Weight",
                    isEnabled: isLogged || Double(weightText.replacingOccurrences(of: ",", with: ".")) != nil
                ) {
                    focused = false
                    onLog()
                }
            }
        }
    }
}

// MARK: - Coach message

struct MCCoachMessage: View {
    let text: String
    var role: CoachChatMessage.Role = .coach
    var structured: CoachAIStructuredResponse? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var isUser: Bool { role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: MCTheme.Spacing.sm) {
            if isUser { Spacer(minLength: 40) }
            if !isUser {
                ZStack {
                    Circle()
                        .fill(MCTheme.ColorToken.primary.opacity(0.15))
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MCTheme.ColorToken.primary)
                }
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: MCTheme.Spacing.xs) {
                Text(text)
                    .font(MCTheme.Typography.body)
                    .foregroundStyle(isUser ? .white : MCTheme.Surface.primaryText(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                if let structured {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(structured.recommendation.capitalized)
                            .font(MCTheme.Typography.caption)
                            .foregroundStyle(MCTheme.ColorToken.primary)
                        ForEach(structured.reasoning, id: \.self) { reason in
                            Text("• \(reason)")
                                .font(MCTheme.Typography.caption2)
                                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(MCTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: MCTheme.Radius.md, style: .continuous)
                    .fill(isUser ? MCTheme.ColorToken.primary : MCTheme.Surface.secondaryFill(colorScheme))
            )

            if !isUser { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isUser ? "You: \(text)" : "Coach: \(text)")
    }
}

// MARK: - Meal card

struct MCMealCard: View {
    let meal: Meal
    var onSwap: ((MealItem) -> Void)? = nil
    var onToggleLock: ((MealItem) -> Void)? = nil
    var onLogMeal: (() -> Void)? = nil
    var onSwapMeal: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.name)
                            .font(MCTheme.Typography.headline)
                            .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                        if let time = meal.timeLabel {
                            Text(time)
                                .font(MCTheme.Typography.caption)
                                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(meal.totalCalories.rounded())) kcal")
                            .font(MCTheme.Typography.numericSmall)
                            .foregroundStyle(MCTheme.ColorToken.calories)
                        Text(macroSummary)
                            .font(MCTheme.Typography.caption2)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    }
                }

                ForEach(meal.items) { item in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.quantityLabel)
                                .font(MCTheme.Typography.callout)
                                .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                            Text("\(Int(item.calories.rounded())) kcal · P \(Int(item.macros.protein.rounded())) · C \(Int(item.macros.carbohydrates.rounded())) · F \(Int(item.macros.fat.rounded()))")
                                .font(MCTheme.Typography.caption2)
                                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                        }
                        Spacer()
                        if let onToggleLock, MealPlanner.spec(for: item.food).role != .supplement {
                            Button {
                                onToggleLock(item)
                            } label: {
                                Image(systemName: item.isLocked ? "lock.fill" : "lock.open")
                                    .foregroundStyle(item.isLocked ? MCTheme.ColorToken.primary : MCTheme.ColorToken.grey400)
                            }
                            .accessibilityLabel(item.isLocked ? "Unlock \(item.food.name)" : "Lock \(item.food.name)")
                        }
                        if let onSwap, MealPlanner.spec(for: item.food).role != .supplement {
                            Button("Swap") { onSwap(item) }
                                .font(MCTheme.Typography.caption)
                                .foregroundStyle(MCTheme.ColorToken.primary)
                        }
                    }
                    .padding(.vertical, 2)
                }

                HStack {
                    if let onLogMeal {
                        Button("Log Planned Meal", action: onLogMeal)
                            .font(MCTheme.Typography.callout)
                            .foregroundStyle(MCTheme.ColorToken.primary)
                    }
                    Spacer()
                    if let onSwapMeal {
                        Button(action: onSwapMeal) {
                            Label("Swap meal", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .font(MCTheme.Typography.callout)
                        .foregroundStyle(MCTheme.ColorToken.primary)
                    }
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var macroSummary: String {
        let m = meal.totalMacros.roundedForDisplay()
        return "P \(Int(m.protein))  C \(Int(m.carbohydrates))  F \(Int(m.fat))"
    }
}

// MARK: - Food row

struct MCFoodRow: View {
    let food: FoodItem
    var amountLabel: String? = nil
    var calories: Double? = nil
    var macros: MacroGrams? = nil
    var showsChevron: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: MCTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .font(MCTheme.Typography.callout)
                    .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                    .lineLimit(1)
                Text(subtitle)
                    .font(MCTheme.Typography.caption2)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let calories {
                    Text("\(Int(calories.rounded())) kcal")
                        .font(MCTheme.Typography.numericSmall)
                        .foregroundStyle(MCTheme.ColorToken.calories)
                } else if let c = food.calories {
                    Text("\(Int(c.rounded())) kcal")
                        .font(MCTheme.Typography.numericSmall)
                        .foregroundStyle(MCTheme.ColorToken.calories)
                }
                if let macros {
                    Text("P \(Int(macros.protein.rounded())) · C \(Int(macros.carbohydrates.rounded())) · F \(Int(macros.fat.rounded()))")
                        .font(MCTheme.Typography.caption2)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                }
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MCTheme.ColorToken.grey400)
            }
        }
        .padding(.vertical, MCTheme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts: [String] = [food.displaySubtitle]
        if let amountLabel { parts.insert(amountLabel, at: 0) }
        parts.append(food.measurementLabel)
        return parts.joined(separator: " · ")
    }
}

// MARK: - Progress header

struct MCProgressHeader: View {
    let title: String
    let progress: Double
    var stepLabel: String? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
            HStack {
                Text(title)
                    .font(MCTheme.Typography.title2)
                    .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                Spacer()
                if let stepLabel {
                    Text(stepLabel)
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(MCTheme.Surface.secondaryFill(colorScheme))
                    Capsule()
                        .fill(MCTheme.ColorToken.primary)
                        .frame(width: max(8, geo.size.width * min(max(progress, 0), 1)))
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(Int((progress * 100).rounded())) percent complete")
    }
}

// MARK: - Empty state

struct MCEmptyState: View {
    let title: String
    let message: String
    var systemImage: String = "tray"
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: MCTheme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(MCTheme.ColorToken.primary)
                .accessibilityHidden(true)
            Text(title)
                .font(MCTheme.Typography.title2)
                .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                .multilineTextAlignment(.center)
            Text(message)
                .font(MCTheme.Typography.body)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                MCPrimaryButton(title: actionTitle, action: action)
                    .frame(maxWidth: 280)
            }
        }
        .padding(MCTheme.Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Paywall feature

struct MCPaywallFeature: View {
    let title: String
    let subtitle: String
    var systemImage: String = "checkmark.circle.fill"

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: MCTheme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(MCTheme.ColorToken.primary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MCTheme.Typography.headline)
                    .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                Text(subtitle)
                    .font(MCTheme.Typography.subheadline)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Section header

struct MCSectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            Text(title)
                .font(MCTheme.Typography.headline)
                .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(MCTheme.Typography.callout)
                    .foregroundStyle(MCTheme.ColorToken.primary)
            }
        }
        .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
        .padding(.top, MCTheme.Spacing.md)
        .padding(.bottom, MCTheme.Spacing.xs)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Selection option row

struct MCSelectableRow: View {
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: MCTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(MCTheme.Typography.headline)
                        .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                    if let subtitle {
                        Text(subtitle)
                            .font(MCTheme.Typography.subheadline)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? MCTheme.ColorToken.primary : MCTheme.ColorToken.grey400)
                    .font(.title3)
            }
            .padding(MCTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: MCTheme.Radius.md, style: .continuous)
                    .stroke(
                        isSelected ? MCTheme.ColorToken.primary : MCTheme.Surface.border(colorScheme),
                        lineWidth: isSelected ? 2 : 1
                    )
                    .background(
                        RoundedRectangle(cornerRadius: MCTheme.Radius.md, style: .continuous)
                            .fill(MCTheme.Surface.elevated(colorScheme))
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Training / Rest badge

struct MCDayTypeBadge: View {
    let isTrainingDay: Bool

    var body: some View {
        Text(isTrainingDay ? "Training Day" : "Rest Day")
            .font(MCTheme.Typography.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(isTrainingDay ? MCTheme.ColorToken.primary : MCTheme.ColorToken.grey600)
            .background(
                Capsule().fill(
                    isTrainingDay
                        ? MCTheme.ColorToken.primary.opacity(0.12)
                        : MCTheme.ColorToken.grey200.opacity(0.7)
                )
            )
            .accessibilityLabel(isTrainingDay ? "Training day" : "Rest day")
    }
}
