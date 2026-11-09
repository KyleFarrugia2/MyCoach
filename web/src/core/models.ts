import { CoachingConfig } from "./config";
import type { Day, Weekday } from "./dates";

// ---------------------------------------------------------------------------
// Enums (string unions) + display labels
// ---------------------------------------------------------------------------

export type GoalPhase = "cut" | "gain" | "maintenance";
export const GoalPhaseInfo: Record<GoalPhase, { name: string; subtitle: string }> = {
  cut: {
    name: "Lose Weight",
    subtitle: "Reduce body fat while maintaining as much muscle and training performance as possible.",
  },
  gain: { name: "Gain Weight", subtitle: "Build muscle using a controlled calorie surplus." },
  maintenance: { name: "Maintain", subtitle: "Hold body weight while refining composition and performance." },
};

export type BiologicalSex = "female" | "male" | "preferNotToSay";
export const BiologicalSexLabel: Record<BiologicalSex, string> = {
  female: "Female",
  male: "Male",
  preferNotToSay: "Prefer not to say",
};

export const WEEKDAYS: Weekday[] = [1, 2, 3, 4, 5, 6, 7];
export const WeekdayShort: Record<Weekday, string> = { 1: "M", 2: "T", 3: "W", 4: "T", 5: "F", 6: "S", 7: "S" };
export const WeekdayFull: Record<Weekday, string> = {
  1: "Monday",
  2: "Tuesday",
  3: "Wednesday",
  4: "Thursday",
  5: "Friday",
  6: "Saturday",
  7: "Sunday",
};

export type ActivityBand = "under4000" | "fourToSix" | "sixToEight" | "eightToTen" | "tenPlus";
export const ACTIVITY_BANDS: ActivityBand[] = ["under4000", "fourToSix", "sixToEight", "eightToTen", "tenPlus"];
export const ActivityBandInfo: Record<ActivityBand, { name: string; midpoint: number }> = {
  under4000: { name: "Under 4,000", midpoint: 3_000 },
  fourToSix: { name: "4,000–6,000", midpoint: 5_000 },
  sixToEight: { name: "6,000–8,000", midpoint: 7_000 },
  eightToTen: { name: "8,000–10,000", midpoint: 9_000 },
  tenPlus: { name: "10,000+", midpoint: 11_000 },
};
export function initialStepTarget(band: ActivityBand): number {
  return Math.min(CoachingConfig.maxStepTarget, ActivityBandInfo[band].midpoint + 1_000);
}

export type TrainingTimePreference = "morning" | "midday" | "afternoon" | "evening" | "variable";
export const TRAINING_TIMES: TrainingTimePreference[] = ["morning", "midday", "afternoon", "evening", "variable"];
export const TrainingTimeLabel: Record<TrainingTimePreference, string> = {
  morning: "Morning",
  midday: "Midday",
  afternoon: "Afternoon",
  evening: "Evening",
  variable: "Variable",
};

export type FoodAllergy =
  | "none"
  | "dairy"
  | "eggs"
  | "peanuts"
  | "treeNuts"
  | "fish"
  | "shellfish"
  | "glutenWheat"
  | "soy"
  | "other";
export const FOOD_ALLERGIES: FoodAllergy[] = [
  "none",
  "dairy",
  "eggs",
  "peanuts",
  "treeNuts",
  "fish",
  "shellfish",
  "glutenWheat",
  "soy",
  "other",
];
export const FoodAllergyLabel: Record<FoodAllergy, string> = {
  none: "None",
  dairy: "Dairy",
  eggs: "Eggs",
  peanuts: "Peanuts",
  treeNuts: "Tree nuts",
  fish: "Fish",
  shellfish: "Shellfish",
  glutenWheat: "Gluten/Wheat",
  soy: "Soy",
  other: "Other",
};

export type AppearanceFeedback = "softer" | "aboutTheSame" | "flatter" | "better" | "notSure";
export const APPEARANCE_OPTIONS: AppearanceFeedback[] = ["softer", "aboutTheSame", "flatter", "better", "notSure"];
export const AppearanceInfo: Record<AppearanceFeedback, { title: string; subtitle: string }> = {
  softer: { title: "Softer", subtitle: "I look noticeably softer or smoother." },
  aboutTheSame: { title: "About The Same", subtitle: "No major visual difference." },
  flatter: { title: "Flatter", subtitle: "My muscles look flatter and less full." },
  better: { title: "Better", subtitle: "I look tighter/full and progress looks good." },
  notSure: { title: "Not Sure", subtitle: "I'm not sure how to judge this week." },
};

export type TrainingPerformance = "muchWorse" | "slightlyWorse" | "same" | "better" | "muchBetter";
export const PERFORMANCE_OPTIONS: TrainingPerformance[] = ["muchWorse", "slightlyWorse", "same", "better", "muchBetter"];
export const PerformanceLabel: Record<TrainingPerformance, string> = {
  muchWorse: "Much worse",
  slightlyWorse: "Slightly worse",
  same: "Same",
  better: "Better",
  muchBetter: "Much better",
};

export type DigestionFeedback = "poor" | "okay" | "good";
export const DIGESTION_OPTIONS: DigestionFeedback[] = ["poor", "okay", "good"];
export const DigestionLabel: Record<DigestionFeedback, string> = { poor: "Poor", okay: "Okay", good: "Good" };

export type AdherenceBand = "under50" | "fiftyTo69" | "seventyTo84" | "eightyFiveTo94" | "ninetyFiveTo100";
export const ADHERENCE_BANDS: AdherenceBand[] = [
  "under50",
  "fiftyTo69",
  "seventyTo84",
  "eightyFiveTo94",
  "ninetyFiveTo100",
];
export const AdherenceInfo: Record<AdherenceBand, { name: string; percent: number; isHigh: boolean; isPoor: boolean }> =
  {
    under50: { name: "Under 50%", percent: 40, isHigh: false, isPoor: true },
    fiftyTo69: { name: "50–69%", percent: 60, isHigh: false, isPoor: true },
    seventyTo84: { name: "70–84%", percent: 77, isHigh: false, isPoor: false },
    eightyFiveTo94: { name: "85–94%", percent: 90, isHigh: true, isPoor: false },
    ninetyFiveTo100: { name: "95–100%", percent: 97, isHigh: true, isPoor: false },
  };

export type MeasurementState = "raw" | "cooked" | "dry" | "prepared" | "serving" | "package";
export const MEASUREMENT_STATES: MeasurementState[] = ["raw", "cooked", "dry", "prepared", "serving", "package"];
export const MeasurementLabel: Record<MeasurementState, string> = {
  raw: "Raw",
  cooked: "Cooked",
  dry: "Dry",
  prepared: "Prepared",
  serving: "Serving",
  package: "Package",
};

export type TargetSource = "engine" | "coachRecommendation" | "userOverride" | "adaptiveModel";

export type MealSlot =
  | "breakfast"
  | "lunch"
  | "dinner"
  | "snack"
  | "afternoonSnack"
  | "preWorkout"
  | "intraWorkout"
  | "postWorkout"
  | "custom";
export const MealSlotLabel: Record<MealSlot, string> = {
  breakfast: "Meal 1",
  snack: "Meal 2",
  lunch: "Meal 3",
  afternoonSnack: "Meal 4",
  dinner: "Meal 5",
  preWorkout: "Pre Workout / Intra Workout",
  intraWorkout: "Intra Workout",
  postWorkout: "Post Workout",
  custom: "Meal",
};
export const REST_DAY_SLOTS: MealSlot[] = ["breakfast", "snack", "lunch", "afternoonSnack", "dinner"];
export const TRAINING_DAY_SLOTS: MealSlot[] = ["breakfast", "snack", "preWorkout", "postWorkout", "dinner"];
export function mealSlots(isTrainingDay: boolean): MealSlot[] {
  return isTrainingDay ? TRAINING_DAY_SLOTS : REST_DAY_SLOTS;
}

export type AppearancePreference = "system" | "light" | "dark";
export const AppearanceLabel: Record<AppearancePreference, string> = { system: "System", light: "Light", dark: "Dark" };

export type WeightUnit = "kilogram" | "pound";
export const WeightUnitShort: Record<WeightUnit, string> = { kilogram: "kg", pound: "lb" };

// ---------------------------------------------------------------------------
// Nutrition
// ---------------------------------------------------------------------------

export interface MacroGrams {
  protein: number;
  carbohydrates: number;
  fat: number;
}

export const ZERO_MACROS: MacroGrams = { protein: 0, carbohydrates: 0, fat: 0 };

export const Macros = {
  add: (a: MacroGrams, b: MacroGrams): MacroGrams => ({
    protein: a.protein + b.protein,
    carbohydrates: a.carbohydrates + b.carbohydrates,
    fat: a.fat + b.fat,
  }),
  sum: (list: MacroGrams[]): MacroGrams => list.reduce(Macros.add, ZERO_MACROS),
  calories: (m: MacroGrams): number =>
    NutritionMath.calories(m.protein, m.carbohydrates, m.fat),
};

export const NutritionMath = {
  calories(protein: number, carbs: number, fat: number): number {
    return (
      protein * CoachingConfig.caloriesPerGramProtein +
      carbs * CoachingConfig.caloriesPerGramCarbohydrate +
      fat * CoachingConfig.caloriesPerGramFat
    );
  },
  carbohydratesFromRemainingCalories(totalCalories: number, protein: number, fat: number): number {
    const remaining =
      totalCalories - protein * CoachingConfig.caloriesPerGramProtein - fat * CoachingConfig.caloriesPerGramFat;
    return Math.max(0, remaining / CoachingConfig.caloriesPerGramCarbohydrate);
  },
};

export interface DailyNutritionTarget {
  id: string;
  calories: number;
  macros: MacroGrams;
  isTrainingDay: boolean;
  stepTarget: number;
  source: TargetSource;
  includesIntraWorkout: boolean;
}

export function makeTarget(t: {
  calories: number;
  macros: MacroGrams;
  isTrainingDay: boolean;
  stepTarget: number;
  source?: TargetSource;
  includesIntraWorkout?: boolean;
}): DailyNutritionTarget {
  return {
    id: uuid(),
    calories: t.calories,
    macros: t.macros,
    isTrainingDay: t.isTrainingDay,
    stepTarget: Math.min(t.stepTarget, CoachingConfig.maxStepTarget),
    source: t.source ?? "engine",
    includesIntraWorkout: t.includesIntraWorkout ?? false,
  };
}

export interface NutritionTargetPair {
  training: DailyNutritionTarget;
  rest: DailyNutritionTarget;
}

// ---------------------------------------------------------------------------
// Food
// ---------------------------------------------------------------------------

export type FoodSource = "bundledGeneric" | "verifiedAPI" | "brandedPackage" | "restaurant" | "customUser" | "barcode";

export interface FoodItem {
  id: string;
  name: string;
  brand?: string;
  restaurant?: string;
  source: FoodSource;
  servingDescription: string;
  servingGrams?: number;
  calories?: number;
  proteinGrams?: number;
  carbohydrateGrams?: number;
  fatGrams?: number;
  fibreGrams?: number;
  measurementState: MeasurementState;
  /** GTIN/EAN/UPC for packaged foods added by scanning. */
  barcode?: string;
  isCustom: boolean;
  isVerified: boolean;
  allergenTags: FoodAllergy[];
  isFavorite: boolean;
}

export function foodSubtitle(food: FoodItem): string {
  if (food.restaurant) return food.restaurant;
  if (food.brand) return food.brand;
  switch (food.source) {
    case "bundledGeneric":
      return "Generic Database";
    case "customUser":
      return "My Foods";
    case "verifiedAPI":
      return "Verified";
    case "brandedPackage":
      return "Branded";
    case "restaurant":
      return "Restaurant";
    case "barcode":
      return "Scanned";
  }
}

export function measurementLabel(food: FoodItem): string {
  return `${MeasurementLabel[food.measurementState]} · ${food.servingDescription}`;
}

export interface PerGram {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
}

/** Per-gram nutrition when gram-based serving data exists. Unknown values stay undefined. */
export function nutritionPerGram(food: FoodItem): PerGram | undefined {
  const g = food.servingGrams;
  if (
    g === undefined ||
    g <= 0 ||
    food.calories === undefined ||
    food.proteinGrams === undefined ||
    food.carbohydrateGrams === undefined ||
    food.fatGrams === undefined
  ) {
    return undefined;
  }
  return {
    calories: food.calories / g,
    protein: food.proteinGrams / g,
    carbs: food.carbohydrateGrams / g,
    fat: food.fatGrams / g,
  };
}

export function scaleFood(food: FoodItem, grams: number): { calories: number; macros: MacroGrams } | undefined {
  const per = nutritionPerGram(food);
  if (!per) return undefined;
  return {
    calories: per.calories * grams,
    macros: { protein: per.protein * grams, carbohydrates: per.carbs * grams, fat: per.fat * grams },
  };
}

export function hasBannedAllergen(food: FoodItem, banned: FoodAllergy[]): boolean {
  return food.allergenTags.some((a) => a !== "none" && banned.includes(a));
}

export interface FoodLogEntry {
  id: string;
  localDate: Day;
  mealSlot: MealSlot;
  food: FoodItem;
  /** Grams when scalable; otherwise number of servings. */
  amount: number;
  amountIsServings: boolean;
  loggedCalories: number;
  loggedMacros: MacroGrams;
  createdAt: string;
  notes: string;
}

export interface DailyFoodDiary {
  localDate: Day;
  entries: FoodLogEntry[];
  markedComplete: boolean;
}

export interface MealItem {
  id: string;
  food: FoodItem;
  grams?: number;
  servings?: number;
  isLocked: boolean;
  calories: number;
  macros: MacroGrams;
}

export function makeMealItem(i: Omit<MealItem, "id" | "isLocked"> & { isLocked?: boolean }): MealItem {
  return { id: uuid(), isLocked: false, ...i };
}

export function quantityLabel(item: MealItem): string {
  if (item.grams !== undefined) {
    // State word only where weight changes with cooking: raw / dry / cooked.
    const s = item.food.measurementState;
    const state = s === "raw" || s === "dry" || s === "cooked" ? `${MeasurementLabel[s].toLowerCase()} ` : "";
    return `${fmt(item.grams, 1)} g ${state}${item.food.name}`;
  }
  if (item.servings !== undefined) return `${fmt(item.servings, 2)} × ${item.food.servingDescription}`;
  return item.food.name;
}

export interface Meal {
  id: string;
  slot: MealSlot;
  name: string;
  scheduledTimeMinutes?: number;
  items: MealItem[];
  /** Planner recipe this meal was built from (used to offer the next alternative on "Swap meal"). */
  recipeId?: string;
}

export const mealCalories = (m: Meal) => m.items.reduce((s, i) => s + i.calories, 0);
export const mealMacros = (m: Meal) => Macros.sum(m.items.map((i) => i.macros));

export interface MealPlanDay {
  id: string;
  localDate: Day;
  weekday: Weekday;
  isTrainingDay: boolean;
  target: DailyNutritionTarget;
  meals: Meal[];
  solverMessage?: string;
}

export const planCalories = (p: MealPlanDay) => p.meals.reduce((s, m) => s + mealCalories(m), 0);
export const planMacros = (p: MealPlanDay) => Macros.sum(p.meals.map(mealMacros));

export interface RefeedPlan {
  id: string;
  normalTarget: DailyNutritionTarget;
  refeedTarget: DailyNutritionTarget;
  reason: string;
  accepted: boolean;
}

// ---------------------------------------------------------------------------
// Weight
// ---------------------------------------------------------------------------

export interface WeightEntry {
  id: string;
  timestamp: string;
  localDate: Day;
  weightKg: number;
  inputUnit: WeightUnit;
  isOfficialMorningCheckIn: boolean;
}

export type WeekCompleteness =
  | "empty"
  | "partial"
  | "complete"
  | "insufficientForAdjustment"
  | "sufficientForAdjustment";

export interface CoachingWeek {
  startDate: Day;
  endDate: Day;
  entries: WeightEntry[];
  averageKg?: number;
  entryCount: number;
  completeness: WeekCompleteness;
}

export interface WeeklyRateOfChange {
  previousAverageKg: number;
  currentAverageKg: number;
  absoluteChangeKg: number;
  percentChange: number;
}

// ---------------------------------------------------------------------------
// User
// ---------------------------------------------------------------------------

export interface UserProfile {
  id: string;
  displayName: string;
  dateOfBirth?: Day;
  biologicalSex: BiologicalSex;
  heightCm: number;
  currentWeightKg: number;
  desiredWeightKg: number;
  weightUnit: WeightUnit;
  goalPhase: GoalPhase;
  trainingDays: Weekday[];
  activityBand: ActivityBand;
  stepTarget: number;
  mealCount: number;
  trainingTime: TrainingTimePreference;
  allergies: FoodAllergy[];
  customAllergyNotes: string;
  dislikedFoods: string[];
  preferredFoods: string[];
  intraWorkoutEnabled: boolean;
  appearance: AppearancePreference;
  hasCompletedOnboarding: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface NotificationSettings {
  morningWeighInEnabled: boolean;
  mealRemindersEnabled: boolean;
  stepRemindersEnabled: boolean;
  weeklyCheckInEnabled: boolean;
  progressPhotosEnabled: boolean;
}

export interface UserPreferences {
  customMealNames: Partial<Record<MealSlot, string>>;
  notifications: NotificationSettings;
  /** Let the personal adaptive model change calorie targets automatically (at most weekly). */
  adaptiveAutoAdjust: boolean;
}

export function mealName(prefs: UserPreferences, slot: MealSlot): string {
  return prefs.customMealNames[slot] ?? MealSlotLabel[slot];
}

export interface StepEntry {
  id: string;
  localDate: Day;
  steps: number;
  source: "manual";
}

export interface ProgressPhotoSet {
  id: string;
  weekStart: Day;
  /** Small, downscaled JPEG data URLs kept in browser storage. */
  front?: string;
  side?: string;
  back?: string;
  createdAt: string;
}

export interface PlanAdjustment {
  id: string;
  date: string;
  oldCalories: number;
  newCalories: number;
  oldSteps: number;
  newSteps: number;
  reason: string;
  source: TargetSource;
  userApproved: boolean;
}

// ---------------------------------------------------------------------------
// Coaching
// ---------------------------------------------------------------------------

export type CoachAdjustment =
  | { type: "maintain" }
  | { type: "increaseCalories"; amount: number }
  | { type: "decreaseCalories"; amount: number }
  | { type: "increaseSteps"; amount: number }
  | { type: "decreaseSteps"; amount: number }
  | { type: "suggestRefeed" }
  | { type: "requireMoreData" }
  | { type: "reviewAdherence" }
  | { type: "reviewRecovery" }
  | { type: "recommendNutritionIncreaseReview" }
  | { type: "recommendNutritionDecreaseReview" };

export type CoachConfidence = "low" | "medium" | "high";

export type CoachReasonCode =
  | "rateOnTarget"
  | "rateTooFastLoss"
  | "rateTooFastGain"
  | "rateTooSlow"
  | "highAdherence"
  | "poorAdherence"
  | "insufficientWeighIns"
  | "performanceStable"
  | "performanceDeclining"
  | "appearanceFlat"
  | "appearanceSoft"
  | "appearanceImproving"
  | "extremeWeeklyChange"
  | "stepCapReached"
  | "userFeelingHungry"
  | "recoveryConcern"
  | "modelPrediction";

export interface CoachDecision {
  id: string;
  weekStart: Day;
  action: CoachAdjustment;
  secondaryActions: CoachAdjustment[];
  confidence: CoachConfidence;
  reasons: CoachReasonCode[];
  summary: string;
  suggestedTrainingCalories?: number;
  suggestedRestCalories?: number;
  suggestedMacros?: MacroGrams;
  suggestedSteps?: number;
  refeed?: RefeedPlan;
  createdAt: string;
}

export interface WeeklyCheckIn {
  id: string;
  weekStart: Day;
  previousAverageKg?: number;
  currentAverageKg?: number;
  rateKg?: number;
  ratePercent?: number;
  appearance: AppearanceFeedback;
  adherence: AdherenceBand;
  adherencePercent: number;
  performance: TrainingPerformance;
  hunger: number;
  energy: number;
  digestion: DigestionFeedback;
  notes: string;
  photoSetID?: string;
  decision?: CoachDecision;
  userApprovedAdjustment: boolean;
  createdAt: string;
}

export interface CoachAIContext {
  goal: GoalPhase;
  weightKg: number;
  previousWeeklyAverageKg?: number;
  currentWeeklyAverageKg?: number;
  weeklyRateKg?: number;
  trainingCalories: number;
  restCalories: number;
  protein: number;
  carbs: number;
  fat: number;
  stepTarget: number;
  adherence?: number;
  performance?: TrainingPerformance;
  appearance?: AppearanceFeedback;
  targetSource: TargetSource;
  /** Personal adaptive model summary, when one has been trained. */
  model?: {
    maintenanceKcal: number;
    maintenanceSD: number;
    confidence: "low" | "medium" | "high";
    observations: number;
    predictedKgPerWeek: number;
    targetKgPerWeek: number;
    recommendedDeltaKcal: number;
  };
}

export interface CoachAIStructuredResponse {
  summary: string;
  recommendation: string;
  reasoning: string[];
  userMessage: string;
}

export interface CoachChatMessage {
  id: string;
  role: "user" | "coach" | "system";
  text: string;
  createdAt: string;
  structured?: CoachAIStructuredResponse;
}

export type SubscriptionStatus =
  | "notSubscribed"
  | "trial"
  | "active"
  | "expired"
  | "billingRetry"
  | "gracePeriod"
  | "pending";

export interface SubscriptionEntitlement {
  productID: string;
  status: SubscriptionStatus;
  expirationDate?: string;
  isTrialEligible: boolean;
  localizedPrice?: string;
}

export function hasCoachAIAccess(e: SubscriptionEntitlement): boolean {
  if (e.status === "trial" && e.expirationDate && new Date(e.expirationDate) <= new Date()) return false;
  return e.status === "trial" || e.status === "active" || e.status === "gracePeriod" || e.status === "billingRetry";
}

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

export function uuid(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) return crypto.randomUUID();
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    return (c === "x" ? r : (r & 0x3) | 0x8).toString(16);
  });
}

/** Formats with up to `maxFraction` decimals and no trailing zeros (like Swift `.fractionLength(0...n)`). */
export function fmt(value: number, maxFraction: number): string {
  return value.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: maxFraction });
}

export function round(n: number): number {
  return Math.round(n);
}
