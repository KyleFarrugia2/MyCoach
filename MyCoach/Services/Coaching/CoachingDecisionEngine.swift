import Foundation

struct CoachingDecisionEngine: Sendable {
    struct Input: Sendable {
        var goal: GoalPhase
        var previousWeek: CoachingWeek
        var currentWeek: CoachingWeek
        var rate: WeeklyRateOfChange?
        var currentTrainingCalories: Int
        var currentRestCalories: Int
        var currentMacros: MacroGrams
        var stepTarget: Int
        var adherence: AdherenceBand
        var performance: TrainingPerformance
        var appearance: AppearanceFeedback
        var hunger: Int
        var energy: Int
        var weightKg: Double
        var sex: BiologicalSex
        var recentRefeed: Bool
    }

    private let nutrition = NutritionEngine()

    func evaluate(_ input: Input) -> CoachDecision {
        let weekStart = input.currentWeek.startDate

        // Insufficient weigh-ins — never punish, never adjust strongly.
        if input.currentWeek.completeness == .empty
            || input.currentWeek.completeness == .insufficientForAdjustment
            || input.rate == nil {
            return CoachDecision(
                weekStart: weekStart,
                action: .requireMoreData,
                confidence: .low,
                reasons: [.insufficientWeighIns],
                summary: "Not enough consistent weigh-ins to confidently adjust your plan this week."
            )
        }

        guard let rate = input.rate else {
            return CoachDecision(
                weekStart: weekStart,
                action: .requireMoreData,
                confidence: .low,
                reasons: [.insufficientWeighIns],
                summary: "Not enough consistent weigh-ins to confidently adjust your plan this week."
            )
        }

        // Poor adherence — do not modify calories from weight noise.
        if input.adherence.isPoor {
            return CoachDecision(
                weekStart: weekStart,
                action: .reviewAdherence,
                confidence: .medium,
                reasons: [.poorAdherence],
                summary: "Your current plan hasn't had enough consistent execution for me to confidently change calories."
            )
        }

        // Extreme weekly change (> 1.5 kg) — review, do not blindly slash/add.
        if abs(rate.absoluteChangeKg) > CoachingConfig.extremeWeeklyChangeKg {
            return extremeChangeDecision(input: input, rate: rate, weekStart: weekStart)
        }

        // Edge: exactly 1.5 kg — still flag for review awareness but allow measured response.
        if abs(rate.absoluteChangeKg) == CoachingConfig.extremeWeeklyChangeKg {
            return extremeChangeDecision(input: input, rate: rate, weekStart: weekStart, exactThreshold: true)
        }

        return standardDecision(input: input, rate: rate, weekStart: weekStart)
    }

    private func extremeChangeDecision(
        input: Input,
        rate: WeeklyRateOfChange,
        weekStart: Date,
        exactThreshold: Bool = false
    ) -> CoachDecision {
        var reasons: [CoachReasonCode] = [.extremeWeeklyChange]
        let changeText = String(format: "%.1f", abs(rate.absoluteChangeKg))

        switch input.goal {
        case .cut:
            if rate.absoluteChangeKg < 0 {
                reasons.append(.rateTooFastLoss)
                if input.appearance == .flatter { reasons.append(.appearanceFlat) }
                if input.performance == .slightlyWorse || input.performance == .muchWorse {
                    reasons.append(.performanceDeclining)
                }
                let pair = nutrition.applyCalorieAdjustment(
                    currentTraining: DailyNutritionTarget(
                        calories: input.currentTrainingCalories,
                        macros: input.currentMacros,
                        isTrainingDay: true,
                        stepTarget: input.stepTarget
                    ),
                    deltaCalories: CoachingConfig.largeCalorieAdjustment,
                    weightKg: input.weightKg,
                    goal: input.goal,
                    sex: input.sex
                )
                var secondary: [CoachAdjustment] = []
                var refeed: RefeedPlan?
                if shouldSuggestRefeed(input: input, rate: rate) {
                    secondary.append(.suggestRefeed)
                    refeed = makeRefeed(from: pair.training, weightKg: input.weightKg, goal: input.goal)
                }
                return CoachDecision(
                    weekStart: weekStart,
                    action: .recommendNutritionIncreaseReview,
                    secondaryActions: secondary + [.increaseCalories(CoachingConfig.largeCalorieAdjustment)],
                    confidence: exactThreshold ? .medium : .high,
                    reasons: reasons,
                    summary: "Your weekly average decreased by \(changeText) kg. Before reducing food further, let's review recovery, appearance and adherence.",
                    suggestedTrainingCalories: pair.training.calories,
                    suggestedRestCalories: pair.rest.calories,
                    suggestedMacros: pair.training.macros,
                    suggestedSteps: input.stepTarget,
                    refeed: refeed
                )
            } else {
                // Weight up on a cut — do not slash immediately.
                reasons.append(.appearanceSoft)
                return CoachDecision(
                    weekStart: weekStart,
                    action: .reviewRecovery,
                    confidence: .medium,
                    reasons: reasons,
                    summary: "Weight rose \(changeText) kg on your weekly average during a cut. We'll review adherence, sodium, sleep and unusual meals before changing food."
                )
            }

        case .gain:
            if rate.absoluteChangeKg > 0 {
                reasons.append(.rateTooFastGain)
                let pair = nutrition.applyCalorieAdjustment(
                    currentTraining: DailyNutritionTarget(
                        calories: input.currentTrainingCalories,
                        macros: input.currentMacros,
                        isTrainingDay: true,
                        stepTarget: input.stepTarget
                    ),
                    deltaCalories: -CoachingConfig.largeCalorieAdjustment,
                    weightKg: input.weightKg,
                    goal: input.goal,
                    sex: input.sex
                )
                return CoachDecision(
                    weekStart: weekStart,
                    action: .recommendNutritionDecreaseReview,
                    secondaryActions: [.decreaseCalories(CoachingConfig.largeCalorieAdjustment)],
                    confidence: exactThreshold ? .medium : .high,
                    reasons: reasons,
                    summary: "You gained \(changeText) kg on your weekly average. Let's review your physique and adherence before adding any more food.",
                    suggestedTrainingCalories: pair.training.calories,
                    suggestedRestCalories: pair.rest.calories,
                    suggestedMacros: pair.training.macros,
                    suggestedSteps: input.stepTarget
                )
            } else {
                reasons.append(.rateTooSlow)
                let pair = nutrition.applyCalorieAdjustment(
                    currentTraining: DailyNutritionTarget(
                        calories: input.currentTrainingCalories,
                        macros: input.currentMacros,
                        isTrainingDay: true,
                        stepTarget: input.stepTarget
                    ),
                    deltaCalories: CoachingConfig.defaultCalorieAdjustment,
                    weightKg: input.weightKg,
                    goal: input.goal,
                    sex: input.sex
                )
                return CoachDecision(
                    weekStart: weekStart,
                    action: .recommendNutritionIncreaseReview,
                    secondaryActions: [.increaseCalories(CoachingConfig.defaultCalorieAdjustment)],
                    confidence: .medium,
                    reasons: reasons,
                    summary: "Weight fell during a gaining phase. With solid adherence, increasing food — primarily carbohydrates — is the measured next step.",
                    suggestedTrainingCalories: pair.training.calories,
                    suggestedRestCalories: pair.rest.calories,
                    suggestedMacros: pair.training.macros,
                    suggestedSteps: input.stepTarget
                )
            }

        case .maintenance:
            return CoachDecision(
                weekStart: weekStart,
                action: .reviewRecovery,
                confidence: .medium,
                reasons: reasons,
                summary: "Weekly change of \(changeText) kg is larger than expected for maintenance. Review adherence before adjusting."
            )
        }
    }

    private func standardDecision(input: Input, rate: WeeklyRateOfChange, weekStart: Date) -> CoachDecision {
        var reasons: [CoachReasonCode] = []
        if input.adherence.isHigh { reasons.append(.highAdherence) }
        if input.performance == .same || input.performance == .better || input.performance == .muchBetter {
            reasons.append(.performanceStable)
        }

        switch input.goal {
        case .cut:
            // Healthy loss roughly 0.25–1.0 kg/week depending on size; treat near-target as maintain.
            if rate.absoluteChangeKg <= -0.25 && rate.absoluteChangeKg >= -1.2 {
                reasons.append(.rateOnTarget)
                var secondary: [CoachAdjustment] = []
                var refeed: RefeedPlan?
                if shouldSuggestRefeed(input: input, rate: rate) {
                    secondary.append(.suggestRefeed)
                    let training = DailyNutritionTarget(
                        calories: input.currentTrainingCalories,
                        macros: input.currentMacros,
                        isTrainingDay: true,
                        stepTarget: input.stepTarget
                    )
                    refeed = makeRefeed(from: training, weightKg: input.weightKg, goal: input.goal)
                }
                return CoachDecision(
                    weekStart: weekStart,
                    action: .maintain,
                    secondaryActions: secondary,
                    confidence: .high,
                    reasons: reasons + (input.appearance == .flatter ? [.appearanceFlat] : []),
                    summary: "Right on target. No calorie adjustment.",
                    suggestedTrainingCalories: input.currentTrainingCalories,
                    suggestedRestCalories: input.currentRestCalories,
                    suggestedMacros: input.currentMacros,
                    suggestedSteps: input.stepTarget,
                    refeed: refeed
                )
            }

            if rate.absoluteChangeKg > 0.2 && input.adherence.isHigh {
                // Modest deficit or steps — never exceed step cap.
                let stepDelta = CoachingConfig.defaultStepIncrement
                let newSteps = nutrition.adjustedStepTarget(current: input.stepTarget, delta: stepDelta)
                if newSteps == input.stepTarget && input.stepTarget >= CoachingConfig.maxStepTarget {
                    reasons.append(.stepCapReached)
                    let pair = nutrition.applyCalorieAdjustment(
                        currentTraining: DailyNutritionTarget(
                            calories: input.currentTrainingCalories,
                            macros: input.currentMacros,
                            isTrainingDay: true,
                            stepTarget: input.stepTarget
                        ),
                        deltaCalories: -CoachingConfig.defaultCalorieAdjustment,
                        weightKg: input.weightKg,
                        goal: input.goal,
                        sex: input.sex
                    )
                    return CoachDecision(
                        weekStart: weekStart,
                        action: .decreaseCalories(CoachingConfig.defaultCalorieAdjustment),
                        confidence: .medium,
                        reasons: reasons,
                        summary: "Trend is stalled upward with strong adherence. Modest calorie reduction primarily from carbohydrates.",
                        suggestedTrainingCalories: pair.training.calories,
                        suggestedRestCalories: pair.rest.calories,
                        suggestedMacros: pair.training.macros,
                        suggestedSteps: input.stepTarget
                    )
                }
                return CoachDecision(
                    weekStart: weekStart,
                    action: .increaseSteps(stepDelta),
                    confidence: .medium,
                    reasons: reasons,
                    summary: "Weight trend is flat/up with strong adherence. A gradual step increase is preferred before cutting food.",
                    suggestedTrainingCalories: input.currentTrainingCalories,
                    suggestedRestCalories: input.currentRestCalories,
                    suggestedMacros: input.currentMacros,
                    suggestedSteps: newSteps
                )
            }

            if rate.absoluteChangeKg > -0.2 {
                reasons.append(.rateTooSlow)
                return CoachDecision(
                    weekStart: weekStart,
                    action: .maintain,
                    confidence: .medium,
                    reasons: reasons,
                    summary: "Loss is slower than ideal this week. Hold calories and reassess next week unless the trend persists.",
                    suggestedTrainingCalories: input.currentTrainingCalories,
                    suggestedRestCalories: input.currentRestCalories,
                    suggestedMacros: input.currentMacros,
                    suggestedSteps: input.stepTarget
                )
            }

        case .gain:
            if rate.absoluteChangeKg >= 0.15 && rate.absoluteChangeKg <= 0.75 {
                reasons.append(.rateOnTarget)
                if input.appearance == .better { reasons.append(.appearanceImproving) }
                return CoachDecision(
                    weekStart: weekStart,
                    action: .maintain,
                    confidence: .high,
                    reasons: reasons,
                    summary: "Right on target. No calorie adjustment.",
                    suggestedTrainingCalories: input.currentTrainingCalories,
                    suggestedRestCalories: input.currentRestCalories,
                    suggestedMacros: input.currentMacros,
                    suggestedSteps: input.stepTarget
                )
            }
            if rate.absoluteChangeKg < 0 && input.adherence.isHigh {
                let pair = nutrition.applyCalorieAdjustment(
                    currentTraining: DailyNutritionTarget(
                        calories: input.currentTrainingCalories,
                        macros: input.currentMacros,
                        isTrainingDay: true,
                        stepTarget: input.stepTarget
                    ),
                    deltaCalories: CoachingConfig.defaultCalorieAdjustment,
                    weightKg: input.weightKg,
                    goal: input.goal,
                    sex: input.sex
                )
                return CoachDecision(
                    weekStart: weekStart,
                    action: .increaseCalories(CoachingConfig.defaultCalorieAdjustment),
                    confidence: .medium,
                    reasons: reasons + [.rateTooSlow],
                    summary: "Weight drifted down while gaining. Increase calories primarily from carbohydrates.",
                    suggestedTrainingCalories: pair.training.calories,
                    suggestedRestCalories: pair.rest.calories,
                    suggestedMacros: pair.training.macros,
                    suggestedSteps: input.stepTarget
                )
            }

        case .maintenance:
            reasons.append(.rateOnTarget)
            return CoachDecision(
                weekStart: weekStart,
                action: .maintain,
                confidence: .medium,
                reasons: reasons,
                summary: "Hold the current plan and monitor the weekly average.",
                suggestedTrainingCalories: input.currentTrainingCalories,
                suggestedRestCalories: input.currentRestCalories,
                suggestedMacros: input.currentMacros,
                suggestedSteps: input.stepTarget
            )
        }

        reasons.append(.rateOnTarget)
        return CoachDecision(
            weekStart: weekStart,
            action: .maintain,
            confidence: .medium,
            reasons: reasons,
            summary: "Hold steady. Consistency beats reacting to one noisy week.",
            suggestedTrainingCalories: input.currentTrainingCalories,
            suggestedRestCalories: input.currentRestCalories,
            suggestedMacros: input.currentMacros,
            suggestedSteps: input.stepTarget
        )
    }

    private func shouldSuggestRefeed(input: Input, rate: WeeklyRateOfChange) -> Bool {
        guard input.goal == .cut, input.adherence.isHigh, !input.recentRefeed else { return false }
        let losing = rate.absoluteChangeKg < -0.3
        let flatOrTired = input.appearance == .flatter
            || input.performance == .slightlyWorse
            || input.performance == .muchWorse
            || input.hunger >= 4
            || input.energy <= 2
        return losing && flatOrTired
    }

    private func makeRefeed(from normal: DailyNutritionTarget, weightKg: Double, goal: GoalPhase) -> RefeedPlan {
        let bump = CoachingConfig.largeCalorieAdjustment + 100
        let refeedCalories = normal.calories + bump
        let protein = normal.macros.protein
        let fat = max(normal.macros.fat, weightKg * CoachingConfig.minimumFatGramsPerKg)
        let carbs = NutritionMath.carbohydratesFromRemainingCalories(
            totalCalories: Double(refeedCalories),
            proteinGrams: protein,
            fatGrams: fat
        )
        let refeedTarget = DailyNutritionTarget(
            calories: refeedCalories,
            macros: MacroGrams(protein: protein, carbohydrates: carbs, fat: fat),
            isTrainingDay: true,
            stepTarget: normal.stepTarget,
            source: .coachRecommendation,
            includesIntraWorkout: normal.includesIntraWorkout
        )
        return RefeedPlan(
            normalTarget: normal,
            refeedTarget: refeedTarget,
            reason: "A higher-carbohydrate day may help support training performance and adherence."
        )
    }
}
