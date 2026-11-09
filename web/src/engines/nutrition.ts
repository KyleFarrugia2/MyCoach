import { CoachingConfig } from "../core/config";
import {
  type ActivityBand,
  type BiologicalSex,
  type DailyNutritionTarget,
  type GoalPhase,
  type MacroGrams,
  type NutritionTargetPair,
  NutritionMath,
  makeTarget,
} from "../core/models";

/** Port of NutritionEngine.swift — deterministic starting targets and adjustments. */
export interface ProfileInput {
  weightKg: number;
  heightCm: number;
  ageYears: number;
  sex: BiologicalSex;
  goal: GoalPhase;
  activityBand: ActivityBand;
  trainingDaysPerWeek: number;
  stepTarget: number;
  intraWorkoutEnabled: boolean;
}

/** Mifflin–St Jeor inspired BMR estimate. Initial target only — adapts from weigh-ins later. */
export function basalMetabolicRate(weightKg: number, heightCm: number, ageYears: number, sex: BiologicalSex): number {
  const base = 10 * weightKg + 6.25 * heightCm - 5 * ageYears;
  switch (sex) {
    case "male":
      return base + 5;
    case "female":
      return base - 161;
    case "preferNotToSay":
      return base - 78;
  }
}

export function activityMultiplier(band: ActivityBand, trainingDaysPerWeek: number): number {
  const trainingBoost = Math.min(0.25, trainingDaysPerWeek * 0.03);
  const base = { under4000: 1.2, fourToSix: 1.35, sixToEight: 1.45, eightToTen: 1.55, tenPlus: 1.65 }[band];
  return base + trainingBoost;
}

export function estimatedMaintenanceCalories(input: ProfileInput): number {
  const bmr = basalMetabolicRate(input.weightKg, input.heightCm, input.ageYears, input.sex);
  return Math.round(bmr * activityMultiplier(input.activityBand, input.trainingDaysPerWeek));
}

export function clampCalories(value: number, sex: BiologicalSex): number {
  const floor =
    sex === "male"
      ? CoachingConfig.absoluteMinimumDailyCaloriesMale
      : sex === "female"
        ? CoachingConfig.absoluteMinimumDailyCaloriesFemale
        : CoachingConfig.absoluteMinimumDailyCaloriesUnspecified;
  return Math.max(floor, value);
}

export function initialTrainingCalories(input: ProfileInput): number {
  const maintenance = estimatedMaintenanceCalories(input);
  const raw = input.goal === "cut" ? maintenance - 400 : input.goal === "gain" ? maintenance + 250 : maintenance;
  return clampCalories(raw, input.sex);
}

/** 1 g per pound of current bodyweight (≈ 2.2 g/kg), regardless of goal. */
export function proteinGrams(weightKg: number, _goal?: GoalPhase): number {
  return weightKg * CoachingConfig.proteinGramsPerKg;
}

export function fatGrams(weightKg: number, goal: GoalPhase): number {
  const perKg =
    goal === "cut"
      ? CoachingConfig.fatGramsPerKgCut
      : goal === "gain"
        ? CoachingConfig.fatGramsPerKgGain
        : (CoachingConfig.fatGramsPerKgCut + CoachingConfig.fatGramsPerKgGain) / 2;
  return Math.max(weightKg * CoachingConfig.minimumFatGramsPerKg, weightKg * perKg);
}

export function macrosForCalories(calories: number, weightKg: number, goal: GoalPhase): MacroGrams {
  const protein = proteinGrams(weightKg, goal);
  const fat = fatGrams(weightKg, goal);
  const carbs = NutritionMath.carbohydratesFromRemainingCalories(calories, protein, fat);
  return { protein, carbohydrates: Math.max(0, carbs), fat };
}

/**
 * Rest day ideally ~500 kcal below training, primarily from carbohydrate.
 * If constraints would be violated, shrink the deficit rather than cutting protein/fat unsafely.
 */
export function restDayTarget(
  training: DailyNutritionTarget,
  weightKg: number,
  _goal: GoalPhase,
  sex: BiologicalSex,
): DailyNutritionTarget {
  const desired = training.calories - CoachingConfig.restDayCalorieDeficit;
  const floored = clampCalories(desired, sex);
  const protein = training.macros.protein;
  const fat = Math.max(training.macros.fat, weightKg * CoachingConfig.minimumFatGramsPerKg);
  const minCaloriesForPF = Math.ceil(
    protein * CoachingConfig.caloriesPerGramProtein + fat * CoachingConfig.caloriesPerGramFat,
  );
  const restCalories = Math.max(floored, minCaloriesForPF);
  const carbs = NutritionMath.carbohydratesFromRemainingCalories(restCalories, protein, fat);
  return makeTarget({
    calories: restCalories,
    macros: { protein, carbohydrates: Math.max(0, carbs), fat },
    isTrainingDay: false,
    stepTarget: training.stepTarget,
    source: training.source,
    includesIntraWorkout: false,
  });
}

export function cappedStepTarget(requested: number): number {
  return Math.max(0, Math.min(requested, CoachingConfig.maxStepTarget));
}

export function adjustedStepTarget(current: number, delta: number): number {
  return cappedStepTarget(current + delta);
}

export function buildInitialTargets(input: ProfileInput): NutritionTargetPair {
  const steps = cappedStepTarget(input.stepTarget);
  const calories = initialTrainingCalories(input);
  const training = makeTarget({
    calories,
    macros: macrosForCalories(calories, input.weightKg, input.goal),
    isTrainingDay: true,
    stepTarget: steps,
    source: "engine",
    includesIntraWorkout: input.intraWorkoutEnabled,
  });
  return { training, rest: restDayTarget(training, input.weightKg, input.goal, input.sex) };
}

export function applyCalorieAdjustment(
  currentTraining: DailyNutritionTarget,
  deltaCalories: number,
  weightKg: number,
  goal: GoalPhase,
  sex: BiologicalSex,
): NutritionTargetPair {
  const bounded =
    Math.min(Math.abs(deltaCalories), CoachingConfig.maximumSingleWeekCalorieChange) * (deltaCalories >= 0 ? 1 : -1);
  const newCalories = clampCalories(currentTraining.calories + bounded, sex);
  const training = makeTarget({
    calories: newCalories,
    macros: macrosForCalories(newCalories, weightKg, goal),
    isTrainingDay: true,
    stepTarget: currentTraining.stepTarget,
    source: "coachRecommendation",
    includesIntraWorkout: currentTraining.includesIntraWorkout,
  });
  return { training, rest: restDayTarget(training, weightKg, goal, sex) };
}

export interface IntraWorkoutTargets {
  eaaGrams: number;
  dextroseGrams: number;
  waterMl: [number, number];
}

export function intraWorkoutTargets(weightKg: number, goal: GoalPhase): IntraWorkoutTargets {
  const eaa = Math.min(
    CoachingConfig.maximumEAAGrams,
    Math.max(CoachingConfig.minimumEAAGrams, weightKg * CoachingConfig.eaaGramsPerKgTraining),
  );
  const dexPerKg = goal === "gain" ? CoachingConfig.dextroseGramsPerKgGain : CoachingConfig.dextroseGramsPerKgCut;
  const dextrose = Math.min(
    CoachingConfig.maximumDextroseGrams,
    Math.max(CoachingConfig.minimumDextroseGrams, weightKg * dexPerKg),
  );
  return { eaaGrams: Math.round(eaa), dextroseGrams: Math.round(dextrose), waterMl: [750, 1000] };
}
