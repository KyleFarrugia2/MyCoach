import { beforeAll, describe, expect, it } from "vitest";
import { phases, simulate } from "./simulate";

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

const flush = () => new Promise((r) => setTimeout(r, 0));

describe("adaptive model in the app store", async () => {
  const store = await import("../src/state/store");
  const { actions, getState, adaptiveModel, adaptiveRecommendation } = store;
  const { addDays, today } = await import("../src/core/dates");
  const { uuid } = await import("../src/core/models");

  /** Load `weeks` of simulated logs ending today. The person's true maintenance is far above the formula. */
  async function loadHistory(weeks: number, opts: { trial: boolean; auto: boolean }) {
    actions.deleteAccountLocally();
    actions.updateProfile({
      displayName: "Sim",
      currentWeightKg: 90,
      desiredWeightKg: 80,
      heightCm: 180,
      biologicalSex: "male",
      goalPhase: "cut",
      dateOfBirth: "1990-01-01",
      trainingDays: [1, 2, 4, 5],
    });
    actions.completeOnboarding();
    const t = getState().targets!;
    const planAvg = (4 * t.training.calories + 3 * t.rest.calories) / 7;
    const sim = simulate({
      seed: 21,
      startWeightKg: 90,
      truth: { maintenance: 3600, perThousandSteps: 40, adaptation: 100, referenceIntake: 2500 },
      intakePlan: phases([weeks * 7, planAvg]),
      stepsMean: 8000,
    });
    const n = sim.days.length;
    const json = JSON.parse(actions.exportDataJSON());
    json.weightEntries = [];
    json.diaries = {};
    json.stepEntries = [];
    sim.days.forEach((d, i) => {
      const day = addDays(today(), i - (n - 1));
      if (d.weightKg !== undefined) {
        json.weightEntries.push({ id: uuid(), timestamp: `${day}T07:00:00Z`, localDate: day, weightKg: d.weightKg, inputUnit: "kilogram", isOfficialMorningCheckIn: true });
      }
      if (d.intakeKcal !== undefined && i < n - 1) {
        json.diaries[day] = {
          localDate: day,
          markedComplete: true,
          entries: [{ id: uuid(), localDate: day, mealSlot: "breakfast", amount: 1, amountIsServings: true, loggedCalories: d.intakeKcal, loggedMacros: { protein: 0, carbohydrates: 0, fat: 0 }, createdAt: "", notes: "", food: { id: "q", name: "Quick Add", source: "customUser", servingDescription: "1", measurementState: "serving", isCustom: true, isVerified: false, allergenTags: [], isFavorite: false } }],
        };
      }
      if (d.steps !== undefined) json.stepEntries.push({ id: uuid(), localDate: day, steps: d.steps, source: "manual" });
    });
    json.subscription = opts.trial
      ? { ...json.subscription, status: "trial", expirationDate: new Date(Date.now() + 14 * 864e5).toISOString() }
      : { ...json.subscription, status: "notSubscribed" };
    json.preferences.adaptiveAutoAdjust = opts.auto;
    json.planAdjustments = [];
    expect(actions.importDataJSON(JSON.stringify(json))).toBe(true);
    await flush();
  }

  it("trains on logged history and auto-raises calories for someone who maintains above the formula", async () => {
    const before = await (async () => {
      await loadHistory(8, { trial: true, auto: false });
      return getState().targets!.training.calories;
    })();
    const m = adaptiveModel()!;
    expect(m.observations).toBeGreaterThanOrEqual(6);
    expect(m.confidence).not.toBe("low");
    expect(m.maintenanceKcal).toBeGreaterThan(m.priorMaintenanceKcal + 300);
    expect(getState().planAdjustments).toHaveLength(0); // auto-adjust off

    await loadHistory(8, { trial: true, auto: true });
    const adj = getState().planAdjustments;
    expect(adj).toHaveLength(1);
    expect(adj[0].source).toBe("adaptiveModel");
    expect(getState().targets!.training.calories).toBeGreaterThan(before);
    expect(getState().targets!.training.source).toBe("adaptiveModel");
    expect(getState().targets!.training.calories - before).toBeLessThanOrEqual(300);

    // New data within the week → retrains but does not stack another change.
    actions.logSteps(9000);
    await flush();
    expect(getState().planAdjustments).toHaveLength(1);
  });

  it("never auto-adjusts without Coach AI access, or with too little data", async () => {
    await loadHistory(8, { trial: false, auto: true });
    expect(getState().planAdjustments).toHaveLength(0);
    await loadHistory(2, { trial: true, auto: true });
    expect(adaptiveModel()!.confidence).toBe("low");
    expect(getState().planAdjustments).toHaveLength(0);
  });

  it("weekly check-in uses the model's calorie change and the chat cites the model", async () => {
    await loadHistory(8, { trial: true, auto: false });
    const rec = adaptiveRecommendation()!;
    const decision = actions.submitWeeklyCheckIn({
      appearance: "aboutTheSame",
      adherence: "eightyFiveTo94",
      adherencePercent: 90,
      performance: "same",
      hunger: 3,
      energy: 3,
      digestion: "good",
      notes: "",
    });
    if (["maintain", "increaseCalories", "decreaseCalories"].includes(decision.action.type)) {
      expect(decision.reasons).toContain("modelPrediction");
      if (rec.deltaKcal > 0) expect(decision.action).toEqual({ type: "increaseCalories", amount: rec.deltaKcal });
    }
    actions.sendCoachMessage("How is my progress?");
    await new Promise((r) => setTimeout(r, 600));
    const last = getState().chatMessages[getState().chatMessages.length - 1];
    expect(last.structured?.reasoning.some((l) => l.startsWith("Personal model"))).toBe(true);
  });
});
