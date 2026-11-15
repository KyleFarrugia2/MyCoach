/**
 * Training/rest schedule with user overrides — the coach works around the user.
 * Port: `MyCoach/Services/Coaching/DayPlanEngine.swift` (keep in sync).
 *
 *  - The weekly schedule (Settings) says which weekdays are training days.
 *  - An emergency rest day turns today into a rest day; the missed session moves to the next rest day later
 *    this week (Mon–Sun), preferring no more than 2 training days in a row, accepting 3, never 4+ — or is
 *    dropped if nothing fits.
 *  - Undo restores both days.
 */
import { type Day, type Weekday, addDays, weekEnd, weekdayOf } from "../core/dates";

export type DayType = "training" | "rest";
export type OverrideReason = "emergencyRest" | "movedSession";

export interface DayOverride {
  day: Day;
  type: DayType;
  reason: OverrideReason;
  /** emergencyRest → the day the session moved to; movedSession → the day it came from. */
  linkedDay?: Day;
}

export function isScheduledTraining(trainingDays: Weekday[], day: Day): boolean {
  return trainingDays.includes(weekdayOf(day));
}

export function overrideFor(overrides: DayOverride[], day: Day): DayOverride | undefined {
  return overrides.find((o) => o.day === day);
}

export function dayType(trainingDays: Weekday[], overrides: DayOverride[], day: Day): DayType {
  const o = overrideFor(overrides, day);
  if (o) return o.type;
  return isScheduledTraining(trainingDays, day) ? "training" : "rest";
}

export interface EmergencyRestResult {
  overrides: DayOverride[];
  /** Where the session went, if it could be moved this week. */
  movedTo?: Day;
}

/** Turn `day` into a rest day and move its session to the best remaining rest day this week. */
export function takeEmergencyRest(trainingDays: Weekday[], overrides: DayOverride[], day: Day): EmergencyRestResult {
  if (dayType(trainingDays, overrides, day) !== "training") return { overrides };
  const base = overrides.filter((o) => o.day !== day);
  const typeOf = (d: Day) => (d === day ? "rest" : dayType(trainingDays, base, d));
  const end = weekEnd(day);
  // Length of the consecutive training run `d` would sit in if it became a training day.
  const runIfTraining = (d: Day) => {
    let run = 1;
    for (let x = addDays(d, -1); run < 8 && typeOf(x) === "training"; x = addDays(x, -1)) run++;
    for (let x = addDays(d, 1); run < 8 && typeOf(x) === "training"; x = addDays(x, 1)) run++;
    return run;
  };
  const candidates: Day[] = [];
  for (let d = addDays(day, 1); d <= end; d = addDays(d, 1)) {
    if (typeOf(d) === "rest" && !overrideFor(base, d)) candidates.push(d);
  }
  // Prefer no more than 2 training days in a row; accept 3 if nothing better; never 4+.
  const movedTo: Day | undefined =
    candidates.find((d) => runIfTraining(d) <= 2) ?? candidates.find((d) => runIfTraining(d) <= 3);
  const next: DayOverride[] = [...base, { day, type: "rest", reason: "emergencyRest", linkedDay: movedTo }];
  if (movedTo) next.push({ day: movedTo, type: "training", reason: "movedSession", linkedDay: day });
  return { overrides: next, movedTo };
}

/** Undo an emergency rest day (and the session it moved). */
export function undoEmergencyRest(overrides: DayOverride[], day: Day): DayOverride[] {
  const o = overrideFor(overrides, day);
  if (!o || o.reason !== "emergencyRest") return overrides;
  return overrides.filter((x) => x.day !== day && !(x.reason === "movedSession" && x.linkedDay === day));
}

/** Default weekdays for a chosen number of training days (spread out, Mon-first). */
export const TRAINING_PRESETS: Record<number, Weekday[]> = {
  1: [3],
  2: [1, 4],
  3: [1, 3, 5],
  4: [1, 2, 4, 5],
  5: [1, 2, 3, 5, 6],
  6: [1, 2, 3, 4, 5, 6],
  7: [1, 2, 3, 4, 5, 6, 7],
};
