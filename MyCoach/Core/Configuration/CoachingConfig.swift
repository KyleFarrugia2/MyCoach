import Foundation

/// Centralized, testable coaching & nutrition constants.
/// All tunable defaults live here — never scatter magic numbers across views.
enum CoachingConfig {
    // MARK: - Steps
    static let maxStepTarget = 12_000
    static let defaultStepIncrement = 500
    static let largeStepIncrement = 1_000

    // MARK: - Weekly coaching
    /// Absolute weekly average change that triggers an extreme-change review.
    static let extremeWeeklyChangeKg = 1.5
    /// Minimum morning weigh-ins in a Mon–Sun week before strong adjustments.
    static let minimumWeighInsForAdjustment = 4
    /// Ideal rest-day calorie reduction relative to training day.
    static let restDayCalorieDeficit = 500

    // MARK: - Macro priorities (evidence-informed defaults)
    /// Protein g per kg body weight — cut / gain.
    /// 1 g protein per pound of current bodyweight (= 2.2046 g/kg), for every goal.
    static let proteinGramsPerKg = 2.2046226218

    /// Fat g per kg body weight floors / defaults.
    static let minimumFatGramsPerKg = 0.6
    static let fatGramsPerKgCut = 0.7
    static let fatGramsPerKgGain = 0.85

    // MARK: - Energy
    static let caloriesPerGramProtein = 4.0
    static let caloriesPerGramCarbohydrate = 4.0
    static let caloriesPerGramFat = 9.0

    // MARK: - Meals
    /// Fixed daily meal structure — plans always use five meals.
    static let requiredMealCount = 5

    // MARK: - Workouts
    static let defaultRestSeconds = 3 * 60
    static let stagnationWorkoutStreak = 3

    // MARK: - Meal solver tolerances
    static let calorieToleranceFraction = 0.03
    static let macroToleranceGrams = 8.0
    static let minimumPracticalFoodGrams = 10.0
    static let maximumPracticalFoodGrams = 800.0

    // MARK: - Incremental adjustments
    static let defaultCalorieAdjustment = 150
    static let largeCalorieAdjustment = 200
    static let maximumSingleWeekCalorieChange = 300

    // MARK: - Intra-workout (optional performance nutrition)
    static let eaaGramsPerKgTraining = 0.12
    static let minimumEAAGrams = 5.0
    static let maximumEAAGrams = 15.0
    static let dextroseGramsPerKgCut = 0.3
    static let dextroseGramsPerKgGain = 0.45
    static let minimumDextroseGrams = 15.0
    static let maximumDextroseGrams = 60.0

    // MARK: - Subscription (placeholders — display localized StoreKit price in UI)
    static let coachProductID = "com.company.mycoach.coach.monthly"
    static let subscriptionMarketingComparisonEUR = 12.99
    static let traditionalCoachingComparisonEUR = 300.0
    static let traditionalCoachingFootnote = "*Individual coaching prices vary by coach and service."
    static let freeTrialDays = 14

    // MARK: - Safety
    static let absoluteMinimumDailyCaloriesMale = 1_800
    static let absoluteMinimumDailyCaloriesFemale = 1_500
    static let absoluteMinimumDailyCaloriesUnspecified = 1_600
}
