import type { Day } from "../core/dates";
import { fmt } from "../core/models";

/** Port of WorkoutModels.swift. */
export type WorkoutTemplateID = "pushA" | "pullA" | "legsA" | "upper" | "legsB";
export const TEMPLATE_IDS: WorkoutTemplateID[] = ["pushA", "pullA", "legsA", "upper", "legsB"];
export const TemplateName: Record<WorkoutTemplateID, string> = {
  pushA: "Push A",
  pullA: "Pull A",
  legsA: "Legs A",
  upper: "Upper",
  legsB: "Legs B",
};

export interface ExerciseBlueprint {
  id: string;
  name: string;
  defaultSets: number;
  isBodyweightMaxReps: boolean;
}

export interface WorkoutTemplate {
  id: WorkoutTemplateID;
  name: string;
  exercises: ExerciseBlueprint[];
}

const ex = (name: string, defaultSets: number, isBodyweightMaxReps = false): ExerciseBlueprint => ({
  id: name.toLowerCase(),
  name,
  defaultSets,
  isBodyweightMaxReps,
});

export const WORKOUT_LIBRARY: WorkoutTemplate[] = [
  {
    id: "pushA",
    name: "Push A",
    exercises: [
      ex("Y raise", 2),
      ex("Upper chest flye", 2),
      ex("Flat chest press", 2),
      ex("Shoulder press", 1),
      ex("Poliquin tricep extensions", 3),
      ex("Cable crunch", 2),
    ],
  },
  {
    id: "pullA",
    name: "Pull A",
    exercises: [
      ex("Wide grip pulldown", 2),
      ex("Iliac lat pulldown", 1),
      ex("Upper back row", 2),
      ex("Cable hammer curl", 2),
      ex("Dbell preacher curl", 2),
      ex("Leg raise (bodyweight max reps)", 2, true),
    ],
  },
  {
    id: "legsA",
    name: "Legs A",
    exercises: [
      ex("Glute bridge", 2),
      ex("Seated leg curl", 3),
      ex("Hyperextension", 2),
      ex("Leg extension", 2),
      ex("Straight leg calf raise", 2),
      ex("Leg press", 2),
      ex("Adductor", 1),
    ],
  },
  {
    id: "upper",
    name: "Upper",
    exercises: [
      ex("Machine side lateral raise", 2),
      ex("Prime incline", 2),
      ex("Pec deck", 2),
      ex("Assisted Pull up", 2),
      ex("Cybex eagle lat row", 1),
      ex("Tbar row", 2),
      ex("Poliquin tricep extensions", 2),
      ex("Cable hammer curl", 1),
      ex("Dbell preacher curl", 2),
    ],
  },
  {
    id: "legsB",
    name: "Legs B",
    exercises: [
      ex("Glute bridge", 2),
      ex("Seated leg curl", 3),
      ex("Hyperextension", 2),
      ex("Leg extension", 2),
      ex("Straight leg calf raise", 2),
      ex("Squat press", 2),
      ex("Adductor", 1),
      ex("Rope crunch", 2),
    ],
  },
];

export interface LoggedSet {
  id: string;
  setNumber: number;
  weightKg?: number;
  reps: number;
  completedAt: string;
}

export function setSummary(set: LoggedSet): string {
  if (set.weightKg !== undefined && set.weightKg > 0) return `${fmt(set.weightKg, 1)} kg × ${set.reps}`;
  return `${set.reps} reps`;
}

export interface ExerciseLog {
  id: string;
  name: string;
  plannedSets: number;
  isBodyweightMaxReps: boolean;
  sets: LoggedSet[];
}

export const bestWeight = (e: ExerciseLog) => Math.max(0, ...e.sets.map((s) => s.weightKg ?? 0));
export const bestReps = (e: ExerciseLog) => Math.max(0, ...e.sets.map((s) => s.reps));
export const totalVolume = (e: ExerciseLog) => e.sets.reduce((s, x) => s + (x.weightKg ?? 0) * x.reps, 0);
export function lastSetSummary(e: ExerciseLog): string {
  const last = [...e.sets].sort((a, b) => a.setNumber - b.setNumber).pop();
  return last ? setSummary(last) : "Not logged";
}

export interface WorkoutSession {
  id: string;
  templateID: WorkoutTemplateID;
  templateName: string;
  localDate: Day;
  startedAt: string;
  completedAt?: string;
  exercises: ExerciseLog[];
  notes: string;
}

export function sessionDurationSeconds(s: WorkoutSession, now: Date = new Date()): number {
  const end = s.completedAt ? new Date(s.completedAt) : now;
  return Math.max(0, Math.floor((end.getTime() - new Date(s.startedAt).getTime()) / 1000));
}

export const completedSets = (s: WorkoutSession) => s.exercises.reduce((n, e) => n + e.sets.length, 0);

export interface TemplateOverride {
  templateID: WorkoutTemplateID;
  /** exercise id → planned set count */
  setCounts: Record<string, number>;
}

/** True if `current` improved vs `previous` (weight, then reps, then volume). */
export function didProgress(previous: ExerciseLog | undefined, current: ExerciseLog): boolean {
  if (!previous || previous.sets.length === 0 || current.sets.length === 0) return true;
  const cw = bestWeight(current);
  const pw = bestWeight(previous);
  if (cw > pw + 0.05) return true;
  if (Math.abs(cw - pw) <= 0.05 && bestReps(current) > bestReps(previous)) return true;
  if (current.isBodyweightMaxReps && bestReps(current) > bestReps(previous)) return true;
  if (totalVolume(current) > totalVolume(previous) + 0.5) return true;
  return false;
}

/** Exercises with no progress across the last `streak` consecutive completed sessions of this template. */
export function stagnantExercises(templateID: WorkoutTemplateID, sessions: WorkoutSession[], streak = 3): string[] {
  const completed = sessions
    .filter((s) => s.templateID === templateID && s.completedAt)
    .sort((a, b) => a.startedAt.localeCompare(b.startedAt));
  if (completed.length < streak + 1) return [];
  const window = completed.slice(-(streak + 1));
  const latest = window[window.length - 1];
  const stagnant: string[] = [];
  for (const exercise of latest.exercises) {
    let failed = 0;
    for (let i = 1; i < window.length; i++) {
      const prior = window[i - 1].exercises.find((e) => e.id === exercise.id);
      const current = window[i].exercises.find((e) => e.id === exercise.id);
      if (!current || current.sets.length === 0) continue;
      failed = didProgress(prior, current) ? 0 : failed + 1;
    }
    if (failed >= streak) stagnant.push(exercise.name);
  }
  return stagnant;
}
