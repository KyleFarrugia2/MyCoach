import { describe, expect, it } from "vitest";
import type { FoodAllergy, MealPlanDay } from "../src/core/models";
import { BUNDLED_FOODS } from "../src/engines/foodCatalog";
import {
  PLANNER_FOODS,
  PlannerConfig,
  type PlannerContext,
  databaseKcalConsistent,
  domainOf,
  generatePlanDay,
  specForFood,
  swapOptionsFor,
  swapPlanItem,
  swapPlanMeal,
  validatePlanDay,
} from "../src/engines/mealPlanner";
import { buildInitialTargets, proteinGrams } from "../src/engines/nutrition";

const ctx = (over: Partial<PlannerContext> = {}): PlannerContext => ({
  allergies: ["none"],
  dislikedFoods: [],
  preferredFoods: [],
  trainingTime: "evening",
  intraWorkoutEnabled: true,
  weightKg: 80,
  goal: "cut",
  ...over,
});

function plan(weightKg: number, goal: "cut" | "gain", sex: "male" | "female", training: boolean, weekday: 1 | 2 | 3 | 4 | 5 | 6 | 7, c: Partial<PlannerContext> = {}) {
  const pair = buildInitialTargets({
    weightKg,
    heightCm: 175,
    ageYears: 30,
    sex,
    goal,
    activityBand: "sixToEight",
    trainingDaysPerWeek: 4,
    stepTarget: 8000,
    intraWorkoutEnabled: true,
  });
  return generatePlanDay({
    date: "2026-11-09",
    weekday,
    isTrainingDay: training,
    target: training ? pair.training : pair.rest,
    ctx: ctx({ weightKg, goal, ...c }),
  });
}

/** Rules every displayed plan must satisfy. */
function assertPractical(day: MealPlanDay) {
  for (const meal of day.meals) {
    const proteinSources = new Set(
      meal.items.map((i) => specForFood(i.food)).filter((s) => s.role === "protein").map((s) => s.group ?? s.key),
    );
    expect(proteinSources.size, `${meal.name}: one main protein source`).toBe(1);
    for (const item of meal.items) {
      const spec = specForFood(item.food);
      expect(item.food.measurementState, `${item.food.name} never cooked`).not.toBe("cooked");
      const amount = item.grams ?? item.servings!;
      if (spec.role !== "supplement") expect(domainOf(spec), `${item.food.name} ${amount} on its practical grid`).toContain(amount);
      if (spec.role === "carb") expect(amount, `${item.food.name} kept at a real portion`).toBeGreaterThanOrEqual(spec.min);
      expect(amount).toBeGreaterThan(0);
    }
  }
}

describe("protein target", () => {
  it("is 1 g per lb of current bodyweight for every goal", () => {
    expect(proteinGrams(80, "cut")).toBeCloseTo(176.37, 1);
    expect(proteinGrams(80, "gain")).toBeCloseTo(176.37, 1);
    expect(proteinGrams(100, "maintenance")).toBeCloseTo(220.46, 1);
  });

  it("training and rest targets fit 4/4/9 exactly within calories", () => {
    const { training, rest } = buildInitialTargets({ weightKg: 90, heightCm: 180, ageYears: 30, sex: "male", goal: "cut", activityBand: "sixToEight", trainingDaysPerWeek: 4, stepTarget: 8000, intraWorkoutEnabled: true });
    for (const t of [training, rest]) {
      const { protein, carbohydrates, fat } = t.macros;
      expect(4 * protein + 4 * carbohydrates + 9 * fat).toBeCloseTo(t.calories, 6);
      expect(protein).toBeCloseTo(90 * 2.2046226218, 6);
    }
  });
});

describe("planner food database", () => {
  it("uses only raw / dry / no-cook entries whose kcal match 4/4/9 within rounding", () => {
    for (const f of PLANNER_FOODS) {
      expect(f.state, f.name).not.toBe("cooked");
      expect(databaseKcalConsistent(f), `${f.name} kcal vs 4/4/9`).toBe(true);
    }
  });
});

describe("generated plans", () => {
  const allergySets: FoodAllergy[][] = [["none"], ["dairy"], ["eggs", "fish"], ["glutenWheat"]];
  const cases: [number, "cut" | "gain", "male" | "female"][] = [
    [55, "cut", "female"],
    [65, "gain", "female"],
    [75, "cut", "male"],
    [85, "gain", "male"],
    [95, "cut", "female"],
    [110, "cut", "male"],
    [130, "cut", "male"],
  ];

  it("meet protein, calories (4/4/9), carbs and fat within tolerance and every practicality rule", () => {
    let checked = 0;
    for (const [w, goal, sex] of cases)
      for (const training of [true, false])
        for (const weekday of [1, 4, 6] as const)
          for (const allergies of allergySets) {
            const day = plan(w, goal, sex, training, weekday, { allergies });
            const v = validatePlanDay(day);
            expect(v.issues, `${w}kg ${goal} ${sex} ${training ? "training" : "rest"} ${allergies}`).toEqual([]);
            expect(v.ok).toBe(true);
            const target = day.target.macros.protein;
            expect(v.totals.protein).toBeGreaterThanOrEqual(target - PlannerConfig.proteinUnderToleranceG);
            assertPractical(day);
            checked++;
          }
    expect(checked).toBe(cases.length * 2 * 3 * allergySets.length);
  });

  it("never mixes small amounts of different protein foods (e.g. chicken + 10 g beef)", () => {
    const day = plan(80, "cut", "male", true, 2);
    for (const meal of day.meals) {
      const proteinFoods = meal.items.filter((i) => specForFood(i.food).role === "protein");
      const groups = new Set(proteinFoods.map((i) => specForFood(i.food).group ?? i.food.id));
      expect(groups.size).toBe(1);
    }
  });

  it("labels every quantity raw or dry where cooking changes weight", () => {
    const day = plan(80, "cut", "male", true, 2);
    for (const item of day.meals.flatMap((m) => m.items)) {
      if (["Chicken Breast", "Lean Beef (5% fat)", "Turkey Breast", "White Fish (cod)", "Potato", "Sweet Potato"].includes(item.food.name)) {
        expect(item.food.measurementState).toBe("raw");
      }
      if (["White Rice", "Brown Rice", "Pasta", "Oats (rolled)"].includes(item.food.name)) {
        expect(item.food.measurementState).toBe("dry");
      }
    }
  });

  it("honours allergies, dislikes and preferences", () => {
    const day = plan(72, "cut", "female", true, 2, {
      allergies: ["dairy"],
      dislikedFoods: ["fish"],
      preferredFoods: ["Chicken breast", "Rice"],
    });
    const names = day.meals.flatMap((m) => m.items.map((i) => i.food.name));
    expect(names.some((n) => /yogurt|cottage|whey/i.test(n))).toBe(false);
    expect(names.some((n) => /fish|cod/i.test(n))).toBe(false);
    expect(names).toContain("Chicken Breast");
    expect(names.some((n) => /rice/i.test(n)), "a preferred rice appears").toBe(true);
  });

  it("distributes protein across meals instead of loading one meal", () => {
    const day = plan(80, "cut", "male", false, 3);
    const perMeal = day.meals.map((m) => m.items.reduce((s, i) => s + i.macros.protein, 0));
    const target = day.target.macros.protein / day.meals.length;
    for (const p of perMeal) {
      expect(p).toBeGreaterThan(target * 0.5);
      expect(p).toBeLessThan(target * 1.7);
    }
  });
});

describe("swaps keep the rules", () => {
  it("ingredient swap re-fits portions and totals; cooked choices become their raw entry", () => {
    const day = plan(80, "cut", "male", true, 2);
    const chicken = day.meals.flatMap((m) => m.items).find((i) => i.food.name === "Chicken Breast")!;
    const cookedBeef = BUNDLED_FOODS.find((f) => f.name.startsWith("Lean Beef") && f.measurementState === "cooked")!;
    const { plan: swapped, message } = swapPlanItem(day, chicken.id, cookedBeef);
    expect(message ?? swapped.solverMessage).toMatch(/raw/i);
    const item = swapped.meals.flatMap((m) => m.items).find((i) => i.id === chicken.id)!;
    expect(item.food.name).toBe("Lean Beef (5% fat)");
    expect(item.food.measurementState).toBe("raw");
    expect(validatePlanDay(swapped).ok).toBe(true);
    assertPractical(swapped);
  });

  it("swap options are same-role, raw/dry and allergy-safe", () => {
    const day = plan(80, "cut", "male", true, 2);
    const rice = day.meals.flatMap((m) => m.items).find((i) => specForFood(i.food).role === "carb")!;
    const options = swapOptionsFor(rice, [], ["glutenWheat"]);
    expect(options.length).toBeGreaterThan(2);
    for (const f of options) {
      expect(specForFood(f).role).toBe("carb");
      expect(f.measurementState).not.toBe("cooked");
      expect(f.allergenTags).not.toContain("glutenWheat");
    }
  });

  it("meal swap builds a different real meal and the day stays valid", () => {
    const day = plan(80, "cut", "male", false, 2);
    const before = day.meals[2];
    const after = swapPlanMeal(day, before.id, ctx());
    expect(after.meals[2].recipeId).not.toBe(before.recipeId);
    expect(validatePlanDay(after).ok).toBe(true);
    assertPractical(after);
  });
});
