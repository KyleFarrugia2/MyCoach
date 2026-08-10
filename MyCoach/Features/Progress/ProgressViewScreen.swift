import Charts
import SwiftUI

struct ProgressViewScreen: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    enum RangeFilter: String, CaseIterable, Identifiable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1Y"
        case all = "All"
        var id: String { rawValue }
    }

    enum ProgressTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case weights = "Weights"
        var id: String { rawValue }
    }

    @State private var range: RangeFilter = .threeMonths
    @State private var selectedEntry: WeightEntry?
    @State private var progressTab: ProgressTab = .overview

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Progress", selection: $progressTab) {
                    ForEach(ProgressTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
                .padding(.top, MCTheme.Spacing.sm)
                .padding(.bottom, MCTheme.Spacing.xs)

                ScrollView {
                    Group {
                        switch progressTab {
                        case .overview:
                            VStack(spacing: MCTheme.Spacing.md) {
                                statsGrid
                                chartCard
                                checkInHistory
                                photosSection
                            }
                        case .weights:
                            weightHistorySection
                        }
                    }
                    .padding(.vertical, MCTheme.Spacing.md)
                }
            }
            .mcScreenBackground()
            .navigationTitle("Progress")
        }
    }

    private var weightHistorySection: some View {
        let entries = env.weightEntries
            .filter(\.isOfficialMorningCheckIn)
            .sorted { $0.localDate > $1.localDate }

        return VStack(alignment: .leading, spacing: MCTheme.Spacing.sm) {
            if entries.isEmpty {
                MCEmptyState(
                    title: "No weigh-ins yet",
                    message: "Log your morning weight on Today to build your history.",
                    systemImage: "scalemass",
                    actionTitle: "Log Weight"
                ) {
                    env.selectedTab = .today
                }
                .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
            } else {
                Text("Previous Weights")
                    .font(MCTheme.Typography.headline)
                    .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                    .padding(.horizontal, MCTheme.Spacing.screenHorizontal)

                Text("\(entries.count) morning check-ins")
                    .font(MCTheme.Typography.subheadline)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    .padding(.horizontal, MCTheme.Spacing.screenHorizontal)

                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    let previous = index + 1 < entries.count ? entries[index + 1] : nil
                    let deltaKg = previous.map { entry.weightKg - $0.weightKg }
                    MCCard {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.localDate, format: .dateTime.weekday(.abbreviated).month().day().year())
                                    .font(MCTheme.Typography.headline)
                                    .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                                if Calendar.current.isDateInToday(entry.localDate) {
                                    Text("Today")
                                        .font(MCTheme.Typography.caption)
                                        .foregroundStyle(MCTheme.ColorToken.primary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(env.displayWeight(entry.weightKg))
                                    .font(MCTheme.Typography.numericMedium)
                                    .foregroundStyle(MCTheme.Surface.primaryText(colorScheme))
                                if let deltaKg {
                                    let displayDelta = UnitConversion.displayWeight(kg: abs(deltaKg), unit: env.profile.weightUnit)
                                    Text(String(format: "%@%.1f %@", deltaKg > 0 ? "+" : deltaKg < 0 ? "−" : "", displayDelta, env.profile.weightUnit.shortLabel))
                                        .font(MCTheme.Typography.caption)
                                        .foregroundStyle(
                                            deltaKg < 0
                                                ? MCTheme.ColorToken.success
                                                : deltaKg > 0
                                                    ? MCTheme.ColorToken.warning
                                                    : MCTheme.Surface.secondaryText(colorScheme)
                                        )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
                }
            }
        }
    }

    private var statsGrid: some View {
        let current = env.weightEntries.last?.weightKg ?? env.profile.currentWeightKg
        let starting = env.weightEntries.first?.weightKg ?? env.profile.currentWeightKg
        let weeklyAvg = env.currentWeek.averageKg
        let change = env.weeklyRate?.absoluteChangeKg
        let overall = current - starting

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MCTheme.Spacing.sm) {
            MCStatCard(title: "Current Weight", value: env.displayWeight(current))
            MCStatCard(title: "Starting Weight", value: env.displayWeight(starting))
            MCStatCard(title: "Goal Weight", value: env.displayWeight(env.profile.desiredWeightKg))
            MCStatCard(
                title: "Weekly Average",
                value: weeklyAvg.map { env.displayWeight($0) } ?? "—",
                subtitle: env.currentWeek.weighInSummary
            )
            MCStatCard(
                title: "Weekly Change",
                value: change.map {
                    let display = UnitConversion.displayWeight(kg: abs($0), unit: env.profile.weightUnit)
                    return String(format: "%@%.1f %@", $0 >= 0 ? "+" : "−", display, env.profile.weightUnit.shortLabel)
                } ?? "—",
                subtitle: env.weeklyRate.map { String(format: "%+.1f%%", $0.percentChange) },
                accent: (change ?? 0) < 0 ? MCTheme.ColorToken.success : MCTheme.ColorToken.primary
            )
            MCStatCard(
                title: "Overall Change",
                value: String(format: "%+.1f %@", UnitConversion.displayWeight(kg: overall, unit: env.profile.weightUnit), env.profile.weightUnit.shortLabel),
                subtitle: env.profile.goalPhase.displayName
            )
        }
        .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
    }

    private var chartCard: some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCTheme.Spacing.md) {
                Text("Weight Trend")
                    .font(MCTheme.Typography.headline)

                Picker("Range", selection: $range) {
                    ForEach(RangeFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                if filteredEntries.isEmpty {
                    MCEmptyState(
                        title: "Your progress starts with your first weigh-in.",
                        message: "Log morning weight on Today to see your chart.",
                        systemImage: "chart.line.uptrend.xyaxis",
                        actionTitle: "Log Weight"
                    ) {
                        env.selectedTab = .today
                    }
                    .frame(height: 220)
                } else {
                    Chart {
                        ForEach(filteredEntries) { entry in
                            LineMark(
                                x: .value("Date", entry.localDate),
                                y: .value("Weight", UnitConversion.displayWeight(kg: entry.weightKg, unit: env.profile.weightUnit))
                            )
                            .foregroundStyle(MCTheme.ColorToken.primary.opacity(0.35))
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Date", entry.localDate),
                                y: .value("Weight", UnitConversion.displayWeight(kg: entry.weightKg, unit: env.profile.weightUnit))
                            )
                            .foregroundStyle(MCTheme.ColorToken.primary.opacity(0.5))
                            .symbolSize(30)
                        }

                        ForEach(weeklyAverages, id: \.date) { point in
                            LineMark(
                                x: .value("Week", point.date),
                                y: .value("Weekly Avg", point.value)
                            )
                            .foregroundStyle(MCTheme.ColorToken.navy)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            .symbol(Circle())
                            .symbolSize(40)

                            PointMark(
                                x: .value("Week", point.date),
                                y: .value("Weekly Avg", point.value)
                            )
                            .foregroundStyle(MCTheme.ColorToken.navy)
                            .symbolSize(50)
                        }
                    }
                    .chartYAxisLabel(env.profile.weightUnit.shortLabel)
                    .frame(height: 240)
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            guard let plotFrame = proxy.plotFrame else { return }
                                            let x = value.location.x - geo[plotFrame].origin.x
                                            if let date: Date = proxy.value(atX: x) {
                                                selectedEntry = filteredEntries.min(by: {
                                                    abs($0.localDate.timeIntervalSince(date)) < abs($1.localDate.timeIntervalSince(date))
                                                })
                                            }
                                        }
                                )
                        }
                    }

                    if let selectedEntry {
                        Text("\(selectedEntry.localDate.formatted(date: .abbreviated, time: .omitted)): \(env.displayWeight(selectedEntry.weightKg))")
                            .font(MCTheme.Typography.caption)
                            .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    }

                    HStack(spacing: MCTheme.Spacing.md) {
                        legendDot(MCTheme.ColorToken.primary.opacity(0.5), "Daily weight")
                        legendDot(MCTheme.ColorToken.navy, "Weekly average")
                    }
                }
            }
        }
        .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(MCTheme.Typography.caption2)
                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
        }
    }

    private var checkInHistory: some View {
        VStack(alignment: .leading, spacing: 0) {
            MCSectionHeader(title: "Check-In History")
            if env.checkIns.isEmpty {
                Text("Weekly coach reviews will appear here after your first check-in.")
                    .font(MCTheme.Typography.subheadline)
                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                    .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
            } else {
                ForEach(env.checkIns) { checkIn in
                    MCCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(checkIn.weekStart, format: .dateTime.month().day().year())
                                    .font(MCTheme.Typography.headline)
                                if let rate = checkIn.rateKg {
                                    Text(String(format: "%+.1f kg", rate))
                                        .font(MCTheme.Typography.numericSmall)
                                        .foregroundStyle(MCTheme.ColorToken.primary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(calorieChangeLabel(checkIn))
                                    .font(MCTheme.Typography.caption)
                                    .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                                if checkIn.userApprovedAdjustment {
                                    Text("Applied")
                                        .font(MCTheme.Typography.caption2)
                                        .foregroundStyle(MCTheme.ColorToken.success)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
                    .padding(.bottom, MCTheme.Spacing.sm)
                }
            }
        }
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            MCSectionHeader(title: "Progress Photos")
            if env.photoSets.isEmpty {
                MCEmptyState(
                    title: "Add your first progress photos when you're ready.",
                    message: "Take them fasted in the morning under similar lighting. Photos stay private on device.",
                    systemImage: "camera"
                )
                .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
            } else {
                ForEach(env.photoSets) { set in
                    MCCard {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(set.weekStart, format: .dateTime.month().day().year())
                                .font(MCTheme.Typography.headline)
                            Text(photoSummary(set))
                                .font(MCTheme.Typography.caption)
                                .foregroundStyle(MCTheme.Surface.secondaryText(colorScheme))
                        }
                    }
                    .padding(.horizontal, MCTheme.Spacing.screenHorizontal)
                    .padding(.bottom, MCTheme.Spacing.sm)
                }
            }
        }
    }

    private var filteredEntries: [WeightEntry] {
        let entries = env.weightEntries.filter(\.isOfficialMorningCheckIn)
        guard let cutoff = cutoffDate else { return entries }
        return entries.filter { $0.localDate >= cutoff }
    }

    private var cutoffDate: Date? {
        let cal = Calendar.current
        switch range {
        case .oneMonth: return cal.date(byAdding: .month, value: -1, to: Date())
        case .threeMonths: return cal.date(byAdding: .month, value: -3, to: Date())
        case .sixMonths: return cal.date(byAdding: .month, value: -6, to: Date())
        case .oneYear: return cal.date(byAdding: .year, value: -1, to: Date())
        case .all: return nil
        }
    }

    private var weeklyAverages: [(date: Date, value: Double)] {
        let cal = CoachingCalendar()
        let entries = filteredEntries
        guard !entries.isEmpty else { return [] }
        var weeks: [Date: [WeightEntry]] = [:]
        for entry in entries {
            let start = cal.weekStart(containing: entry.localDate)
            weeks[start, default: []].append(entry)
        }
        return weeks.keys.sorted().compactMap { start in
            guard let avg = WeightAnalytics.weeklyAverage(entries: weeks[start] ?? []) else { return nil }
            let display = UnitConversion.displayWeight(kg: avg, unit: env.profile.weightUnit)
            return (start, display)
        }
    }

    private func calorieChangeLabel(_ checkIn: WeeklyCheckIn) -> String {
        guard let decision = checkIn.decision else { return "No analysis" }
        switch decision.action {
        case .maintain: return "Calories: No change"
        case .increaseCalories(let v): return "Calories: +\(v)"
        case .decreaseCalories(let v): return "Calories: -\(v)"
        case .increaseSteps(let v): return "Steps: +\(v)"
        case .decreaseSteps(let v): return "Steps: -\(v)"
        case .suggestRefeed: return "Refeed suggested"
        case .requireMoreData: return "Need more data"
        case .reviewAdherence: return "Review adherence"
        case .reviewRecovery: return "Review recovery"
        case .recommendNutritionIncreaseReview: return "Calories: review +"
        case .recommendNutritionDecreaseReview: return "Calories: review −"
        }
    }

    private func photoSummary(_ set: ProgressPhotoSet) -> String {
        var parts: [String] = []
        if set.frontLocalPath != nil { parts.append("Front") }
        if set.sideLocalPath != nil { parts.append("Side") }
        if set.backLocalPath != nil { parts.append("Back") }
        return parts.isEmpty ? "No photos attached" : parts.joined(separator: " · ")
    }
}

#Preview {
    ProgressViewScreen()
        .environment(AppEnvironment())
}
