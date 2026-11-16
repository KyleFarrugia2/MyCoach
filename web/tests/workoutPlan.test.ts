import { describe, expect, it } from "vitest";
import {
  catalogEntry,
  generateWorkoutPlan,
  replacementsFor,
  TYPICAL_GYM,
} from "../src/engines/exerciseCatalog";
import { actions, getState, resolvedTemplate } from "../src/state/store";

describe("workout plan generator", () => {
  it("machines only never picks barbell", () => {
    const plan = generateWorkoutPlan({
      seed: 7,
      volume: "high",
      goal: "bodybuilding",
      equipment: ["machines", "cables"],
      daysPerWeek: 5,
      blockedIDs: [],
    });
    expect(plan.days.flatMap((d) => d.exercises).some((e) => e.equipment === "barbell")).toBe(false);
    expect(plan.programID).toBe("gymMachines");
  });

  it("blocked exercise is not used", () => {
    const plan = generateWorkoutPlan({
      seed: 3,
      volume: "high",
      goal: "bodybuilding",
      equipment: ["machines", "cables"],
      daysPerWeek: 5,
      blockedIDs: ["pec deck"],
    });
    expect(plan.days.flatMap((d) => d.exercises).some((e) => e.catalogID === "pec deck")).toBe(false);
  });

  it("high volume has more sets than low volume", () => {
    const high = generateWorkoutPlan({
      seed: 1,
      volume: "high",
      goal: "bodybuilding",
      equipment: TYPICAL_GYM,
      daysPerWeek: 4,
      blockedIDs: [],
    });
    const low = generateWorkoutPlan({
      seed: 1,
      volume: "low",
      goal: "bodybuilding",
      equipment: TYPICAL_GYM,
      daysPerWeek: 4,
      blockedIDs: [],
    });
    const sets = (plan: typeof high) => plan.days.flatMap((d) => d.exercises).reduce((n, e) => n + e.defaultSets, 0);
    expect(sets(high)).toBeGreaterThan(sets(low));
  });

  it("regenerate changes exercises", () => {
    const first = generateWorkoutPlan({
      seed: 1,
      volume: "high",
      goal: "powerbuilding",
      equipment: TYPICAL_GYM,
      daysPerWeek: 4,
      blockedIDs: [],
    });
    const second = generateWorkoutPlan({
      seed: 2,
      volume: "high",
      goal: "powerbuilding",
      equipment: TYPICAL_GYM,
      daysPerWeek: 4,
      blockedIDs: [],
    });
    expect(first.days.flatMap((d) => d.exercises).map((e) => e.catalogID)).not.toEqual(
      second.days.flatMap((d) => d.exercises).map((e) => e.catalogID),
    );
  });

  it("replacements match the same muscle", () => {
    const pecDeck = catalogEntry("pec deck")!;
    const options = replacementsFor(pecDeck, new Set(["machines", "cables", "dumbbells"]), new Set(["pec deck"]), new Set());
    expect(options.length).toBeGreaterThan(0);
    expect(options.every((o) => o.muscle === "chest")).toBe(true);
    expect(options.some((o) => o.id === "pec deck")).toBe(false);
  });

  it("bodyweight split when no weights", () => {
    const plan = generateWorkoutPlan({
      seed: 4,
      volume: "low",
      goal: "keepFit",
      equipment: ["bodyweight"],
      daysPerWeek: 3,
      blockedIDs: [],
    });
    expect(plan.programID).toBe("bodyweight");
    expect(plan.days.every((d) => d.exercises.length > 0)).toBe(true);
  });

  it("same seed is deterministic", () => {
    const input = {
      seed: 11,
      volume: "high" as const,
      goal: "strength" as const,
      equipment: ["barbell", "dumbbells"] as const,
      daysPerWeek: 4,
      blockedIDs: [],
    };
    expect(generateWorkoutPlan({ ...input, equipment: [...input.equipment] })).toEqual(
      generateWorkoutPlan({ ...input, equipment: [...input.equipment] }),
    );
  });

  it("applying a plan swaps the workout tab templates", () => {
    actions.deleteAccountLocally();
    const plan = generateWorkoutPlan({
      seed: 1,
      volume: "low",
      goal: "keepFit",
      equipment: ["bodyweight"],
      daysPerWeek: 3,
      blockedIDs: [],
    });
    actions.applyGeneratedPlan(plan);
    const state = getState();
    expect(state.generatedWorkoutPlan?.programID).toBe("bodyweight");
    expect(resolvedTemplate(state, "bwFullA").exercises.length).toBeGreaterThan(0);
  });
});
