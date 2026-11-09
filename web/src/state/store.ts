import { useSyncExternalStore } from "react";
import { CoachingConfig } from "../core/config";
import { type Day, addDays, ageYears, addMonths, datesInWeek, today, weekdayOf } from "../core/dates";
import {
  type CoachAIContext,
  type CoachChatMessage,
  type CoachDecision,
  type DailyFoodDiary,
  type DailyNutritionTarget,
  type FoodItem,
  type FoodLogEntry,
  type MacroGrams,
  type Meal,
  type MealPlanDay,
  type MealSlot,
  type NutritionTargetPair,
  type PlanAdjustment,
  type ProgressPhotoSet,
  type StepEntry,
  type SubscriptionEntitlement,
  type UserPreferences,
  type UserProfile,
  type WeeklyCheckIn,
  type WeightEntry,
  type WeightUnit,
  ZERO_MACROS,
  hasCoachAIAccess,
  initialStepTarget,
  uuid,
} from "../core/models";
import {
  type AdaptiveDay,
  type AdaptiveFitInput,
  type AdaptiveModelSnapshot,
  type AdaptiveRecommendation,
  AdaptiveConfig,
  fitAdaptiveModel,
  recommend,
} from "../engines/adaptive";
import { applyModelAdjustment, blendDecisionWithModel } from "../engines/adaptiveCoaching";
import { evaluate } from "../engines/coaching";
import { OFFLINE_COACH_MESSAGE, chat } from "../engines/coachAI";
import { BUNDLED_FOODS } from "../engines/foodCatalog";
import { type PlannerContext, generatePlanDay, swapPlanItem, swapPlanMeal, validatePlanDay } from "../engines/mealPlanner";
import {
  adjustedStepTarget,
  applyCalorieAdjustment,
  buildInitialTargets,
  cappedStepTarget,
  estimatedMaintenanceCalories,
  macrosForCalories,
  restDayTarget,
} from "../engines/nutrition";
import { UnitConversion, formatWeight } from "../engines/units";
import { makeWeek, rateOfChange } from "../engines/weight";
import {
  type ExerciseLog,
  type TemplateOverride,
  type WorkoutSession,
  type WorkoutTemplate,
  type WorkoutTemplateID,
  WORKOUT_LIBRARY,
  stagnantExercises,
} from "../engines/workout";

/** Port of AppEnvironment.swift — app state, actions, and localStorage persistence. */

export type MainTab = "today" | "mealPlan" | "log" | "foods" | "workout" | "progress" | "coach";

export interface PersistedState {
  version: 1;
  profile: UserProfile;
  preferences: UserPreferences;
  weightEntries: WeightEntry[];
  stepEntries: StepEntry[];
  diaries: Record<Day, DailyFoodDiary>;
  mealPlanDays: Record<Day, MealPlanDay>;
  targets?: NutritionTargetPair;
  checkIns: WeeklyCheckIn[];
  chatMessages: CoachChatMessage[];
  planAdjustments: PlanAdjustment[];
  photoSets: ProgressPhotoSet[];
  customFoods: FoodItem[];
  subscription: SubscriptionEntitlement;
  coachStatusMessage: string;
  workoutSessions: WorkoutSession[];
  workoutTemplateOverrides: TemplateOverride[];
  activeWorkout?: WorkoutSession;
  workoutRestEndsAt?: string;
}

export interface AppState extends PersistedState {
  selectedTab: MainTab;
  pendingStagnationAlerts: string[];
}

const STORAGE_KEY = "mycoach.state.v1";

const nowISO = () => new Date().toISOString();

function draftProfile(): UserProfile {
  return {
    id: uuid(),
    displayName: "",
    dateOfBirth: addMonths(today(), -25 * 12),
    biologicalSex: "preferNotToSay",
    heightCm: 175,
    currentWeightKg: 80,
    desiredWeightKg: 75,
    weightUnit: "kilogram",
    goalPhase: "cut",
    trainingDays: [1, 2, 4, 5],
    activityBand: "sixToEight",
    stepTarget: initialStepTarget("sixToEight"),
    mealCount: CoachingConfig.requiredMealCount,
    trainingTime: "evening",
    allergies: ["none"],
    customAllergyNotes: "",
    dislikedFoods: [],
    preferredFoods: [],
    intraWorkoutEnabled: true,
    appearance: "system",
    hasCompletedOnboarding: false,
    createdAt: nowISO(),
    updatedAt: nowISO(),
  };
}

function defaultPreferences(): UserPreferences {
  return {
    customMealNames: {},
    notifications: {
      morningWeighInEnabled: true,
      mealRemindersEnabled: false,
      stepRemindersEnabled: true,
      weeklyCheckInEnabled: true,
      progressPhotosEnabled: true,
    },
    adaptiveAutoAdjust: true,
  };
}

function defaultSubscription(): SubscriptionEntitlement {
  return {
    productID: CoachingConfig.coachProductID,
    status: "notSubscribed",
    isTrialEligible: true,
    localizedPrice: `€${CoachingConfig.subscriptionMarketingComparisonEUR.toFixed(2)}`,
  };
}

const message = (role: CoachChatMessage["role"], text: string, extra?: Partial<CoachChatMessage>): CoachChatMessage => ({
  id: uuid(),
  role,
  text,
  createdAt: nowISO(),
  ...extra,
});

function freshState(): AppState {
  return {
    version: 1,
    profile: draftProfile(),
    preferences: defaultPreferences(),
    weightEntries: [],
    stepEntries: [],
    diaries: {},
    mealPlanDays: {},
    targets: undefined,
    checkIns: [],
    chatMessages: [
      message("coach", "I'm your My Coach AI. Ask about progress, refeeds, or what to eat around training."),
    ],
    planAdjustments: [],
    photoSets: [],
    customFoods: [],
    subscription: defaultSubscription(),
    coachStatusMessage: "Complete onboarding to unlock your plan.",
    workoutSessions: [],
    workoutTemplateOverrides: [],
    activeWorkout: undefined,
    workoutRestEndsAt: undefined,
    selectedTab: "today",
    pendingStagnationAlerts: [],
  };
}

function load(): AppState {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return freshState();
    const parsed = JSON.parse(raw) as PersistedState;
    if (parsed.version !== 1) return freshState();
    // Merge over a fresh state so fields added later get defaults.
    const base = freshState();
    return {
      ...base,
      ...parsed,
      profile: { ...base.profile, ...parsed.profile, mealCount: CoachingConfig.requiredMealCount },
      preferences: {
        ...base.preferences,
        ...parsed.preferences,
        notifications: { ...base.preferences.notifications, ...parsed.preferences?.notifications },
      },
      selectedTab: "today",
      pendingStagnationAlerts: [],
    };
  } catch {
    return freshState();
  }
}

export let persistError: string | undefined;

function persist(state: AppState) {
  const { selectedTab: _t, pendingStagnationAlerts: _p, ...persisted } = state;
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(persisted));
    persistError = undefined;
  } catch (e) {
    // Most likely quota exceeded (photos). Never crash the UI over persistence.
    persistError = "Storage is full — some changes may not be saved. Try removing progress photos.";
    console.error("MyCoach persistence error", e);
  }
}

// ---------------------------------------------------------------------------
// Store plumbing
// ---------------------------------------------------------------------------

let state: AppState = load();
const listeners = new Set<() => void>();

export function getState(): AppState {
  return state;
}

function set(next: AppState, save = true) {
  const prev = state;
  state = next;
  if (save) persist(state);
  listeners.forEach((l) => l());
  if (
    prev.weightEntries !== next.weightEntries ||
    prev.diaries !== next.diaries ||
    prev.stepEntries !== next.stepEntries ||
    prev.subscription !== next.subscription ||
    prev.preferences.adaptiveAutoAdjust !== next.preferences.adaptiveAutoAdjust
  ) {
    // New data → the model re-trains (lazily, memoised) and may adjust the plan. Deferred so the
    // triggering action finishes first.
    queueMicrotask(() => actions.runAdaptiveAutoAdjust());
  }
}

function update(fn: (s: AppState) => Partial<AppState>, save = true) {
  set({ ...state, ...fn(state) }, save);
}

function subscribe(l: () => void) {
  listeners.add(l);
  return () => listeners.delete(l);
}

export function useApp(): AppState {
  return useSyncExternalStore(subscribe, getState);
}

// Persist on tab hide so a killed PWA never loses the active workout.
if (typeof document !== "undefined") {
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "hidden") persist(state);
  });
}

// ---------------------------------------------------------------------------
// Derived values
// ---------------------------------------------------------------------------

export const hasCoachAccess = (s: AppState = state) => hasCoachAIAccess(s.subscription);

export const isTrainingDay = (s: AppState, day: Day) => s.profile.trainingDays.includes(weekdayOf(day));

export function targetFor(s: AppState, day: Day): DailyNutritionTarget | undefined {
  if (!s.targets) return undefined;
  return isTrainingDay(s, day) ? s.targets.training : s.targets.rest;
}

export function diaryFor(s: AppState, day: Day): DailyFoodDiary {
  return s.diaries[day] ?? { localDate: day, entries: [], markedComplete: false };
}

export const weightEntryOn = (s: AppState, day: Day) =>
  s.weightEntries.find((e) => e.localDate === day && e.isOfficialMorningCheckIn);

export const stepsOn = (s: AppState, day: Day) => s.stepEntries.find((e) => e.localDate === day);

export const currentWeek = (s: AppState) => makeWeek(today(), s.weightEntries);
export const previousWeek = (s: AppState) => makeWeek(addDays(today(), -7), s.weightEntries);
export const weeklyRate = (s: AppState) => rateOfChange(previousWeek(s), currentWeek(s));

export function greeting(s: AppState): string {
  const hour = new Date().getHours();
  const name = s.profile.displayName ? `, ${s.profile.displayName}` : "";
  if (hour >= 5 && hour < 12) return `Good Morning${name}`;
  if (hour >= 12 && hour < 17) return `Good Afternoon${name}`;
  return `Good Evening${name}`;
}

export const displayWeight = (s: AppState, kg: number) => formatWeight(kg, s.profile.weightUnit);

export const catalogFoods = (s: AppState) => [...s.customFoods, ...BUNDLED_FOODS];

/** A food the user already saved for this barcode (scanned or created), so re-scans work offline. */
export const customFoodByBarcode = (s: AppState, barcode: string) => s.customFoods.find((f) => f.barcode === barcode);

export function plannerContext(s: AppState, day: Day = today()): PlannerContext {
  return {
    allergies: s.profile.allergies,
    dislikedFoods: s.profile.dislikedFoods,
    preferredFoods: s.profile.preferredFoods,
    trainingTime: s.profile.trainingTime,
    intraWorkoutEnabled: s.profile.intraWorkoutEnabled && isTrainingDay(s, day),
    weightKg: s.profile.currentWeightKg,
    goal: s.profile.goalPhase,
  };
}

/**
 * Same calories, macros re-derived for the *current* bodyweight: protein 1 g/lb, fat per kg, carbs fill the
 * rest (4/4/9). Keeps any coach/model calorie adjustments intact.
 */
export function targetsForCurrentWeight(s: AppState, includesIntraWorkout?: boolean): NutritionTargetPair | undefined {
  if (!s.targets) return undefined;
  const w = s.profile.currentWeightKg;
  const old = s.targets.training;
  const training: DailyNutritionTarget = {
    ...old,
    macros: macrosForCalories(old.calories, w, s.profile.goalPhase),
    includesIntraWorkout: includesIntraWorkout ?? old.includesIntraWorkout,
  };
  const rest = restDayTarget(training, w, s.profile.goalPhase, s.profile.biologicalSex);
  return {
    training,
    rest: { ...rest, id: s.targets.rest.id, source: s.targets.rest.source, stepTarget: s.targets.rest.stepTarget },
  };
}

function aiContext(s: AppState): CoachAIContext {
  const prev = previousWeek(s);
  const curr = currentWeek(s);
  const rate = weeklyRate(s);
  return {
    goal: s.profile.goalPhase,
    weightKg: s.profile.currentWeightKg,
    previousWeeklyAverageKg: prev.averageKg,
    currentWeeklyAverageKg: curr.averageKg,
    weeklyRateKg: rate?.absoluteChangeKg,
    trainingCalories: s.targets?.training.calories ?? 0,
    restCalories: s.targets?.rest.calories ?? 0,
    protein: s.targets?.training.macros.protein ?? 0,
    carbs: s.targets?.training.macros.carbohydrates ?? 0,
    fat: s.targets?.training.macros.fat ?? 0,
    stepTarget: s.profile.stepTarget,
    adherence: s.checkIns[0]?.adherencePercent,
    performance: s.checkIns[0]?.performance,
    appearance: s.checkIns[0]?.appearance,
    targetSource: s.targets?.training.source ?? "engine",
    model: (() => {
      const m = adaptiveModel(s);
      const r = adaptiveRecommendation(s);
      if (!m || !r) return undefined;
      return {
        maintenanceKcal: m.maintenanceKcal,
        maintenanceSD: m.maintenanceSD,
        confidence: m.confidence,
        observations: m.observations,
        predictedKgPerWeek: r.predictedCurrent.meanKgPerWeek,
        targetKgPerWeek: r.targetKgPerWeek,
        recommendedDeltaKcal: r.deltaKcal,
      };
    })(),
  };
}

// ---------------------------------------------------------------------------
// Personal adaptive model (on-device ML) — see engines/adaptive.ts
// ---------------------------------------------------------------------------

const MAX_MODEL_HISTORY_DAYS = 365;
const MIN_LOGGED_DAY_KCAL = 600;
/** A day's food log counts as training data only if it looks complete (marked done, or >= 50% of target). */
const COMPLETE_DAY_FRACTION = 0.5;

function priorMaintenance(s: AppState, weightKg: number): number {
  const p = s.profile;
  return estimatedMaintenanceCalories({
    weightKg,
    heightCm: p.heightCm,
    ageYears: p.dateOfBirth ? ageYears(p.dateOfBirth) : 25,
    sex: p.biologicalSex,
    goal: p.goalPhase,
    activityBand: p.activityBand,
    trainingDaysPerWeek: p.trainingDays.length,
    stepTarget: p.stepTarget,
    intraWorkoutEnabled: p.intraWorkoutEnabled,
  });
}

function planAverageIntake(s: AppState): number | undefined {
  if (!s.targets) return undefined;
  const n = s.profile.trainingDays.length;
  return (n * s.targets.training.calories + (7 - n) * s.targets.rest.calories) / 7;
}

/** Turns the user's logs into the model's day-indexed training series (oldest -> today). */
export function adaptiveInput(s: AppState, asOf: Day = today()): AdaptiveFitInput | undefined {
  const official = s.weightEntries
    .filter((e) => e.isOfficialMorningCheckIn && e.localDate <= asOf)
    .sort((a, b) => a.localDate.localeCompare(b.localDate));
  if (official.length === 0) return undefined;
  const earliest = addDays(asOf, -(MAX_MODEL_HISTORY_DAYS - 1));
  const start = official[0].localDate > earliest ? official[0].localDate : earliest;
  const weights = new Map(official.map((e) => [e.localDate, e.weightKg]));
  const steps = new Map(s.stepEntries.map((e) => [e.localDate, e.steps]));
  const days: AdaptiveDay[] = [];
  for (let d = start; d <= asOf; d = addDays(d, 1)) {
    const diary = s.diaries[d];
    let intakeKcal: number | undefined;
    // Today only counts once the user marks it complete — a half-logged day would look like a deficit.
    if (diary && diary.entries.length > 0 && (d < asOf || diary.markedComplete)) {
      const total = diary.entries.reduce((sum, e) => sum + e.loggedCalories, 0);
      const target = targetFor(s, d)?.calories ?? 2000;
      if (total >= MIN_LOGGED_DAY_KCAL && (diary.markedComplete || total >= COMPLETE_DAY_FRACTION * target)) {
        intakeKcal = total;
      }
    }
    days.push({ weightKg: weights.get(d), intakeKcal, steps: steps.get(d) });
  }
  const prior = priorMaintenance(s, official[0].weightKg);
  return {
    days,
    priorMaintenanceKcal: prior,
    bodyWeightKg: official[official.length - 1].weightKg,
    fallbackSteps: s.profile.stepTarget,
    fallbackIntakeKcal: planAverageIntake(s) ?? prior,
  };
}

let modelCache: { key: unknown[]; model: AdaptiveModelSnapshot | undefined } | undefined;

/** The trained personal model. Re-trains whenever the underlying logs change (memoised by reference). */
export function adaptiveModel(s: AppState = state): AdaptiveModelSnapshot | undefined {
  const key = [s.weightEntries, s.diaries, s.stepEntries, s.profile, s.targets, today()];
  if (modelCache && modelCache.key.every((k, i) => k === key[i])) return modelCache.model;
  const input = adaptiveInput(s);
  const model = input ? fitAdaptiveModel(input) : undefined;
  modelCache = { key, model };
  return model;
}

export function adaptiveRecommendation(s: AppState = state): AdaptiveRecommendation | undefined {
  const m = adaptiveModel(s);
  if (!m || !s.targets) return undefined;
  return recommend(
    m,
    {
      trainingKcal: s.targets.training.calories,
      restKcal: s.targets.rest.calories,
      trainingDaysPerWeek: s.profile.trainingDays.length,
    },
    s.profile.goalPhase,
    s.profile.desiredWeightKg,
    m.currentSteps,
  );
}

/** Days since any plan change (auto or check-in) — the model never stacks adjustments within a week. */
function daysSinceLastAdjustment(s: AppState): number {
  const last = s.planAdjustments[0];
  if (!last) return Infinity;
  return (Date.now() - new Date(last.date).getTime()) / 86_400_000;
}

export function nextAutoAdjustEligibleDate(s: AppState = state): Date | undefined {
  const last = s.planAdjustments[0];
  if (!last) return undefined;
  return new Date(new Date(last.date).getTime() + AdaptiveConfig.minDaysBetweenAutoAdjustments * 86_400_000);
}

// ---------------------------------------------------------------------------
// Pure helpers used by actions
// ---------------------------------------------------------------------------

function buildTargets(profile: UserProfile): NutritionTargetPair {
  return buildInitialTargets({
    weightKg: profile.currentWeightKg,
    heightCm: profile.heightCm,
    ageYears: profile.dateOfBirth ? ageYears(profile.dateOfBirth) : 25,
    sex: profile.biologicalSex,
    goal: profile.goalPhase,
    activityBand: profile.activityBand,
    trainingDaysPerWeek: profile.trainingDays.length,
    stepTarget: profile.stepTarget,
    intraWorkoutEnabled: profile.intraWorkoutEnabled,
  });
}

function planFor(s: AppState, day: Day): MealPlanDay | undefined {
  if (!s.targets) return undefined;
  const training = isTrainingDay(s, day);
  return generatePlanDay({
    date: day,
    weekday: weekdayOf(day),
    isTrainingDay: training,
    target: training ? s.targets.training : s.targets.rest,
    ctx: plannerContext(s, day),
  });
}

function withWeekPlan(s: AppState, containing: Day): Record<Day, MealPlanDay> {
  if (!hasCoachAIAccess(s.subscription) || !s.targets) return s.mealPlanDays;
  const next = { ...s.mealPlanDays };
  for (const day of datesInWeek(containing)) {
    const plan = planFor(s, day);
    if (plan) next[day] = plan;
  }
  return next;
}

function appendEntries(s: AppState, day: Day, entries: FoodLogEntry[]): Record<Day, DailyFoodDiary> {
  const diary = diaryFor(s, day);
  return { ...s.diaries, [day]: { ...diary, entries: [...diary.entries, ...entries] } };
}

function makeEntry(
  food: FoodItem,
  amount: number,
  amountIsServings: boolean,
  mealSlot: MealSlot,
  day: Day,
  calories: number,
  macros: MacroGrams,
  notes = "",
): FoodLogEntry {
  return {
    id: uuid(),
    localDate: day,
    mealSlot,
    food,
    amount,
    amountIsServings,
    loggedCalories: calories,
    loggedMacros: macros,
    createdAt: nowISO(),
    notes,
  };
}

function vibrate(pattern: number | number[]) {
  try {
    navigator.vibrate?.(pattern);
  } catch {
    /* unsupported */
  }
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

export const actions = {
  selectTab(tab: MainTab) {
    update(() => ({ selectedTab: tab }), false);
  },

  // Onboarding / profile ------------------------------------------------------

  updateProfile(patch: Partial<UserProfile>) {
    update((s) => ({
      profile: { ...s.profile, ...patch, mealCount: CoachingConfig.requiredMealCount, updatedAt: nowISO() },
    }));
  },

  completeOnboarding() {
    update((s) => {
      const profile: UserProfile = {
        ...s.profile,
        hasCompletedOnboarding: true,
        updatedAt: nowISO(),
        stepTarget: Math.min(initialStepTarget(s.profile.activityBand), CoachingConfig.maxStepTarget),
      };
      const next: AppState = { ...s, profile, targets: buildTargets(profile) };
      const canPlan = hasCoachAIAccess(s.subscription);
      return {
        profile,
        targets: next.targets,
        mealPlanDays: withWeekPlan(next, today()),
        coachStatusMessage: canPlan
          ? "Your plan is ready. Log your morning weight to start the coaching cycle."
          : "Food logging is ready. Start a Coach AI trial to unlock meal plans and weekly adjustments.",
      };
    });
  },

  rebuildTargetsFromProfile() {
    update((s) => ({ targets: buildTargets(s.profile) }));
  },

  updatePreferences(patch: Partial<UserPreferences>) {
    update((s) => ({ preferences: { ...s.preferences, ...patch } }));
  },

  setMealName(slot: MealSlot, name: string) {
    update((s) => {
      const names = { ...s.preferences.customMealNames };
      const trimmed = name.trim();
      if (trimmed) names[slot] = trimmed;
      else delete names[slot];
      return { preferences: { ...s.preferences, customMealNames: names } };
    });
  },

  // Weight / steps ------------------------------------------------------------

  logMorningWeight(value: number, unit: WeightUnit) {
    const kg = UnitConversion.kilograms(value, unit);
    const day = today();
    update((s) => {
      const existing = s.weightEntries.find((e) => e.localDate === day && e.isOfficialMorningCheckIn);
      const entries = existing
        ? s.weightEntries.map((e) => (e.id === existing.id ? { ...e, weightKg: kg, inputUnit: unit, timestamp: nowISO() } : e))
        : [
            ...s.weightEntries,
            { id: uuid(), timestamp: nowISO(), localDate: day, weightKg: kg, inputUnit: unit, isOfficialMorningCheckIn: true },
          ];
      entries.sort((a, b) => a.localDate.localeCompare(b.localDate));
      const profile = { ...s.profile, currentWeightKg: kg, updatedAt: nowISO() };
      // Protein follows bodyweight (1 g/lb); calories stay as set.
      return { weightEntries: entries, profile, targets: targetsForCurrentWeight({ ...s, profile }) };
    });
    vibrate(30);
  },

  deleteWeightEntry(id: string) {
    update((s) => ({ weightEntries: s.weightEntries.filter((e) => e.id !== id) }));
  },

  logSteps(steps: number) {
    const day = today();
    update((s) => {
      const existing = stepsOn(s, day);
      const stepEntries = existing
        ? s.stepEntries.map((e) => (e.id === existing.id ? { ...e, steps: Math.max(0, steps) } : e))
        : [...s.stepEntries, { id: uuid(), localDate: day, steps: Math.max(0, steps), source: "manual" as const }];
      return { stepEntries };
    });
  },

  // Food diary ----------------------------------------------------------------

  logFood(
    food: FoodItem,
    amount: number,
    amountIsServings: boolean,
    mealSlot: MealSlot,
    day: Day,
    calories: number,
    macros: MacroGrams,
  ) {
    update((s) => ({
      diaries: appendEntries(s, day, [makeEntry(food, amount, amountIsServings, mealSlot, day, calories, macros)]),
    }));
    vibrate(15);
  },

  deleteFoodEntry(entry: FoodLogEntry) {
    update((s) => {
      const diary = diaryFor(s, entry.localDate);
      return {
        diaries: {
          ...s.diaries,
          [entry.localDate]: { ...diary, entries: diary.entries.filter((e) => e.id !== entry.id) },
        },
      };
    });
  },

  setDiaryComplete(day: Day, complete: boolean) {
    update((s) => ({ diaries: { ...s.diaries, [day]: { ...diaryFor(s, day), markedComplete: complete } } }));
  },

  copyYesterday(day: Day) {
    update((s) => {
      const source = diaryFor(s, addDays(day, -1));
      if (source.entries.length === 0) return {};
      const copied = source.entries.map((e) =>
        makeEntry(e.food, e.amount, e.amountIsServings, e.mealSlot, day, e.loggedCalories, e.loggedMacros, e.notes),
      );
      return { diaries: appendEntries(s, day, copied) };
    });
  },

  quickAdd(calories: number, protein: number, carbs: number, fat: number, mealSlot: MealSlot, day: Day) {
    const food: FoodItem = {
      id: uuid(),
      name: "Quick Add",
      source: "customUser",
      servingDescription: "1 entry",
      calories,
      proteinGrams: protein,
      carbohydrateGrams: carbs,
      fatGrams: fat,
      measurementState: "serving",
      isCustom: true,
      isVerified: false,
      allergenTags: [],
      isFavorite: false,
    };
    actions.logFood(food, 1, true, mealSlot, day, calories, { protein, carbohydrates: carbs, fat });
  },

  saveCustomFood(food: FoodItem) {
    update((s) => {
      // One food per barcode: re-scanning a product replaces the earlier entry.
      const others = s.customFoods.filter((f) => f.id !== food.id && !(food.barcode && f.barcode === food.barcode));
      const index = s.customFoods.findIndex((f) => f.id === food.id || (food.barcode && f.barcode === food.barcode));
      const next = [...others];
      next.splice(index < 0 ? next.length : Math.min(index, next.length), 0, food);
      return { customFoods: next };
    });
  },

  deleteCustomFood(id: string) {
    update((s) => ({ customFoods: s.customFoods.filter((f) => f.id !== id) }));
  },

  // Meal plan -----------------------------------------------------------------

  generateMealPlan(containing: Day) {
    update((s) => {
      const targets = targetsForCurrentWeight(s);
      return { targets, mealPlanDays: withWeekPlan({ ...s, targets }, containing) };
    });
  },

  regenerateDay(day: Day) {
    update((s) => {
      if (!hasCoachAIAccess(s.subscription)) return {};
      const targets = targetsForCurrentWeight(s);
      const plan = planFor({ ...s, targets }, day);
      return plan ? { targets, mealPlanDays: { ...s.mealPlanDays, [day]: plan } } : {};
    });
  },

  toggleLock(itemID: string, day: Day) {
    update((s) => {
      const plan = s.mealPlanDays[day];
      if (!plan) return {};
      const meals = plan.meals.map((m) => ({
        ...m,
        items: m.items.map((i) => (i.id === itemID ? { ...i, isLocked: !i.isLocked } : i)),
      }));
      return { mealPlanDays: { ...s.mealPlanDays, [day]: { ...plan, meals } } };
    });
  },

  /** Swap one ingredient; portions and daily totals are re-fitted and the day re-validated. */
  swapFood(itemID: string, food: FoodItem, day: Day): string | undefined {
    const plan = state.mealPlanDays[day];
    if (!plan) return undefined;
    const result = swapPlanItem(plan, itemID, food);
    update((s) => ({ mealPlanDays: { ...s.mealPlanDays, [day]: result.plan } }));
    return result.message;
  },

  /** Replace a whole meal with the next suitable recipe; the day is re-fitted and re-validated. */
  swapMeal(mealID: string, day: Day) {
    update((s) => {
      const plan = s.mealPlanDays[day];
      if (!plan) return {};
      return { mealPlanDays: { ...s.mealPlanDays, [day]: swapPlanMeal(plan, mealID, plannerContext(s, day)) } };
    });
  },

  logPlannedMeal(meal: Meal, day: Day) {
    update((s) => {
      const entries = meal.items.map((item) =>
        item.grams !== undefined
          ? makeEntry(item.food, item.grams, false, meal.slot, day, item.calories, item.macros)
          : makeEntry(item.food, item.servings ?? 1, true, meal.slot, day, item.calories, item.macros),
      );
      return { diaries: appendEntries(s, day, entries), selectedTab: "log" };
    });
    vibrate(15);
  },

  setIntraWorkoutEnabled(enabled: boolean) {
    update((s) => {
      const profile = { ...s.profile, intraWorkoutEnabled: enabled, updatedAt: nowISO() };
      // Keep any coach/model calorie adjustments — only the intra flag and macro split refresh.
      const next: AppState = { ...s, profile, targets: targetsForCurrentWeight({ ...s, profile }, enabled) };
      const plan = hasCoachAIAccess(s.subscription) ? planFor(next, today()) : undefined;
      return {
        profile,
        targets: next.targets,
        mealPlanDays: plan ? { ...s.mealPlanDays, [today()]: plan } : s.mealPlanDays,
      };
    });
  },

  // Coaching ------------------------------------------------------------------

  submitWeeklyCheckIn(
    draft: Omit<WeeklyCheckIn, "id" | "createdAt" | "decision" | "userApprovedAdjustment" | "weekStart">,
  ): CoachDecision {
    const s = state;
    const prev = previousWeek(s);
    const curr = currentWeek(s);
    const rate = weeklyRate(s);
    const ruleDecision = evaluate({
      goal: s.profile.goalPhase,
      previousWeek: prev,
      currentWeek: curr,
      rate,
      currentTrainingCalories: s.targets?.training.calories ?? 0,
      currentRestCalories: s.targets?.rest.calories ?? 0,
      currentMacros: s.targets?.training.macros ?? ZERO_MACROS,
      stepTarget: s.profile.stepTarget,
      adherence: draft.adherence,
      performance: draft.performance,
      appearance: draft.appearance,
      hunger: draft.hunger,
      energy: draft.energy,
      weightKg: s.profile.currentWeightKg,
      sex: s.profile.biologicalSex,
      recentRefeed: s.checkIns.some((c) => c.decision?.refeed && c.userApprovedAdjustment),
    });
    // The rules decide whether calories may change; a confident personal model decides by how much.
    const decision = blendDecisionWithModel(
      ruleDecision,
      adaptiveRecommendation(s),
      s.targets?.training,
      s.profile.currentWeightKg,
      s.profile.goalPhase,
      s.profile.biologicalSex,
    );
    const checkIn: WeeklyCheckIn = {
      ...draft,
      id: uuid(),
      weekStart: curr.startDate,
      createdAt: nowISO(),
      decision,
      userApprovedAdjustment: false,
      previousAverageKg: prev.averageKg,
      currentAverageKg: curr.averageKg,
      rateKg: rate?.absoluteChangeKg,
      ratePercent: rate?.percentChange,
    };
    update((st) => ({
      checkIns: [checkIn, ...st.checkIns],
      coachStatusMessage: decision.summary,
      chatMessages: [...st.chatMessages, message("coach", decision.summary)],
    }));
    return decision;
  },

  applyCoachDecision(decision: CoachDecision) {
    update((s) => {
      if (!s.targets) return {};
      const old = s.targets;
      let targets: NutritionTargetPair = { training: { ...old.training }, rest: { ...old.rest } };
      let profile = { ...s.profile };
      const setSteps = (n: number) => {
        profile.stepTarget = n;
        targets.training.stepTarget = n;
        targets.rest.stepTarget = n;
      };
      const a = decision.action;
      switch (a.type) {
        case "increaseCalories":
        case "decreaseCalories": {
          const signed = a.type === "increaseCalories" ? Math.abs(a.amount) : -Math.abs(a.amount);
          targets = applyCalorieAdjustment(
            targets.training,
            signed,
            profile.currentWeightKg,
            profile.goalPhase,
            profile.biologicalSex,
          );
          break;
        }
        case "increaseSteps":
          setSteps(adjustedStepTarget(profile.stepTarget, a.amount));
          break;
        case "decreaseSteps":
          setSteps(adjustedStepTarget(profile.stepTarget, -Math.abs(a.amount)));
          break;
        case "recommendNutritionIncreaseReview":
        case "recommendNutritionDecreaseReview":
          if (decision.suggestedTrainingCalories !== undefined && decision.suggestedMacros) {
            targets.training = {
              ...targets.training,
              calories: decision.suggestedTrainingCalories,
              macros: decision.suggestedMacros,
              source: "coachRecommendation",
            };
            targets.rest = restDayTarget(targets.training, profile.currentWeightKg, profile.goalPhase, profile.biologicalSex);
          }
          break;
        default:
          break;
      }
      if (decision.suggestedSteps !== undefined) setSteps(cappedStepTarget(decision.suggestedSteps));

      const adjustment: PlanAdjustment = {
        id: uuid(),
        date: nowISO(),
        oldCalories: old.training.calories,
        newCalories: targets.training.calories,
        oldSteps: old.training.stepTarget,
        newSteps: targets.training.stepTarget,
        reason: decision.summary,
        source: "coachRecommendation",
        userApproved: true,
      };
      const next: AppState = { ...s, profile, targets };
      return {
        profile,
        targets,
        planAdjustments: [adjustment, ...s.planAdjustments],
        checkIns: s.checkIns.map((c) => (c.decision?.id === decision.id ? { ...c, userApprovedAdjustment: true } : c)),
        mealPlanDays: withWeekPlan(next, today()),
        coachStatusMessage: "Updated plan applied for the new coaching week.",
      };
    });
  },

  /**
   * Apply the personal model's recommendation. `auto` = triggered by new data (respects the user's
   * auto-adjust setting, subscription, confidence, and the one-change-per-week limit).
   */
  applyAdaptiveRecommendation(auto = false): boolean {
    const s = state;
    const rec = adaptiveRecommendation(s);
    if (!s.targets || !rec || !rec.shouldAdjust || !hasCoachAIAccess(s.subscription)) return false;
    if (
      auto &&
      (!s.preferences.adaptiveAutoAdjust || daysSinceLastAdjustment(s) < AdaptiveConfig.minDaysBetweenAutoAdjustments)
    ) {
      return false;
    }
    const old = s.targets;
    const targets = applyModelAdjustment(old, rec.deltaKcal, s.profile.currentWeightKg, s.profile.goalPhase, s.profile.biologicalSex);
    if (targets.training.calories === old.training.calories) return false; // already at a safety floor
    const reason = rec.summary;
    update((st) => {
      const next: AppState = { ...st, targets };
      return {
        targets,
        planAdjustments: [
          {
            id: uuid(),
            date: nowISO(),
            oldCalories: old.training.calories,
            newCalories: targets.training.calories,
            oldSteps: old.training.stepTarget,
            newSteps: targets.training.stepTarget,
            reason,
            source: "adaptiveModel",
            userApproved: !auto,
          },
          ...st.planAdjustments,
        ],
        mealPlanDays: withWeekPlan(next, today()),
        coachStatusMessage: `${auto ? "Auto-adjusted" : "Adjusted"} by your personal model: ${old.training.calories} → ${targets.training.calories} kcal on training days.`,
        chatMessages: [...st.chatMessages, message("coach", `${auto ? "I updated your plan automatically. " : ""}${reason}`)],
      };
    });
    return true;
  },

  runAdaptiveAutoAdjust() {
    actions.applyAdaptiveRecommendation(true);
  },

  /**
   * Plans saved by the old generator (no recipe ids) that fail validation — e.g. cooked weights or two
   * protein foods in one meal — are rebuilt with the current planner before they're shown again.
   */
  revalidateStoredPlans() {
    const s = state;
    if (!hasCoachAIAccess(s.subscription) || !s.targets) return;
    const stale = Object.entries(s.mealPlanDays).filter(
      ([, plan]) => plan.meals.every((m) => !m.recipeId) && !validatePlanDay(plan).ok,
    );
    if (!stale.length) return;
    update((st) => {
      const targets = targetsForCurrentWeight(st);
      const next: AppState = { ...st, targets };
      const days = { ...st.mealPlanDays };
      for (const [day] of stale) {
        const plan = planFor(next, day);
        if (plan) days[day] = plan;
      }
      return { targets, mealPlanDays: days };
    });
  },

  sendCoachMessage(text: string) {
    const trimmed = text.trim();
    if (!trimmed) return;
    update((s) => ({ chatMessages: [...s.chatMessages, message("user", trimmed)] }));
    const s = state;
    if (!hasCoachAIAccess(s.subscription)) {
      update((st) => ({
        chatMessages: [
          ...st.chatMessages,
          message(
            "coach",
            "Coach AI subscription required for live coaching conversations. Your food log and history remain available.",
          ),
        ],
      }));
      return;
    }
    // Small delay so the reply feels conversational.
    setTimeout(() => {
      let reply: CoachChatMessage;
      try {
        const response = chat(state.chatMessages, state.checkIns[0]?.decision, aiContext(state));
        reply = message("coach", response.userMessage, { structured: response });
      } catch {
        reply = message("coach", OFFLINE_COACH_MESSAGE);
      }
      update((st) => ({ chatMessages: [...st.chatMessages, reply] }));
    }, 450);
  },

  // Subscription (local demo — the web build takes no payments) -----------------

  startTrialLocally() {
    update((s) => {
      const subscription: SubscriptionEntitlement = {
        ...s.subscription,
        status: "trial",
        isTrialEligible: false,
        expirationDate: new Date(Date.now() + CoachingConfig.freeTrialDays * 86_400_000).toISOString(),
      };
      const next: AppState = { ...s, subscription };
      return {
        subscription,
        mealPlanDays: Object.keys(s.mealPlanDays).length ? s.mealPlanDays : withWeekPlan(next, today()),
        coachStatusMessage: "Coach AI trial active — weekly check-ins and meal plans unlocked.",
      };
    });
  },

  restorePurchasesLocally() {
    update((s) => ({
      coachStatusMessage: hasCoachAIAccess(s.subscription)
        ? "Subscription restored."
        : "No active subscription found to restore.",
    }));
  },

  cancelSubscriptionLocally() {
    update(() => ({ subscription: { ...defaultSubscription(), isTrialEligible: false } }));
  },

  // Settings / data -----------------------------------------------------------

  exportDataJSON(): string {
    const { selectedTab: _t, pendingStagnationAlerts: _p, ...persisted } = state;
    return JSON.stringify(persisted, null, 2);
  },

  importDataJSON(json: string): boolean {
    try {
      const parsed = JSON.parse(json) as PersistedState;
      if (parsed.version !== 1 || !parsed.profile) return false;
      localStorage.setItem(STORAGE_KEY, JSON.stringify(parsed));
      set(load(), false);
      return true;
    } catch {
      return false;
    }
  },

  deleteCoachingData() {
    update(() => ({
      weightEntries: [],
      stepEntries: [],
      diaries: {},
      mealPlanDays: {},
      checkIns: [],
      planAdjustments: [],
      photoSets: [],
      workoutSessions: [],
      workoutTemplateOverrides: [],
      activeWorkout: undefined,
      workoutRestEndsAt: undefined,
      pendingStagnationAlerts: [],
      chatMessages: [message("coach", "Your coaching data was cleared. Generate a new plan when you're ready.")],
      coachStatusMessage: "Coaching data deleted.",
    }));
  },

  deleteAccountLocally() {
    set(freshState());
  },

  savePhotoSet(photoSet: ProgressPhotoSet) {
    update((s) => {
      const exists = s.photoSets.some((p) => p.id === photoSet.id);
      return {
        photoSets: exists ? s.photoSets.map((p) => (p.id === photoSet.id ? photoSet : p)) : [photoSet, ...s.photoSets],
      };
    });
  },

  deletePhotoSet(id: string) {
    update((s) => ({ photoSets: s.photoSets.filter((p) => p.id !== id) }));
  },

  // Workouts ------------------------------------------------------------------

  startWorkout(templateID: WorkoutTemplateID) {
    const template = resolvedTemplate(state, templateID);
    const exercises: ExerciseLog[] = template.exercises.map((e) => ({
      id: e.id,
      name: e.name,
      plannedSets: e.defaultSets,
      isBodyweightMaxReps: e.isBodyweightMaxReps,
      sets: [],
    }));
    update(() => ({
      activeWorkout: {
        id: uuid(),
        templateID,
        templateName: template.name,
        localDate: today(),
        startedAt: nowISO(),
        exercises,
        notes: "",
      },
      workoutRestEndsAt: undefined,
      selectedTab: "workout",
    }));
  },

  updatePlannedSets(templateID: WorkoutTemplateID, exerciseID: string, sets: number) {
    const clamped = Math.max(1, Math.min(sets, 12));
    update((s) => {
      const existing = s.workoutTemplateOverrides.find((o) => o.templateID === templateID);
      const overrides = existing
        ? s.workoutTemplateOverrides.map((o) =>
            o.templateID === templateID ? { ...o, setCounts: { ...o.setCounts, [exerciseID]: clamped } } : o,
          )
        : [...s.workoutTemplateOverrides, { templateID, setCounts: { [exerciseID]: clamped } }];
      const active =
        s.activeWorkout && s.activeWorkout.templateID === templateID
          ? {
              ...s.activeWorkout,
              exercises: s.activeWorkout.exercises.map((e) => (e.id === exerciseID ? { ...e, plannedSets: clamped } : e)),
            }
          : s.activeWorkout;
      return { workoutTemplateOverrides: overrides, activeWorkout: active };
    });
  },

  logSet(exerciseID: string, weightKg: number | undefined, reps: number) {
    update((s) => {
      const session = s.activeWorkout;
      if (!session) return {};
      const exercises = session.exercises.map((e) =>
        e.id === exerciseID
          ? {
              ...e,
              sets: [
                ...e.sets,
                {
                  id: uuid(),
                  setNumber: e.sets.length + 1,
                  weightKg: e.isBodyweightMaxReps ? undefined : weightKg,
                  reps,
                  completedAt: nowISO(),
                },
              ],
            }
          : e,
      );
      return {
        activeWorkout: { ...session, exercises },
        workoutRestEndsAt: new Date(Date.now() + CoachingConfig.defaultRestSeconds * 1000).toISOString(),
      };
    });
    vibrate(20);
  },

  deleteLastSet(exerciseID: string) {
    update((s) => {
      const session = s.activeWorkout;
      if (!session) return {};
      const exercises = session.exercises.map((e) => (e.id === exerciseID ? { ...e, sets: e.sets.slice(0, -1) } : e));
      return { activeWorkout: { ...session, exercises } };
    });
  },

  skipRestTimer() {
    update(() => ({ workoutRestEndsAt: undefined }));
  },

  discardActiveWorkout() {
    update(() => ({ activeWorkout: undefined, workoutRestEndsAt: undefined }));
  },

  finishActiveWorkout(): string[] {
    const session = state.activeWorkout;
    if (!session) return [];
    const completed = { ...session, completedAt: nowISO() };
    const sessions = [...state.workoutSessions, completed].sort((a, b) => b.startedAt.localeCompare(a.startedAt));
    const stagnant = stagnantExercises(session.templateID, sessions, CoachingConfig.stagnationWorkoutStreak);
    update(() => ({
      workoutSessions: sessions,
      activeWorkout: undefined,
      workoutRestEndsAt: undefined,
      pendingStagnationAlerts: stagnant,
    }));
    return stagnant;
  },

  deleteWorkoutSession(id: string) {
    update((s) => ({ workoutSessions: s.workoutSessions.filter((w) => w.id !== id) }));
  },

  acknowledgeStagnationAlerts() {
    update(() => ({ pendingStagnationAlerts: [] }), false);
  },
};

// Workout selectors ------------------------------------------------------------

export function resolvedTemplate(s: AppState, id: WorkoutTemplateID): WorkoutTemplate {
  const base = WORKOUT_LIBRARY.find((t) => t.id === id)!;
  const override = s.workoutTemplateOverrides.find((o) => o.templateID === id);
  if (!override) return base;
  return {
    ...base,
    exercises: base.exercises.map((e) =>
      override.setCounts[e.id] !== undefined ? { ...e, defaultSets: Math.max(1, override.setCounts[e.id]) } : e,
    ),
  };
}

export function lastCompletedSession(s: AppState, id: WorkoutTemplateID): WorkoutSession | undefined {
  return s.workoutSessions
    .filter((w) => w.templateID === id && w.completedAt)
    .sort((a, b) => b.startedAt.localeCompare(a.startedAt))[0];
}

export function previousPerformance(s: AppState, id: WorkoutTemplateID, exerciseID: string): ExerciseLog | undefined {
  return lastCompletedSession(s, id)?.exercises.find((e) => e.id === exerciseID);
}

// Re-train on launch and catch up on any adjustment that became due while the app was closed.
if (typeof window !== "undefined") {
  queueMicrotask(() => {
    actions.revalidateStoredPlans();
    actions.runAdaptiveAutoAdjust();
  });
}
