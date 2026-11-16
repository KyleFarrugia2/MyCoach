import type { Day } from "../core/dates";
import { fmt } from "../core/models";

/** Port of WorkoutModels.swift / TrainingProgram.swift. */
export type WorkoutTemplateID =
  | "pushA"
  | "pullA"
  | "legsA"
  | "upper"
  | "legsB"
  | "fwPush"
  | "fwPull"
  | "fwLegs"
  | "ulUpperA"
  | "ulLowerA"
  | "ulUpperB"
  | "ulLowerB"
  | "fbA"
  | "fbB"
  | "fbC"
  | "bwFullA"
  | "bwFullB"
  | "bwFullC";

export const TEMPLATE_IDS: WorkoutTemplateID[] = [
  "pushA",
  "pullA",
  "legsA",
  "upper",
  "legsB",
  "fwPush",
  "fwPull",
  "fwLegs",
  "ulUpperA",
  "ulLowerA",
  "ulUpperB",
  "ulLowerB",
  "fbA",
  "fbB",
  "fbC",
  "bwFullA",
  "bwFullB",
  "bwFullC",
];

export const TemplateName: Record<WorkoutTemplateID, string> = {
  pushA: "Push A",
  pullA: "Pull A",
  legsA: "Legs A",
  upper: "Upper",
  legsB: "Legs B",
  fwPush: "Push",
  fwPull: "Pull",
  fwLegs: "Legs",
  ulUpperA: "Upper A",
  ulLowerA: "Lower A",
  ulUpperB: "Upper B",
  ulLowerB: "Lower B",
  fbA: "Full Body A",
  fbB: "Full Body B",
  fbC: "Full Body C",
  bwFullA: "Home A",
  bwFullB: "Home B",
  bwFullC: "Home C",
};

export const TemplateFocus: Record<WorkoutTemplateID, string> = {
  pushA: "Chest · shoulders · triceps",
  pullA: "Back · biceps · core",
  legsA: "Quads · glutes · hamstrings",
  upper: "Chest · back · arms",
  legsB: "Quads · glutes · hamstrings",
  fwPush: "Chest · shoulders · triceps",
  fwPull: "Back · biceps · core",
  fwLegs: "Quads · glutes · hamstrings",
  ulUpperA: "Chest · back · arms",
  ulLowerA: "Squat · hinge · calves",
  ulUpperB: "Chest · back · arms",
  ulLowerB: "Squat · hinge · calves",
  fbA: "Squat · press · row",
  fbB: "Hinge · overhead · pull",
  fbC: "Front squat · incline · lats",
  bwFullA: "Push-up · squat · core",
  bwFullB: "Pull · lunge · hips",
  bwFullC: "Split squat · push · carry",
};

export type TrainingStyle = "hypertrophy" | "strength" | "athletic";
export const TRAINING_STYLES: TrainingStyle[] = ["hypertrophy", "strength", "athletic"];
export const TrainingStyleInfo: Record<TrainingStyle, { name: string; subtitle: string }> = {
  hypertrophy: { name: "Build muscle", subtitle: "Moderate sets, more isolation, 8–12 reps." },
  strength: { name: "Get stronger", subtitle: "Heavier compounds, extra top sets, fewer extras." },
  athletic: { name: "Stay athletic", subtitle: "The same lifts plus a short conditioning finisher." },
};

export type TrainingProgramID = "gymMachines" | "freeWeights" | "upperLower" | "fullBody" | "bodyweight";
export const TRAINING_PROGRAMS: TrainingProgramID[] = ["gymMachines", "freeWeights", "upperLower", "fullBody", "bodyweight"];
export const TrainingProgramInfo: Record<
  TrainingProgramID,
  { name: string; subtitle: string; equipment: string; recommendedDays: number; templateIDs: WorkoutTemplateID[] }
> = {
  gymMachines: {
    name: "Gym machines",
    subtitle: "The original 5-day machine split (Push, Pull, Legs, Upper, Legs).",
    equipment: "Cables, machines, some free weights",
    recommendedDays: 5,
    templateIDs: ["pushA", "pullA", "legsA", "upper", "legsB"],
  },
  freeWeights: {
    name: "Free weights",
    subtitle: "Barbell and dumbbell Push / Pull / Legs.",
    equipment: "Barbell, dumbbells, bench, rack",
    recommendedDays: 3,
    templateIDs: ["fwPush", "fwPull", "fwLegs"],
  },
  upperLower: {
    name: "Upper / lower",
    subtitle: "Four sessions: two upper, two lower.",
    equipment: "Barbell, dumbbells, machines",
    recommendedDays: 4,
    templateIDs: ["ulUpperA", "ulLowerA", "ulUpperB", "ulLowerB"],
  },
  fullBody: {
    name: "Full body",
    subtitle: "Three full-body days — best if you train 2–3× a week.",
    equipment: "Barbell and dumbbells",
    recommendedDays: 3,
    templateIDs: ["fbA", "fbB", "fbC"],
  },
  bodyweight: {
    name: "Home / bodyweight",
    subtitle: "No gym. Push-ups, rows, squats and core.",
    equipment: "Floor space, a bar if you have one",
    recommendedDays: 3,
    templateIDs: ["bwFullA", "bwFullB", "bwFullC"],
  },
};

export function recommendedProgram(daysPerWeek: number): TrainingProgramID {
  if (daysPerWeek <= 3) return "fullBody";
  if (daysPerWeek === 4) return "upperLower";
  return "gymMachines";
}

export function trainingStyleOf(prefs: { trainingStyle?: TrainingStyle }): TrainingStyle {
  return prefs.trainingStyle ?? "hypertrophy";
}

export function trainingProgramOf(prefs: { trainingProgramID?: TrainingProgramID }): TrainingProgramID {
  return prefs.trainingProgramID ?? "gymMachines";
}

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
  {
    id: "fwPush",
    name: "Push",
    exercises: [
      ex("Barbell bench press", 3),
      ex("Overhead press", 3),
      ex("Incline dumbbell press", 2),
      ex("Dumbbell lateral raise", 2),
      ex("Tricep pushdown", 2),
      ex("Dip", 2),
    ],
  },
  {
    id: "fwPull",
    name: "Pull",
    exercises: [
      ex("Conventional deadlift", 3),
      ex("Barbell row", 3),
      ex("Pull-up", 2),
      ex("Face pull", 2),
      ex("Dumbbell curl", 2),
      ex("Hammer curl", 2),
    ],
  },
  {
    id: "fwLegs",
    name: "Legs",
    exercises: [
      ex("Back squat", 3),
      ex("Romanian deadlift", 3),
      ex("Walking lunge", 2),
      ex("Lying leg curl", 2),
      ex("Standing calf raise", 2),
      ex("Plank", 2, true),
    ],
  },
  {
    id: "ulUpperA",
    name: "Upper A",
    exercises: [
      ex("Barbell bench press", 3),
      ex("Barbell row", 3),
      ex("Overhead press", 2),
      ex("Pull-up", 2),
      ex("Lateral raise", 2),
      ex("Barbell curl", 2),
    ],
  },
  {
    id: "ulLowerA",
    name: "Lower A",
    exercises: [
      ex("Back squat", 3),
      ex("Romanian deadlift", 3),
      ex("Leg press", 2),
      ex("Seated leg curl", 2),
      ex("Standing calf raise", 2),
      ex("Sit-up", 2, true),
    ],
  },
  {
    id: "ulUpperB",
    name: "Upper B",
    exercises: [
      ex("Incline dumbbell press", 3),
      ex("Lat pulldown", 3),
      ex("Seated dumbbell press", 2),
      ex("Chest-supported row", 2),
      ex("Overhead tricep extension", 2),
      ex("Rear delt flye", 2),
    ],
  },
  {
    id: "ulLowerB",
    name: "Lower B",
    exercises: [
      ex("Front squat", 3),
      ex("Hip thrust", 3),
      ex("Walking lunge", 2),
      ex("Leg extension", 2),
      ex("Seated calf raise", 2),
      ex("Hanging leg raise", 2, true),
    ],
  },
  {
    id: "fbA",
    name: "Full Body A",
    exercises: [
      ex("Back squat", 3),
      ex("Barbell bench press", 3),
      ex("Barbell row", 3),
      ex("Romanian deadlift", 2),
      ex("Plank", 2, true),
    ],
  },
  {
    id: "fbB",
    name: "Full Body B",
    exercises: [
      ex("Conventional deadlift", 3),
      ex("Overhead press", 3),
      ex("Pull-up", 3),
      ex("Walking lunge", 2),
      ex("Dumbbell curl", 2),
    ],
  },
  {
    id: "fbC",
    name: "Full Body C",
    exercises: [
      ex("Front squat", 3),
      ex("Incline dumbbell press", 3),
      ex("Lat pulldown", 3),
      ex("Hip thrust", 2),
      ex("Lateral raise", 2),
    ],
  },
  {
    id: "bwFullA",
    name: "Home A",
    exercises: [
      ex("Push-up", 3, true),
      ex("Inverted row", 3, true),
      ex("Bodyweight squat", 3, true),
      ex("Glute bridge", 2, true),
      ex("Pike push-up", 2, true),
      ex("Hollow hold", 2, true),
    ],
  },
  {
    id: "bwFullB",
    name: "Home B",
    exercises: [
      ex("Decline push-up", 3, true),
      ex("Chin-up", 3, true),
      ex("Reverse lunge", 3, true),
      ex("Hip thrust", 2, true),
      ex("Bench dip", 2, true),
      ex("Hanging leg raise", 2, true),
    ],
  },
  {
    id: "bwFullC",
    name: "Home C",
    exercises: [
      ex("Diamond push-up", 3, true),
      ex("Superman", 3, true),
      ex("Bulgarian split squat", 3, true),
      ex("Calf raise", 2, true),
      ex("Side plank", 2, true),
      ex("Burpee", 2, true),
    ],
  },
];

export function applyTrainingStyle(style: TrainingStyle, template: WorkoutTemplate): WorkoutTemplate {
  if (style === "hypertrophy") return template;
  if (style === "strength") {
    return {
      ...template,
      exercises: template.exercises.map((exercise, index) => {
        if (index < 2 && !exercise.isBodyweightMaxReps) {
          return { ...exercise, defaultSets: Math.min(5, Math.max(exercise.defaultSets, 4)) };
        }
        if (index >= 3) return { ...exercise, defaultSets: Math.max(1, exercise.defaultSets - 1) };
        return exercise;
      }),
    };
  }
  const finisher = ex("Conditioning finisher", 2, true);
  if (template.exercises.some((e) => e.id === finisher.id)) return template;
  return { ...template, exercises: [...template.exercises, finisher] };
}

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
