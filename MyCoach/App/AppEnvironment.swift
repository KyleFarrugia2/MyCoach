import Foundation
import Observation
import SwiftUI
import UIKit

/// In-memory + disk-backed app state. Wires deterministic engines to the UI.
@Observable
@MainActor
final class AppEnvironment {
    // MARK: - Published state

    var profile: UserProfile
    var preferences: UserPreferences
    var weightEntries: [WeightEntry]
    var stepEntries: [StepEntry]
    var diaries: [Date: DailyFoodDiary]
    var mealPlanDays: [Date: MealPlanDay]
    var targets: NutritionTargetPair?
    var checkIns: [WeeklyCheckIn]
    var chatMessages: [CoachChatMessage]
    var planAdjustments: [PlanAdjustment]
    var photoSets: [ProgressPhotoSet]
    var customFoods: [FoodItem]
    var subscription: SubscriptionEntitlement
    var selectedTab: MainTab = .today
    var isGeneratingMealPlan = false
    var coachStatusMessage: String
    var paywallComparisonTraditionalEUR: Double
    var paywallComparisonCoachEUR: Double
    var workoutSessions: [WorkoutSession]
    var workoutTemplateOverrides: [WorkoutTemplateOverride]
    var activeWorkout: WorkoutSession?
    var workoutRestEndsAt: Date?
    var pendingStagnationAlerts: [String] = []

    // Adaptive model cache — recomputed when persisted data changes (see `save()`), not observed by views.
    @ObservationIgnored var dataRevision = 0
    @ObservationIgnored var adaptiveCacheRevision = -1
    @ObservationIgnored var adaptiveCacheDay: Date?
    @ObservationIgnored var adaptiveCachedModel: AdaptiveModelSnapshot?
    @ObservationIgnored var isApplyingAdaptiveAdjustment = false

    // MARK: - Services

    private let nutritionEngine = NutritionEngine()
    private let decisionEngine = CoachingDecisionEngine()
    private let calendar = CoachingCalendar()
    private let persistenceURL: URL
    private let bundledCatalog = BundledFoodCatalog()
    private let coachAI: any CoachAIProvider = LocalDeterministicCoachAI()
    private(set) var subscriptionProvider: any SubscriptionProviding

    /// Sync cache of bundled foods for meal-plan generation and offline search.
    private var bundledFoodCache: [FoodItem] = []

    // MARK: - Init

    init(persistenceDirectory: URL? = nil, subscriptionProvider: (any SubscriptionProviding)? = nil) {
        let dir = persistenceDirectory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("MyCoach", isDirectory: true)
        self.persistenceURL = dir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        if let snapshot = Self.load(from: dir) {
            self.profile = snapshot.profile
            self.profile.mealCount = CoachingConfig.requiredMealCount
            self.preferences = snapshot.preferences
            self.weightEntries = snapshot.weightEntries
            self.stepEntries = snapshot.stepEntries
            self.diaries = Dictionary(uniqueKeysWithValues: snapshot.diaries.map { (Self.calendarKey($0.localDate), $0) })
            self.mealPlanDays = Dictionary(uniqueKeysWithValues: snapshot.mealPlanDays.map { (Self.calendarKey($0.localDate), $0) })
            self.targets = snapshot.targets
            self.checkIns = snapshot.checkIns
            self.chatMessages = snapshot.chatMessages
            self.planAdjustments = snapshot.planAdjustments
            self.photoSets = snapshot.photoSets
            self.customFoods = snapshot.customFoods
            self.subscription = snapshot.subscription
            self.coachStatusMessage = snapshot.coachStatusMessage
            self.paywallComparisonTraditionalEUR = snapshot.paywallComparisonTraditionalEUR
            self.paywallComparisonCoachEUR = snapshot.paywallComparisonCoachEUR
            self.workoutSessions = snapshot.workoutSessions
            self.workoutTemplateOverrides = snapshot.workoutTemplateOverrides
            self.subscriptionProvider = subscriptionProvider ?? SubscriptionManager(initial: snapshot.subscription) { [weak self] entitlement in
                Task { @MainActor in
                    self?.subscription = entitlement
                    self?.save()
                }
            }
        } else {
            self.profile = .draft()
            self.preferences = UserPreferences()
            self.weightEntries = []
            self.stepEntries = []
            self.diaries = [:]
            self.mealPlanDays = [:]
            self.targets = nil
            self.checkIns = []
            self.chatMessages = [
                CoachChatMessage(
                    role: .coach,
                    text: "I'm your My Coach AI. Ask about progress, refeeds, or what to eat around training."
                )
            ]
            self.planAdjustments = []
            self.photoSets = []
            self.customFoods = []
            self.subscription = SubscriptionEntitlement(
                productID: CoachingConfig.coachProductID,
                status: .notSubscribed,
                expirationDate: nil,
                isTrialEligible: true,
                localizedPrice: "€\(String(format: "%.2f", CoachingConfig.subscriptionMarketingComparisonEUR))"
            )
            self.coachStatusMessage = "Complete onboarding to unlock your plan."
            self.paywallComparisonTraditionalEUR = CoachingConfig.traditionalCoachingComparisonEUR
            self.paywallComparisonCoachEUR = CoachingConfig.subscriptionMarketingComparisonEUR
            self.workoutSessions = []
            self.workoutTemplateOverrides = []
            self.subscriptionProvider = subscriptionProvider ?? SubscriptionManager { [weak self] entitlement in
                Task { @MainActor in
                    self?.subscription = entitlement
                    self?.save()
                }
            }
        }

        Task { [weak self] in
            guard let self else { return }
            self.bundledFoodCache = await self.bundledCatalog.search(query: "")
            self.subscription = await self.subscriptionProvider.refreshEntitlement()
            // Rebuild plans saved by the old generator that fail validation, then re-train the adaptive model
            // and catch up on any adjustment that became due while the app was closed.
            self.revalidateStoredPlans()
            self.runAdaptiveAutoAdjust()
        }
    }

    // MARK: - Derived

    var hasCoachAccess: Bool { FeatureAccess.canUseCoachAI(subscription) }

    var today: Date { calendar.localDate(for: Date()) }

    var todayTarget: DailyNutritionTarget? {
        guard let targets else { return nil }
        let weekday = weekday(for: today)
        let training = profile.trainingSchedule.isTrainingDay(weekday)
        return targets.target(isTrainingDay: training)
    }

    var todayMealPlan: MealPlanDay? {
        mealPlanDays[Self.calendarKey(today)]
    }

    var todayDiary: DailyFoodDiary {
        diaries[Self.calendarKey(today)] ?? DailyFoodDiary(localDate: today, entries: [], markedComplete: false)
    }

    var todayWeightEntry: WeightEntry? {
        weightEntries.first { calendar.isSameLocalDay($0.localDate, today) && $0.isOfficialMorningCheckIn }
    }

    var todaySteps: StepEntry? {
        stepEntries.first { calendar.isSameLocalDay($0.localDate, today) }
    }

    var currentWeek: CoachingWeek {
        WeightAnalytics.makeWeek(containing: today, entries: weightEntries, calendar: calendar)
    }

    var previousWeek: CoachingWeek {
        let previous = calendar.calendar.date(byAdding: .day, value: -7, to: today) ?? today
        return WeightAnalytics.makeWeek(containing: previous, entries: weightEntries, calendar: calendar)
    }

    var weeklyRate: WeeklyRateOfChange? {
        WeightAnalytics.rateOfChange(previous: previousWeek, current: currentWeek)
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = profile.displayName.isEmpty ? "" : ", \(profile.displayName)"
        switch hour {
        case 5..<12: return "Good Morning\(name)"
        case 12..<17: return "Good Afternoon\(name)"
        default: return "Good Evening\(name)"
        }
    }

    var catalogFoods: [FoodItem] {
        let bundled = bundledFoodCache.isEmpty ? Self.bundledFoods() : bundledFoodCache
        return customFoods + bundled
    }

    // MARK: - Onboarding / profile

    func completeOnboarding() {
        profile.hasCompletedOnboarding = true
        profile.updatedAt = Date()
        profile.stepTarget = min(profile.activityBand.initialStepTarget, CoachingConfig.maxStepTarget)
        rebuildTargetsFromProfile()
        if FeatureAccess.canGenerateMealPlan(subscription) {
            generateMealPlan(forWeekContaining: today)
            coachStatusMessage = "Your plan is ready. Log your morning weight to start the coaching cycle."
        } else {
            coachStatusMessage = "Food logging is ready. Start a Coach AI trial to unlock meal plans and weekly adjustments."
        }
        save()
    }

    func updateProfile(_ transform: (inout UserProfile) -> Void) {
        transform(&profile)
        profile.mealCount = CoachingConfig.requiredMealCount
        profile.updatedAt = Date()
        save()
    }

    func rebuildTargetsFromProfile() {
        let age = profile.ageYears ?? 25
        let input = NutritionEngine.ProfileInput(
            weightKg: profile.currentWeightKg,
            heightCm: profile.heightCm,
            ageYears: age,
            sex: profile.biologicalSex,
            goal: profile.goalPhase,
            activityBand: profile.activityBand,
            trainingDaysPerWeek: profile.trainingSchedule.trainingDaysPerWeek,
            stepTarget: profile.stepTarget,
            intraWorkoutEnabled: profile.intraWorkoutEnabled
        )
        targets = nutritionEngine.buildInitialTargets(for: input)
        save()
    }

    // MARK: - Weight

    func logMorningWeight(_ value: Double, unit: WeightUnit) {
        let kg = UnitConversion.kilograms(from: value, unit: unit)
        let day = today
        if let index = weightEntries.firstIndex(where: {
            calendar.isSameLocalDay($0.localDate, day) && $0.isOfficialMorningCheckIn
        }) {
            weightEntries[index].weightKg = kg
            weightEntries[index].inputUnit = unit
            weightEntries[index].timestamp = Date()
            weightEntries[index].updatedAt = Date()
        } else {
            weightEntries.append(
                WeightEntry(
                    localDate: day,
                    weightKg: kg,
                    inputUnit: unit,
                    isOfficialMorningCheckIn: true
                )
            )
        }
        profile.currentWeightKg = kg
        profile.updatedAt = Date()
        // Protein follows bodyweight (1 g/lb); calories stay as set.
        refreshTargetsForCurrentWeight()
        weightEntries.sort { $0.localDate < $1.localDate }
        save()
        runAdaptiveAutoAdjust()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Steps

    func logSteps(_ steps: Int, source: StepEntry.StepSource = .manual) {
        let day = today
        if let index = stepEntries.firstIndex(where: { calendar.isSameLocalDay($0.localDate, day) }) {
            stepEntries[index].steps = max(0, steps)
            stepEntries[index].source = source
            stepEntries[index].updatedAt = Date()
        } else {
            stepEntries.append(StepEntry(localDate: day, steps: steps, source: source))
        }
        save()
        runAdaptiveAutoAdjust()
    }

    // MARK: - Food diary

    func diary(for date: Date) -> DailyFoodDiary {
        let key = Self.calendarKey(date)
        return diaries[key] ?? DailyFoodDiary(localDate: calendar.localDate(for: date), entries: [], markedComplete: false)
    }

    func upsertDiary(_ diary: DailyFoodDiary) {
        diaries[Self.calendarKey(diary.localDate)] = diary
        save()
        runAdaptiveAutoAdjust()
    }

    func logFood(
        _ food: FoodItem,
        amount: Double,
        amountIsServings: Bool,
        mealSlot: MealSlot,
        on date: Date,
        calories: Double,
        macros: MacroGrams
    ) {
        let day = calendar.localDate(for: date)
        var diary = diary(for: day)
        let entry = FoodLogEntry(
            localDate: day,
            mealSlot: mealSlot,
            food: food,
            amount: amount,
            amountIsServings: amountIsServings,
            loggedCalories: calories,
            loggedMacros: macros
        )
        diary.entries.append(entry)
        upsertDiary(diary)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func deleteFoodEntry(_ entry: FoodLogEntry) {
        var diary = diary(for: entry.localDate)
        diary.entries.removeAll { $0.id == entry.id }
        upsertDiary(diary)
    }

    func copyYesterday(to date: Date) {
        let day = calendar.localDate(for: date)
        guard let previous = calendar.calendar.date(byAdding: .day, value: -1, to: day) else { return }
        let source = diary(for: previous)
        guard !source.entries.isEmpty else { return }
        var target = diary(for: day)
        let copied = source.entries.map { entry in
            FoodLogEntry(
                localDate: day,
                mealSlot: entry.mealSlot,
                food: entry.food,
                amount: entry.amount,
                amountIsServings: entry.amountIsServings,
                loggedCalories: entry.loggedCalories,
                loggedMacros: entry.loggedMacros,
                notes: entry.notes
            )
        }
        target.entries.append(contentsOf: copied)
        upsertDiary(target)
    }

    func quickAddCalories(
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        mealSlot: MealSlot,
        on date: Date
    ) {
        let food = FoodItem(
            name: "Quick Add",
            source: .customUser,
            servingDescription: "1 entry",
            servingGrams: nil,
            calories: calories,
            proteinGrams: protein,
            carbohydrateGrams: carbs,
            fatGrams: fat,
            measurementState: .serving,
            isCustom: true
        )
        logFood(
            food,
            amount: 1,
            amountIsServings: true,
            mealSlot: mealSlot,
            on: date,
            calories: calories,
            macros: MacroGrams(protein: protein, carbohydrates: carbs, fat: fat)
        )
    }

    func saveCustomFood(_ food: FoodItem) {
        // One food per barcode: re-scanning a product replaces the earlier entry.
        if let index = customFoods.firstIndex(where: { $0.id == food.id || (food.barcode != nil && $0.barcode == food.barcode) }) {
            customFoods[index] = food
            customFoods.removeAll { $0.id != food.id && food.barcode != nil && $0.barcode == food.barcode }
        } else {
            customFoods.append(food)
        }
        save()
    }

    func deleteCustomFood(_ food: FoodItem) {
        customFoods.removeAll { $0.id == food.id }
        save()
    }

    /// A food the user already saved for this barcode, so re-scans work offline.
    func customFood(barcode: String) -> FoodItem? {
        customFoods.first { $0.barcode == barcode }
    }

    func searchFoods(query: String) async -> [FoodItem] {
        let customs = customFoods
        let catalog = CompositeFoodCatalog(bundled: bundledCatalog) {
            customs
        }
        return await catalog.search(query: query)
    }

    /// Synchronous helper for SwiftUI lists while async search is in flight.
    func searchFoodsSync(query: String) -> [FoodItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else {
            return Array(catalogFoods.prefix(40))
        }
        return catalogFoods.filter {
            $0.name.lowercased().contains(q)
                || ($0.brand?.lowercased().contains(q) ?? false)
                || ($0.restaurant?.lowercased().contains(q) ?? false)
        }
    }

    // MARK: - Meal plan

    /// Planner inputs for a given day (intra-workout only on training days).
    func plannerContext(for date: Date) -> PlannerContext {
        let training = profile.trainingSchedule.isTrainingDay(weekday(for: date))
        return PlannerContext(
            allergies: Array(profile.allergies).sorted { $0.rawValue < $1.rawValue },
            dislikedFoods: profile.dislikedFoods,
            preferredFoods: profile.preferredFoods,
            trainingTime: profile.trainingTime,
            intraWorkoutEnabled: profile.intraWorkoutEnabled && training,
            weightKg: profile.currentWeightKg,
            goal: profile.goalPhase
        )
    }

    /// Same calories, macros re-derived for the *current* bodyweight: protein 1 g/lb, fat per kg, carbs fill
    /// the rest (4/4/9). Keeps coach/model calorie adjustments intact.
    func refreshTargetsForCurrentWeight(includesIntraWorkout: Bool? = nil) {
        guard var pair = targets else { return }
        let weight = profile.currentWeightKg
        pair.training.macros = nutritionEngine.macros(forCalories: pair.training.calories, weightKg: weight, goal: profile.goalPhase)
        if let includesIntraWorkout { pair.training.includesIntraWorkout = includesIntraWorkout }
        var rest = nutritionEngine.restDayTarget(
            fromTraining: pair.training,
            weightKg: weight,
            goal: profile.goalPhase,
            sex: profile.biologicalSex
        )
        rest.id = pair.rest.id
        rest.source = pair.rest.source
        rest.stepTarget = pair.rest.stepTarget
        pair.rest = rest
        targets = pair
    }

    private func plannedDay(_ day: Date, targets: NutritionTargetPair) -> MealPlanDay {
        let weekday = weekday(for: day)
        let training = profile.trainingSchedule.isTrainingDay(weekday)
        return MealPlanner.generateDay(
            date: day,
            weekday: weekday,
            isTrainingDay: training,
            target: targets.target(isTrainingDay: training),
            context: plannerContext(for: day)
        )
    }

    /// Plans saved by the old generator (no recipe ids) that fail validation — e.g. cooked weights or two
    /// protein foods in one meal — are rebuilt with the current planner before they're shown again.
    func revalidateStoredPlans() {
        guard FeatureAccess.canGenerateMealPlan(subscription), targets != nil else { return }
        let stale = mealPlanDays.filter { _, plan in
            plan.meals.allSatisfy { $0.recipeID == nil } && !MealPlanner.validate(plan).ok
        }
        guard !stale.isEmpty else { return }
        refreshTargetsForCurrentWeight()
        guard let targets else { return }
        for (key, plan) in stale {
            mealPlanDays[key] = plannedDay(plan.localDate, targets: targets)
        }
        save()
    }

    func generateMealPlan(forWeekContaining date: Date) {
        guard FeatureAccess.canGenerateMealPlan(subscription) else { return }
        refreshTargetsForCurrentWeight()
        guard let targets else { return }
        isGeneratingMealPlan = true
        defer { isGeneratingMealPlan = false }
        for day in calendar.datesInWeek(containing: date) {
            mealPlanDays[Self.calendarKey(day)] = plannedDay(day, targets: targets)
        }
        save()
    }

    func regenerateDay(_ date: Date) {
        guard FeatureAccess.canGenerateMealPlan(subscription) else { return }
        refreshTargetsForCurrentWeight()
        guard let targets else { return }
        let day = calendar.localDate(for: date)
        mealPlanDays[Self.calendarKey(day)] = plannedDay(day, targets: targets)
        save()
    }

    func toggleLock(itemID: UUID, on date: Date) {
        guard var plan = mealPlanDays[Self.calendarKey(date)] else { return }
        for m in plan.meals.indices {
            for i in plan.meals[m].items.indices where plan.meals[m].items[i].id == itemID {
                plan.meals[m].items[i].isLocked.toggle()
            }
        }
        mealPlanDays[Self.calendarKey(date)] = plan
        save()
    }

    /// Swap one ingredient; portions and daily totals are re-fitted and the day re-validated.
    @discardableResult
    func swapFood(itemID: UUID, with food: FoodItem, on date: Date) -> String? {
        guard let plan = mealPlanDays[Self.calendarKey(date)] else { return nil }
        let result = MealPlanner.swapItem(plan, itemID: itemID, with: food)
        mealPlanDays[Self.calendarKey(date)] = result.plan
        save()
        return result.message
    }

    /// Replace a whole meal with the next suitable recipe; the day is re-fitted and re-validated.
    func swapMeal(mealID: UUID, on date: Date) {
        guard let plan = mealPlanDays[Self.calendarKey(date)] else { return }
        mealPlanDays[Self.calendarKey(date)] = MealPlanner.swapMeal(plan, mealID: mealID, context: plannerContext(for: date))
        save()
    }

    func logPlannedMeal(_ meal: Meal, on date: Date) {
        for item in meal.items {
            let amount: Double
            let amountIsServings: Bool
            if let grams = item.grams {
                amount = grams
                amountIsServings = false
            } else {
                amount = item.servings ?? 1
                amountIsServings = true
            }
            logFood(
                item.food,
                amount: amount,
                amountIsServings: amountIsServings,
                mealSlot: meal.slot == .custom ? .custom : meal.slot,
                on: date,
                calories: item.calories,
                macros: item.macros
            )
        }
        selectedTab = .log
    }

    func setIntraWorkoutEnabled(_ enabled: Bool) {
        profile.intraWorkoutEnabled = enabled
        profile.updatedAt = Date()
        // Keep any coach/model calorie adjustments — only the intra flag and macro split refresh.
        refreshTargetsForCurrentWeight(includesIntraWorkout: enabled)
        save()
        regenerateDay(today)
    }

    // MARK: - Coaching

    func submitWeeklyCheckIn(_ draft: WeeklyCheckIn) -> CoachDecision {
        let ruleDecision = decisionEngine.evaluate(
            CoachingDecisionEngine.Input(
                goal: profile.goalPhase,
                previousWeek: previousWeek,
                currentWeek: currentWeek,
                rate: weeklyRate,
                currentTrainingCalories: targets?.training.calories ?? 0,
                currentRestCalories: targets?.rest.calories ?? 0,
                currentMacros: targets?.training.macros ?? .zero,
                stepTarget: profile.stepTarget,
                adherence: draft.adherence,
                performance: draft.performance,
                appearance: draft.appearance,
                hunger: draft.hunger,
                energy: draft.energy,
                weightKg: profile.currentWeightKg,
                sex: profile.biologicalSex,
                recentRefeed: checkIns.contains { $0.decision?.refeed != nil && $0.userApprovedAdjustment }
            )
        )
        // The rules decide whether calories may change; a confident personal model decides by how much.
        let decision = blendWithAdaptiveModel(ruleDecision)
        var completed = draft
        completed.decision = decision
        completed.previousAverageKg = previousWeek.averageKg
        completed.currentAverageKg = currentWeek.averageKg
        completed.rateKg = weeklyRate?.absoluteChangeKg
        completed.ratePercent = weeklyRate?.percentChange
        checkIns.insert(completed, at: 0)
        coachStatusMessage = decision.summary
        chatMessages.append(CoachChatMessage(role: .coach, text: decision.summary))
        save()
        return decision
    }

    func applyCoachDecision(_ decision: CoachDecision) {
        guard var targets else { return }
        let old = targets
        switch decision.action {
        case .increaseCalories(let delta), .decreaseCalories(let delta):
            let signed = decision.action.isIncrease ? abs(delta) : -abs(delta)
            targets = nutritionEngine.applyCalorieAdjustment(
                currentTraining: targets.training,
                deltaCalories: signed,
                weightKg: profile.currentWeightKg,
                goal: profile.goalPhase,
                sex: profile.biologicalSex
            )
        case .increaseSteps(let delta):
            let next = nutritionEngine.adjustedStepTarget(current: profile.stepTarget, delta: delta)
            profile.stepTarget = next
            targets.training.stepTarget = next
            targets.rest.stepTarget = next
        case .decreaseSteps(let delta):
            let next = nutritionEngine.adjustedStepTarget(current: profile.stepTarget, delta: -abs(delta))
            profile.stepTarget = next
            targets.training.stepTarget = next
            targets.rest.stepTarget = next
        case .maintain, .requireMoreData, .reviewAdherence, .reviewRecovery, .suggestRefeed:
            break
        case .recommendNutritionIncreaseReview:
            if let cal = decision.suggestedTrainingCalories, let macros = decision.suggestedMacros {
                targets.training.calories = cal
                targets.training.macros = macros
                targets.training.source = .coachRecommendation
                targets.rest = nutritionEngine.restDayTarget(
                    fromTraining: targets.training,
                    weightKg: profile.currentWeightKg,
                    goal: profile.goalPhase,
                    sex: profile.biologicalSex
                )
            }
        case .recommendNutritionDecreaseReview:
            if let cal = decision.suggestedTrainingCalories, let macros = decision.suggestedMacros {
                targets.training.calories = cal
                targets.training.macros = macros
                targets.training.source = .coachRecommendation
                targets.rest = nutritionEngine.restDayTarget(
                    fromTraining: targets.training,
                    weightKg: profile.currentWeightKg,
                    goal: profile.goalPhase,
                    sex: profile.biologicalSex
                )
            }
        }

        if let steps = decision.suggestedSteps {
            profile.stepTarget = nutritionEngine.cappedStepTarget(steps)
            targets.training.stepTarget = profile.stepTarget
            targets.rest.stepTarget = profile.stepTarget
        }

        planAdjustments.insert(
            PlanAdjustment(
                oldCalories: old.training.calories,
                newCalories: targets.training.calories,
                oldMacros: old.training.macros,
                newMacros: targets.training.macros,
                oldSteps: old.training.stepTarget,
                newSteps: targets.training.stepTarget,
                reason: decision.summary,
                source: .coachRecommendation,
                userApproved: true
            ),
            at: 0
        )

        if let index = checkIns.firstIndex(where: { $0.decision?.id == decision.id }) {
            checkIns[index].userApprovedAdjustment = true
        }

        self.targets = targets
        generateMealPlan(forWeekContaining: today)
        coachStatusMessage = "Updated plan applied for the new coaching week."
        save()
    }

    func sendCoachMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        chatMessages.append(CoachChatMessage(role: .user, text: trimmed))

        if !hasCoachAccess {
            chatMessages.append(
                CoachChatMessage(
                    role: .coach,
                    text: "Coach AI subscription required for live coaching conversations. Your food log and history remain available."
                )
            )
            save()
            return
        }

        Task {
            let context = makeAIContext()
            do {
                let response = try await coachAI.chat(
                    messages: chatMessages,
                    decision: checkIns.first?.decision,
                    context: context
                )
                chatMessages.append(
                    CoachChatMessage(role: .coach, text: response.userMessage, structured: response)
                )
            } catch {
                chatMessages.append(
                    CoachChatMessage(
                        role: .coach,
                        text: CoachAIError.offlineUserMessage
                    )
                )
            }
            save()
        }
    }

    func purchaseSubscription() async throws {
        let entitlement = try await subscriptionProvider.purchase()
        subscription = entitlement
        if let price = entitlement.localizedPrice ?? subscriptionProvider.localizedPrice {
            subscription.localizedPrice = price
        }
        coachStatusMessage = entitlement.hasCoachAIAccess
            ? "Coach AI active — weekly check-ins and meal plans unlocked."
            : coachStatusMessage
        save()
        runAdaptiveAutoAdjust()
    }

    func restoreSubscription() async {
        do {
            subscription = try await subscriptionProvider.restore()
            if subscription.hasCoachAIAccess {
                coachStatusMessage = "Subscription restored."
            } else {
                coachStatusMessage = "No active subscription found to restore."
            }
        } catch {
            coachStatusMessage = "Couldn't restore purchases right now. Try again shortly."
        }
        save()
    }

    // MARK: - Subscription

    func startTrialLocally() {
        Task {
            do {
                try await purchaseSubscription()
            } catch {
                // Fallback when StoreKit product isn't configured yet.
                subscription.status = .trial
                subscription.isTrialEligible = false
                subscription.expirationDate = Calendar.current.date(
                    byAdding: .day,
                    value: CoachingConfig.freeTrialDays,
                    to: Date()
                )
                if let mock = subscriptionProvider as? MockSubscriptionManager {
                    mock.setStatus(.trial)
                }
                coachStatusMessage = "Coach AI trial active — weekly check-ins and meal plans unlocked."
                save()
                runAdaptiveAutoAdjust()
            }
        }
    }

    func restorePurchasesLocally() {
        Task { await restoreSubscription() }
    }

    private func makeAIContext() -> CoachAIContext {
        CoachAIContext(
            goal: profile.goalPhase,
            weightKg: profile.currentWeightKg,
            previousWeeklyAverageKg: previousWeek.averageKg,
            currentWeeklyAverageKg: currentWeek.averageKg,
            weeklyRateKg: weeklyRate?.absoluteChangeKg,
            trainingCalories: targets?.training.calories ?? 0,
            restCalories: targets?.rest.calories ?? 0,
            protein: targets?.training.macros.protein ?? 0,
            carbs: targets?.training.macros.carbohydrates ?? 0,
            fat: targets?.training.macros.fat ?? 0,
            stepTarget: profile.stepTarget,
            adherence: checkIns.first?.adherencePercent,
            performance: checkIns.first?.performance,
            appearance: checkIns.first?.appearance,
            targetSource: targets?.training.source ?? .engine,
            model: adaptiveAIContext
        )
    }

    func updateRemotePaywallComparison(traditional: Double?, coach: Double?) {
        if let traditional { paywallComparisonTraditionalEUR = traditional }
        if let coach { paywallComparisonCoachEUR = coach }
        save()
    }

    // MARK: - Settings / data

    func exportDataJSON() -> Data? {
        try? JSONEncoder.pretty.encode(makeSnapshot())
    }

    func deleteCoachingData() {
        weightEntries = []
        stepEntries = []
        diaries = [:]
        mealPlanDays = [:]
        checkIns = []
        planAdjustments = []
        photoSets = []
        workoutSessions = []
        workoutTemplateOverrides = []
        activeWorkout = nil
        workoutRestEndsAt = nil
        pendingStagnationAlerts = []
        chatMessages = [
            CoachChatMessage(role: .coach, text: "Your coaching data was cleared. Generate a new plan when you're ready.")
        ]
        coachStatusMessage = "Coaching data deleted."
        save()
    }

    func deleteAccountLocally() {
        deleteCoachingData()
        customFoods = []
        preferences = UserPreferences()
        targets = nil
        profile = .draft()
        subscription = SubscriptionEntitlement(
            productID: CoachingConfig.coachProductID,
            status: .notSubscribed,
            expirationDate: nil,
            isTrialEligible: true,
            localizedPrice: "€\(String(format: "%.2f", CoachingConfig.subscriptionMarketingComparisonEUR))"
        )
        save()
    }

    func savePhotoSet(_ set: ProgressPhotoSet) {
        if let index = photoSets.firstIndex(where: { $0.id == set.id }) {
            photoSets[index] = set
        } else {
            photoSets.insert(set, at: 0)
        }
        save()
    }

    // MARK: - Workouts

    func resolvedTemplate(id: WorkoutTemplateID) -> WorkoutTemplate {
        let base = WorkoutLibrary.template(id: id)
        guard let override = workoutTemplateOverrides.first(where: { $0.templateID == id }) else {
            return base
        }
        let exercises = base.exercises.map { exercise in
            var next = exercise
            if let sets = override.setCounts[exercise.id] {
                next.defaultSets = max(1, sets)
            }
            return next
        }
        return WorkoutTemplate(id: id, exercises: exercises)
    }

    func updatePlannedSets(templateID: WorkoutTemplateID, exerciseID: String, sets: Int) {
        let clamped = max(1, min(sets, 12))
        if let index = workoutTemplateOverrides.firstIndex(where: { $0.templateID == templateID }) {
            workoutTemplateOverrides[index].setCounts[exerciseID] = clamped
        } else {
            workoutTemplateOverrides.append(
                WorkoutTemplateOverride(templateID: templateID, setCounts: [exerciseID: clamped])
            )
        }
        if var active = activeWorkout, active.templateID == templateID,
           let exerciseIndex = active.exercises.firstIndex(where: { $0.id == exerciseID }) {
            active.exercises[exerciseIndex].plannedSets = clamped
            activeWorkout = active
        }
        save()
    }

    func lastCompletedSession(for templateID: WorkoutTemplateID) -> WorkoutSession? {
        workoutSessions
            .filter { $0.templateID == templateID && $0.isCompleted }
            .sorted { $0.startedAt > $1.startedAt }
            .first
    }

    func previousPerformance(templateID: WorkoutTemplateID, exerciseID: String) -> WorkoutExerciseLog? {
        lastCompletedSession(for: templateID)?.exercises.first { $0.id == exerciseID }
    }

    func sessions(on day: Date) -> [WorkoutSession] {
        let key = Self.calendarKey(day)
        return workoutSessions
            .filter { Self.calendarKey($0.localDate) == key }
            .sorted { $0.startedAt > $1.startedAt }
    }

    func startWorkout(templateID: WorkoutTemplateID) {
        let template = resolvedTemplate(id: templateID)
        let exercises = template.exercises.map {
            WorkoutExerciseLog(
                id: $0.id,
                name: $0.name,
                plannedSets: $0.defaultSets,
                isBodyweightMaxReps: $0.isBodyweightMaxReps
            )
        }
        activeWorkout = WorkoutSession(
            templateID: templateID,
            templateName: template.name,
            exercises: exercises
        )
        workoutRestEndsAt = nil
        selectedTab = .workout
    }

    func logSet(
        exerciseID: String,
        weightKg: Double?,
        reps: Int
    ) {
        guard var session = activeWorkout,
              let index = session.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let nextNumber = session.exercises[index].sets.count + 1
        let set = LoggedSet(
            setNumber: nextNumber,
            weightKg: session.exercises[index].isBodyweightMaxReps ? nil : weightKg,
            reps: reps
        )
        session.exercises[index].sets.append(set)
        activeWorkout = session
        workoutRestEndsAt = Date().addingTimeInterval(TimeInterval(CoachingConfig.defaultRestSeconds))
        save()
    }

    func skipRestTimer() {
        workoutRestEndsAt = nil
    }

    func discardActiveWorkout() {
        activeWorkout = nil
        workoutRestEndsAt = nil
    }

    @discardableResult
    func finishActiveWorkout() -> [String] {
        guard var session = activeWorkout else { return [] }
        session.completedAt = Date()
        workoutSessions.append(session)
        workoutSessions.sort { $0.startedAt > $1.startedAt }
        activeWorkout = nil
        workoutRestEndsAt = nil

        let stagnant = WorkoutProgressAnalyzer.stagnantExercises(
            templateID: session.templateID,
            sessions: workoutSessions,
            streak: CoachingConfig.stagnationWorkoutStreak
        )
        pendingStagnationAlerts = stagnant
        save()
        return stagnant
    }

    func acknowledgeStagnationAlerts() {
        pendingStagnationAlerts = []
    }

    // MARK: - Formatting helpers

    func displayWeight(_ kg: Double) -> String {
        let value = UnitConversion.displayWeight(kg: kg, unit: profile.weightUnit)
        return String(format: "%.1f %@", value, profile.weightUnit.shortLabel)
    }

    func weekday(for date: Date) -> Weekday {
        let component = calendar.calendar.component(.weekday, from: date)
        // Gregorian Sunday=1 … convert to Monday-first Weekday
        switch component {
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .sunday
        }
    }

    // MARK: - Private

    private func localCoachReply(for prompt: String) -> String {
        let lower = prompt.lowercased()
        if lower.contains("refeed") {
            return profile.goalPhase == .cut
                ? "Refeeds make sense when adherence is high, you've lost meaningful weight, and performance feels flat. We'll only suggest one after a weekly check-in confirms those signals."
                : "Refeeds are mainly a cutting tool. On a gain phase we usually keep carbs consistent unless recovery specifically needs a push."
        }
        if lower.contains("progress") || lower.contains("how am i") {
            if let rate = weeklyRate, let curr = currentWeek.averageKg, let prev = previousWeek.averageKg {
                return "Weekly average moved from \(String(format: "%.1f", prev)) to \(String(format: "%.1f", curr)) kg (\(String(format: "%+.1f", rate.absoluteChangeKg)) kg). \(coachStatusMessage)"
            }
            return "I need a few more morning weigh-ins this week before I can speak confidently about your trend."
        }
        if lower.contains("flat") {
            return "Feeling flat can come from low carbs, poor sleep, or aggressive loss. Don't slash food from one session — finish the week and we'll review appearance with your average."
        }
        if lower.contains("hungry") {
            return "Hunger is useful context, not an automatic calorie increase. If adherence is high and the weekly rate is aggressive, we may add carbohydrate after check-in."
        }
        if lower.contains("calories") || lower.contains("change") {
            return coachStatusMessage
        }
        if lower.contains("eat out") || lower.contains("missed") {
            return "You don't need the exact meal plan today. Use the free food log, stay near your calorie and protein targets, and we'll treat it as data — not a failure."
        }
        if lower.contains("jumped") || lower.contains("overnight") {
            return "One morning jump rarely matters. Weekly averages drive decisions — keep today's plan and reassess on Sunday."
        }
        return "Based on your current targets (\(targets?.training.calories ?? 0) kcal training / \(targets?.rest.calories ?? 0) kcal rest), \(coachStatusMessage) Ask about progress, refeeds, or pre-training food anytime."
    }

    private func makeSnapshot() -> PersistedSnapshot {
        PersistedSnapshot(
            profile: profile,
            preferences: preferences,
            weightEntries: weightEntries,
            stepEntries: stepEntries,
            diaries: Array(diaries.values),
            mealPlanDays: Array(mealPlanDays.values),
            targets: targets,
            checkIns: checkIns,
            chatMessages: chatMessages,
            planAdjustments: planAdjustments,
            photoSets: photoSets,
            customFoods: customFoods,
            subscription: subscription,
            coachStatusMessage: coachStatusMessage,
            paywallComparisonTraditionalEUR: paywallComparisonTraditionalEUR,
            paywallComparisonCoachEUR: paywallComparisonCoachEUR,
            workoutSessions: workoutSessions,
            workoutTemplateOverrides: workoutTemplateOverrides
        )
    }

    func save() {
        dataRevision &+= 1
        let snapshot = makeSnapshot()
        let url = persistenceURL.appendingPathComponent("state.json")
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: [.atomic])
        } catch {
            // Persistence failure should not crash UI flows.
            print("MyCoach persistence error: \(error.localizedDescription)")
        }
    }

    private static func load(from directory: URL) -> PersistedSnapshot? {
        let url = directory.appendingPathComponent("state.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PersistedSnapshot.self, from: data)
    }

    private static func calendarKey(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func bundledFoods() -> [FoodItem] {
        [
            FoodItem(name: "Chicken breast", source: .bundledGeneric, servingDescription: "100 g raw", servingGrams: 100, calories: 110, proteinGrams: 23, carbohydrateGrams: 0, fatGrams: 1.2, measurementState: .raw, isVerified: true),
            FoodItem(name: "Lean beef", source: .bundledGeneric, servingDescription: "100 g raw", servingGrams: 100, calories: 140, proteinGrams: 22, carbohydrateGrams: 0, fatGrams: 5, measurementState: .raw, isVerified: true),
            FoodItem(name: "Rice", source: .bundledGeneric, servingDescription: "100 g dry", servingGrams: 100, calories: 360, proteinGrams: 7, carbohydrateGrams: 80, fatGrams: 0.6, measurementState: .dry, isVerified: true),
            FoodItem(name: "Rice", brand: "Cooked", source: .bundledGeneric, servingDescription: "100 g cooked", servingGrams: 100, calories: 130, proteinGrams: 2.5, carbohydrateGrams: 28, fatGrams: 0.3, measurementState: .cooked, isVerified: true),
            FoodItem(name: "Potatoes", source: .bundledGeneric, servingDescription: "100 g raw", servingGrams: 100, calories: 77, proteinGrams: 2, carbohydrateGrams: 17, fatGrams: 0.1, measurementState: .raw, isVerified: true),
            FoodItem(name: "Pasta", source: .bundledGeneric, servingDescription: "100 g dry", servingGrams: 100, calories: 350, proteinGrams: 12, carbohydrateGrams: 72, fatGrams: 1.5, measurementState: .dry, isVerified: true),
            FoodItem(name: "Oats", source: .bundledGeneric, servingDescription: "100 g dry", servingGrams: 100, calories: 380, proteinGrams: 13, carbohydrateGrams: 67, fatGrams: 7, measurementState: .dry, isVerified: true),
            FoodItem(name: "Eggs", source: .bundledGeneric, servingDescription: "1 large", servingGrams: 50, calories: 70, proteinGrams: 6, carbohydrateGrams: 0.5, fatGrams: 5, measurementState: .raw, allergenTags: [.eggs], isVerified: true),
            FoodItem(name: "Egg whites", source: .bundledGeneric, servingDescription: "100 g", servingGrams: 100, calories: 52, proteinGrams: 11, carbohydrateGrams: 0.7, fatGrams: 0.2, measurementState: .raw, allergenTags: [.eggs], isVerified: true),
            FoodItem(name: "Greek yogurt", source: .bundledGeneric, servingDescription: "100 g", servingGrams: 100, calories: 59, proteinGrams: 10, carbohydrateGrams: 3.6, fatGrams: 0.4, measurementState: .prepared, allergenTags: [.dairy], isVerified: true),
            FoodItem(name: "Banana", source: .bundledGeneric, servingDescription: "100 g", servingGrams: 100, calories: 89, proteinGrams: 1.1, carbohydrateGrams: 23, fatGrams: 0.3, measurementState: .raw, isVerified: true),
            FoodItem(name: "Apple", source: .bundledGeneric, servingDescription: "100 g", servingGrams: 100, calories: 52, proteinGrams: 0.3, carbohydrateGrams: 14, fatGrams: 0.2, measurementState: .raw, isVerified: true),
            FoodItem(name: "Berries", source: .bundledGeneric, servingDescription: "100 g", servingGrams: 100, calories: 57, proteinGrams: 0.7, carbohydrateGrams: 14, fatGrams: 0.3, measurementState: .raw, isVerified: true),
            FoodItem(name: "Mixed vegetables", source: .bundledGeneric, servingDescription: "100 g raw", servingGrams: 100, calories: 35, proteinGrams: 2, carbohydrateGrams: 6, fatGrams: 0.2, measurementState: .raw, isVerified: true),
            FoodItem(name: "Broccoli", source: .bundledGeneric, servingDescription: "100 g raw", servingGrams: 100, calories: 34, proteinGrams: 2.8, carbohydrateGrams: 7, fatGrams: 0.4, measurementState: .raw, isVerified: true),
            FoodItem(name: "Bread", source: .bundledGeneric, servingDescription: "1 slice (30 g)", servingGrams: 30, calories: 80, proteinGrams: 3, carbohydrateGrams: 14, fatGrams: 1, measurementState: .prepared, allergenTags: [.glutenWheat], isVerified: true),
            FoodItem(name: "Peanut butter", source: .bundledGeneric, servingDescription: "100 g", servingGrams: 100, calories: 588, proteinGrams: 25, carbohydrateGrams: 20, fatGrams: 50, measurementState: .prepared, allergenTags: [.peanuts], isVerified: true),
            FoodItem(name: "Olive oil", source: .bundledGeneric, servingDescription: "1 tbsp (14 g)", servingGrams: 14, calories: 120, proteinGrams: 0, carbohydrateGrams: 0, fatGrams: 14, measurementState: .serving, isVerified: true),
            FoodItem(name: "Dextrose", source: .bundledGeneric, servingDescription: "100 g dry", servingGrams: 100, calories: 380, proteinGrams: 0, carbohydrateGrams: 95, fatGrams: 0, measurementState: .dry, isVerified: true),
            FoodItem(name: "EAAs", source: .bundledGeneric, servingDescription: "10 g serving", servingGrams: 10, calories: 40, proteinGrams: 10, carbohydrateGrams: 0, fatGrams: 0, measurementState: .serving, isVerified: true),
            FoodItem(name: "Whey protein", source: .bundledGeneric, servingDescription: "30 g scoop", servingGrams: 30, calories: 120, proteinGrams: 24, carbohydrateGrams: 3, fatGrams: 1.5, measurementState: .serving, allergenTags: [.dairy], isVerified: true),
            FoodItem(name: "Salmon", source: .bundledGeneric, servingDescription: "100 g raw", servingGrams: 100, calories: 208, proteinGrams: 20, carbohydrateGrams: 0, fatGrams: 13, measurementState: .raw, allergenTags: [.fish], isVerified: true),
            FoodItem(name: "Spinach", source: .bundledGeneric, servingDescription: "100 g raw", servingGrams: 100, calories: 23, proteinGrams: 2.9, carbohydrateGrams: 3.6, fatGrams: 0.4, measurementState: .raw, isVerified: true)
        ]
    }
}

// MARK: - Personal adaptive model (on-device ML)

extension AppEnvironment {
    private static let maxModelHistoryDays = 365
    private static let minLoggedDayKcal = 600.0
    /// A day's food log counts as training data only if it looks complete (marked done, or ≥ 50% of target).
    private static let completeDayFraction = 0.5

    private func priorMaintenance(weightKg: Double) -> Double {
        let input = NutritionEngine.ProfileInput(
            weightKg: weightKg,
            heightCm: profile.heightCm,
            ageYears: profile.ageYears ?? 25,
            sex: profile.biologicalSex,
            goal: profile.goalPhase,
            activityBand: profile.activityBand,
            trainingDaysPerWeek: profile.trainingSchedule.trainingDaysPerWeek,
            stepTarget: profile.stepTarget,
            intraWorkoutEnabled: profile.intraWorkoutEnabled
        )
        return Double(nutritionEngine.estimatedMaintenanceCalories(for: input))
    }

    private var planAverageIntake: Double? {
        guard let targets else { return nil }
        let n = Double(profile.trainingSchedule.trainingDaysPerWeek)
        return (n * Double(targets.training.calories) + (7 - n) * Double(targets.rest.calories)) / 7
    }

    /// Turns the user's logs into the model's day-indexed training series (oldest → today).
    func adaptiveInput(asOf: Date = Date()) -> AdaptiveFitInput? {
        let end = calendar.localDate(for: asOf)
        let official = weightEntries
            .filter { $0.isOfficialMorningCheckIn && calendar.localDate(for: $0.localDate) <= end }
            .sorted { $0.localDate < $1.localDate }
        guard let firstEntry = official.first, let lastEntry = official.last else { return nil }
        let earliest = calendar.calendar.date(byAdding: .day, value: -(Self.maxModelHistoryDays - 1), to: end) ?? end
        let start = max(calendar.localDate(for: firstEntry.localDate), earliest)

        var weights: [Date: Double] = [:]
        for entry in official { weights[calendar.localDate(for: entry.localDate)] = entry.weightKg }
        var steps: [Date: Double] = [:]
        for entry in stepEntries { steps[calendar.localDate(for: entry.localDate)] = Double(entry.steps) }

        var days: [AdaptiveDay] = []
        var day = start
        while day <= end {
            var intake: Double?
            // Today only counts once marked complete — a half-logged day would look like a deficit.
            if let diary = diaries[Self.calendarKey(day)], !diary.entries.isEmpty, day < end || diary.markedComplete {
                let total = diary.totalCalories
                let training = profile.trainingSchedule.isTrainingDay(weekday(for: day))
                let target = Double(targets?.target(isTrainingDay: training).calories ?? 2000)
                if total >= Self.minLoggedDayKcal, diary.markedComplete || total >= Self.completeDayFraction * target {
                    intake = total
                }
            }
            days.append(AdaptiveDay(weightKg: weights[day], intakeKcal: intake, steps: steps[day]))
            guard let next = calendar.calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        let prior = priorMaintenance(weightKg: firstEntry.weightKg)
        return AdaptiveFitInput(
            days: days,
            priorMaintenanceKcal: prior,
            bodyWeightKg: lastEntry.weightKg,
            fallbackSteps: Double(profile.stepTarget),
            fallbackIntakeKcal: planAverageIntake ?? prior
        )
    }

    /// The trained personal model. Re-trains whenever persisted data changes or the day rolls over.
    var adaptiveModel: AdaptiveModelSnapshot? {
        let day = today
        if adaptiveCacheRevision == dataRevision, adaptiveCacheDay == day {
            return adaptiveCachedModel
        }
        let model = adaptiveInput().map { AdaptiveModel.fit($0) }
        adaptiveCacheRevision = dataRevision
        adaptiveCacheDay = day
        adaptiveCachedModel = model
        return model
    }

    var adaptiveRecommendation: AdaptiveRecommendation? {
        guard let model = adaptiveModel, let targets else { return nil }
        return AdaptiveModel.recommend(
            model,
            plan: AdaptivePlanCalories(
                trainingKcal: Double(targets.training.calories),
                restKcal: Double(targets.rest.calories),
                trainingDaysPerWeek: profile.trainingSchedule.trainingDaysPerWeek
            ),
            goal: profile.goalPhase,
            desiredWeightKg: profile.desiredWeightKg,
            steps: model.currentSteps
        )
    }

    /// Earliest time another automatic change may happen (one change per week, from any source).
    var nextAdaptiveAdjustmentDate: Date? {
        planAdjustments.first.map { $0.date.addingTimeInterval(AdaptiveConfig.minDaysBetweenAutoAdjustments * 86_400) }
    }

    var adaptiveAIContext: CoachAIModelContext? {
        guard let model = adaptiveModel, let rec = adaptiveRecommendation else { return nil }
        return CoachAIModelContext(
            maintenanceKcal: model.maintenanceKcal,
            maintenanceSD: model.maintenanceSD,
            confidence: model.confidence,
            observations: model.observations,
            predictedKgPerWeek: rec.predictedCurrent.meanKgPerWeek,
            targetKgPerWeek: rec.targetKgPerWeek,
            recommendedDeltaKcal: rec.deltaKcal
        )
    }

    /// Apply the model's recommendation. `auto` = triggered by new data: respects the auto-adjust setting,
    /// the subscription, model confidence, and the one-change-per-week limit.
    @discardableResult
    func applyAdaptiveRecommendation(auto: Bool) -> Bool {
        guard !isApplyingAdaptiveAdjustment else { return false }
        guard let rec = adaptiveRecommendation, rec.shouldAdjust, hasCoachAccess, let old = targets else { return false }
        if auto {
            guard preferences.adaptiveAutoAdjust else { return false }
            if let next = nextAdaptiveAdjustmentDate, next > Date() { return false }
        }
        isApplyingAdaptiveAdjustment = true
        defer { isApplyingAdaptiveAdjustment = false }

        var next = nutritionEngine.applyCalorieAdjustment(
            currentTraining: old.training,
            deltaCalories: rec.deltaKcal,
            weightKg: profile.currentWeightKg,
            goal: profile.goalPhase,
            sex: profile.biologicalSex
        )
        guard next.training.calories != old.training.calories else { return false } // at a safety floor
        next.training.source = .adaptiveModel
        next.rest.source = .adaptiveModel

        planAdjustments.insert(
            PlanAdjustment(
                oldCalories: old.training.calories,
                newCalories: next.training.calories,
                oldMacros: old.training.macros,
                newMacros: next.training.macros,
                oldSteps: old.training.stepTarget,
                newSteps: next.training.stepTarget,
                reason: rec.summary,
                source: .adaptiveModel,
                userApproved: !auto
            ),
            at: 0
        )
        targets = next
        generateMealPlan(forWeekContaining: today)
        coachStatusMessage = "\(auto ? "Auto-adjusted" : "Adjusted") by your personal model: \(old.training.calories) → \(next.training.calories) kcal on training days."
        chatMessages.append(
            CoachChatMessage(role: .coach, text: (auto ? "I updated your plan automatically. " : "") + rec.summary)
        )
        save()
        return true
    }

    func runAdaptiveAutoAdjust() {
        applyAdaptiveRecommendation(auto: true)
    }

    /// The rule engine keeps its safety gates (weigh-ins, adherence, extreme swings, recovery). When it would
    /// make a standard fixed-size calorie move and the model is confident, the model decides the amount.
    func blendWithAdaptiveModel(_ decision: CoachDecision) -> CoachDecision {
        guard let rec = adaptiveRecommendation, rec.confidence != .low, let training = targets?.training else {
            return decision
        }
        switch decision.action {
        case .maintain, .increaseCalories, .decreaseCalories:
            break
        default:
            return decision
        }
        var blended = decision
        blended.reasons = decision.reasons.filter { $0 != .rateOnTarget && $0 != .rateTooSlow } + [.modelPrediction]
        blended.summary = rec.summary
        blended.confidence = rec.confidence == .high ? .high : .medium
        guard rec.deltaKcal != 0 else {
            blended.action = .maintain
            return blended
        }
        let pair = nutritionEngine.applyCalorieAdjustment(
            currentTraining: training,
            deltaCalories: rec.deltaKcal,
            weightKg: profile.currentWeightKg,
            goal: profile.goalPhase,
            sex: profile.biologicalSex
        )
        blended.action = rec.deltaKcal > 0 ? .increaseCalories(rec.deltaKcal) : .decreaseCalories(-rec.deltaKcal)
        blended.secondaryActions = decision.secondaryActions.filter {
            if case .suggestRefeed = $0 { return true }
            return false
        }
        blended.suggestedTrainingCalories = pair.training.calories
        blended.suggestedRestCalories = pair.rest.calories
        blended.suggestedMacros = pair.training.macros
        return blended
    }
}

// MARK: - Tabs

enum MainTab: Hashable {
    case today
    case mealPlan
    case log
    case foods
    case workout
    case progress
    case coach
}

// MARK: - Persistence snapshot

private struct PersistedSnapshot: Codable {
    var profile: UserProfile
    var preferences: UserPreferences
    var weightEntries: [WeightEntry]
    var stepEntries: [StepEntry]
    var diaries: [DailyFoodDiary]
    var mealPlanDays: [MealPlanDay]
    var targets: NutritionTargetPair?
    var checkIns: [WeeklyCheckIn]
    var chatMessages: [CoachChatMessage]
    var planAdjustments: [PlanAdjustment]
    var photoSets: [ProgressPhotoSet]
    var customFoods: [FoodItem]
    var subscription: SubscriptionEntitlement
    var coachStatusMessage: String
    var paywallComparisonTraditionalEUR: Double
    var paywallComparisonCoachEUR: Double
    var workoutSessions: [WorkoutSession]
    var workoutTemplateOverrides: [WorkoutTemplateOverride]

    enum CodingKeys: String, CodingKey {
        case profile, preferences, weightEntries, stepEntries, diaries, mealPlanDays
        case targets, checkIns, chatMessages, planAdjustments, photoSets, customFoods
        case subscription, coachStatusMessage, paywallComparisonTraditionalEUR, paywallComparisonCoachEUR
        case workoutSessions, workoutTemplateOverrides
    }

    init(
        profile: UserProfile,
        preferences: UserPreferences,
        weightEntries: [WeightEntry],
        stepEntries: [StepEntry],
        diaries: [DailyFoodDiary],
        mealPlanDays: [MealPlanDay],
        targets: NutritionTargetPair?,
        checkIns: [WeeklyCheckIn],
        chatMessages: [CoachChatMessage],
        planAdjustments: [PlanAdjustment],
        photoSets: [ProgressPhotoSet],
        customFoods: [FoodItem],
        subscription: SubscriptionEntitlement,
        coachStatusMessage: String,
        paywallComparisonTraditionalEUR: Double,
        paywallComparisonCoachEUR: Double,
        workoutSessions: [WorkoutSession] = [],
        workoutTemplateOverrides: [WorkoutTemplateOverride] = []
    ) {
        self.profile = profile
        self.preferences = preferences
        self.weightEntries = weightEntries
        self.stepEntries = stepEntries
        self.diaries = diaries
        self.mealPlanDays = mealPlanDays
        self.targets = targets
        self.checkIns = checkIns
        self.chatMessages = chatMessages
        self.planAdjustments = planAdjustments
        self.photoSets = photoSets
        self.customFoods = customFoods
        self.subscription = subscription
        self.coachStatusMessage = coachStatusMessage
        self.paywallComparisonTraditionalEUR = paywallComparisonTraditionalEUR
        self.paywallComparisonCoachEUR = paywallComparisonCoachEUR
        self.workoutSessions = workoutSessions
        self.workoutTemplateOverrides = workoutTemplateOverrides
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profile = try c.decode(UserProfile.self, forKey: .profile)
        preferences = try c.decode(UserPreferences.self, forKey: .preferences)
        weightEntries = try c.decode([WeightEntry].self, forKey: .weightEntries)
        stepEntries = try c.decode([StepEntry].self, forKey: .stepEntries)
        diaries = try c.decode([DailyFoodDiary].self, forKey: .diaries)
        mealPlanDays = try c.decode([MealPlanDay].self, forKey: .mealPlanDays)
        targets = try c.decodeIfPresent(NutritionTargetPair.self, forKey: .targets)
        checkIns = try c.decode([WeeklyCheckIn].self, forKey: .checkIns)
        chatMessages = try c.decode([CoachChatMessage].self, forKey: .chatMessages)
        planAdjustments = try c.decode([PlanAdjustment].self, forKey: .planAdjustments)
        photoSets = try c.decode([ProgressPhotoSet].self, forKey: .photoSets)
        customFoods = try c.decode([FoodItem].self, forKey: .customFoods)
        subscription = try c.decode(SubscriptionEntitlement.self, forKey: .subscription)
        coachStatusMessage = try c.decode(String.self, forKey: .coachStatusMessage)
        paywallComparisonTraditionalEUR = try c.decode(Double.self, forKey: .paywallComparisonTraditionalEUR)
        paywallComparisonCoachEUR = try c.decode(Double.self, forKey: .paywallComparisonCoachEUR)
        workoutSessions = try c.decodeIfPresent([WorkoutSession].self, forKey: .workoutSessions) ?? []
        workoutTemplateOverrides = try c.decodeIfPresent([WorkoutTemplateOverride].self, forKey: .workoutTemplateOverrides) ?? []
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension CoachAdjustment {
    var isIncrease: Bool {
        if case .increaseCalories = self { return true }
        return false
    }
}
