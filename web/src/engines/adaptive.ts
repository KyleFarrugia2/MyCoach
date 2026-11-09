/**
 * Personal adaptive energy-balance model (on-device machine learning).
 *
 * This file is the reference implementation. `MyCoach/Services/Adaptive/AdaptiveModel.swift` is a
 * line-for-line port — keep them numerically identical (shared fixture: tests/fixtures/adaptive-fixture.json).
 *
 * Two learners, both fully Bayesian and updated online as data arrives:
 *
 * 1. Weight trend — a local-linear-trend Kalman filter + Rauch–Tung–Striebel smoother over the daily
 *    morning weigh-ins. Separates true tissue change (level, slope) from day-to-day water noise and
 *    handles missing days.
 *
 * 2. Energy expenditure — Bayesian linear regression learned with a Kalman filter over its parameters
 *    (recursive least squares with random-walk drift so the model tracks metabolic adaptation).
 *    For every ~weekly window it observes the user's *implied* expenditure:
 *
 *        y = mean logged intake − ρ · Δtrend / days          (ρ ≈ 7700 kcal per kg)
 *
 *    and regresses it on
 *
 *        x = [ 1, (steps − 8000)/1000, (trailing 14-day intake − prior maintenance)/1000 ]
 *
 *    so θ = [ personal maintenance (kcal/day at 8k steps, at prior intake),
 *             kcal burned per extra 1000 steps,
 *             expenditure response per +1000 kcal of intake (adaptive thermogenesis / NEAT) ].
 *
 *    Every observation carries its own noise variance derived from the trend smoother's uncertainty and
 *    how many days were logged, so sparse or noisy weeks count for less.
 *
 * The posterior (θ, Σ) gives predictions *with uncertainty* for any intake/steps plan, and the controller
 * inverts the model to find the intake that hits the goal rate.
 */

export const AdaptiveConfig = {
  kcalPerKg: 7700,
  windowDays: 7,
  minLoggedIntakeDays: 4,
  minWeighInsPerWindow: 3,
  adaptationLookbackDays: 14,
  referenceSteps: 8000,

  // Weight-trend Kalman filter (kg, per day).
  trendLevelProcessVar: 0.005,
  trendSlopeProcessVar: 2e-5,
  weighInNoiseVar: 0.3,
  trendInitialLevelVar: 1.0,
  trendInitialSlopeVar: 0.01,

  // Parameter priors and drift (per observation ≈ per week).
  priorMaintenanceSD: 350,
  priorStepCoefficientPerKg: 0.45, // kcal per 1000 steps per kg body weight
  priorStepCoefficientSD: 25,
  priorAdaptationMean: 100, // kcal of expenditure per +1000 kcal intake
  priorAdaptationSD: 120,
  driftMaintenanceSD: 25,
  driftStepSD: 1,
  driftAdaptationSD: 5,
  intakeReportingSD: 200, // per logged day
  modelResidualSD: 100,

  // Confidence thresholds on the posterior SD of maintenance at current habits.
  highConfidenceMaxSD: 120,
  highConfidenceMinObservations: 5,
  mediumConfidenceMaxSD: 160,
  mediumConfidenceMinObservations: 3,

  // Controller.
  cutRatePercentPerWeek: 0.7,
  cutRateMinKg: 0.35,
  cutRateMaxKg: 1.0,
  gainRatePercentPerWeek: 0.25,
  gainRateMinKg: 0.15,
  gainRateMaxKg: 0.5,
  goalApproachWeeks: 4,
  adaptationClampMin: -200,
  adaptationClampMax: 500,
  adjustmentDeadbandKcal: 50,
  maxAdjustmentKcal: 300,
  minDaysBetweenAutoAdjustments: 7,
} as const;

export interface AdaptiveDay {
  weightKg?: number;
  intakeKcal?: number;
  steps?: number;
}

export interface AdaptiveFitInput {
  /** Consecutive calendar days, oldest first; the last element is "today". */
  days: AdaptiveDay[];
  /** Formula maintenance estimate (Mifflin–St Jeor × activity) used as the prior mean. */
  priorMaintenanceKcal: number;
  /** Body weight for scaling the step-coefficient prior. */
  bodyWeightKg: number;
  /** Fallbacks for "current habits" when there is too little recent logging. */
  fallbackSteps: number;
  fallbackIntakeKcal: number;
}

export type ModelConfidence = "low" | "medium" | "high";

export interface TrendPoint {
  day: number;
  levelKg: number;
  slopeKgPerDay: number;
  levelVar: number;
}

export interface TrainingObservation {
  endDay: number;
  impliedExpenditure: number;
  features: [number, number, number];
  noiseVar: number;
  residual: number; // prediction error before the update (one-step-ahead)
}

export interface AdaptiveModelSnapshot {
  version: 1;
  priorMaintenanceKcal: number;
  theta: [number, number, number];
  covariance: number[][]; // 3×3
  observations: number;
  loggedIntakeDays: number;
  weighIns: number;
  trend?: { levelKg: number; slopeKgPerWeek: number; slopeSDKgPerWeek: number };
  currentSteps: number;
  currentIntakeKcal: number;
  maintenanceKcal: number;
  maintenanceSD: number;
  confidence: ModelConfidence;
  /** Root-mean-square one-step-ahead prediction error (kcal/day); undefined until ≥ 2 observations. */
  rmseKcal?: number;
  history: TrainingObservation[];
}

// ---------------------------------------------------------------------------
// Small linear-algebra helpers (3×3 and 2×2 only — explicit for Swift parity)
// ---------------------------------------------------------------------------

type V3 = [number, number, number];
type M3 = number[][];

function matVec3(m: M3, v: V3): V3 {
  return [
    m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2],
    m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2],
    m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2],
  ];
}
const dot3 = (a: V3, b: V3) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const quad3 = (m: M3, v: V3) => dot3(v, matVec3(m, v));

// ---------------------------------------------------------------------------
// 1. Weight trend: local linear trend Kalman filter + RTS smoother
// ---------------------------------------------------------------------------

export function smoothWeightTrend(days: AdaptiveDay[]): TrendPoint[] {
  const first = days.findIndex((d) => d.weightKg !== undefined);
  if (first < 0) return [];
  const c = AdaptiveConfig;
  const n = days.length - first;

  // Predicted (p) and filtered (f) means/covariances. Covariance stored as [a, b, d] for [[a,b],[b,d]].
  const mp: [number, number][] = [];
  const Pp: [number, number, number][] = [];
  const mf: [number, number][] = [];
  const Pf: [number, number, number][] = [];

  let m: [number, number] = [days[first].weightKg!, 0];
  let P: [number, number, number] = [c.trendInitialLevelVar, 0, c.trendInitialSlopeVar];

  for (let i = 0; i < n; i++) {
    if (i > 0) {
      // x' = F x with F = [[1,1],[0,1]];  P' = F P Fᵀ + Q
      m = [m[0] + m[1], m[1]];
      P = [P[0] + 2 * P[1] + P[2] + c.trendLevelProcessVar, P[1] + P[2], P[2] + c.trendSlopeProcessVar];
    }
    mp.push([m[0], m[1]]);
    Pp.push([P[0], P[1], P[2]]);
    const w = days[first + i].weightKg;
    if (w !== undefined) {
      const S = P[0] + c.weighInNoiseVar;
      const k0 = P[0] / S;
      const k1 = P[1] / S;
      const innov = w - m[0];
      m = [m[0] + k0 * innov, m[1] + k1 * innov];
      P = [P[0] - k0 * P[0], P[1] - k0 * P[1], P[2] - k1 * P[1]];
    }
    mf.push([m[0], m[1]]);
    Pf.push([P[0], P[1], P[2]]);
  }

  // Rauch–Tung–Striebel backward pass.
  const ms = mf.map((x) => [x[0], x[1]] as [number, number]);
  const Ps = Pf.map((x) => [x[0], x[1], x[2]] as [number, number, number]);
  for (let i = n - 2; i >= 0; i--) {
    const [fa, fb, fd] = Pf[i];
    // A = Pf Fᵀ = [[fa+fb, fb],[fb+fd, fd]]
    const a00 = fa + fb;
    const a01 = fb;
    const a10 = fb + fd;
    const a11 = fd;
    const [pa, pb, pd] = Pp[i + 1];
    const det = pa * pd - pb * pb;
    // inv(Pp) = [[pd, -pb],[-pb, pa]] / det
    const i00 = pd / det;
    const i01 = -pb / det;
    const i11 = pa / det;
    // C = A inv(Pp)
    const c00 = a00 * i00 + a01 * i01;
    const c01 = a00 * i01 + a01 * i11;
    const c10 = a10 * i00 + a11 * i01;
    const c11 = a10 * i01 + a11 * i11;
    const d0 = ms[i + 1][0] - mp[i + 1][0];
    const d1 = ms[i + 1][1] - mp[i + 1][1];
    ms[i] = [mf[i][0] + c00 * d0 + c01 * d1, mf[i][1] + c10 * d0 + c11 * d1];
    // Ps = Pf + C (Ps' − Pp') Cᵀ
    const e00 = Ps[i + 1][0] - pa;
    const e01 = Ps[i + 1][1] - pb;
    const e11 = Ps[i + 1][2] - pd;
    const t00 = c00 * e00 + c01 * e01;
    const t01 = c00 * e01 + c01 * e11;
    const t10 = c10 * e00 + c11 * e01;
    const t11 = c10 * e01 + c11 * e11;
    Ps[i] = [fa + t00 * c00 + t01 * c01, fb + t00 * c10 + t01 * c11, fd + t10 * c10 + t11 * c11];
  }

  return ms.map((x, i) => ({ day: first + i, levelKg: x[0], slopeKgPerDay: x[1], levelVar: Math.max(Ps[i][0], 1e-6) }));
}

// ---------------------------------------------------------------------------
// 2. Training data → Bayesian regression over expenditure parameters
// ---------------------------------------------------------------------------

function mean(xs: number[]): number {
  return xs.reduce((s, x) => s + x, 0) / xs.length;
}

function trailingIntake(days: AdaptiveDay[], endExclusive: number, lookback: number): number | undefined {
  const vals: number[] = [];
  for (let d = Math.max(0, endExclusive - lookback); d < endExclusive; d++) {
    const v = days[d].intakeKcal;
    if (v !== undefined) vals.push(v);
  }
  return vals.length >= AdaptiveConfig.minLoggedIntakeDays ? mean(vals) : undefined;
}

export function buildObservations(input: AdaptiveFitInput, trend: TrendPoint[]): Omit<TrainingObservation, "residual">[] {
  const c = AdaptiveConfig;
  if (trend.length === 0) return [];
  const first = trend[0].day;
  const at = (d: number) => trend[d - first];
  const { days } = input;
  const obs: Omit<TrainingObservation, "residual">[] = [];
  for (let e = days.length - 1; e - c.windowDays >= first; e -= c.windowDays) {
    const s = e - c.windowDays;
    const intakes: number[] = [];
    let stepSum = 0;
    for (let d = s; d < e; d++) {
      const v = days[d].intakeKcal;
      if (v !== undefined) intakes.push(v);
      stepSum += days[d].steps ?? c.referenceSteps;
    }
    if (intakes.length < c.minLoggedIntakeDays) continue;
    let weighIns = 0;
    for (let d = s; d <= e; d++) if (days[d].weightKg !== undefined) weighIns++;
    if (weighIns < c.minWeighInsPerWindow) continue;

    const meanIntake = mean(intakes);
    const deltaKg = at(e).levelKg - at(s).levelKg;
    const y = meanIntake - (c.kcalPerKg * deltaKg) / c.windowDays;
    const stepsK = (stepSum / c.windowDays - c.referenceSteps) / 1000;
    const trailing = trailingIntake(days, e, c.adaptationLookbackDays) ?? meanIntake;
    const adapt = (trailing - input.priorMaintenanceKcal) / 1000;
    const weightVar = (c.kcalPerKg * c.kcalPerKg * (at(s).levelVar + at(e).levelVar)) / (c.windowDays * c.windowDays);
    const noiseVar = weightVar + (c.intakeReportingSD * c.intakeReportingSD) / intakes.length + c.modelResidualSD * c.modelResidualSD;
    obs.push({ endDay: e, impliedExpenditure: y, features: [1, stepsK, adapt], noiseVar });
  }
  return obs.reverse(); // chronological
}

export function priorFor(input: AdaptiveFitInput): { theta: V3; cov: M3 } {
  const c = AdaptiveConfig;
  return {
    theta: [input.priorMaintenanceKcal, c.priorStepCoefficientPerKg * input.bodyWeightKg, c.priorAdaptationMean],
    cov: [
      [c.priorMaintenanceSD ** 2, 0, 0],
      [0, c.priorStepCoefficientSD ** 2, 0],
      [0, 0, c.priorAdaptationSD ** 2],
    ],
  };
}

/** Train (or re-train) the personal model on everything logged so far. Deterministic and cheap (O(days)). */
export function fitAdaptiveModel(input: AdaptiveFitInput): AdaptiveModelSnapshot {
  const c = AdaptiveConfig;
  const trend = smoothWeightTrend(input.days);
  const raw = buildObservations(input, trend);
  let { theta, cov } = priorFor(input);
  const drift = [c.driftMaintenanceSD ** 2, c.driftStepSD ** 2, c.driftAdaptationSD ** 2];

  const history: TrainingObservation[] = [];
  raw.forEach((o, i) => {
    if (i > 0) cov = cov.map((row, r) => row.map((v, k) => (r === k ? v + drift[r] : v)));
    const x = o.features;
    const Px = matVec3(cov, x);
    const S = dot3(x, Px) + o.noiseVar;
    const residual = o.impliedExpenditure - dot3(x, theta);
    const K: V3 = [Px[0] / S, Px[1] / S, Px[2] / S];
    theta = [theta[0] + K[0] * residual, theta[1] + K[1] * residual, theta[2] + K[2] * residual];
    // P ← P − K (P x)ᵀ, then symmetrise.
    cov = cov.map((row, r) => row.map((v, k) => v - K[r] * Px[k]));
    cov = cov.map((row, r) => row.map((_, k) => (cov[r][k] + cov[k][r]) / 2));
    history.push({ ...o, residual });
  });

  // "Current habits" — recent averages, falling back to the plan.
  const n = input.days.length;
  const recent = input.days.slice(Math.max(0, n - 14));
  const stepVals = recent.filter((d) => d.steps !== undefined).map((d) => d.steps!);
  const currentSteps = stepVals.length >= 5 ? mean(stepVals) : input.fallbackSteps;
  const currentIntakeKcal = trailingIntake(input.days, n, 14) ?? input.fallbackIntakeKcal;

  const model: AdaptiveModelSnapshot = {
    version: 1,
    priorMaintenanceKcal: input.priorMaintenanceKcal,
    theta,
    covariance: cov,
    observations: history.length,
    loggedIntakeDays: input.days.filter((d) => d.intakeKcal !== undefined).length,
    weighIns: input.days.filter((d) => d.weightKg !== undefined).length,
    currentSteps,
    currentIntakeKcal,
    maintenanceKcal: 0,
    maintenanceSD: 0,
    confidence: "low",
    history,
  };
  if (trend.length) {
    const last = trend[trend.length - 1];
    model.trend = {
      levelKg: last.levelKg,
      slopeKgPerWeek: last.slopeKgPerDay * 7,
      slopeSDKgPerWeek: trendSlopeSD(input.days) * 7,
    };
  }
  const x = features(model, currentIntakeKcal, currentSteps);
  model.maintenanceKcal = dot3(x, theta);
  model.maintenanceSD = Math.sqrt(Math.max(quad3(cov, x), 0));
  if (history.length >= 2) model.rmseKcal = Math.sqrt(mean(history.slice(1).map((h) => h.residual * h.residual)));
  model.confidence =
    history.length >= c.highConfidenceMinObservations && model.maintenanceSD <= c.highConfidenceMaxSD
      ? "high"
      : history.length >= c.mediumConfidenceMinObservations && model.maintenanceSD <= c.mediumConfidenceMaxSD
        ? "medium"
        : "low";
  return model;
}

/** Forward-filter slope SD at the last day (uncertainty of "how fast am I moving right now"). */
function trendSlopeSD(days: AdaptiveDay[]): number {
  const c = AdaptiveConfig;
  const first = days.findIndex((d) => d.weightKg !== undefined);
  if (first < 0) return 0;
  let P: [number, number, number] = [c.trendInitialLevelVar, 0, c.trendInitialSlopeVar];
  for (let i = first; i < days.length; i++) {
    if (i > first) P = [P[0] + 2 * P[1] + P[2] + c.trendLevelProcessVar, P[1] + P[2], P[2] + c.trendSlopeProcessVar];
    if (days[i].weightKg !== undefined) {
      const S = P[0] + c.weighInNoiseVar;
      const k0 = P[0] / S;
      const k1 = P[1] / S;
      P = [P[0] - k0 * P[0], P[1] - k0 * P[1], P[2] - k1 * P[1]];
    }
  }
  return Math.sqrt(Math.max(P[2], 0));
}

function features(model: AdaptiveModelSnapshot, intakeKcal: number, steps: number): V3 {
  return [1, (steps - AdaptiveConfig.referenceSteps) / 1000, (intakeKcal - model.priorMaintenanceKcal) / 1000];
}

// ---------------------------------------------------------------------------
// 3. Prediction + controller
// ---------------------------------------------------------------------------

export interface RatePrediction {
  /** Expected change in kg per week. */
  meanKgPerWeek: number;
  /** Posterior SD from parameter uncertainty (kg per week). */
  sdKgPerWeek: number;
  expenditureKcal: number;
}

export function predictWeeklyRate(model: AdaptiveModelSnapshot, intakeKcal: number, steps: number): RatePrediction {
  const x = features(model, intakeKcal, steps);
  const tdee = dot3(x, model.theta as V3);
  const k = 7 / AdaptiveConfig.kcalPerKg;
  return {
    meanKgPerWeek: (intakeKcal - tdee) * k,
    sdKgPerWeek: Math.sqrt(Math.max(quad3(model.covariance, x), 0)) * k,
    expenditureKcal: tdee,
  };
}

/** Intake (kcal/day) the model expects to produce `targetKgPerWeek`, given steps. */
export function requiredIntake(model: AdaptiveModelSnapshot, targetKgPerWeek: number, steps: number): number {
  const c = AdaptiveConfig;
  const [t0, t1, t2raw] = model.theta;
  const t2 = Math.min(Math.max(t2raw, c.adaptationClampMin), c.adaptationClampMax) / 1000;
  const stepsK = (steps - c.referenceSteps) / 1000;
  // I − (t0 + t1·s + t2·(I − M0)) = ρ·r/7   ⇒   I = (ρ·r/7 + t0 + t1·s − t2·M0) / (1 − t2)
  return ((c.kcalPerKg * targetKgPerWeek) / 7 + t0 + t1 * stepsK - t2 * model.priorMaintenanceKcal) / (1 - t2);
}

export type AdaptiveGoal = "cut" | "gain" | "maintenance";

/** Goal rate in kg/week; tapers to zero as the trend approaches the desired weight. */
export function targetWeeklyRate(goal: AdaptiveGoal, trendWeightKg: number, desiredWeightKg?: number): number {
  const c = AdaptiveConfig;
  if (goal === "maintenance") return 0;
  const clamp = (v: number, lo: number, hi: number) => Math.min(Math.max(v, lo), hi);
  let magnitude =
    goal === "cut"
      ? clamp((trendWeightKg * c.cutRatePercentPerWeek) / 100, c.cutRateMinKg, c.cutRateMaxKg)
      : clamp((trendWeightKg * c.gainRatePercentPerWeek) / 100, c.gainRateMinKg, c.gainRateMaxKg);
  if (desiredWeightKg !== undefined && desiredWeightKg > 0) {
    const remaining = goal === "cut" ? trendWeightKg - desiredWeightKg : desiredWeightKg - trendWeightKg;
    if (remaining <= 0) return 0;
    magnitude = Math.min(magnitude, remaining / c.goalApproachWeeks);
  }
  return goal === "cut" ? -magnitude : magnitude;
}

export interface PlanCalories {
  trainingKcal: number;
  restKcal: number;
  trainingDaysPerWeek: number;
}

export interface AdaptiveRecommendation {
  targetKgPerWeek: number;
  currentAverageIntake: number;
  predictedCurrent: RatePrediction;
  requiredAverageIntake: number;
  /** Change to apply to the training-day target (rest day follows); 0 inside the deadband. */
  deltaKcal: number;
  predictedAfter: RatePrediction;
  shouldAdjust: boolean;
  confidence: ModelConfidence;
  summary: string;
}

export function planAverage(plan: PlanCalories): number {
  const nT = Math.min(Math.max(plan.trainingDaysPerWeek, 0), 7);
  return (nT * plan.trainingKcal + (7 - nT) * plan.restKcal) / 7;
}

export function recommend(
  model: AdaptiveModelSnapshot,
  plan: PlanCalories,
  goal: AdaptiveGoal,
  desiredWeightKg: number | undefined,
  steps: number,
): AdaptiveRecommendation {
  const c = AdaptiveConfig;
  const trendKg = model.trend?.levelKg ?? 0;
  const target = model.trend ? targetWeeklyRate(goal, trendKg, desiredWeightKg) : 0;
  const currentAvg = planAverage(plan);
  const predictedCurrent = predictWeeklyRate(model, currentAvg, steps);
  const required = requiredIntake(model, target, steps);
  let delta = required - currentAvg;
  delta = Math.min(Math.max(delta, -c.maxAdjustmentKcal), c.maxAdjustmentKcal);
  delta = Math.abs(delta) < c.adjustmentDeadbandKcal ? 0 : Math.round(delta / 10) * 10;
  const predictedAfter = predictWeeklyRate(model, currentAvg + delta, steps);
  const shouldAdjust = delta !== 0 && model.confidence !== "low";

  const f = (v: number) => `${v >= 0 ? "+" : "−"}${Math.abs(v).toFixed(2)}`;
  const goalReached = model.trend !== undefined && goal !== "maintenance" && target === 0;
  const versus = goalReached ? "but you've reached your goal weight, so the aim is now to hold steady" : `versus a ${f(target)} kg/week target`;
  const onTarget = goalReached ? "holding at your goal weight" : `on target (${f(target)})`;
  const summary =
    model.confidence === "low"
      ? `Still learning your metabolism (${model.observations} training ${model.observations === 1 ? "week" : "weeks"}). Keep logging weight and food to unlock personal adjustments.`
      : delta === 0
        ? `Your model estimates maintenance at ~${Math.round(model.maintenanceKcal)} kcal and predicts ${f(predictedCurrent.meanKgPerWeek)} kg/week on this plan — ${onTarget}. No change needed.`
        : `Your model estimates maintenance at ~${Math.round(model.maintenanceKcal)} kcal and predicts ${f(predictedCurrent.meanKgPerWeek)} kg/week on this plan ${versus}. ${delta > 0 ? "Adding" : "Removing"} ${Math.abs(delta)} kcal/day should give ${f(predictedAfter.meanKgPerWeek)} kg/week.`;

  return {
    targetKgPerWeek: target,
    currentAverageIntake: currentAvg,
    predictedCurrent,
    requiredAverageIntake: required,
    deltaKcal: delta,
    predictedAfter,
    shouldAdjust,
    confidence: model.confidence,
    summary,
  };
}

/** Forecast of the trend weight `weeks` ahead on a given intake, with a ±1 SD band (parameter + trend uncertainty). */
export function forecast(
  model: AdaptiveModelSnapshot,
  intakeKcal: number,
  steps: number,
  weeks: number,
): { week: number; meanKg: number; sdKg: number }[] {
  if (!model.trend) return [];
  const p = predictWeeklyRate(model, intakeKcal, steps);
  return Array.from({ length: weeks + 1 }, (_, w) => ({
    week: w,
    meanKg: model.trend!.levelKg + p.meanKgPerWeek * w,
    sdKg: Math.sqrt((p.sdKgPerWeek * w) ** 2 + 0.15 ** 2),
  }));
}
