/** Centralized coaching & nutrition constants — ported 1:1 from CoachingConfig.swift. */
export const CoachingConfig = {
  // Steps
  maxStepTarget: 12_000,
  defaultStepIncrement: 500,
  largeStepIncrement: 1_000,

  // Weekly coaching
  extremeWeeklyChangeKg: 1.5,
  minimumWeighInsForAdjustment: 4,
  restDayCalorieDeficit: 500,

  // Macro priorities
  /** 1 g protein per pound of current bodyweight (= 2.2046 g/kg), for every goal. */
  proteinGramsPerKg: 2.2046226218,
  minimumFatGramsPerKg: 0.6,
  fatGramsPerKgCut: 0.7,
  fatGramsPerKgGain: 0.85,

  // Energy
  caloriesPerGramProtein: 4.0,
  caloriesPerGramCarbohydrate: 4.0,
  caloriesPerGramFat: 9.0,

  // Meals
  requiredMealCount: 5,

  // Workouts
  defaultRestSeconds: 3 * 60,
  stagnationWorkoutStreak: 3,

  // Meal solver tolerances
  calorieToleranceFraction: 0.03,
  macroToleranceGrams: 8.0,
  minimumPracticalFoodGrams: 10.0,
  maximumPracticalFoodGrams: 800.0,

  // Incremental adjustments
  defaultCalorieAdjustment: 150,
  largeCalorieAdjustment: 200,
  maximumSingleWeekCalorieChange: 300,

  // Intra-workout
  eaaGramsPerKgTraining: 0.12,
  minimumEAAGrams: 5.0,
  maximumEAAGrams: 15.0,
  dextroseGramsPerKgCut: 0.3,
  dextroseGramsPerKgGain: 0.45,
  minimumDextroseGrams: 15.0,
  maximumDextroseGrams: 60.0,

  // Subscription (local demo — no real payments in the web build)
  coachProductID: "com.company.mycoach.coach.monthly",
  subscriptionMarketingComparisonEUR: 12.99,
  traditionalCoachingComparisonEUR: 300.0,
  traditionalCoachingFootnote: "*Individual coaching prices vary by coach and service.",
  freeTrialDays: 14,

  // Safety
  absoluteMinimumDailyCaloriesMale: 1_800,
  absoluteMinimumDailyCaloriesFemale: 1_500,
  absoluteMinimumDailyCaloriesUnspecified: 1_600,
} as const;

export const AppIdentity = {
  displayName: "My Coach",
  subtitle: "AI Nutrition & Physique Coach",
  supportContactPlaceholder: "[Your support email — replace before release]",
  legalEntityPlaceholder: "[Legal entity / developer name — replace before release]",
  privacyPolicyURLPlaceholder: "https://example.com/privacy",
  termsURLPlaceholder: "https://example.com/terms",
} as const;
