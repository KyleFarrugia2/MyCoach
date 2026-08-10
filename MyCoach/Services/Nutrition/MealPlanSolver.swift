import Foundation

/// Deterministic constrained meal optimizer.
/// Priority: allergen safety → calories → protein → carbohydrate → fat → practical portions.
struct MealPlanSolver: Sendable {
    struct Request: Sendable {
        var target: DailyNutritionTarget
        var meals: [Meal]
        var bannedAllergies: Set<FoodAllergy>
        var calorieToleranceFraction: Double
        var macroToleranceGrams: Double

        init(
            target: DailyNutritionTarget,
            meals: [Meal],
            bannedAllergies: Set<FoodAllergy> = [],
            calorieToleranceFraction: Double = CoachingConfig.calorieToleranceFraction,
            macroToleranceGrams: Double = CoachingConfig.macroToleranceGrams
        ) {
            self.target = target
            self.meals = meals
            self.bannedAllergies = bannedAllergies.filter { $0 != .none }
            self.calorieToleranceFraction = calorieToleranceFraction
            self.macroToleranceGrams = macroToleranceGrams
        }
    }

    struct Result: Sendable {
        var meals: [Meal]
        var achievedCalories: Double
        var achievedMacros: MacroGrams
        var withinTolerance: Bool
        var message: String?
        var blockedByAllergen: Bool
    }

    func solve(_ request: Request) -> Result {
        // Hard allergen constraint.
        for meal in request.meals {
            for item in meal.items {
                if !item.food.allergenTags.isDisjoint(with: request.bannedAllergies) {
                    return Result(
                        meals: request.meals,
                        achievedCalories: request.meals.reduce(0) { $0 + $1.totalCalories },
                        achievedMacros: request.meals.reduce(.zero) { $0 + $1.totalMacros },
                        withinTolerance: false,
                        message: "A selected food conflicts with your allergy constraints and was not adjusted.",
                        blockedByAllergen: true
                    )
                }
            }
        }

        var meals = request.meals.map { normalizePracticalBounds($0) }

        // Iteratively scale unlocked flexible foods toward daily targets.
        for _ in 0..<12 {
            let totals = aggregate(meals)
            let calorieError = Double(request.target.calories) - totals.calories
            let proteinError = request.target.macros.protein - totals.macros.protein
            let carbError = request.target.macros.carbohydrates - totals.macros.carbohydrates
            let fatError = request.target.macros.fat - totals.macros.fat

            if withinTolerance(
                calorieError: calorieError,
                proteinError: proteinError,
                carbError: carbError,
                fatError: fatError,
                request: request
            ) {
                break
            }

            meals = adjustMeals(
                meals,
                calorieError: calorieError,
                proteinError: proteinError,
                carbError: carbError,
                fatError: fatError
            )
        }

        let finalTotals = aggregate(meals)
        let calorieError = Double(request.target.calories) - finalTotals.calories
        let ok = withinTolerance(
            calorieError: calorieError,
            proteinError: request.target.macros.protein - finalTotals.macros.protein,
            carbError: request.target.macros.carbohydrates - finalTotals.macros.carbohydrates,
            fatError: request.target.macros.fat - finalTotals.macros.fat,
            request: request
        )

        var message: String?
        if !ok {
            message = "Exact matching isn't mathematically possible with the current foods and locked amounts. Quantities are as close as practical constraints allow."
        }

        return Result(
            meals: meals,
            achievedCalories: finalTotals.calories,
            achievedMacros: finalTotals.macros,
            withinTolerance: ok,
            message: message,
            blockedByAllergen: false
        )
    }

    /// Recalculate a single food quantity after custom nutrition changes (calorie-primary with macro awareness).
    func rescaleItem(
        _ item: MealItem,
        targetCalories: Double,
        siblingFlexibleItems: [MealItem],
        mealMacroTarget: MacroGrams?,
        bannedAllergies: Set<FoodAllergy>
    ) -> (item: MealItem, siblings: [MealItem], message: String) {
        let banned = bannedAllergies.filter { $0 != .none }
        if !item.food.allergenTags.isDisjoint(with: banned) {
            return (item, siblingFlexibleItems, "This food conflicts with your allergy settings.")
        }

        guard let per = item.food.nutritionPerGram(), per.calories > 0 else {
            return (item, siblingFlexibleItems, "This food isn't gram-scalable; servings were left unchanged.")
        }

        var grams = targetCalories / per.calories
        grams = min(max(grams, CoachingConfig.minimumPracticalFoodGrams), CoachingConfig.maximumPracticalFoodGrams)
        let scaled = item.food.scaled(toGrams: grams)!
        var updated = item
        updated.grams = grams
        updated.calories = scaled.calories
        updated.macros = scaled.macros

        // Distribute remaining meal macro gap across unlocked siblings if a meal target is provided.
        var siblings = siblingFlexibleItems
        if let mealMacroTarget {
            let remaining = MacroGrams(
                protein: max(0, mealMacroTarget.protein - updated.macros.protein),
                carbohydrates: max(0, mealMacroTarget.carbohydrates - updated.macros.carbohydrates),
                fat: max(0, mealMacroTarget.fat - updated.macros.fat)
            )
            let remainingCalories = max(0, (mealMacroTarget.calorieEstimate) - updated.calories)
            siblings = redistribute(siblings, calories: remainingCalories, macros: remaining)
        }

        return (updated, siblings, "Updated to match your \(item.food.name.lowercased())'s nutrition label.")
    }

    // MARK: - Internals

    private func aggregate(_ meals: [Meal]) -> (calories: Double, macros: MacroGrams) {
        (
            meals.reduce(0) { $0 + $1.totalCalories },
            meals.reduce(.zero) { $0 + $1.totalMacros }
        )
    }

    private func withinTolerance(
        calorieError: Double,
        proteinError: Double,
        carbError: Double,
        fatError: Double,
        request: Request
    ) -> Bool {
        let calorieOK = abs(calorieError) <= Double(request.target.calories) * request.calorieToleranceFraction
        let proteinOK = abs(proteinError) <= request.macroToleranceGrams
        let carbOK = abs(carbError) <= request.macroToleranceGrams * 1.5
        let fatOK = abs(fatError) <= request.macroToleranceGrams
        return calorieOK && proteinOK && carbOK && fatOK
    }

    private func normalizePracticalBounds(_ meal: Meal) -> Meal {
        var copy = meal
        copy.items = meal.items.map { item in
            guard !item.isLocked, let grams = item.grams, let scaled = item.food.scaled(toGrams: clampGrams(grams)) else {
                return item
            }
            var next = item
            next.grams = clampGrams(grams)
            next.calories = scaled.calories
            next.macros = scaled.macros
            return next
        }
        return copy
    }

    private func clampGrams(_ grams: Double) -> Double {
        min(max(grams, CoachingConfig.minimumPracticalFoodGrams), CoachingConfig.maximumPracticalFoodGrams)
    }

    private func adjustMeals(
        _ meals: [Meal],
        calorieError: Double,
        proteinError: Double,
        carbError: Double,
        fatError: Double
    ) -> [Meal] {
        meals.map { meal in
            var copy = meal
            copy.items = meal.items.map { item in
                guard !item.isLocked, let grams = item.grams, let per = item.food.nutritionPerGram() else {
                    return item
                }

                // Weight adjustments by which macro the food contributes most to.
                var factor = 1.0
                let dominance = dominantMacro(per: per)
                switch dominance {
                case .protein:
                    if abs(proteinError) > 1 { factor += (proteinError / max(1, item.macros.protein)) * 0.25 }
                case .carbohydrates:
                    if abs(carbError) > 1 { factor += (carbError / max(1, item.macros.carbohydrates)) * 0.25 }
                case .fat:
                    if abs(fatError) > 1 { factor += (fatError / max(1, item.macros.fat)) * 0.2 }
                }
                if abs(calorieError) > 10 {
                    factor += (calorieError / max(1, item.calories)) * 0.15
                }
                factor = min(max(factor, 0.7), 1.35)

                let newGrams = clampGrams(grams * factor)
                guard let scaled = item.food.scaled(toGrams: newGrams) else { return item }
                var next = item
                next.grams = newGrams
                next.calories = scaled.calories
                next.macros = scaled.macros
                return next
            }
            return copy
        }
    }

    private enum Dominant { case protein, carbohydrates, fat }

    private func dominantMacro(per: (calories: Double, protein: Double, carbs: Double, fat: Double)) -> Dominant {
        let p = per.protein * 4
        let c = per.carbs * 4
        let f = per.fat * 9
        if p >= c && p >= f { return .protein }
        if f >= c && f >= p { return .fat }
        return .carbohydrates
    }

    private func redistribute(_ items: [MealItem], calories: Double, macros: MacroGrams) -> [MealItem] {
        let flexible = items.filter { !$0.isLocked && $0.food.nutritionPerGram() != nil }
        guard !flexible.isEmpty else { return items }
        let shareCalories = calories / Double(flexible.count)
        return items.map { item in
            guard !item.isLocked, let per = item.food.nutritionPerGram(), per.calories > 0 else { return item }
            let grams = clampGrams(shareCalories / per.calories)
            guard let scaled = item.food.scaled(toGrams: grams) else { return item }
            var next = item
            next.grams = grams
            next.calories = scaled.calories
            next.macros = scaled.macros
            return next
        }
    }
}

struct MealPlanGenerator: Sendable {
    private let solver = MealPlanSolver()
    private let nutrition = NutritionEngine()

    func generateDay(
        date: Date,
        weekday: Weekday,
        isTrainingDay: Bool,
        target: DailyNutritionTarget,
        preferredFoods: [FoodItem],
        allergies: Set<FoodAllergy>,
        mealCount: Int,
        trainingTime: TrainingTimePreference,
        intraWorkoutEnabled: Bool,
        weightKg: Double,
        goal: GoalPhase
    ) -> MealPlanDay {
        let safeFoods = preferredFoods.filter { food in
            let banned = allergies.filter { $0 != .none }
            return food.allergenTags.isDisjoint(with: banned)
        }

        let proteinFoods = safeFoods.filter { ($0.proteinGrams ?? 0) >= 15 }
        let carbFoods = safeFoods.filter { ($0.carbohydrateGrams ?? 0) >= 15 && ($0.fatGrams ?? 0) < 15 }
        let fatFoods = safeFoods.filter { ($0.fatGrams ?? 0) >= 5 }
        let vegFoods = safeFoods.filter { $0.name.lowercased().contains("vegetable") || $0.name.lowercased().contains("spinach") || $0.name.lowercased().contains("broccoli") }

        var meals: [Meal] = []
        let slots = mealSlots(mealCount: mealCount, isTrainingDay: isTrainingDay, intraWorkoutEnabled: intraWorkoutEnabled, trainingTime: trainingTime)
        let perMealCalories = Double(target.calories) / Double(max(slots.count, 1))

        for (index, slot) in slots.enumerated() {
            let protein = proteinFoods[safeIndex(index, count: proteinFoods.count)] ?? defaultChicken()
            let carb = carbFoods[safeIndex(index, count: carbFoods.count)] ?? defaultRice()
            let veg = vegFoods.first ?? defaultVegetables()
            let fat = fatFoods.first

            var items: [MealItem] = []
            let proteinCalories = perMealCalories * 0.35
            let carbCalories = perMealCalories * 0.50
            let fatCalories = perMealCalories * 0.15

            if let p = protein.nutritionPerGram(), p.calories > 0, let scaled = protein.scaled(toGrams: proteinCalories / p.calories) {
                let g = min(max(proteinCalories / p.calories, 40), 300)
                let s = protein.scaled(toGrams: g) ?? scaled
                items.append(MealItem(food: protein, grams: g, calories: s.calories, macros: s.macros))
            }
            if let c = carb.nutritionPerGram(), c.calories > 0 {
                let g = min(max(carbCalories / c.calories, 30), 400)
                if let s = carb.scaled(toGrams: g) {
                    items.append(MealItem(food: carb, grams: g, calories: s.calories, macros: s.macros))
                }
            }
            if let v = veg.nutritionPerGram(), let s = veg.scaled(toGrams: 100) {
                items.append(MealItem(food: veg, grams: 100, calories: s.calories, macros: s.macros))
            }
            if slot == .breakfast || slot == .snack, let fat, let f = fat.nutritionPerGram(), f.calories > 0 {
                let g = min(max(fatCalories / f.calories, 5), 40)
                if let s = fat.scaled(toGrams: g) {
                    items.append(MealItem(food: fat, grams: g, calories: s.calories, macros: s.macros))
                }
            }

            // Fold optional intra nutrition into the Pre Workout / Intra Workout meal.
            if slot == .preWorkout, intraWorkoutEnabled {
                items.append(contentsOf: intraWorkoutItems(weightKg: weightKg, goal: goal))
            }

            meals.append(Meal(
                slot: slot,
                name: slot.displayName,
                scheduledTimeMinutes: timeForSlot(slot, trainingTime: trainingTime, index: index),
                items: items
            ))
        }

        let solved = solver.solve(MealPlanSolver.Request(target: target, meals: meals, bannedAllergies: allergies))
        return MealPlanDay(
            localDate: date,
            weekday: weekday,
            isTrainingDay: isTrainingDay,
            target: target,
            meals: solved.meals,
            solverMessage: solved.message
        )
    }

    private func intraWorkoutItems(weightKg: Double, goal: GoalPhase) -> [MealItem] {
        let intra = nutrition.intraWorkoutTargets(weightKg: weightKg, goal: goal)
        let dextrose = FoodItem(
            name: "Dextrose",
            source: .bundledGeneric,
            servingDescription: "100 g dry",
            servingGrams: 100,
            calories: 380,
            proteinGrams: 0,
            carbohydrateGrams: 95,
            fatGrams: 0,
            measurementState: .dry,
            isVerified: true
        )
        let eaa = FoodItem(
            name: "EAAs",
            source: .bundledGeneric,
            servingDescription: "10 g serving",
            servingGrams: 10,
            calories: 40,
            proteinGrams: 10,
            carbohydrateGrams: 0,
            fatGrams: 0,
            measurementState: .serving,
            isVerified: true
        )
        var items: [MealItem] = []
        if let d = dextrose.scaled(toGrams: intra.dextroseGrams) {
            items.append(MealItem(food: dextrose, grams: intra.dextroseGrams, calories: d.calories, macros: d.macros))
        }
        if let e = eaa.scaled(toGrams: intra.eaaGrams) {
            items.append(MealItem(food: eaa, grams: intra.eaaGrams, calories: e.calories, macros: e.macros))
        }
        return items
    }

    private func mealSlots(
        mealCount: Int,
        isTrainingDay: Bool,
        intraWorkoutEnabled: Bool,
        trainingTime: TrainingTimePreference
    ) -> [MealSlot] {
        _ = mealCount
        _ = trainingTime
        _ = intraWorkoutEnabled
        return MealSlot.slots(isTrainingDay: isTrainingDay)
    }

    private func timeForSlot(_ slot: MealSlot, trainingTime: TrainingTimePreference, index: Int) -> Int {
        let trainingMinutes: Int
        switch trainingTime {
        case .morning: trainingMinutes = 8 * 60
        case .midday: trainingMinutes = 12 * 60
        case .afternoon: trainingMinutes = 15 * 60
        case .evening: trainingMinutes = 18 * 60
        case .variable: trainingMinutes = 17 * 60
        }
        switch slot {
        case .breakfast: return 8 * 60
        case .snack: return 10 * 60 + 30
        case .lunch: return 13 * 60
        case .afternoonSnack: return 16 * 60
        case .dinner: return 19 * 60
        case .preWorkout: return trainingMinutes - 90
        case .intraWorkout: return trainingMinutes
        case .postWorkout: return trainingMinutes + 60
        case .custom: return 10 * 60 + index * 180
        }
    }

    private func safeIndex(_ index: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        return index % count
    }

    private func defaultChicken() -> FoodItem {
        FoodItem(
            name: "Chicken breast",
            source: .bundledGeneric,
            servingDescription: "100 g raw",
            servingGrams: 100,
            calories: 110,
            proteinGrams: 23,
            carbohydrateGrams: 0,
            fatGrams: 1.2,
            measurementState: .raw,
            isVerified: true
        )
    }

    private func defaultRice() -> FoodItem {
        FoodItem(
            name: "Rice",
            source: .bundledGeneric,
            servingDescription: "100 g dry",
            servingGrams: 100,
            calories: 360,
            proteinGrams: 7,
            carbohydrateGrams: 80,
            fatGrams: 0.6,
            measurementState: .dry,
            isVerified: true
        )
    }

    private func defaultVegetables() -> FoodItem {
        FoodItem(
            name: "Mixed vegetables",
            source: .bundledGeneric,
            servingDescription: "100 g raw",
            servingGrams: 100,
            calories: 35,
            proteinGrams: 2,
            carbohydrateGrams: 6,
            fatGrams: 0.2,
            measurementState: .raw,
            isVerified: true
        )
    }
}

private extension Array {
    subscript(safe index: Int?) -> Element? {
        guard let index, indices.contains(index) else { return nil }
        return self[index]
    }
}
