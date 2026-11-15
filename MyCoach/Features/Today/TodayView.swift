import SwiftUI

/// Today: quote, training/rest day with emergency rest, sleep, weight, targets, cardio, steps, and a
/// 7-day catch-up table. Any of the last 60 days can be opened to fill in what was missed.
struct TodayView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var showSettings = false

    private let maxDaysBack = 60

    private var calendar: Calendar { Calendar.current }
    private var isToday: Bool { calendar.isDateInToday(selectedDay) }
    private var oldest: Date { calendar.date(byAdding: .day, value: -maxDaysBack, to: env.today) ?? env.today }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MCTheme.Spacing.md) {
                    header.mcAppear(0)
                    QuoteCard().mcAppear(1)
                    dayNavigator.mcAppear(2)
                    if !isToday { catchUpBanner }
                    DayTypeCard(day: selectedDay).mcAppear(3)
                    SleepAdviceBanner(day: selectedDay)
                    WeightCard(day: selectedDay).id("w-\(selectedDay)").mcAppear(4)
                    SleepCard(day: selectedDay).id("s-\(selectedDay)").mcAppear(5)
                    TargetsCard(day: selectedDay).mcAppear(6)
                    if isToday { CardioCard().mcAppear(7) }
                    StepsCard(day: selectedDay).mcAppear(8)
                    RecentDaysCard(selected: $selectedDay).mcAppear(9)
                    if isToday { mealsAndCoach.mcAppear(10) }
                }
                .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
                .padding(.vertical, MCTheme.Spacing.md)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: selectedDay)
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
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(env.greeting)
                .font(MCTheme.Typography.title)
                .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
            Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                .font(MCTheme.Typography.subheadline)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dayNavigator: some View {
        MCCard(padding: MCTheme.Spacing.xs) {
            HStack {
                navButton("chevron.left", label: "Previous day", disabled: selectedDay <= oldest) { shift(-1) }
                Spacer()
                VStack(spacing: 0) {
                    Text(TodayFormat.dayLabel(selectedDay))
                        .font(MCTheme.Typography.headline)
                        .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                        .contentTransition(.numericText())
                    if !isToday {
                        Button("Back to today") { selectedDay = env.today }
                            .font(MCTheme.Typography.caption)
                            .foregroundStyle(MCTheme.ColorToken.primary)
                    }
                }
                Spacer()
                navButton("chevron.right", label: "Next day", disabled: isToday) { shift(1) }
            }
        }
    }

    private func navButton(_ icon: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(Circle().fill(MCTheme.Surface.secondaryFill(colorScheme)))
                .foregroundStyle(MCTheme.ColorToken.primary)
        }
        .buttonStyle(MCPressStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .accessibilityLabel(label)
    }

    private func shift(_ days: Int) {
        if let next = calendar.date(byAdding: .day, value: days, to: selectedDay) {
            selectedDay = calendar.startOfDay(for: next)
        }
    }

    private var catchUpBanner: some View {
        Label(
            "Catching up on \(TodayFormat.dayLabel(selectedDay)) — anything you log here is saved to that day and used by your coach.",
            systemImage: "calendar"
        )
        .font(MCTheme.Typography.subheadline)
        .padding(MCTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: MCTheme.Radius.md).fill(MCTheme.ColorToken.primary.opacity(0.1)))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var mealsAndCoach: some View {
        let slots = MealSlot.slots(isTrainingDay: env.isTrainingDay(on: env.today))
        let logged = Set(env.todayDiary.entries.map(\.mealSlot))
        let complete = slots.filter { logged.contains($0) || ($0 == .preWorkout && logged.contains(.intraWorkout)) }.count
        return VStack(spacing: MCTheme.Spacing.md) {
            MCCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Meals").font(MCTheme.Typography.headline)
                        Text("\(complete) / \(CoachingConfig.requiredMealCount) logged")
                            .font(MCTheme.Typography.subheadline)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    }
                    Spacer()
                    Button("Open Log") { env.selectedTab = .log }
                        .font(MCTheme.Typography.callout)
                        .foregroundStyle(MCTheme.ColorToken.primary)
                }
            }
            MCCard {
                VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
                    HStack(alignment: .top, spacing: MCTheme.Spacing.sm) {
                        MCCoachAvatar(size: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Coach").font(MCTheme.Typography.headline)
                            Text(env.coachStatusMessage)
                                .font(MCTheme.Typography.subheadline)
                                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Button(env.hasCoachAccess ? "View Coach Analysis" : "Unlock Coach AI") { env.selectedTab = .coach }
                        .font(MCTheme.Typography.callout)
                        .foregroundStyle(MCTheme.ColorToken.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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
}

// MARK: - Quote of the day

private struct QuoteCard: View {
    @State private var quote: Quote?

    var body: some View {
        Group {
            if let quote {
                VStack(alignment: .leading, spacing: MCTheme.Spacing.xs) {
                    Label("Quote of the day", systemImage: "sparkles")
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.75))
                    Text("“\(quote.t)”")
                        .font(.system(size: 17, weight: .medium, design: .serif).italic())
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("— \(quote.a)")
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(MCTheme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: MCTheme.Radius.lg, style: .continuous)
                        .fill(LinearGradient(
                            colors: [MCTheme.ColorToken.navy, Color(red: 0.10, green: 0.23, blue: 0.52)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                )
                .transition(.opacity)
                .accessibilityElement(children: .combine)
            }
        }
        .task {
            let q = QuoteOfTheDay.quote(for: Date())
            withAnimation(.easeOut(duration: 0.8)) { quote = q }
        }
    }
}

// MARK: - Training / rest day

private struct DayTypeCard: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    let day: Date
    @State private var confirmRest = false

    var body: some View {
        let training = env.isTrainingDay(on: day)
        let override = env.dayOverride(on: day)
        let isToday = Calendar.current.isDateInToday(day)
        let session = env.workoutSessions.first { Calendar.current.isDate($0.localDate, inSameDayAs: day) && $0.isCompleted }
        let next = env.nextWorkoutTemplate

        VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isToday ? "Today's plan" : "\(TodayFormat.dayLabel(day))'s plan")
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    Label(training ? "Training Day" : "Rest Day", systemImage: training ? "dumbbell.fill" : "sun.max.fill")
                        .font(MCTheme.Typography.title2)
                        .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                        .contentTransition(.symbolEffect(.replace))
                }
                Spacer()
                MCDayTypeBadge(isTrainingDay: training)
            }

            if training, isToday, session == nil {
                Text(movedNote(override).map { "On the plan: \(next.displayName) · \($0)" } ?? "On the plan: \(next.displayName)")
                    .font(MCTheme.Typography.subheadline)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            }
            if let session {
                Label("\(session.templateName) completed", systemImage: "checkmark.circle.fill")
                    .font(MCTheme.Typography.subheadline)
                    .foregroundStyle(MCTheme.ColorToken.success)
            }
            if !training, override?.reason == .emergencyRest {
                Text(override?.linkedDay.map { "Emergency rest day — session moved to \(TodayFormat.weekdayName($0)). Rest-day calories apply." }
                    ?? "Emergency rest day. Rest-day calories apply.")
                    .font(MCTheme.Typography.subheadline)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            } else if !training, override == nil {
                Text("Recover, hit your steps and eat to your rest-day targets.")
                    .font(MCTheme.Typography.subheadline)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            }

            if isToday, training, session == nil {
                HStack(spacing: MCTheme.Spacing.sm) {
                    MCPrimaryButton(title: "Start \(next.displayName)") { env.startWorkout(templateID: next) }
                    MCSecondaryButton(title: "Emergency rest day") { confirmRest = true }
                }
            }
            if isToday, override?.reason == .emergencyRest {
                Button("Undo rest day") {
                    withAnimation { env.undoEmergencyRestDay(on: day) }
                }
                .font(MCTheme.Typography.callout)
                .foregroundStyle(MCTheme.ColorToken.primary)
            }
        }
        .padding(MCTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: MCTheme.Radius.lg, style: .continuous)
                .fill(LinearGradient(
                    colors: [(training ? MCTheme.ColorToken.primary : MCTheme.ColorToken.success).opacity(0.14), MCTheme.Surface.elevated(colorScheme)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
        .modifier(ConditionalShimmer(active: training))
        .clipShape(RoundedRectangle(cornerRadius: MCTheme.Radius.lg, style: .continuous))
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: training)
        .confirmationDialog("Take an emergency rest day?", isPresented: $confirmRest, titleVisibility: .visible) {
            Button("Take Rest Day") {
                withAnimation { _ = env.takeEmergencyRestDay(on: day) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Today switches to rest-day calories and no training. Your coach moves the session to a free day later this week if there's a good slot.")
        }
    }

    private func movedNote(_ override: DayOverride?) -> String? {
        guard let override, override.reason == .movedSession, let from = override.linkedDay else { return nil }
        return "moved here from \(TodayFormat.weekdayName(from))"
    }
}

private struct ConditionalShimmer: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active { content.mcShimmer() } else { content }
    }
}

// MARK: - Sleep advice

private struct SleepAdviceBanner: View {
    @Environment(AppEnvironment.self) private var env
    let day: Date
    @State private var dismissed = false

    var body: some View {
        if !dismissed, Calendar.current.isDateInToday(day), let sleep = env.sleep(on: day), sleep.hours <= 5, env.isTrainingDay(on: day) {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
                Label {
                    Text("**You slept \(CardioCoach.formatHours(sleep.hours)).** With 5 hours or less, your coach recommends taking today as a rest day — training on that little sleep raises injury risk and slows recovery.")
                        .font(MCTheme.Typography.subheadline)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(MCTheme.ColorToken.warning)
                }
                HStack(spacing: MCTheme.Spacing.sm) {
                    MCPrimaryButton(title: "Make it a rest day") {
                        withAnimation { _ = env.takeEmergencyRestDay(on: day) }
                    }
                    MCSecondaryButton(title: "Train anyway") {
                        withAnimation { dismissed = true }
                    }
                }
            }
            .padding(MCTheme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: MCTheme.Radius.lg).fill(MCTheme.ColorToken.warning.opacity(0.14)))
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
    }
}

// MARK: - Weight

private struct WeightCard: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    let day: Date
    @State private var text = ""
    @State private var editing = false

    var body: some View {
        let entry = env.weightEntry(on: day)
        let isToday = Calendar.current.isDateInToday(day)
        let value = Double(text.replacingOccurrences(of: ",", with: "."))
        MCCard {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                HStack {
                    Text("Morning Weight").font(MCTheme.Typography.headline)
                    Spacer()
                    if entry != nil {
                        Label("Logged", systemImage: "checkmark.circle.fill")
                            .font(MCTheme.Typography.caption)
                            .foregroundStyle(MCTheme.ColorToken.success)
                    } else if !isToday {
                        Text("Missing")
                            .font(MCTheme.Typography.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(MCTheme.ColorToken.warning.opacity(0.15)))
                            .foregroundStyle(MCTheme.ColorToken.warning)
                    }
                }
                if let entry, !editing {
                    Text(env.displayWeight(entry.weightKg))
                        .font(MCTheme.Typography.numeric)
                        .foregroundStyle(MCTheme.ColorToken.primary)
                        .contentTransition(.numericText())
                    MCSecondaryButton(title: "Edit Weight") {
                        text = String(format: "%.1f", UnitConversion.displayWeight(kg: entry.weightKg, unit: env.profile.weightUnit))
                        editing = true
                    }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("0.0", text: $text)
                            .keyboardType(.decimalPad)
                            .font(MCTheme.Typography.numeric)
                        Text(env.profile.weightUnit.shortLabel)
                            .font(MCTheme.Typography.title2)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    }
                    if isToday {
                        Text("For the most consistent readings, weigh yourself under similar morning conditions.")
                            .font(MCTheme.Typography.caption)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    }
                    MCPrimaryButton(title: entry == nil ? "Log Weight" : "Save Weight", isEnabled: (value ?? 0) > 0) {
                        guard let value, value > 0 else { return }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            env.logMorningWeight(value, unit: env.profile.weightUnit, on: day)
                            editing = false
                        }
                    }
                }
            }
        }
        .onAppear {
            if text.isEmpty {
                let kg = entry?.weightKg ?? (isToday ? env.profile.currentWeightKg : nil)
                if let kg { text = String(format: "%.1f", UnitConversion.displayWeight(kg: kg, unit: env.profile.weightUnit)) }
            }
        }
    }
}

// MARK: - Sleep

private struct SleepCard: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    let day: Date
    @State private var hoursText = ""
    @State private var wakeText = ""
    @State private var editing = false

    var body: some View {
        let entry = env.sleep(on: day)
        let hours = UnitConversion.parseHours(hoursText)
        let wake = wakeText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : Int(wakeText)
        let wakeValid = wakeText.trimmingCharacters(in: .whitespaces).isEmpty || (wake.map { (0..<50).contains($0) } ?? false)
        MCCard {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                HStack {
                    Label("Sleep", systemImage: "moon.zzz.fill").font(MCTheme.Typography.headline)
                    Spacer()
                    if entry != nil, !editing {
                        Button("Edit") { beginEditing(entry) }
                            .font(MCTheme.Typography.callout)
                            .foregroundStyle(MCTheme.ColorToken.primary)
                    }
                }
                if let entry, !editing {
                    HStack(alignment: .firstTextBaseline, spacing: MCTheme.Spacing.md) {
                        Text(CardioCoach.formatHours(entry.hours))
                            .font(MCTheme.Typography.numeric)
                            .foregroundStyle(entry.hours <= 5 ? MCTheme.ColorToken.warning : MCTheme.ColorToken.primary)
                            .contentTransition(.numericText())
                        Text(entry.wakeUps.map { "\($0) wake-up\($0 == 1 ? "" : "s")" } ?? "Wake-ups not logged")
                            .font(MCTheme.Typography.subheadline)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    }
                } else {
                    HStack(spacing: MCTheme.Spacing.sm) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enter sleep (hours)")
                                .font(MCTheme.Typography.caption)
                                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                            TextField("e.g. 7.5 or 7:30", text: $hoursText)
                                .keyboardType(.numbersAndPunctuation)
                                .textFieldStyle(.roundedBorder)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Wake-ups (optional)")
                                .font(MCTheme.Typography.caption)
                                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                            TextField("0", text: $wakeText)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    Text("Sleep for the night before \(Calendar.current.isDateInToday(day) ? "today" : TodayFormat.dayLabel(day)).")
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    MCPrimaryButton(title: "Save Sleep", isEnabled: hours != nil && wakeValid) {
                        guard let hours else { return }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            env.logSleep(hours: hours, wakeUps: wake, on: day)
                            editing = false
                        }
                    }
                }
            }
        }
        .onAppear { if entry == nil { editing = true } }
    }

    private func beginEditing(_ entry: SleepEntry?) {
        if let entry {
            hoursText = entry.hours.formatted(.number.precision(.fractionLength(0...2)))
            wakeText = entry.wakeUps.map(String.init) ?? ""
        }
        editing = true
    }
}

// MARK: - Targets

private struct TargetsCard: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    let day: Date

    var body: some View {
        if let target = env.target(on: day) {
            MCCard {
                VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                    HStack {
                        Text(Calendar.current.isDateInToday(day) ? "Today's Targets" : "\(TodayFormat.dayLabel(day))'s Targets")
                            .font(MCTheme.Typography.headline)
                        Spacer()
                        if target.source == .adaptiveModel {
                            Text("Personalised")
                                .font(MCTheme.Typography.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(MCTheme.ColorToken.success.opacity(0.15)))
                                .foregroundStyle(MCTheme.ColorToken.success)
                        }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(target.calories)")
                            .font(MCTheme.Typography.numericLarge)
                            .foregroundStyle(MCTheme.ColorToken.primary)
                            .contentTransition(.numericText(value: Double(target.calories)))
                        Text("kcal")
                            .font(MCTheme.Typography.title2)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    }
                    HStack(spacing: MCTheme.Spacing.sm) {
                        pill(.protein, target.macros.protein)
                        pill(.carbohydrates, target.macros.carbohydrates)
                        pill(.fat, target.macros.fat)
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

    private func pill(_ kind: MCTheme.MacroKind, _ grams: Double) -> some View {
        VStack(spacing: 2) {
            Text(kind.label)
                .font(MCTheme.Typography.caption)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            Text("\(Int(grams.rounded())) g")
                .font(MCTheme.Typography.numericSmall)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MCTheme.Spacing.xs)
        .background(RoundedRectangle(cornerRadius: MCTheme.Radius.sm).fill(kind.color.opacity(0.12)))
    }
}

// MARK: - Cardio

private struct CardioCard: View {
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
        MCCard {
            HStack(alignment: .top, spacing: MCTheme.Spacing.sm) {
                RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 4)
                VStack(alignment: .leading, spacing: MCTheme.Spacing.xs) {
                    HStack {
                        Label("Coach's cardio for today", systemImage: "heart.fill")
                            .font(MCTheme.Typography.caption)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                        Spacer()
                        if cardio.minutes > 0 {
                            Text("\(cardio.minutes) min")
                                .font(MCTheme.Typography.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(MCTheme.ColorToken.primary.opacity(0.12)))
                                .foregroundStyle(MCTheme.ColorToken.primary)
                        }
                    }
                    Text(cardio.title).font(MCTheme.Typography.title2)
                    Text(cardio.activity).font(MCTheme.Typography.callout)
                    Text(cardio.intensity)
                        .font(MCTheme.Typography.caption)
                        .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    ForEach(cardio.reasons, id: \.self) { reason in
                        Text("• \(reason)")
                            .font(MCTheme.Typography.caption2)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    }
                }
            }
        }
    }
}

// MARK: - Steps

private struct StepsCard: View {
    @Environment(AppEnvironment.self) private var env
    let day: Date
    @State private var editing = false
    @State private var text = ""

    var body: some View {
        let steps = env.steps(on: day)?.steps
        let target = env.target(on: day)?.stepTarget ?? env.profile.stepTarget
        MCCard {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
                HStack {
                    Text("Steps").font(MCTheme.Typography.headline)
                    Spacer()
                    Button(steps == nil ? "Add" : "Edit") {
                        text = steps.map(String.init) ?? ""
                        editing = true
                    }
                    .font(MCTheme.Typography.callout)
                    .foregroundStyle(MCTheme.ColorToken.primary)
                }
                Text("\((steps ?? 0).formatted()) / \(target.formatted())")
                    .font(MCTheme.Typography.numericMedium)
                    .contentTransition(.numericText())
                ProgressView(value: Double(min(steps ?? 0, target)), total: Double(max(target, 1)))
                    .tint(MCTheme.ColorToken.primary)
                    .animation(.easeOut(duration: 0.6), value: steps)
            }
        }
        .alert("Steps — \(TodayFormat.dayLabel(day))", isPresented: $editing) {
            TextField("Steps", text: $text).keyboardType(.numberPad)
            Button("Save") {
                if let n = Int(text) {
                    withAnimation { env.logSteps(n, on: day) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Last 7 days

private struct RecentDaysCard: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.buttonSound) private var sound
    @Binding var selected: Date

    var body: some View {
        let days = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: env.today) }
        let missing = days.filter { !Calendar.current.isDateInToday($0) && env.weightEntry(on: $0) == nil }.count
        MCCard {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
                HStack {
                    Text("Last 7 Days").font(MCTheme.Typography.headline)
                    Spacer()
                    if missing > 0 {
                        Text("\(missing) weigh-in\(missing == 1 ? "" : "s") missing")
                            .font(MCTheme.Typography.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(MCTheme.ColorToken.warning.opacity(0.15)))
                            .foregroundStyle(MCTheme.ColorToken.warning)
                    }
                }
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        column("Day"); column("Weight"); column("Sleep"); column("Steps")
                    }
                    .font(MCTheme.Typography.caption)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    .padding(.vertical, 6)
                    ForEach(days, id: \.self) { day in
                        row(day)
                        Divider()
                    }
                }
                Text("Tap a day to view or fill in what you missed.")
                    .font(MCTheme.Typography.caption)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
            }
        }
    }

    @ViewBuilder
    private func row(_ day: Date) -> some View {
        let w = env.weightEntry(on: day)
        let s = env.sleep(on: day)
        let st = env.steps(on: day)
        let isSelected = Calendar.current.isDate(day, inSameDayAs: selected)
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(env.isTrainingDay(on: day) ? MCTheme.ColorToken.primary : MCTheme.ColorToken.success)
                    .frame(width: 7, height: 7)
                Text(TodayFormat.dayLabel(day)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            cell(w.map { env.displayWeight($0.weightKg) })
            cell(s.map { CardioCoach.formatHours($0.hours) })
            cell(st.map { $0.steps.formatted() })
        }
        .font(MCTheme.Typography.subheadline)
        .padding(.vertical, 8)
        .background(isSelected ? MCTheme.ColorToken.primary.opacity(0.1) : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            ButtonSounds.play(sound)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { selected = Calendar.current.startOfDay(for: day) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private func column(_ title: String) -> some View {
        Text(title).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cell(_ value: String?) -> some View {
        Text(value ?? "—")
            .fontWeight(value == nil ? .bold : .semibold)
            .foregroundStyle(value == nil ? MCTheme.ColorToken.warning : MCTheme.Surface.primaryText(colorScheme))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
