/**
 * Coach cardio recommendation for today. Port: `MyCoach/Services/Coaching/CardioCoach.swift` (keep in sync).
 *
 * Low-intensity steady-state (LISS) is the default — it supports fat loss and recovery without eating into
 * lifting performance. Poor sleep or an emergency rest day always means recovery-only movement.
 */
import type { GoalPhase } from "../core/models";

export interface CardioInput {
  goal: GoalPhase;
  isTrainingDay: boolean;
  emergencyRest: boolean;
  /** Hours slept last night, if logged. */
  sleepHours?: number;
  stepsSoFar: number;
  stepTarget: number;
  /** From the adaptive model: predicted vs goal weekly rate (kg/week), when confident. */
  predictedKgPerWeek?: number;
  targetKgPerWeek?: number;
}

export type CardioTone = "recovery" | "steady" | "boost" | "light";

export interface CardioRecommendation {
  tone: CardioTone;
  minutes: number;
  title: string;
  activity: string;
  intensity: string;
  reasons: string[];
}

const WALK_STEPS_PER_MIN = 110;

export function cardioRecommendation(input: CardioInput): CardioRecommendation {
  const reasons: string[] = [];
  const stepsLeft = Math.max(0, input.stepTarget - input.stepsSoFar);

  if ((input.sleepHours !== undefined && input.sleepHours <= 5) || input.emergencyRest) {
    if (input.sleepHours !== undefined && input.sleepHours <= 5) reasons.push(`Only ${fmtHours(input.sleepHours)} of sleep — recovery comes first.`);
    if (input.emergencyRest) reasons.push("Emergency rest day — keep it easy.");
    return {
      tone: "recovery",
      minutes: 20,
      title: "Recovery walk only",
      activity: "Easy outdoor walk or gentle cycling",
      intensity: "Very easy — you could hold a conversation the whole time",
      reasons,
    };
  }

  let minutes: number;
  let activity: string;
  switch (input.goal) {
    case "cut":
      minutes = input.isTrainingDay ? 20 : 35;
      activity = input.isTrainingDay ? "Incline walk after your session" : "Incline walk, bike or cross-trainer";
      reasons.push(input.isTrainingDay ? "Short LISS after lifting supports fat loss without hurting recovery." : "Rest days are the best time for longer, easy cardio.");
      break;
    case "gain":
      minutes = input.isTrainingDay ? 0 : 20;
      activity = "Easy walk or bike";
      reasons.push(input.isTrainingDay ? "Gaining phase — save energy for lifting today." : "A little easy cardio keeps your heart healthy and appetite steady.");
      break;
    default:
      minutes = input.isTrainingDay ? 10 : 25;
      activity = "Walk, bike or cross-trainer";
      reasons.push("Maintenance — easy cardio for health and conditioning.");
  }

  // Adaptive model: nudge by the gap between predicted and goal rate.
  if (input.predictedKgPerWeek !== undefined && input.targetKgPerWeek !== undefined && input.goal !== "maintenance") {
    const gap = input.predictedKgPerWeek - input.targetKgPerWeek; // + means gaining faster / losing slower than goal
    if (input.goal === "cut" && gap > 0.15) {
      minutes += 10;
      reasons.push("Your model predicts slower loss than your goal — a little more cardio helps.");
    } else if (input.goal === "cut" && gap < -0.25) {
      minutes = Math.max(10, minutes - 10);
      reasons.push("You're losing faster than planned — keep cardio light to protect muscle.");
    } else if (input.goal === "gain" && gap < -0.15) {
      minutes = Math.max(0, minutes - 10);
      reasons.push("Weight is rising slower than planned — less cardio leaves more energy for growth.");
    }
  }

  if (input.sleepHours !== undefined && input.sleepHours < 6.5 && minutes > 15) {
    minutes -= 10;
    reasons.push(`${fmtHours(input.sleepHours)} of sleep — trimmed to keep recovery on track.`);
  }

  if (stepsLeft > 0) {
    const walkMinutes = Math.round(stepsLeft / WALK_STEPS_PER_MIN / 5) * 5;
    reasons.push(`${stepsLeft.toLocaleString()} steps to go today (≈ ${Math.max(5, walkMinutes)} min of walking).`);
  }

  if (minutes <= 0) {
    return {
      tone: "light",
      minutes: 0,
      title: "No structured cardio today",
      activity: "Just hit your step target",
      intensity: "Everyday walking",
      reasons,
    };
  }
  return {
    tone: minutes >= 35 ? "boost" : "steady",
    minutes,
    title: `${minutes} min ${minutes >= 30 ? "steady" : "easy"} cardio`,
    activity,
    intensity: "Zone 2 — breathing harder but still able to talk",
    reasons,
  };
}

export function fmtHours(h: number): string {
  const hours = Math.floor(h);
  const mins = Math.round((h - hours) * 60);
  return mins ? `${hours} h ${mins} min` : `${hours} h`;
}
