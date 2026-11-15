/**
 * Post-workout review: what progressed vs last time, the streak, and the messages shown on the
 * Workout Complete screens. Port: `MyCoach/Services/Coaching/WorkoutReview.swift` (keep in sync).
 */
import { type Day, addDays, today as todayDay } from "../core/dates";
import type { Weekday } from "../core/dates";
import { type DayOverride, dayType } from "./dayPlan";
import { dayNumber } from "./quotes";
import { type ExerciseLog, type WorkoutSession, bestReps, bestWeight, totalVolume } from "./workout";

export type ReviewStatus = "progressed" | "same" | "less" | "new";

export interface ExerciseReview {
  id: string;
  name: string;
  status: ReviewStatus;
  detail: string;
}

/** Up to one decimal, no trailing ".0" — identical to the Swift formatter. */
export function fmtKg(x: number): string {
  const r = Math.round(x * 10) / 10;
  return Number.isInteger(r) ? r.toFixed(0) : r.toFixed(1);
}

const TOL = 0.05;

function repsAt(e: ExerciseLog, weight: number): number {
  return Math.max(0, ...e.sets.filter((s) => Math.abs((s.weightKg ?? 0) - weight) <= TOL).map((s) => s.reps));
}

/** Compare one exercise with the previous session of the same workout. Skipped exercises → undefined. */
export function reviewExercise(previous: ExerciseLog | undefined, current: ExerciseLog): ExerciseReview | undefined {
  if (current.sets.length === 0) return undefined;
  const base = { id: current.id, name: current.name };
  if (!previous || previous.sets.length === 0) {
    return { ...base, status: "new", detail: "First time — baseline set" };
  }
  if (current.isBodyweightMaxReps) {
    const cr = bestReps(current);
    const pr = bestReps(previous);
    if (cr > pr) return { ...base, status: "progressed", detail: `+${cr - pr} reps (${pr} → ${cr})` };
    if (cr === pr) return { ...base, status: "same", detail: `${cr} reps again` };
    return { ...base, status: "less", detail: `${pr} → ${cr} reps` };
  }
  const cw = bestWeight(current);
  const pw = bestWeight(previous);
  const cv = totalVolume(current);
  const pv = totalVolume(previous);
  if (cw > pw + TOL) {
    return { ...base, status: "progressed", detail: `+${fmtKg(cw - pw)} kg on your top set (${fmtKg(pw)} → ${fmtKg(cw)} kg)` };
  }
  if (Math.abs(cw - pw) <= TOL) {
    const crt = repsAt(current, cw);
    const prt = repsAt(previous, pw);
    if (crt > prt) return { ...base, status: "progressed", detail: `+${crt - prt} reps at ${fmtKg(cw)} kg` };
    if (crt === prt) {
      if (cv > pv + 0.5) return { ...base, status: "progressed", detail: `More total volume (${Math.round(pv)} → ${Math.round(cv)} kg)` };
      if (cv < pv - 0.5) return { ...base, status: "less", detail: "Slightly less total volume" };
      return { ...base, status: "same", detail: `${fmtKg(cw)} kg × ${crt} again` };
    }
    return { ...base, status: "less", detail: `${prt} → ${crt} reps at ${fmtKg(cw)} kg` };
  }
  if (cv > pv + 0.5) return { ...base, status: "progressed", detail: "More total volume at a lighter weight" };
  return { ...base, status: "less", detail: `Top set ${fmtKg(pw)} → ${fmtKg(cw)} kg` };
}

export interface WorkoutReview {
  exercises: ExerciseReview[];
  progressed: number;
  headline: string;
  subline: string;
  /** Shown when nothing went up — progress isn't linear. */
  encouragement?: string;
}

/** Original coach lines (no attributions) — progress isn't linear. */
export const NON_LINEAR_LINES = [
  "Progress isn't a straight line — it's a staircase with a few landings.",
  "Strength is built over months, not single sessions. Showing up today was the win.",
  "Some days you lift the weight, some days the weight teaches you. Both count.",
  "Plateaus are where your body consolidates the work. Keep stacking sessions.",
  "Sleep, food and stress all show up in the gym. One quieter session changes nothing.",
  "Consistency beats intensity. You trained — that's what moves the needle.",
];

export function reviewWorkout(previous: WorkoutSession | undefined, current: WorkoutSession): WorkoutReview {
  const exercises = current.exercises
    .map((e) => reviewExercise(previous?.exercises.find((p) => p.id === e.id), e))
    .filter((r): r is ExerciseReview => !!r);
  const progressed = exercises.filter((e) => e.status === "progressed").length;
  const allNew = exercises.length > 0 && exercises.every((e) => e.status === "new");
  if (progressed > 0) {
    return {
      exercises,
      progressed,
      headline: "Well done!",
      subline: `You progressed on ${progressed} ${progressed === 1 ? "movement" : "movements"}.`,
    };
  }
  if (allNew) {
    return { exercises, progressed, headline: "Baseline set!", subline: "Next time you'll have numbers to beat." };
  }
  const line = NON_LINEAR_LINES[dayNumber(current.localDate) % NON_LINEAR_LINES.length];
  return {
    exercises,
    progressed,
    headline: "Solid work",
    subline: "Same as last time or a touch under — and that's completely normal.",
    encouragement: `${line} Don't worry — progress isn't linear.`,
  };
}

/**
 * Workouts completed in a row without missing a planned training day. Emergency rest days (and other
 * rest days) never break it; today doesn't count as missed until it's over.
 */
export function workoutStreak(
  trainingDays: Weekday[],
  overrides: DayOverride[],
  sessions: WorkoutSession[],
  today: Day = todayDay(),
): number {
  const done = sessions.filter((s) => s.completedAt);
  if (done.length === 0) return 0;
  const perDay = new Map<Day, number>();
  for (const s of done) perDay.set(s.localDate, (perDay.get(s.localDate) ?? 0) + 1);
  const first = done.map((s) => s.localDate).sort()[0];
  let count = 0;
  for (let d = today; d >= first; d = addDays(d, -1)) {
    const n = perDay.get(d) ?? 0;
    if (n > 0) {
      count += n;
      continue;
    }
    if (d < today && dayType(trainingDays, overrides, d) === "training") break;
  }
  return count;
}

export function streakMessage(streak: number): { title: string; subtitle: string } {
  if (streak <= 1) return { title: "Great start!", subtitle: "Every streak starts with one." };
  if (streak <= 3) return { title: "Keep it up!", subtitle: "You're building a habit." };
  if (streak <= 6) return { title: "You are on fire!", subtitle: "Nothing's stopping you now." };
  if (streak <= 13) return { title: "Unstoppable!", subtitle: "This is what consistency looks like." };
  return { title: "Legend in the making!", subtitle: "Weeks of showing up — incredible." };
}

export interface SessionStats {
  durationSeconds: number;
  sets: number;
  volumeKg: number;
  exercises: number;
}

export function sessionStats(s: WorkoutSession): SessionStats {
  const end = s.completedAt ? new Date(s.completedAt).getTime() : Date.now();
  return {
    durationSeconds: Math.max(0, Math.floor((end - new Date(s.startedAt).getTime()) / 1000)),
    sets: s.exercises.reduce((n, e) => n + e.sets.length, 0),
    volumeKg: s.exercises.reduce((v, e) => v + totalVolume(e), 0),
    exercises: s.exercises.filter((e) => e.sets.length > 0).length,
  };
}
