import { TemplateName, TrainingProgramInfo, type TrainingProgramID, type WorkoutTemplate, type WorkoutTemplateID } from "./workout";

/** Port of ExerciseCatalog.swift / WorkoutPlanGenerator. Keep in numeric lockstep with iOS. */

export type TrainingVolume = "high" | "low";
export const TRAINING_VOLUMES: TrainingVolume[] = ["high", "low"];
export const TrainingVolumeInfo: Record<TrainingVolume, { name: string; subtitle: string }> = {
  high: { name: "High volume", subtitle: "More exercises and sets. Longer sessions, more pump." },
  low: { name: "Low volume", subtitle: "Fewer exercises and sets. Shorter sessions, more recovery." },
};

export type TrainingGoal = "keepFit" | "bodybuilding" | "powerlifting" | "powerbuilding" | "strength";
export const TRAINING_GOALS: TrainingGoal[] = ["keepFit", "bodybuilding", "powerlifting", "powerbuilding", "strength"];
export const TrainingGoalInfo: Record<TrainingGoal, { name: string; subtitle: string; style: "hypertrophy" | "strength" | "athletic" }> = {
  keepFit: {
    name: "Keep fit",
    subtitle: "Stay healthy and athletic without chasing a meet or a show.",
    style: "athletic",
  },
  bodybuilding: {
    name: "Bodybuilding",
    subtitle: "Build muscle with compounds plus isolation work.",
    style: "hypertrophy",
  },
  powerlifting: {
    name: "Powerlifting",
    subtitle: "Squat, bench and deadlift focused, with supporting work.",
    style: "strength",
  },
  powerbuilding: {
    name: "Powerbuilding",
    subtitle: "Get stronger and look like you lift — heavy compounds plus hypertrophy.",
    style: "hypertrophy",
  },
  strength: {
    name: "Increase strength",
    subtitle: "Add kilos to the big lifts. Minimal fluff.",
    style: "strength",
  },
};

export type GymEquipment = "machines" | "cables" | "barbell" | "dumbbells" | "bodyweight";
export const GYM_EQUIPMENT: GymEquipment[] = ["machines", "cables", "barbell", "dumbbells", "bodyweight"];
export const TYPICAL_GYM: GymEquipment[] = ["machines", "cables", "barbell", "dumbbells"];
export const GymEquipmentInfo: Record<GymEquipment, { name: string; subtitle: string }> = {
  machines: { name: "Gym machines", subtitle: "Leg press, pec deck, assisted pull-up, and similar." },
  cables: { name: "Cable machines", subtitle: "Pulldowns, pushdowns, flyes, face pulls." },
  barbell: { name: "Barbell", subtitle: "Squat rack, bench, and a barbell." },
  dumbbells: { name: "Dumbbells", subtitle: "Adjustable or fixed dumbbells and a bench." },
  bodyweight: { name: "Bodyweight / home", subtitle: "Floor space, and a bar if you have one." },
};

export type MuscleGroup =
  | "chest"
  | "shoulders"
  | "triceps"
  | "lats"
  | "upperBack"
  | "biceps"
  | "quads"
  | "hamstrings"
  | "glutes"
  | "calves"
  | "core";

export const MuscleGroupName: Record<MuscleGroup, string> = {
  chest: "Chest",
  shoulders: "Shoulders",
  triceps: "Triceps",
  lats: "Lats",
  upperBack: "Upper back",
  biceps: "Biceps",
  quads: "Quads",
  hamstrings: "Hamstrings",
  glutes: "Glutes",
  calves: "Calves",
  core: "Core",
};

export interface ExerciseCatalogEntry {
  id: string;
  name: string;
  muscle: MuscleGroup;
  equipment: GymEquipment;
  isCompound: boolean;
  isBodyweightMaxReps: boolean;
}

const e = (
  name: string,
  muscle: MuscleGroup,
  equipment: GymEquipment,
  compound = false,
  bodyweight = false,
): ExerciseCatalogEntry => ({
  id: name.toLowerCase(),
  name,
  muscle,
  equipment,
  isCompound: compound,
  isBodyweightMaxReps: bodyweight,
});

export const EXERCISE_CATALOG: ExerciseCatalogEntry[] = [
  e("Barbell bench press", "chest", "barbell", true),
  e("Incline barbell press", "chest", "barbell", true),
  e("Dumbbell bench press", "chest", "dumbbells", true),
  e("Incline dumbbell press", "chest", "dumbbells", true),
  e("Flat chest press", "chest", "machines", true),
  e("Prime incline", "chest", "machines", true),
  e("Chest press machine", "chest", "machines", true),
  e("Pec deck", "chest", "machines"),
  e("Cable flye", "chest", "cables"),
  e("Upper chest flye", "chest", "cables"),
  e("Push-up", "chest", "bodyweight", true, true),
  e("Decline push-up", "chest", "bodyweight", true, true),

  e("Overhead press", "shoulders", "barbell", true),
  e("Seated dumbbell press", "shoulders", "dumbbells", true),
  e("Arnold press", "shoulders", "dumbbells", true),
  e("Shoulder press", "shoulders", "machines", true),
  e("Machine side lateral raise", "shoulders", "machines"),
  e("Dumbbell lateral raise", "shoulders", "dumbbells"),
  e("Lateral raise", "shoulders", "dumbbells"),
  e("Cable lateral raise", "shoulders", "cables"),
  e("Rear delt flye", "shoulders", "dumbbells"),
  e("Face pull", "shoulders", "cables"),
  e("Y raise", "shoulders", "cables"),
  e("Pike push-up", "shoulders", "bodyweight", true, true),

  e("Close-grip bench press", "triceps", "barbell", true),
  e("Skull crusher", "triceps", "barbell"),
  e("Overhead tricep extension", "triceps", "dumbbells"),
  e("Tricep pushdown", "triceps", "cables"),
  e("Poliquin tricep extensions", "triceps", "cables"),
  e("Tricep dip machine", "triceps", "machines"),
  e("Bench dip", "triceps", "bodyweight", false, true),
  e("Dip", "triceps", "bodyweight", true, true),

  e("Pull-up", "lats", "bodyweight", true, true),
  e("Chin-up", "lats", "bodyweight", true, true),
  e("Lat pulldown", "lats", "cables", true),
  e("Wide grip pulldown", "lats", "cables", true),
  e("Iliac lat pulldown", "lats", "cables"),
  e("Assisted Pull up", "lats", "machines", true),
  e("Straight-arm pulldown", "lats", "cables"),
  e("One-arm dumbbell row", "lats", "dumbbells", true),

  e("Barbell row", "upperBack", "barbell", true),
  e("Tbar row", "upperBack", "barbell", true),
  e("Seated cable row", "upperBack", "cables", true),
  e("Cybex eagle lat row", "upperBack", "machines", true),
  e("Upper back row", "upperBack", "machines", true),
  e("Chest-supported row", "upperBack", "machines", true),
  e("Inverted row", "upperBack", "bodyweight", true, true),
  e("Superman", "upperBack", "bodyweight", false, true),

  e("Barbell curl", "biceps", "barbell"),
  e("Dumbbell curl", "biceps", "dumbbells"),
  e("Hammer curl", "biceps", "dumbbells"),
  e("Cable hammer curl", "biceps", "cables"),
  e("Dbell preacher curl", "biceps", "dumbbells"),
  e("Preacher curl machine", "biceps", "machines"),
  e("Incline dumbbell curl", "biceps", "dumbbells"),

  e("Back squat", "quads", "barbell", true),
  e("Front squat", "quads", "barbell", true),
  e("Goblet squat", "quads", "dumbbells", true),
  e("Leg press", "quads", "machines", true),
  e("Squat press", "quads", "machines", true),
  e("Hack squat", "quads", "machines", true),
  e("Leg extension", "quads", "machines"),
  e("Walking lunge", "quads", "dumbbells"),
  e("Bodyweight squat", "quads", "bodyweight", true, true),
  e("Bulgarian split squat", "quads", "bodyweight", true, true),

  e("Conventional deadlift", "hamstrings", "barbell", true),
  e("Romanian deadlift", "hamstrings", "barbell", true),
  e("Dumbbell RDL", "hamstrings", "dumbbells", true),
  e("Seated leg curl", "hamstrings", "machines"),
  e("Lying leg curl", "hamstrings", "machines"),
  e("Hyperextension", "hamstrings", "bodyweight", false, true),
  e("Nordic curl", "hamstrings", "bodyweight", false, true),

  e("Hip thrust", "glutes", "barbell", true),
  e("Glute bridge", "glutes", "bodyweight", false, true),
  e("Cable kickback", "glutes", "cables"),
  e("Hip abduction", "glutes", "machines"),
  e("Adductor", "glutes", "machines"),
  e("Reverse lunge", "glutes", "bodyweight", false, true),

  e("Standing calf raise", "calves", "machines"),
  e("Seated calf raise", "calves", "machines"),
  e("Straight leg calf raise", "calves", "machines"),
  e("Calf raise", "calves", "bodyweight", false, true),

  e("Cable crunch", "core", "cables"),
  e("Rope crunch", "core", "cables"),
  e("Plank", "core", "bodyweight", false, true),
  e("Hanging leg raise", "core", "bodyweight", false, true),
  e("Sit-up", "core", "bodyweight", false, true),
  e("Hollow hold", "core", "bodyweight", false, true),
  e("Side plank", "core", "bodyweight", false, true),
  e("Leg raise (bodyweight max reps)", "core", "bodyweight", false, true),
];

const byID = new Map(EXERCISE_CATALOG.map((entry) => [entry.id, entry]));
export const catalogEntry = (id: string) => byID.get(id);

export interface GeneratedExercise {
  catalogID: string;
  name: string;
  muscle: MuscleGroup;
  equipment: GymEquipment;
  defaultSets: number;
  isBodyweightMaxReps: boolean;
}

export interface GeneratedWorkoutDay {
  templateID: WorkoutTemplateID;
  exercises: GeneratedExercise[];
}

export interface GeneratedWorkoutPlan {
  seed: number;
  volume: TrainingVolume;
  goal: TrainingGoal;
  equipment: GymEquipment[];
  programID: TrainingProgramID;
  blockedExerciseIDs: string[];
  days: GeneratedWorkoutDay[];
}

export const planSummary = (plan: GeneratedWorkoutPlan) =>
  `${TrainingGoalInfo[plan.goal].name} · ${TrainingVolumeInfo[plan.volume].name} · ${plan.days.length} sessions`;

export function seededRng(seed: number) {
  let state = (seed >>> 0) || 1;
  const next = () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state;
  };
  const nextInt = (upper: number) => (upper <= 0 ? 0 : next() % upper);
  const shuffle = <T>(items: T[]) => {
    for (let i = items.length - 1; i >= 1; i--) {
      const j = nextInt(i + 1);
      const tmp = items[i];
      items[i] = items[j];
      items[j] = tmp;
    }
    return items;
  };
  return { nextInt, shuffle };
}

interface Slot {
  muscle: MuscleGroup;
  compound: boolean;
  sets: number;
}

function volumeSets(goal: TrainingGoal, volume: TrainingVolume, compound: boolean): number {
  if ((goal === "powerlifting" || goal === "strength") && volume === "high" && compound) return 5;
  if ((goal === "powerlifting" || goal === "strength") && volume === "low" && compound) return 4;
  if ((goal === "bodybuilding" || goal === "powerbuilding") && volume === "high" && compound) return 4;
  if (goal === "keepFit" && volume === "high" && compound) return 3;
  if (volume === "low" && compound) return 3;
  if (goal === "bodybuilding" && volume === "high" && !compound) return 3;
  if (goal === "keepFit" && !compound) return 2;
  if (volume === "high" && !compound) return 3;
  return 2;
}

function extraIsolation(goal: TrainingGoal, volume: TrainingVolume) {
  return volume === "high" && (goal === "bodybuilding" || goal === "powerbuilding");
}

function slot(muscle: MuscleGroup, compound: boolean, goal: TrainingGoal, volume: TrainingVolume): Slot {
  return { muscle, compound, sets: volumeSets(goal, volume, compound) };
}

function slotsFor(templateID: WorkoutTemplateID, goal: TrainingGoal, volume: TrainingVolume): Slot[] {
  const extra = extraIsolation(goal, volume);
  const heavy = goal === "powerlifting" || goal === "strength";
  const s = (muscle: MuscleGroup, compound: boolean) => slot(muscle, compound, goal, volume);

  switch (templateID) {
    case "pushA":
    case "fwPush": {
      if (heavy) {
        const list = [s("chest", true), s("chest", true), s("shoulders", true), s("triceps", false)];
        if (volume === "high") list.push(s("shoulders", false));
        return list;
      }
      if (goal === "keepFit") {
        const list = [s("chest", true), s("shoulders", true), s("triceps", false)];
        if (volume === "high") list.push(s("chest", false));
        return list;
      }
      const list = [s("chest", true), s("chest", false), s("shoulders", true), s("shoulders", false), s("triceps", false)];
      if (extra) list.push(s("triceps", false));
      return list;
    }
    case "pullA":
    case "fwPull": {
      if (heavy) {
        const list = [s("hamstrings", true), s("upperBack", true), s("lats", true), s("biceps", false)];
        if (volume === "high") list.push(s("upperBack", false));
        return list;
      }
      if (goal === "keepFit") {
        const list = [s("lats", true), s("upperBack", true), s("biceps", false)];
        if (volume === "high") list.push(s("core", false));
        return list;
      }
      const list = [s("lats", true), s("upperBack", true), s("lats", false), s("biceps", false), s("core", false)];
      if (extra) list.push(s("biceps", false));
      return list;
    }
    case "legsA":
    case "fwLegs": {
      if (heavy) {
        const list = [s("quads", true), s("hamstrings", true), s("glutes", true), s("calves", false)];
        if (volume === "high") list.push(s("quads", false));
        return list;
      }
      const list = [s("quads", true), s("hamstrings", true), s("glutes", true), s("quads", false), s("hamstrings", false), s("calves", false)];
      if (extra) list.push(s("core", false));
      return list;
    }
    case "legsB": {
      const list = [s("glutes", true), s("hamstrings", false), s("quads", true), s("quads", false), s("calves", false), s("core", false)];
      if (extra) list.push(s("glutes", false));
      return list;
    }
    case "upper":
    case "ulUpperA": {
      if (heavy) return [s("chest", true), s("upperBack", true), s("shoulders", true), s("lats", true), s("triceps", false)];
      const list = [s("chest", true), s("upperBack", true), s("shoulders", true), s("lats", true), s("biceps", false), s("triceps", false)];
      if (extra) list.push(s("shoulders", false));
      return list;
    }
    case "ulUpperB": {
      const list = [s("chest", false), s("lats", true), s("shoulders", true), s("upperBack", true), s("triceps", false), s("shoulders", false)];
      if (extra) list.push(s("biceps", false));
      return list;
    }
    case "ulLowerA": {
      if (heavy) return [s("quads", true), s("hamstrings", true), s("glutes", true), s("calves", false), s("core", false)];
      const list = [s("quads", true), s("hamstrings", true), s("quads", false), s("hamstrings", false), s("calves", false)];
      if (extra) list.push(s("core", false));
      return list;
    }
    case "ulLowerB": {
      const list = [s("quads", true), s("glutes", true), s("quads", false), s("calves", false), s("core", false)];
      if (extra) list.push(s("hamstrings", false));
      return list;
    }
    case "fbA":
    case "bwFullA": {
      const list = [s("quads", true), s("chest", true), s("upperBack", true), s("hamstrings", true), s("core", false)];
      if (extra) list.push(s("shoulders", false));
      return list;
    }
    case "fbB":
    case "bwFullB": {
      const list = [s("hamstrings", true), s("shoulders", true), s("lats", true), s("quads", false), s("biceps", false)];
      if (extra) list.push(s("core", false));
      return list;
    }
    case "fbC":
    case "bwFullC": {
      const list = [s("quads", true), s("chest", true), s("lats", true), s("glutes", true), s("shoulders", false)];
      if (extra) list.push(s("core", false));
      return list;
    }
  }
}

export function generatedSplit(daysPerWeek: number, equipment: Set<GymEquipment>, goal: TrainingGoal): TrainingProgramID {
  const hasMachines = equipment.has("machines") || equipment.has("cables");
  const hasFree = equipment.has("barbell") || equipment.has("dumbbells");
  if (!hasMachines && !hasFree) return "bodyweight";
  switch (goal) {
    case "keepFit":
      if (daysPerWeek <= 3) return "fullBody";
      if (daysPerWeek === 4) return "upperLower";
      return hasMachines && !hasFree ? "gymMachines" : hasFree && !hasMachines ? "freeWeights" : "upperLower";
    case "bodybuilding":
      if (daysPerWeek <= 3) return "fullBody";
      if (daysPerWeek === 4) return "upperLower";
      return hasMachines ? "gymMachines" : "freeWeights";
    case "powerlifting":
    case "strength":
      if (daysPerWeek <= 3) return "fullBody";
      return "upperLower";
    case "powerbuilding":
      if (daysPerWeek <= 3) return "fullBody";
      if (daysPerWeek === 4) return "upperLower";
      return hasFree ? "freeWeights" : "gymMachines";
  }
}

function pick(
  muscle: MuscleGroup,
  preferCompound: boolean,
  equipment: Set<GymEquipment>,
  blocked: Set<string>,
  used: Set<string>,
  rng: ReturnType<typeof seededRng>,
): ExerciseCatalogEntry | undefined {
  const pool = (muscles: MuscleGroup[], gear: Set<GymEquipment>, compound: boolean | null) =>
    EXERCISE_CATALOG.filter(
      (entry) =>
        muscles.includes(entry.muscle) &&
        gear.has(entry.equipment) &&
        !blocked.has(entry.id) &&
        !used.has(entry.id) &&
        (compound === null || entry.isCompound === compound),
    );
  let options = pool([muscle], equipment, preferCompound);
  if (options.length === 0) options = pool([muscle], equipment, null);
  if (options.length === 0) options = pool([muscle], new Set([...equipment, "bodyweight"]), null);
  rng.shuffle(options);
  return options[0];
}

export function generateWorkoutPlan(input: {
  seed: number;
  volume: TrainingVolume;
  goal: TrainingGoal;
  equipment: GymEquipment[];
  daysPerWeek: number;
  blockedIDs: string[];
}): GeneratedWorkoutPlan {
  const gear = new Set(input.equipment.length ? input.equipment : GYM_EQUIPMENT);
  const program = generatedSplit(input.daysPerWeek, gear, input.goal);
  const blocked = new Set(input.blockedIDs);
  const rng = seededRng(input.seed);
  const used = new Set<string>();
  const days: GeneratedWorkoutDay[] = [];
  for (const templateID of TrainingProgramInfo[program].templateIDs) {
    const exercises: GeneratedExercise[] = [];
    for (const slotDef of slotsFor(templateID, input.goal, input.volume)) {
      const chosen = pick(slotDef.muscle, slotDef.compound, gear, blocked, used, rng);
      if (!chosen) continue;
      used.add(chosen.id);
      exercises.push({
        catalogID: chosen.id,
        name: chosen.name,
        muscle: chosen.muscle,
        equipment: chosen.equipment,
        defaultSets: slotDef.sets,
        isBodyweightMaxReps: chosen.isBodyweightMaxReps,
      });
    }
    days.push({ templateID, exercises });
  }
  return {
    seed: input.seed,
    volume: input.volume,
    goal: input.goal,
    equipment: GYM_EQUIPMENT.filter((item) => gear.has(item)),
    programID: program,
    blockedExerciseIDs: input.blockedIDs,
    days,
  };
}

export function replacementsFor(
  entry: ExerciseCatalogEntry,
  equipment: Set<GymEquipment>,
  blocked: Set<string>,
  excluding: Set<string>,
): ExerciseCatalogEntry[] {
  const sameMuscle = EXERCISE_CATALOG.filter(
    (item) => item.muscle === entry.muscle && item.id !== entry.id && !excluding.has(item.id),
  );
  const preferred = sameMuscle.filter((item) => equipment.has(item.equipment) && !blocked.has(item.id));
  const fallback = sameMuscle.filter((item) => !blocked.has(item.id));
  const seen = new Set<string>();
  const out: ExerciseCatalogEntry[] = [];
  const byName = (a: ExerciseCatalogEntry, b: ExerciseCatalogEntry) => a.name.localeCompare(b.name);
  for (const item of [...preferred.sort(byName), ...fallback.sort(byName)]) {
    if (!seen.has(item.id)) {
      seen.add(item.id);
      out.push(item);
    }
  }
  return out;
}

export function snapshotLibraryPlan(input: {
  programID: TrainingProgramID;
  volume: TrainingVolume;
  goal: TrainingGoal;
  equipment: GymEquipment[];
  templates: WorkoutTemplate[];
}): GeneratedWorkoutPlan {
  return {
    seed: 0,
    volume: input.volume,
    goal: input.goal,
    equipment: input.equipment.length ? input.equipment : TYPICAL_GYM,
    programID: input.programID,
    blockedExerciseIDs: [],
    days: input.templates.map((template) => ({
      templateID: template.id,
      exercises: template.exercises.map((blueprint) => {
        const entry = catalogEntry(blueprint.id);
        return {
          catalogID: blueprint.id,
          name: blueprint.name,
          muscle: entry?.muscle ?? "chest",
          equipment: entry?.equipment ?? "machines",
          defaultSets: blueprint.defaultSets,
          isBodyweightMaxReps: blueprint.isBodyweightMaxReps,
        };
      }),
    })),
  };
}

export function dayOf(plan: GeneratedWorkoutPlan, id: WorkoutTemplateID) {
  return plan.days.find((day) => day.templateID === id);
}

export function generatedAsTemplate(plan: GeneratedWorkoutPlan, id: WorkoutTemplateID): WorkoutTemplate | undefined {
  const day = dayOf(plan, id);
  if (!day || day.exercises.length === 0) return undefined;
  return {
    id,
    name: TemplateName[id],
    exercises: day.exercises.map((exercise) => ({
      id: exercise.catalogID,
      name: exercise.name,
      defaultSets: exercise.defaultSets,
      isBodyweightMaxReps: exercise.isBodyweightMaxReps,
    })),
  };
}
