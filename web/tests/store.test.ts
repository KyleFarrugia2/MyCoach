import { beforeAll, describe, expect, it } from "vitest";

// Minimal localStorage for the node test environment.
const mem = new Map<string, string>();
beforeAll(() => {
  (globalThis as unknown as { localStorage: Storage }).localStorage = {
    getItem: (k: string) => mem.get(k) ?? null,
    setItem: (k: string, v: string) => void mem.set(k, v),
    removeItem: (k: string) => void mem.delete(k),
    clear: () => mem.clear(),
    key: () => null,
    length: 0,
  } as Storage;
});

describe("store", async () => {
  const { actions, getState, diaryFor, weightEntryOn } = await import("../src/state/store");
  const { today, addDays } = await import("../src/core/dates");
  const { BUNDLED_FOODS } = await import("../src/engines/foodCatalog");

  it("onboarding builds targets; meal plans stay locked without Coach AI", () => {
    actions.updateProfile({ displayName: "Sam", currentWeightKg: 80, heightCm: 180, biologicalSex: "male" });
    actions.completeOnboarding();
    const s = getState();
    expect(s.profile.hasCompletedOnboarding).toBe(true);
    expect(s.targets?.training.calories).toBeGreaterThan(0);
    expect(Object.keys(s.mealPlanDays)).toHaveLength(0);
  });

  it("trial unlocks a full week of meal plans", () => {
    actions.startTrialLocally();
    expect(getState().subscription.status).toBe("trial");
    expect(Object.keys(getState().mealPlanDays)).toHaveLength(7);
  });

  it("logs and replaces today's morning weight and persists it", () => {
    actions.logMorningWeight(80, "kilogram");
    actions.logMorningWeight(176, "pound");
    const entries = getState().weightEntries.filter((e) => e.localDate === today());
    expect(entries).toHaveLength(1);
    expect(weightEntryOn(getState(), today())!.weightKg).toBeCloseTo(79.83, 1);
    expect(JSON.parse(mem.get("mycoach.state.v1")!).weightEntries).toHaveLength(1);
  });

  it("logs food, copies yesterday, and deletes entries", () => {
    const food = BUNDLED_FOODS[0];
    actions.logFood(food, 150, false, "breakfast", today(), 165, { protein: 34.65, carbohydrates: 0, fat: 1.8 });
    expect(diaryFor(getState(), today()).entries).toHaveLength(1);
    const tomorrow = addDays(today(), 1);
    actions.copyYesterday(tomorrow);
    expect(diaryFor(getState(), tomorrow).entries).toHaveLength(1);
    actions.deleteFoodEntry(diaryFor(getState(), today()).entries[0]);
    expect(diaryFor(getState(), today()).entries).toHaveLength(0);
  });

  it("runs a workout and records the session", () => {
    actions.startWorkout("pushA");
    const ex = getState().activeWorkout!.exercises[0];
    actions.logSet(ex.id, 12.5, 10);
    expect(getState().workoutRestEndsAt).toBeDefined();
    actions.finishActiveWorkout();
    expect(getState().activeWorkout).toBeUndefined();
    expect(getState().workoutSessions[0].exercises[0].sets[0].weightKg).toBe(12.5);
  });

  it("export → import round-trips state", () => {
    const json = actions.exportDataJSON();
    actions.deleteAccountLocally();
    expect(getState().profile.hasCompletedOnboarding).toBe(false);
    expect(actions.importDataJSON(json)).toBe(true);
    expect(getState().profile.displayName).toBe("Sam");
    expect(actions.importDataJSON("{not json")).toBe(false);
  });
});

describe("scanned foods", async () => {
  const { actions, getState, customFoodByBarcode } = await import("../src/state/store");
  const { parseOpenFoodFacts } = await import("../src/engines/barcode");
  const { readFileSync } = await import("node:fs");
  const nutella = JSON.parse(readFileSync(new URL("./fixtures/off-nutella.json", import.meta.url), "utf-8"));

  it("keeps one food per barcode and finds it by barcode", () => {
    const first = parseOpenFoodFacts(nutella, "3017620422003")!.food;
    actions.saveCustomFood(first);
    const rescanned = { ...parseOpenFoodFacts(nutella, "3017620422003")!.food, calories: 540 };
    actions.saveCustomFood(rescanned);
    const matches = getState().customFoods.filter((f) => f.barcode === "3017620422003");
    expect(matches).toHaveLength(1);
    expect(customFoodByBarcode(getState(), "3017620422003")!.calories).toBe(540);
  });
});

describe("legacy meal plans", async () => {
  const { actions, getState } = await import("../src/state/store");
  const { BUNDLED_FOODS } = await import("../src/engines/foodCatalog");
  const { validatePlanDay } = await import("../src/engines/mealPlanner");
  const { today } = await import("../src/core/dates");

  it("rebuilds an old plan that mixed cooked chicken with a sliver of beef", () => {
    actions.updateProfile({ displayName: "Legacy", currentWeightKg: 80, hasCompletedOnboarding: true });
    actions.completeOnboarding();
    actions.startTrialLocally();
    const chickenCooked = BUNDLED_FOODS.find((f) => f.name === "Chicken Breast" && f.measurementState === "cooked")!;
    const beefRaw = BUNDLED_FOODS.find((f) => f.name.startsWith("Lean Beef") && f.measurementState === "raw")!;
    const json = JSON.parse(actions.exportDataJSON());
    const day = today();
    json.mealPlanDays = {
      [day]: {
        ...json.mealPlanDays[day],
        meals: json.mealPlanDays[day].meals.map((m: { recipeId?: string; items: unknown[] }, i: number) => ({
          ...m,
          recipeId: undefined,
          items:
            i === 0
              ? [
                  { id: "a", food: chickenCooked, grams: 220, isLocked: false, calories: 363, macros: { protein: 68.2, carbohydrates: 0, fat: 7.9 } },
                  { id: "b", food: beefRaw, grams: 10, isLocked: false, calories: 13.7, macros: { protein: 2.1, carbohydrates: 0, fat: 0.5 } },
                ]
              : m.items,
        })),
      },
    };
    actions.importDataJSON(JSON.stringify(json));
    expect(validatePlanDay(getState().mealPlanDays[day]).ok).toBe(false);
    actions.revalidateStoredPlans();
    const rebuilt = getState().mealPlanDays[day];
    expect(validatePlanDay(rebuilt).ok).toBe(true);
    expect(rebuilt.meals.every((m) => m.recipeId)).toBe(true);
    expect(rebuilt.meals.flatMap((m) => m.items).some((i) => i.food.measurementState === "cooked")).toBe(false);
  });
});
