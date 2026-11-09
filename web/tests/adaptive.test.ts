import { describe, expect, it } from "vitest";
import {
  AdaptiveConfig,
  fitAdaptiveModel,
  predictWeeklyRate,
  recommend,
  requiredIntake,
  smoothWeightTrend,
  targetWeeklyRate,
} from "../src/engines/adaptive";
import { phases, simulate } from "./simulate";

// The formula (prior) says 2200 kcal; this person actually maintains at ~2550.
const truth = { maintenance: 2550, perThousandSteps: 40, adaptation: 150, referenceIntake: 2200 };
const fitOn = (days: ReturnType<typeof simulate>["days"]) =>
  fitAdaptiveModel({ days, priorMaintenanceKcal: 2200, bodyWeightKg: 85, fallbackSteps: 8000, fallbackIntakeKcal: 2000 });

describe("weight trend Kalman smoother", () => {
  it("recovers the true trend from noisy, gappy weigh-ins far better than raw readings", () => {
    const sim = simulate({ seed: 7, startWeightKg: 85, truth, intakePlan: phases([56, 2000]), stepsMean: 8000 });
    const trend = smoothWeightTrend(sim.days);
    let errTrend = 0;
    let errRaw = 0;
    let n = 0;
    for (const t of trend) {
      const raw = sim.days[t.day].weightKg;
      if (raw === undefined) continue;
      errTrend += (t.levelKg - sim.trueWeights[t.day]) ** 2;
      errRaw += (raw - sim.trueWeights[t.day]) ** 2;
      n++;
    }
    expect(Math.sqrt(errTrend / n)).toBeLessThan(0.5 * Math.sqrt(errRaw / n));
  });
});

describe("personal energy model", () => {
  it("starts at the formula prior with low confidence and never auto-adjusts", () => {
    const m = fitOn([{ weightKg: 85 }]);
    expect(m.observations).toBe(0);
    expect(m.confidence).toBe("low");
    const rec = recommend(m, { trainingKcal: 2200, restKcal: 1700, trainingDaysPerWeek: 4 }, "cut", 75, 8000);
    expect(rec.shouldAdjust).toBe(false);
  });

  it("learns the user's real maintenance, gains confidence, and keeps learning as data arrives", () => {
    const sim = simulate({
      seed: 42,
      startWeightKg: 85,
      truth,
      intakePlan: phases([28, 2200], [28, 1850], [28, 2050]),
      stepsMean: 8500,
    });
    const after4 = fitOn(sim.days.slice(0, 28));
    const after12 = fitOn(sim.days);
    // Truth at 2050 kcal intake: 2550 + 150 × (2050 − 2200)/1000 ≈ 2527 (± step effect).
    const trueAtCurrent = truth.maintenance + (truth.adaptation * (after12.currentIntakeKcal - 2200)) / 1000 +
      (truth.perThousandSteps * (after12.currentSteps - 8000)) / 1000;
    expect(Math.abs(after12.maintenanceKcal - trueAtCurrent)).toBeLessThan(150);
    expect(after12.maintenanceSD).toBeLessThan(after4.maintenanceSD);
    expect(after12.observations).toBeGreaterThan(after4.observations);
    expect(after12.confidence).not.toBe("low");
    // Far better than the formula's 2200.
    expect(Math.abs(after12.maintenanceKcal - trueAtCurrent)).toBeLessThan(Math.abs(2200 - trueAtCurrent) / 2);
  });

  it("predicts the next 4 weeks of weight change on a new intake better than the formula", () => {
    const sim = simulate({
      seed: 3,
      startWeightKg: 90,
      truth,
      intakePlan: phases([42, 2300], [28, 2000]),
      stepsMean: 8000,
    });
    const train = sim.days.slice(0, 42);
    const m = fitOn(train);
    const actual = (sim.trueWeights[69] - sim.trueWeights[42]) / (27 / 7); // kg/week
    const predicted = predictWeeklyRate(m, 2000, 8000).meanKgPerWeek;
    const formula = ((2000 - 2200) * 7) / 7700; // what the static prior would predict
    expect(Math.abs(predicted - actual)).toBeLessThan(Math.abs(formula - actual));
    expect(Math.abs(predicted - actual)).toBeLessThan(0.25);
  });

  it("controller finds the intake that hits the goal rate (model inverse is consistent)", () => {
    const sim = simulate({ seed: 11, startWeightKg: 85, truth, intakePlan: phases([70, 2100]), stepsMean: 8000 });
    const m = fitOn(sim.days);
    const target = -0.6;
    const intake = requiredIntake(m, target, 8000);
    expect(predictWeeklyRate(m, intake, 8000).meanKgPerWeek).toBeCloseTo(target, 6);
  });

  it("recommendations respect the deadband and the 300 kcal weekly cap", () => {
    const sim = simulate({ seed: 5, startWeightKg: 85, truth, intakePlan: phases([70, 2100]), stepsMean: 8000 });
    const m = fitOn(sim.days);
    const huge = recommend(m, { trainingKcal: 1200, restKcal: 1000, trainingDaysPerWeek: 4 }, "cut", 70, 8000);
    expect(huge.deltaKcal).toBe(AdaptiveConfig.maxAdjustmentKcal);
    const req = requiredIntake(m, targetWeeklyRate("cut", m.trend!.levelKg, 70), 8000);
    const near = recommend(m, { trainingKcal: req + 20, restKcal: req + 20, trainingDaysPerWeek: 4 }, "cut", 70, 8000);
    expect(near.deltaKcal).toBe(0);
    expect(near.shouldAdjust).toBe(false);
  });
});

describe("goal rate", () => {
  it("scales with body weight, clamps, and tapers near the goal", () => {
    expect(targetWeeklyRate("cut", 100)).toBeCloseTo(-0.7);
    expect(targetWeeklyRate("cut", 40)).toBeCloseTo(-AdaptiveConfig.cutRateMinKg);
    expect(targetWeeklyRate("gain", 80)).toBeCloseTo(0.2);
    expect(targetWeeklyRate("cut", 76, 75)).toBeCloseTo(-0.25);
    expect(targetWeeklyRate("cut", 74, 75)).toBe(0);
    expect(targetWeeklyRate("maintenance", 80)).toBe(0);
  });
});
