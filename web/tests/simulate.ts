import type { AdaptiveDay } from "../src/engines/adaptive";

/** Deterministic PRNG (mulberry32) + Box–Muller so fixtures are reproducible across runs and platforms. */
export function rng(seed: number) {
  let a = seed >>> 0;
  const uniform = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  const normal = () => {
    const u = Math.max(uniform(), 1e-12);
    return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * uniform());
  };
  return { uniform, normal };
}

export interface TrueMetabolism {
  maintenance: number; // kcal/day at 8000 steps when eating `referenceIntake`
  perThousandSteps: number;
  adaptation: number; // kcal per +1000 kcal trailing intake
  referenceIntake: number;
}

export interface SimOptions {
  seed: number;
  startWeightKg: number;
  truth: TrueMetabolism;
  /** Planned intake per day (length = number of days). */
  intakePlan: number[];
  stepsMean: number;
  weighInNoiseSD?: number;
  intakeReportSD?: number;
  pMissingWeight?: number;
  pMissingIntake?: number;
  pMissingSteps?: number;
}

/** Simulate a person: true energy balance drives tissue change; logs are noisy and incomplete. */
export function simulate(o: SimOptions): { days: AdaptiveDay[]; trueWeights: number[] } {
  const r = rng(o.seed);
  let w = o.startWeightKg;
  const eaten: number[] = [];
  const days: AdaptiveDay[] = [];
  const trueWeights: number[] = [];
  for (let d = 0; d < o.intakePlan.length; d++) {
    // Morning weigh-in reflects intake through yesterday.
    trueWeights.push(w);
    const weightKg = r.uniform() < (o.pMissingWeight ?? 0.15) ? undefined : round1(w + r.normal() * (o.weighInNoiseSD ?? 0.5));
    const intake = o.intakePlan[d] + r.normal() * 120;
    const steps = Math.max(1000, Math.round(o.stepsMean + r.normal() * 2000));
    eaten.push(intake);
    const trailing = eaten.slice(-14).reduce((s, x) => s + x, 0) / Math.min(eaten.length, 14);
    const tdee =
      o.truth.maintenance +
      (o.truth.perThousandSteps * (steps - 8000)) / 1000 +
      (o.truth.adaptation * (trailing - o.truth.referenceIntake)) / 1000;
    w += (intake - tdee) / 7700;
    days.push({
      weightKg,
      intakeKcal: r.uniform() < (o.pMissingIntake ?? 0.15) ? undefined : Math.round(intake + r.normal() * (o.intakeReportSD ?? 100)),
      steps: r.uniform() < (o.pMissingSteps ?? 0.2) ? undefined : steps,
    });
  }
  return { days, trueWeights };
}

const round1 = (x: number) => Math.round(x * 10) / 10;

export function phases(...segments: [days: number, kcal: number][]): number[] {
  return segments.flatMap(([n, k]) => Array<number>(n).fill(k));
}
