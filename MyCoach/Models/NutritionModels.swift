import Foundation

struct MacroGrams: Codable, Equatable, Sendable, Hashable {
    var protein: Double
    var carbohydrates: Double
    var fat: Double

    static let zero = MacroGrams(protein: 0, carbohydrates: 0, fat: 0)

    var calorieEstimate: Double {
        NutritionMath.calories(
            proteinGrams: protein,
            carbohydrateGrams: carbohydrates,
            fatGrams: fat
        )
    }

    func roundedForDisplay() -> MacroGrams {
        MacroGrams(
            protein: protein.rounded(),
            carbohydrates: carbohydrates.rounded(),
            fat: fat.rounded()
        )
    }

    static func + (lhs: MacroGrams, rhs: MacroGrams) -> MacroGrams {
        MacroGrams(
            protein: lhs.protein + rhs.protein,
            carbohydrates: lhs.carbohydrates + rhs.carbohydrates,
            fat: lhs.fat + rhs.fat
        )
    }

    static func - (lhs: MacroGrams, rhs: MacroGrams) -> MacroGrams {
        MacroGrams(
            protein: lhs.protein - rhs.protein,
            carbohydrates: lhs.carbohydrates - rhs.carbohydrates,
            fat: lhs.fat - rhs.fat
        )
    }

    static func * (lhs: MacroGrams, rhs: Double) -> MacroGrams {
        MacroGrams(
            protein: lhs.protein * rhs,
            carbohydrates: lhs.carbohydrates * rhs,
            fat: lhs.fat * rhs
        )
    }
}

struct DailyNutritionTarget: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var calories: Int
    var macros: MacroGrams
    var isTrainingDay: Bool
    var stepTarget: Int
    var source: TargetSource
    var includesIntraWorkout: Bool

    init(
        id: UUID = UUID(),
        calories: Int,
        macros: MacroGrams,
        isTrainingDay: Bool,
        stepTarget: Int,
        source: TargetSource = .engine,
        includesIntraWorkout: Bool = false
    ) {
        self.id = id
        self.calories = calories
        self.macros = macros
        self.isTrainingDay = isTrainingDay
        self.stepTarget = min(stepTarget, CoachingConfig.maxStepTarget)
        self.source = source
        self.includesIntraWorkout = includesIntraWorkout
    }
}

struct NutritionTargetPair: Codable, Equatable, Sendable {
    var training: DailyNutritionTarget
    var rest: DailyNutritionTarget

    func target(isTrainingDay: Bool) -> DailyNutritionTarget {
        isTrainingDay ? training : rest
    }
}

enum NutritionMath {
    static func calories(proteinGrams: Double, carbohydrateGrams: Double, fatGrams: Double) -> Double {
        (proteinGrams * CoachingConfig.caloriesPerGramProtein)
            + (carbohydrateGrams * CoachingConfig.caloriesPerGramCarbohydrate)
            + (fatGrams * CoachingConfig.caloriesPerGramFat)
    }

    static func carbohydratesFromRemainingCalories(
        totalCalories: Double,
        proteinGrams: Double,
        fatGrams: Double
    ) -> Double {
        let remaining = totalCalories
            - (proteinGrams * CoachingConfig.caloriesPerGramProtein)
            - (fatGrams * CoachingConfig.caloriesPerGramFat)
        return max(0, remaining / CoachingConfig.caloriesPerGramCarbohydrate)
    }
}
