import Foundation

struct NutritionEngine: Sendable {
    struct ProfileInput: Sendable {
        var weightKg: Double
        var heightCm: Double
        var ageYears: Int
        var sex: BiologicalSex
        var goal: GoalPhase
        var activityBand: ActivityBand
        var trainingDaysPerWeek: Int
        var stepTarget: Int
        var intraWorkoutEnabled: Bool
    }

    /// Mifflin–St Jeor inspired BMR estimate. Initial target only — adapts from weigh-ins later.
    func basalMetabolicRate(weightKg: Double, heightCm: Double, ageYears: Int, sex: BiologicalSex) -> Double {
        let base = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(ageYears))
        switch sex {
        case .male:
            return base + 5
        case .female:
            return base - 161
        case .preferNotToSay:
            return base - 78
        }
    }

    func activityMultiplier(band: ActivityBand, trainingDaysPerWeek: Int) -> Double {
        let trainingBoost = min(0.25, Double(trainingDaysPerWeek) * 0.03)
        let base: Double
        switch band {
        case .under4000: base = 1.2
        case .fourToSix: base = 1.35
        case .sixToEight: base = 1.45
        case .eightToTen: base = 1.55
        case .tenPlus: base = 1.65
        }
        return base + trainingBoost
    }

    func estimatedMaintenanceCalories(for input: ProfileInput) -> Int {
        let bmr = basalMetabolicRate(
            weightKg: input.weightKg,
            heightCm: input.heightCm,
            ageYears: input.ageYears,
            sex: input.sex
        )
        let tdee = bmr * activityMultiplier(band: input.activityBand, trainingDaysPerWeek: input.trainingDaysPerWeek)
        return Int(tdee.rounded())
    }

    func initialTrainingCalories(for input: ProfileInput) -> Int {
        let maintenance = estimatedMaintenanceCalories(for: input)
        let raw: Int
        switch input.goal {
        case .cut:
            raw = maintenance - 400
        case .gain:
            raw = maintenance + 250
        case .maintenance:
            raw = maintenance
        }
        return clampCalories(raw, sex: input.sex)
    }

    /// 1 g per pound of current bodyweight (≈ 2.2 g/kg), regardless of goal.
    func proteinGrams(weightKg: Double, goal: GoalPhase) -> Double {
        weightKg * CoachingConfig.proteinGramsPerKg
    }

    func fatGrams(weightKg: Double, goal: GoalPhase) -> Double {
        let perKg: Double
        switch goal {
        case .cut: perKg = CoachingConfig.fatGramsPerKgCut
        case .gain: perKg = CoachingConfig.fatGramsPerKgGain
        case .maintenance: perKg = (CoachingConfig.fatGramsPerKgCut + CoachingConfig.fatGramsPerKgGain) / 2
        }
        return max(weightKg * CoachingConfig.minimumFatGramsPerKg, weightKg * perKg)
    }

    func macros(forCalories calories: Int, weightKg: Double, goal: GoalPhase) -> MacroGrams {
        let protein = proteinGrams(weightKg: weightKg, goal: goal)
        let fat = fatGrams(weightKg: weightKg, goal: goal)
        let carbs = NutritionMath.carbohydratesFromRemainingCalories(
            totalCalories: Double(calories),
            proteinGrams: protein,
            fatGrams: fat
        )
        return MacroGrams(protein: protein, carbohydrates: max(0, carbs), fat: fat)
    }

    /// Rest day ideally ~500 kcal below training, primarily from carbohydrate.
    /// If constraints would be violated, shrink the deficit rather than cutting protein/fat unsafely.
    func restDayTarget(
        fromTraining training: DailyNutritionTarget,
        weightKg: Double,
        goal: GoalPhase,
        sex: BiologicalSex
    ) -> DailyNutritionTarget {
        let desired = training.calories - CoachingConfig.restDayCalorieDeficit
        let floored = clampCalories(desired, sex: sex)
        var protein = training.macros.protein
        var fat = max(training.macros.fat, weightKg * CoachingConfig.minimumFatGramsPerKg)
        let minCaloriesForPF = Int((
            protein * CoachingConfig.caloriesPerGramProtein
                + fat * CoachingConfig.caloriesPerGramFat
        ).rounded(.up))
        let restCalories = max(floored, minCaloriesForPF)
        let carbs = NutritionMath.carbohydratesFromRemainingCalories(
            totalCalories: Double(restCalories),
            proteinGrams: protein,
            fatGrams: fat
        )
        // Protein stays approximately unchanged; difference comes from carbs.
        return DailyNutritionTarget(
            calories: restCalories,
            macros: MacroGrams(protein: protein, carbohydrates: max(0, carbs), fat: fat),
            isTrainingDay: false,
            stepTarget: training.stepTarget,
            source: training.source,
            includesIntraWorkout: false
        )
    }

    func buildInitialTargets(for input: ProfileInput) -> NutritionTargetPair {
        let cappedSteps = cappedStepTarget(input.stepTarget)
        let trainingCalories = initialTrainingCalories(for: input)
        let trainingMacros = macros(forCalories: trainingCalories, weightKg: input.weightKg, goal: input.goal)
        let training = DailyNutritionTarget(
            calories: trainingCalories,
            macros: trainingMacros,
            isTrainingDay: true,
            stepTarget: cappedSteps,
            source: .engine,
            includesIntraWorkout: input.intraWorkoutEnabled
        )
        let rest = restDayTarget(fromTraining: training, weightKg: input.weightKg, goal: input.goal, sex: input.sex)
        return NutritionTargetPair(training: training, rest: rest)
    }

    func cappedStepTarget(_ requested: Int) -> Int {
        max(0, min(requested, CoachingConfig.maxStepTarget))
    }

    func adjustedStepTarget(current: Int, delta: Int) -> Int {
        cappedStepTarget(current + delta)
    }

    func applyCalorieAdjustment(
        currentTraining: DailyNutritionTarget,
        deltaCalories: Int,
        weightKg: Double,
        goal: GoalPhase,
        sex: BiologicalSex
    ) -> NutritionTargetPair {
        let boundedDelta = min(
            abs(deltaCalories),
            CoachingConfig.maximumSingleWeekCalorieChange
        ) * (deltaCalories >= 0 ? 1 : -1)
        let newCalories = clampCalories(currentTraining.calories + boundedDelta, sex: sex)
        let newMacros = macros(forCalories: newCalories, weightKg: weightKg, goal: goal)
        let training = DailyNutritionTarget(
            calories: newCalories,
            macros: newMacros,
            isTrainingDay: true,
            stepTarget: currentTraining.stepTarget,
            source: .coachRecommendation,
            includesIntraWorkout: currentTraining.includesIntraWorkout
        )
        let rest = restDayTarget(fromTraining: training, weightKg: weightKg, goal: goal, sex: sex)
        return NutritionTargetPair(training: training, rest: rest)
    }

    func clampCalories(_ value: Int, sex: BiologicalSex) -> Int {
        let floor: Int
        switch sex {
        case .male: floor = CoachingConfig.absoluteMinimumDailyCaloriesMale
        case .female: floor = CoachingConfig.absoluteMinimumDailyCaloriesFemale
        case .preferNotToSay: floor = CoachingConfig.absoluteMinimumDailyCaloriesUnspecified
        }
        return max(floor, value)
    }

    // MARK: - Adaptive maintenance

    /// Uses observed weekly rate and reported intake to refine maintenance estimate when enough data exists.
    func adaptiveMaintenanceEstimate(
        averageDailyIntake: Double,
        weeklyRateKg: Double,
        weeksOfData: Int
    ) -> Double? {
        guard weeksOfData >= 2 else { return nil }
        // ~7700 kcal ≈ 1 kg body mass (heuristic, not medical truth)
        let dailySurplus = (weeklyRateKg * 7700.0) / 7.0
        return averageDailyIntake - dailySurplus
    }

    // MARK: - Intra-workout

    struct IntraWorkoutTargets: Equatable, Sendable {
        var eaaGrams: Double
        var dextroseGrams: Double
        var waterMillilitersRange: ClosedRange<Int>
    }

    func intraWorkoutTargets(weightKg: Double, goal: GoalPhase) -> IntraWorkoutTargets {
        let eaa = min(
            CoachingConfig.maximumEAAGrams,
            max(CoachingConfig.minimumEAAGrams, weightKg * CoachingConfig.eaaGramsPerKgTraining)
        )
        let dextrosePerKg = goal == .gain
            ? CoachingConfig.dextroseGramsPerKgGain
            : CoachingConfig.dextroseGramsPerKgCut
        let dextrose = min(
            CoachingConfig.maximumDextroseGrams,
            max(CoachingConfig.minimumDextroseGrams, weightKg * dextrosePerKg)
        )
        return IntraWorkoutTargets(
            eaaGrams: eaa.rounded(),
            dextroseGrams: dextrose.rounded(),
            waterMillilitersRange: 750...1000
        )
    }

    /// Custom food calorie-only rescale helper (solver may refine further for full macros).
    func rescaleGramsForCalories(targetCalories: Double, customCaloriesPer100g: Double) -> Double {
        guard customCaloriesPer100g > 0 else { return 0 }
        return targetCalories / customCaloriesPer100g * 100.0
    }
}
