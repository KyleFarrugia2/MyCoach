import { describe, expect, it } from "vitest";
import { CoachingConfig } from "../src/core/config";
import { addDays, datesInWeek, weekStart, weekdayOf } from "../src/core/dates";
import { type WeightEntry, hasBannedAllergen, planCalories, scaleFood, uuid } from "../src/core/models";
import { evaluate, isApplicable } from "../src/engines/coaching";
import { BUNDLED_FOODS, searchFoods } from "../src/engines/foodCatalog";
import { generatePlanDay } from "../src/engines/mealPlanner";
import { applyCalorieAdjustment, buildInitialTargets, intraWorkoutTargets } from "../src/engines/nutrition";
import { UnitConversion, parseDecimal } from "../src/engines/units";
import { makeWeek, rateOfChange } from "../src/engines/weight";
import { type WorkoutSession, stagnantExercises } from "../src/engines/workout";

const profile = {
  weightKg: 80,
  heightCm: 180,
  ageYears: 30,
  sex: "male" as const,
  goal: "cut" as const,
  activityBand: "sixToEight" as const,
  trainingDaysPerWeek: 4,
  stepTarget: 8_000,
  intraWorkoutEnabled: true,
};

function weigh(day: string, kg: number): WeightEntry {
  return { id: uuid(), timestamp: `${day}T07:00:00.000Z`, localDate: day, weightKg: kg, inputUnit: "kilogram", isOfficialMorningCheckIn: true };
}

describe("dates", () => {
  it("uses Monday-first weeks", () => {
    expect(weekdayOf("2026-11-09")).toBe(1); // Monday
    expect(weekdayOf("2026-11-15")).toBe(7); // Sunday
    expect(weekStart("2026-11-15")).toBe("2026-11-09");
    expect(datesInWeek("2026-11-11")).toEqual([
      "2026-11-09",
      "2026-11-10",
      "2026-11-11",
      "2026-11-12",
      "2026-11-13",
      "2026-11-14",
      "2026-11-15",
    ]);
  });
});

describe("nutrition engine", () => {
  it("builds training/rest targets with protein & fat preserved and a smaller rest day", () => {
    const { training, rest } = buildInitialTargets(profile);
    expect(training.isTrainingDay).toBe(true);
    expect(rest.isTrainingDay).toBe(false);
    expect(rest.calories).toBeLessThan(training.calories);
    expect(training.calories - rest.calories).toBeLessThanOrEqual(CoachingConfig.restDayCalorieDeficit);
    expect(rest.macros.protein).toBeCloseTo(training.macros.protein);
    expect(training.macros.protein).toBeCloseTo(80 * 2.2046226218, 6); // 1 g per lb
    expect(training.calories).toBeGreaterThanOrEqual(CoachingConfig.absoluteMinimumDailyCaloriesMale);
  });

  it("caps a single weekly calorie change", () => {
    const { training } = buildInitialTargets(profile);
    const next = applyCalorieAdjustment(training, 1_000, 80, "cut", "male");
    expect(next.training.calories - training.calories).toBe(CoachingConfig.maximumSingleWeekCalorieChange);
  });

  it("keeps intra-workout targets inside configured bounds", () => {
    const t = intraWorkoutTargets(200, "gain");
    expect(t.eaaGrams).toBeLessThanOrEqual(CoachingConfig.maximumEAAGrams);
    expect(t.dextroseGrams).toBeLessThanOrEqual(CoachingConfig.maximumDextroseGrams);
  });
});

describe("units", () => {
  it("parses comma decimals (Android keypads in many locales)", () => {
    expect(parseDecimal("82,5")).toBe(82.5);
    expect(parseDecimal("")).toBeUndefined();
    expect(parseDecimal("abc")).toBeUndefined();
  });
  it("round-trips kg ↔ lb", () => {
    expect(UnitConversion.kilograms(UnitConversion.displayWeight(80, "pound"), "pound")).toBeCloseTo(80);
  });
});

describe("weight analytics", () => {
  it("averages only official entries and classifies completeness", () => {
    const mon = "2026-11-02";
    const entries = [0, 1, 2, 3].map((i) => weigh(addDays(mon, i), 80 + i));
    const week = makeWeek(mon, entries);
    expect(week.entryCount).toBe(4);
    expect(week.completeness).toBe("sufficientForAdjustment");
    expect(week.averageKg).toBeCloseTo(81.5);
  });

  it("computes week-over-week rate", () => {
    const prev = makeWeek("2026-11-02", [0, 1, 2, 3].map((i) => weigh(addDays("2026-11-02", i), 80)));
    const curr = makeWeek("2026-11-09", [0, 1, 2, 3].map((i) => weigh(addDays("2026-11-09", i), 79.5)));
    const rate = rateOfChange(prev, curr)!;
    expect(rate.absoluteChangeKg).toBeCloseTo(-0.5);
  });
});

describe("coaching decision engine", () => {
  const { training, rest } = buildInitialTargets(profile);
  const base = {
    goal: "cut" as const,
    currentTrainingCalories: training.calories,
    currentRestCalories: rest.calories,
    currentMacros: training.macros,
    stepTarget: 8_000,
    adherence: "eightyFiveTo94" as const,
    performance: "same" as const,
    appearance: "aboutTheSame" as const,
    hunger: 3,
    energy: 3,
    weightKg: 80,
    sex: "male" as const,
    recentRefeed: false,
  };

  it("asks for more data when the week has too few weigh-ins", () => {
    const prev = makeWeek("2026-11-02", []);
    const curr = makeWeek("2026-11-09", [weigh("2026-11-09", 80)]);
    const d = evaluate({ ...base, previousWeek: prev, currentWeek: curr, rate: rateOfChange(prev, curr) });
    expect(d.action.type).toBe("requireMoreData");
    expect(isApplicable(d.action)).toBe(false);
  });

  it("reviews adherence instead of cutting food when adherence is poor", () => {
    const prev = makeWeek("2026-11-02", [0, 1, 2, 3].map((i) => weigh(addDays("2026-11-02", i), 80)));
    const curr = makeWeek("2026-11-09", [0, 1, 2, 3].map((i) => weigh(addDays("2026-11-09", i), 80)));
    const d = evaluate({ ...base, adherence: "under50", previousWeek: prev, currentWeek: curr, rate: rateOfChange(prev, curr) });
    expect(d.action.type).toBe("reviewAdherence");
  });

  it("recommends adding food after an extreme loss on a cut", () => {
    const prev = makeWeek("2026-11-02", [0, 1, 2, 3].map((i) => weigh(addDays("2026-11-02", i), 82)));
    const curr = makeWeek("2026-11-09", [0, 1, 2, 3].map((i) => weigh(addDays("2026-11-09", i), 80)));
    const d = evaluate({ ...base, previousWeek: prev, currentWeek: curr, rate: rateOfChange(prev, curr) });
    expect(d.action.type).toBe("recommendNutritionIncreaseReview");
    expect(d.suggestedTrainingCalories).toBeGreaterThan(training.calories);
    expect(isApplicable(d.action)).toBe(true);
  });
});

describe("food catalog", () => {
  it("returns custom foods first and matches multi-token queries", () => {
    const custom = { ...BUNDLED_FOODS[0], id: "custom-1", name: "My Chicken Wrap", source: "customUser" as const, isCustom: true };
    const results = searchFoods("chicken", [custom]);
    expect(results[0].id).toBe("custom-1");
    expect(searchFoods("rice cooked", []).every((f) => f.name.includes("Rice") && f.measurementState === "cooked")).toBe(true);
  });

  it("scales per-gram nutrition", () => {
    const rice = BUNDLED_FOODS.find((f) => f.name === "White Rice" && f.measurementState === "dry")!;
    expect(scaleFood(rice, 50)!.calories).toBeCloseTo(182.5);
  });
});

describe("meal plan generator", () => {
  it("lands near the calorie target and respects allergies", () => {
    const { training } = buildInitialTargets(profile);
    const day = generatePlanDay({
      date: "2026-11-09",
      weekday: 1,
      isTrainingDay: true,
      target: training,
      ctx: {
        allergies: ["dairy", "eggs"],
        dislikedFoods: [],
        preferredFoods: [],
        trainingTime: "evening",
        intraWorkoutEnabled: true,
        weightKg: 80,
        goal: "cut",
      },
    });
    expect(day.meals).toHaveLength(CoachingConfig.requiredMealCount);
    expect(Math.abs(planCalories(day) - training.calories) / training.calories).toBeLessThan(0.06);
    for (const meal of day.meals) for (const item of meal.items) expect(hasBannedAllergen(item.food, ["dairy", "eggs"])).toBe(false);
  });
});

describe("workout stagnation", () => {
  it("flags an exercise with no progress for 3 sessions in a row", () => {
    const session = (i: number): WorkoutSession => ({
      id: uuid(),
      templateID: "pushA",
      templateName: "Push A",
      localDate: addDays("2026-10-01", i * 7),
      startedAt: `2026-10-${String(1 + i).padStart(2, "0")}T18:00:00.000Z`,
      completedAt: `2026-10-${String(1 + i).padStart(2, "0")}T19:00:00.000Z`,
      exercises: [
        {
          id: "y raise",
          name: "Y raise",
          plannedSets: 2,
          isBodyweightMaxReps: false,
          sets: [{ id: uuid(), setNumber: 1, weightKg: 10, reps: 12, completedAt: "" }],
        },
      ],
      notes: "",
    });
    expect(stagnantExercises("pushA", [0, 1, 2, 3].map(session), 3)).toEqual(["Y raise"]);
    expect(stagnantExercises("pushA", [0, 1, 2].map(session), 3)).toEqual([]);
  });
});
