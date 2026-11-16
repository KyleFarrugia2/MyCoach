import SwiftUI

/// Today: the day's brief (training / rest, calories and macros), the check-in tiles (weight, sleep, steps,
/// meals), what the coach says, and a week board. Any of the last 60 days can be opened to fill in what was
/// missed. Mirrors `web/src/screens/Today.tsx`.
struct TodayView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var showSettings = false

    private let maxDaysBack = 60

    private var calendar: Calendar { Calendar.current }
    private var isToday: Bool { calendar.isDateInToday(selectedDay) }
    private var oldest: Date { calendar.date(byAdding: .day, value: -maxDaysBack, to: env.today) ?? env.today }

    /// The seven days (oldest first) of the page that contains the selected day; page 0 ends today.
    private var windowDays: [Date] {
        let back = max(calendar.dateComponents([.day], from: selectedDay, to: env.today).day ?? 0, 0)
        let end = calendar.date(byAdding: .day, value: -7 * (back / 7), to: env.today) ?? env.today
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0 - 6, to: end) }
            .map { calendar.startOfDay(for: $0) }
    }

    var body: some View {
        let days = windowDays
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                    masthead.mcAppear(0)
                    QuoteLine().mcAppear(1)
                    VStack(spacing: 6) {
                        MCWeekStrip(
                            days: days,
                            selected: $selectedDay,
                            isDisabled: { $0 < oldest },
                            mark: { env.isTrainingDay(on: $0) ? .training : .rest },
                            onPrevious: { shift(-7) },
                            onNext: { shift(7) },
                            previousDisabled: (days.first ?? oldest) <= oldest,
                            nextDisabled: days.last.map { calendar.isDateInToday($0) } ?? true
                        )
                        if !isToday { catchUpBanner }
                    }
                    .mcAppear(2)
                    PlanBrief(day: selectedDay).mcAppear(3)
                    SleepAdviceBanner(day: selectedDay)
                    CheckInSection(day: selectedDay).mcAppear(4)
                    if isToday { CoachThread().mcAppear(5) }
                    WeekBoard(days: days, selected: $selectedDay, oldest: oldest).mcAppear(6)
                }
                .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
                .padding(.vertical, MCTheme.Spacing.md)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: selectedDay)
            }
            .mcScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
            }
        }
    }

    private var masthead: some View {
        HStack(alignment: .top, spacing: MCTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                MCEyebrow(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                Text(env.greeting)
                    .font(.system(size: 29, weight: .heavy, design: .rounded))
                    .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 0)
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MCTheme.ColorToken.primary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(MCTheme.Surface.secondaryFill(colorScheme)))
            }
            .buttonStyle(MCPressStyle())
            .accessibilityLabel("Settings")
        }
    }

    private func shift(_ days: Int) {
        guard let next = calendar.date(byAdding: .day, value: days, to: selectedDay) else { return }
        let clamped = min(max(calendar.startOfDay(for: next), calendar.startOfDay(for: oldest)), env.today)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { selectedDay = clamped }
    }

    private var catchUpBanner: some View {
        HStack(spacing: MCTheme.Spacing.xs) {
            Image(systemName: "calendar")
                .foregroundStyle(MCTheme.ColorToken.primary)
            Text("Catching up on **\(TodayFormat.dayLabel(selectedDay))** — what you log here is saved to that day and used by your coach.")
                .font(.system(size: 13))
                .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { selectedDay = env.today }
            } label: {
                Text("Back to today")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MCTheme.ColorToken.primary)
                    .fixedSize()
            }
        }
        .padding(.horizontal, MCTheme.Spacing.sm)
        .padding(.vertical, MCTheme.Spacing.xs)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(MCTheme.ColorToken.primary.opacity(0.1)))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Formatting

enum TodayFormat {
    static func dayLabel(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    static func weekdayName(_ day: Date) -> String {
        day.formatted(.dateTime.weekday(.wide))
    }

    static func shortWeekday(_ day: Date) -> String {
        day.formatted(.dateTime.weekday(.abbreviated))
    }

    /// "7.5h" — for the week board.
    static func compactHours(_ hours: Double) -> String {
        "\(((hours * 10).rounded() / 10).formatted(.number.precision(.fractionLength(0...1))))h"
    }

    /// "850", "6.2k", "12k" — for the week board.
    static func compactSteps(_ steps: Int) -> String {
        if steps < 1000 { return "\(steps)" }
        if steps < 10_000 { return String(format: "%.1fk", Double(steps) / 1000) }
        return "\(Int((Double(steps) / 1000).rounded()))k"
    }
}

// MARK: - Quote of the day

private struct QuoteLine: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var quote: Quote?

    var body: some View {
        Group {
            if let quote {
                HStack(alignment: .top, spacing: 11) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [MCTheme.ColorToken.primary, MCInk.sky], startPoint: .top, endPoint: .bottom))
                        .frame(width: 3)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("“\(quote.t)”")
                            .font(.system(size: 15, weight: .medium).italic())
                            .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                        MCEyebrow(quote.a)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Quote of the day. \(quote.t) \(quote.a)")
            }
        }
        .task {
            let q = QuoteOfTheDay.quote(for: Date())
            withAnimation(.easeOut(duration: 0.8)) { quote = q }
        }
    }
}

// MARK: - The day's brief: training / rest, fuel, and what to do

private struct PlanBrief: View {
    @Environment(AppEnvironment.self) private var env
    let day: Date
    @State private var confirmRest = false

    var body: some View {
        let training = env.isTrainingDay(on: day)
        let override = env.dayOverride(on: day)
        let isToday = Calendar.current.isDateInToday(day)
        let session = env.workoutSessions.first { Calendar.current.isDate($0.localDate, inSameDayAs: day) && $0.isCompleted }
        let next = env.nextWorkoutTemplate
        let target = env.target(on: day)
        let diary = env.diary(for: day)

        MCBrief(tint: training ? .training : .rest) {
            HStack(alignment: .top, spacing: MCTheme.Spacing.xs) {
                VStack(alignment: .leading, spacing: 4) {
                    MCEyebrow(isToday ? "Today's plan" : "\(TodayFormat.dayLabel(day))'s plan", onInk: true)
                    Label(training ? "Training Day" : "Rest Day", systemImage: training ? "dumbbell.fill" : "sun.max.fill")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 6) {
                    if session != nil { MCBriefTag(text: "Done", systemImage: "checkmark", positive: true) }
                    if target?.source == .adaptiveModel { MCBriefTag(text: "Personalised") }
                }
                .padding(.trailing, 20)
            }

            Text(note(training: training, isToday: isToday, session: session, override: override, next: next))
                .font(.system(size: 14))
                .foregroundStyle(Color.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, -8)

            if let target {
                MCFuel(
                    calories: diary.totalCalories,
                    target: Double(target.calories),
                    macros: diary.totalMacros,
                    targetMacros: target.macros
                )
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Rectangle().fill(MCInk.line).frame(height: 1)
                    Text("No plan yet").font(.system(size: 17, weight: .bold))
                    Text("Your coach hasn't built today's nutrition targets.")
                        .font(.system(size: 14))
                        .foregroundStyle(MCInk.soft)
                    MCInkButton(title: "Generate Meal Plan") {
                        env.rebuildTargetsFromProfile()
                        env.generateMealPlan(forWeekContaining: env.today)
                    }
                }
            }

            if isToday, training, session == nil {
                HStack(spacing: MCTheme.Spacing.xs) {
                    MCInkButton(title: "Start \(next.displayName)") { env.startWorkout(templateID: next) }
                    MCInkButton(title: "Emergency rest day", kind: .ghost) { confirmRest = true }
                }
            }
            if isToday, override?.reason == .emergencyRest {
                MCInkButton(title: "Undo rest day", kind: .ghost) {
                    withAnimation { env.undoEmergencyRestDay(on: day) }
                }
            }
        }
        .confirmationDialog("Take an emergency rest day?", isPresented: $confirmRest, titleVisibility: .visible) {
            Button("Take Rest Day") {
                withAnimation { _ = env.takeEmergencyRestDay(on: day) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Today switches to rest-day calories and no training. Your coach moves the session to a free day later this week if there's a good slot.")
        }
    }

    private func note(
        training: Bool,
        isToday: Bool,
        session: WorkoutSession?,
        override: DayOverride?,
        next: WorkoutTemplateID
    ) -> String {
        if let session { return "\(session.templateName) completed." }
        if training, isToday {
            if let override, override.reason == .movedSession, let from = override.linkedDay {
                return "\(next.displayName) is on the plan — moved here from \(TodayFormat.weekdayName(from))."
            }
            return "\(next.displayName) is on the plan."
        }
        if training { return "A training day with training-day calories." }
        if let override, override.reason == .emergencyRest {
            if let to = override.linkedDay {
                return "Emergency rest day — session moved to \(TodayFormat.weekdayName(to)). Rest-day calories apply."
            }
            return "Emergency rest day. Rest-day calories apply."
        }
        return "Recover, hit your steps and eat to your rest-day targets."
    }
}

// MARK: - Coach bubbles

/// Speech bubble: the first one in a thread has a tucked corner that points at the avatar.
private struct CoachBubble<Content: View>: View {
    var first: Bool = true
    var tint: Color? = nil
    var accent: Color? = nil
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: first ? 6 : 18,
            bottomLeadingRadius: 18,
            bottomTrailingRadius: 18,
            topTrailingRadius: 18,
            style: .continuous
        )
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .leading) {
                MCTheme.Surface.elevated(colorScheme)
                if let tint { tint.opacity(0.15) }
                if let accent { accent.frame(width: 3) }
            }
        }
        .clipShape(shape)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.07), radius: 8, y: 4)
    }
}

// MARK: - Sleep advice

private struct SleepAdviceBanner: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    let day: Date
    @State private var dismissed = false

    var body: some View {
        if !dismissed, Calendar.current.isDateInToday(day), let sleep = env.sleep(on: day), sleep.hours <= 5, env.isTrainingDay(on: day) {
            HStack(alignment: .top, spacing: 10) {
                MCCoachAvatar(size: 36)
                CoachBubble(tint: MCTheme.ColorToken.warning) {
                    Text("**You slept \(CardioCoach.formatHours(sleep.hours)).** With 5 hours or less, your coach recommends taking today as a rest day — training on that little sleep raises injury risk and slows recovery.")
                        .font(.system(size: 14.5))
                        .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: MCTheme.Spacing.xs) {
                        Button {
                            withAnimation { _ = env.takeEmergencyRestDay(on: day) }
                        } label: {
                            Text("Make it a rest day")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 36)
                                .background(Capsule().fill(MCTheme.ColorToken.primary))
                        }

                        Button {
                            withAnimation { dismissed = true }
                        } label: {
                            Text("Train anyway")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(MCTheme.ColorToken.primary)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 36)
                                .background(Capsule().fill(MCTheme.Surface.secondaryFill(colorScheme)))
                        }
                    }
                    .buttonStyle(MCPressStyle())
                    .padding(.top, 2)
                }
            }
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
    }
}

// MARK: - Check-in: weight, sleep, steps, meals

private enum CheckInSheet: String, Identifiable {
    case weight, sleep, steps
    var id: String { rawValue }
}

private struct CheckInSection: View {
    @Environment(AppEnvironment.self) private var env
    let day: Date
    @State private var sheet: CheckInSheet?

    var body: some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(day)
        let unit = env.profile.weightUnit
        let weight = env.weightEntry(on: day)
        let sleep = env.sleep(on: day)
        let steps = env.steps(on: day)?.steps
        let stepTarget = env.target(on: day)?.stepTarget ?? env.profile.stepTarget
        let doneCount = [weight != nil, sleep != nil, steps != nil].filter { $0 }.count

        // Meals logged (today only).
        let slots = MealSlot.slots(isTrainingDay: env.isTrainingDay(on: day))
        let logged = Set(env.diary(for: day).entries.map(\.mealSlot))
        let mealsDone = slots.filter { logged.contains($0) || ($0 == .preWorkout && logged.contains(.intraWorkout)) }.count
        let planMeals = env.mealPlanDays[calendar.startOfDay(for: day)]?.meals.count ?? slots.count
        let mealsTotal = max(planMeals, CoachingConfig.requiredMealCount)

        // Text for the tiles, worked out up front to keep the view body simple.
        let weightValue: String? = weight.map { String(format: "%.1f", UnitConversion.displayWeight(kg: $0.weightKg, unit: unit)) }
        let weightLabel: String = weight.map { "Morning weight \(env.displayWeight($0.weightKg)). Edit" } ?? "Log morning weight"
        let sleepValue: String? = sleep.map { CardioCoach.formatHours($0.hours) }
        let sleepLabel: String = sleep.map { "Sleep \(CardioCoach.formatHours($0.hours)). Edit" } ?? "Log sleep"
        let sleepIsLow: Bool = (sleep?.hours ?? 24) <= 5
        let stepsValue: String? = steps.map { $0.formatted() }
        let stepsLabel: String = steps.map { "Steps \($0) of \(stepTarget). Edit" } ?? "Add steps"
        let stepsFraction: Double = Double(min(steps ?? 0, stepTarget)) / Double(max(stepTarget, 1))
        let missingFlag: String? = isToday ? nil : "Missing"
        let sectionLabel: String = isToday ? "Check-in" : "\(TodayFormat.dayLabel(day))'s check-in"

        MCSection(label: sectionLabel) {
            MCSectionCount(text: "\(doneCount) of 3 logged", complete: doneCount == 3)
        } content: {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    CheckInTile(
                        systemImage: "scalemass.fill",
                        label: "Weight",
                        done: weight != nil,
                        flag: missingFlag,
                        value: weightValue,
                        unit: unit.shortLabel,
                        prompt: "Log weight",
                        note: weightNote(weight, isToday: isToday),
                        accessibility: weightLabel
                    ) { sheet = .weight }

                    CheckInTile(
                        systemImage: "moon.fill",
                        label: "Sleep",
                        done: sleep != nil,
                        value: sleepValue,
                        prompt: "Log sleep",
                        note: sleepNote(sleep),
                        warning: sleepIsLow,
                        accessibility: sleepLabel
                    ) { sheet = .sleep }
                }
                .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    CheckInTile(
                        systemImage: "figure.walk",
                        label: "Steps",
                        done: steps != nil,
                        value: stepsValue,
                        prompt: "Add steps",
                        note: "Goal \(stepTarget.formatted())",
                        meter: stepsFraction,
                        compact: !isToday,
                        accessibility: stepsLabel
                    ) { sheet = .steps }

                    if isToday {
                        CheckInTile(
                            systemImage: "fork.knife",
                            label: "Meals",
                            done: mealsDone >= mealsTotal,
                            value: "\(mealsDone) / \(mealsTotal)",
                            prompt: "",
                            note: "Open log",
                            pips: (mealsDone, mealsTotal),
                            accessibility: "Meals: \(mealsDone) of \(mealsTotal) logged. Open Log"
                        ) { env.selectedTab = .log }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .weight: WeightSheet(day: day)
            case .sleep: SleepSheet(day: day)
            case .steps: StepsSheet(day: day)
            }
        }
    }

    /// Change since the previous weigh-in.
    private func weightNote(_ weight: WeightEntry?, isToday: Bool) -> String? {
        guard let weight else { return isToday ? "Morning, before eating" : nil }
        let start = Calendar.current.startOfDay(for: day)
        let previous = env.weightEntries
            .filter { $0.isOfficialMorningCheckIn && $0.localDate < start }
            .max { $0.localDate < $1.localDate }
        guard let previous else { return "First weigh-in" }
        let unit = env.profile.weightUnit
        let delta = UnitConversion.displayWeight(kg: weight.weightKg, unit: unit) - UnitConversion.displayWeight(kg: previous.weightKg, unit: unit)
        let rounded = (delta * 10).rounded() / 10
        let since = TodayFormat.shortWeekday(previous.localDate)
        if rounded == 0 { return "Same as \(since)" }
        return "\(rounded > 0 ? "▲" : "▼") \(String(format: "%.1f", abs(rounded))) \(unit.shortLabel) since \(since)"
    }

    private func sleepNote(_ sleep: SleepEntry?) -> String {
        guard let sleep else { return "Last night" }
        guard let wakeUps = sleep.wakeUps else { return "Wake-ups not logged" }
        return "\(wakeUps) wake-up\(wakeUps == 1 ? "" : "s")"
    }
}

private struct CheckInTile: View {
    let systemImage: String
    let label: String
    let done: Bool
    /// Small amber tag, e.g. "Missing" on a past day.
    var flag: String? = nil
    var value: String? = nil
    var unit: String? = nil
    /// Shown instead of the value when nothing is logged yet.
    var prompt: String
    var note: String? = nil
    var warning: Bool = false
    /// 0...1 progress bar under the value.
    var meter: Double? = nil
    /// (done, total) segmented bar under the value.
    var pips: (Int, Int)? = nil
    /// Full-width tile: no minimum height.
    var compact: Bool = false
    let accessibility: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let accent = warning ? MCTheme.ColorToken.warning : MCTheme.ColorToken.primary
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    MCHex(systemImage: systemImage, color: done ? accent : MCTheme.Surface.secondaryText(colorScheme), size: 30)
                    MCEyebrow(label)
                    Spacer(minLength: 0)
                    state
                }
                Spacer(minLength: 0)
                if let value {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value)
                            .font(.system(size: 25, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(warning ? MCTheme.ColorToken.warning : MCTheme.Surface.primaryText(colorScheme))
                            .contentTransition(.numericText())
                        if let unit {
                            Text(unit)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                } else {
                    Text(prompt)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(MCTheme.ColorToken.primary)
                }
                if let meter {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(MCTheme.Surface.secondaryFill(colorScheme))
                            Capsule()
                                .fill(MCInk.accentGradient)
                                .frame(width: geo.size.width * min(max(meter, 0), 1))
                                .animation(.easeOut(duration: 0.5), value: meter)
                        }
                    }
                    .frame(height: 5)
                }
                if let pips {
                    HStack(spacing: 4) {
                        ForEach(0..<max(pips.1, 1), id: \.self) { index in
                            Capsule()
                                .fill(index < pips.0 ? MCTheme.ColorToken.success : MCTheme.Surface.secondaryFill(colorScheme))
                                .frame(height: 5)
                        }
                    }
                }
                if let note {
                    Text(note)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: compact ? 0 : 118, maxHeight: .infinity, alignment: .topLeading)
            .background {
                let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
                if done {
                    shape
                        .fill(MCTheme.Surface.elevated(colorScheme))
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.07), radius: 8, y: 4)
                } else {
                    shape
                        .fill(MCTheme.ColorToken.primary.opacity(0.05))
                        .overlay(shape.strokeBorder(MCTheme.ColorToken.primary.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(MCPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var state: some View {
        if done {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(MCTheme.ColorToken.success)
                .frame(width: 20, height: 20)
                .background(Circle().fill(MCTheme.ColorToken.success.opacity(0.18)))
        } else if let flag {
            MCTag(text: flag)
        } else {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Color.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(MCTheme.ColorToken.primary))
        }
    }
}

// MARK: - Check-in sheets

private struct WeightSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let day: Date
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        let entry = env.weightEntry(on: day)
        let isToday = Calendar.current.isDateInToday(day)
        let value = Double(text.replacingOccurrences(of: ",", with: "."))
        NavigationStack {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    TextField("0.0", text: $text)
                        .keyboardType(.decimalPad)
                        .font(MCTheme.Typography.numericLarge)
                        .focused($focused)
                        .accessibilityLabel("Morning weight for \(TodayFormat.dayLabel(day))")
                    Text(env.profile.weightUnit.shortLabel)
                        .font(MCTheme.Typography.title2)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                }
                Text("For the most consistent readings, weigh yourself under similar morning conditions.")
                    .font(MCTheme.Typography.caption)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                MCPrimaryButton(title: entry == nil ? "Log Weight" : "Save Weight", isEnabled: (value ?? 0) > 0) {
                    guard let value, value > 0 else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        env.logMorningWeight(value, unit: env.profile.weightUnit, on: day)
                    }
                    dismiss()
                }
                Spacer(minLength: 0)
            }
            .padding(MCTheme.Spacing.screenHorizontal)
            .navigationTitle("Morning weight — \(TodayFormat.dayLabel(day))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            if text.isEmpty {
                let kg = entry?.weightKg ?? (isToday ? env.profile.currentWeightKg : nil)
                if let kg { text = String(format: "%.1f", UnitConversion.displayWeight(kg: kg, unit: env.profile.weightUnit)) }
            }
            focused = true
        }
    }
}

private struct SleepSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let day: Date
    @State private var hoursText = ""
    @State private var wakeText = ""
    @FocusState private var focused: Bool

    var body: some View {
        let hours = UnitConversion.parseHours(hoursText)
        let trimmedWake = wakeText.trimmingCharacters(in: .whitespaces)
        let wake = trimmedWake.isEmpty ? nil : Int(trimmedWake)
        let wakeValid = trimmedWake.isEmpty || (wake.map { (0..<50).contains($0) } ?? false)
        NavigationStack {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                HStack(alignment: .top, spacing: MCTheme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enter sleep (hours)")
                            .font(MCTheme.Typography.caption)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                        TextField("e.g. 7.5 or 7:30", text: $hoursText)
                            .keyboardType(.numbersAndPunctuation)
                            .textFieldStyle(.roundedBorder)
                            .focused($focused)
                            .accessibilityLabel("Hours slept")
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wake-ups (optional)")
                            .font(MCTheme.Typography.caption)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                        TextField("0", text: $wakeText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Wake-ups")
                    }
                }
                Text("Sleep for the night before \(Calendar.current.isDateInToday(day) ? "today" : TodayFormat.dayLabel(day)).")
                    .font(MCTheme.Typography.caption)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                MCPrimaryButton(title: "Save Sleep", isEnabled: hours != nil && wakeValid) {
                    guard let hours else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        env.logSleep(hours: hours, wakeUps: wake, on: day)
                    }
                    dismiss()
                }
                Spacer(minLength: 0)
            }
            .padding(MCTheme.Spacing.screenHorizontal)
            .navigationTitle("Sleep — \(TodayFormat.dayLabel(day))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            if let entry = env.sleep(on: day), hoursText.isEmpty {
                hoursText = entry.hours.formatted(.number.precision(.fractionLength(0...2)))
                wakeText = entry.wakeUps.map(String.init) ?? ""
            }
            focused = true
        }
    }
}

private struct StepsSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let day: Date
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        let target = env.target(on: day)?.stepTarget ?? env.profile.stepTarget
        NavigationStack {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                TextField("0", text: $text)
                    .keyboardType(.numberPad)
                    .font(MCTheme.Typography.numericLarge)
                    .focused($focused)
                    .accessibilityLabel("Steps")
                Text("Your step target is \(target.formatted()) steps.")
                    .font(MCTheme.Typography.caption)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                MCPrimaryButton(title: "Save", isEnabled: Int(text) != nil) {
                    guard let steps = Int(text) else { return }
                    withAnimation { env.logSteps(steps, on: day) }
                    dismiss()
                }
                Spacer(minLength: 0)
            }
            .padding(MCTheme.Spacing.screenHorizontal)
            .navigationTitle("Steps — \(TodayFormat.dayLabel(day))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            if text.isEmpty, let steps = env.steps(on: day)?.steps { text = String(steps) }
            focused = true
        }
    }
}

// MARK: - From your coach: today's cardio and status

private struct CoachThread: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let day = env.today
        let rec = env.adaptiveRecommendation
        let confident = (env.adaptiveModel?.confidence ?? .low) != .low && rec != nil
        let cardio = CardioCoach.recommend(
            CardioCoach.Input(
                goal: env.profile.goalPhase,
                isTrainingDay: env.isTrainingDay(on: day),
                emergencyRest: env.dayOverride(on: day)?.reason == .emergencyRest,
                sleepHours: env.sleep(on: day)?.hours,
                stepsSoFar: env.steps(on: day)?.steps ?? 0,
                stepTarget: env.target(on: day)?.stepTarget ?? env.profile.stepTarget,
                predictedKgPerWeek: confident ? rec?.predictedCurrent.meanKgPerWeek : nil,
                targetKgPerWeek: confident ? rec?.targetKgPerWeek : nil
            )
        )
        let accent: Color = switch cardio.tone {
        case .recovery: MCTheme.ColorToken.warning
        case .light: MCTheme.ColorToken.success
        case .steady, .boost: MCTheme.ColorToken.primary
        }

        MCSection(label: "From your coach") {
            HStack(alignment: .top, spacing: 10) {
                MCCoachAvatar(size: 36)
                VStack(spacing: 8) {
                    CoachBubble(accent: accent) {
                        HStack {
                            MCEyebrow("Coach's cardio for today")
                            Spacer(minLength: 8)
                            if cardio.minutes > 0 {
                                Text("\(cardio.minutes) min")
                                    .font(.system(size: 13, weight: .heavy, design: .rounded).monospacedDigit())
                                    .foregroundStyle(accent)
                            }
                        }
                        Text(cardio.title)
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                        Text(cardio.activity)
                            .font(MCTheme.Typography.callout)
                            .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                        Text(cardio.intensity)
                            .font(MCTheme.Typography.caption)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                        ForEach(cardio.reasons, id: \.self) { reason in
                            Text("• \(reason)")
                                .font(MCTheme.Typography.caption2)
                                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    CoachBubble(first: false) {
                        Text(env.coachStatusMessage)
                            .font(.system(size: 14.5))
                            .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                        Button(env.hasCoachAccess ? "View Coach Analysis" : "Unlock Coach AI") { env.selectedTab = .coach }
                            .font(MCTheme.Typography.callout)
                            .foregroundStyle(MCTheme.ColorToken.primary)
                    }
                }
            }
        }
    }
}

// MARK: - The week at a glance

private struct WeekBoard: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    let days: [Date]
    @Binding var selected: Date
    let oldest: Date

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        let missing = days.filter { $0 < env.today && $0 >= calendar.startOfDay(for: oldest) && env.weightEntry(on: $0) == nil }.count
        MCSection(label: title) {
            if missing > 0 {
                MCTag(text: "\(missing) weigh-in\(missing == 1 ? "" : "s") missing")
            }
        } content: {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 34)
                    rowIcon("scalemass.fill")
                    rowIcon("moon.fill")
                    rowIcon("figure.walk")
                }
                .frame(width: 22)
                .accessibilityHidden(true)
                ForEach(days, id: \.self) { day in
                    column(day)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .mcSurface()

            HStack(spacing: 5) {
                Circle().fill(MCTheme.ColorToken.primary).frame(width: 6, height: 6)
                Text("Training")
                Circle().fill(MCTheme.ColorToken.success).frame(width: 6, height: 6)
                Text("Rest · Tap a day to view or fill in what you missed.")
            }
            .font(MCTheme.Typography.caption)
            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            .lineLimit(2)
            .minimumScaleFactor(0.85)
        }
    }

    private var title: String {
        guard let first = days.first, let last = days.last else { return "Last 7 days" }
        if calendar.isDateInToday(last) { return "Last 7 days" }
        return "\(first.formatted(.dateTime.day().month(.abbreviated))) – \(last.formatted(.dateTime.day().month(.abbreviated)))"
    }

    private func rowIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            .frame(height: 30)
    }

    private func column(_ day: Date) -> some View {
        let weight = env.weightEntry(on: day)
        let sleep = env.sleep(on: day)
        let steps = env.steps(on: day)
        let isSelected = calendar.isDate(day, inSameDayAs: selected)
        let isToday = calendar.isDateInToday(day)
        let disabled = day < calendar.startOfDay(for: oldest)
        let weightText = weight.map { String(format: "%.1f", UnitConversion.displayWeight(kg: $0.weightKg, unit: env.profile.weightUnit)) }
        let weightSpoken: String = weight.map { env.displayWeight($0.weightKg) } ?? "missing"
        let sleepSpoken: String = sleep.map { CardioCoach.formatHours($0.hours) } ?? "missing"
        let stepsSpoken: String = steps.map { "\($0.steps)" } ?? "missing"
        let summary = "\(TodayFormat.dayLabel(day)): weight \(weightSpoken), sleep \(sleepSpoken), steps \(stepsSpoken)"
        let sleepText: String? = sleep.map { TodayFormat.compactHours($0.hours) }
        let stepsText: String? = steps.map { TodayFormat.compactSteps($0.steps) }
        let sleepIsLow: Bool = (sleep?.hours ?? 24) <= 5
        return Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { selected = calendar.startOfDay(for: day) }
        } label: {
            VStack(spacing: 0) {
                VStack(spacing: 3) {
                    Circle()
                        .fill(env.isTrainingDay(on: day) ? MCTheme.ColorToken.primary : MCTheme.ColorToken.success)
                        .frame(width: 6, height: 6)
                    Text(isToday ? "Today" : TodayFormat.shortWeekday(day))
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(isToday ? MCTheme.ColorToken.primary : MCTheme.Surface.secondaryText(colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(height: 34)
                cell(weightText, missingColor: MCTheme.ColorToken.warning)
                cell(sleepText, low: sleepIsLow)
                cell(stepsText)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? MCTheme.ColorToken.primary.opacity(0.13) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(MCPressStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.3 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func cell(_ value: String?, low: Bool = false, missingColor: Color? = nil) -> some View {
        let color: Color
        if value == nil {
            color = missingColor ?? MCTheme.Surface.border(colorScheme)
        } else {
            color = low ? MCTheme.ColorToken.warning : MCTheme.Surface.primaryText(colorScheme)
        }
        return Text(value ?? "–")
            .font(.system(size: 12.5, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(height: 30)
    }
}
