import { describe, expect, it } from "vitest";
import type { ExerciseLog, WorkoutSession } from "../src/engines/workout";
import { fmtKg, reviewExercise, reviewWorkout, streakMessage, workoutStreak } from "../src/engines/workoutReview";

const ex = (sets: [number | undefined, number][], bodyweight = false): ExerciseLog => ({
  id: "press",
  name: "Flat chest press",
  plannedSets: sets.length,
  isBodyweightMaxReps: bodyweight,
  sets: sets.map(([w, r], i) => ({ id: `s${i}`, setNumber: i + 1, weightKg: w, reps: r, completedAt: "" })),
});

describe("exercise review", () => {
  it("detects heavier top sets, more reps, more volume, same and less", () => {
    expect(reviewExercise(ex([[40, 10]]), ex([[42.5, 8]]))).toMatchObject({ status: "progressed", detail: "+2.5 kg on your top set (40 → 42.5 kg)" });
    expect(reviewExercise(ex([[40, 10]]), ex([[40, 12]]))).toMatchObject({ status: "progressed", detail: "+2 reps at 40 kg" });
    expect(reviewExercise(ex([[40, 10]]), ex([[40, 10], [40, 8]]))).toMatchObject({ status: "progressed", detail: "More total volume (400 → 720 kg)" });
    expect(reviewExercise(ex([[40, 10]]), ex([[40, 10]]))).toMatchObject({ status: "same", detail: "40 kg × 10 again" });
    expect(reviewExercise(ex([[40, 10]]), ex([[40, 8]]))).toMatchObject({ status: "less", detail: "10 → 8 reps at 40 kg" });
    expect(reviewExercise(ex([[40, 10]]), ex([[35, 10]]))).toMatchObject({ status: "less", detail: "Top set 40 → 35 kg" });
    expect(reviewExercise(undefined, ex([[40, 10]]))).toMatchObject({ status: "new" });
    expect(reviewExercise(ex([[40, 10]]), ex([]))).toBeUndefined();
  });

  it("handles bodyweight max-rep movements", () => {
    expect(reviewExercise(ex([[undefined, 12]], true), ex([[undefined, 15]], true))).toMatchObject({ status: "progressed", detail: "+3 reps (12 → 15)" });
    expect(reviewExercise(ex([[undefined, 12]], true), ex([[undefined, 12]], true))).toMatchObject({ status: "same" });
  });

  it("formats kilograms like the Swift port", () => {
    expect(fmtKg(40)).toBe("40");
    expect(fmtKg(42.5)).toBe("42.5");
    expect(fmtKg(2.25)).toBe("2.3");
  });
});

const session = (day: string, exercises: ExerciseLog[] = [ex([[40, 10]])]): WorkoutSession => ({
  id: day,
  templateID: "pushA",
  templateName: "Push A",
  localDate: day,
  startedAt: `${day}T17:00:00Z`,
  completedAt: `${day}T18:00:00Z`,
  exercises,
  notes: "",
});

describe("workout review summary", () => {
  it("celebrates progress, or encourages when nothing went up", () => {
    const up = reviewWorkout(session("2026-11-08"), session("2026-11-15", [ex([[42.5, 10]])]));
    expect(up.headline).toBe("Well done!");
    expect(up.encouragement).toBeUndefined();
    const flat = reviewWorkout(session("2026-11-08"), session("2026-11-15", [ex([[40, 9]])]));
    expect(flat.headline).toBe("Solid work");
    expect(flat.encouragement).toMatch(/progress isn't linear/);
    expect(reviewWorkout(undefined, session("2026-11-15")).headline).toBe("Baseline set!");
  });
});

describe("streak", () => {
  const mwf = [1, 3, 5] as never; // Mon Wed Fri

  it("counts workouts until a missed planned training day", () => {
    // Mon 9, Wed 11, Fri 13 done; today Sun 15 → streak 3.
    const s = [session("2026-11-09"), session("2026-11-11"), session("2026-11-13")];
    expect(workoutStreak(mwf, [], s, "2026-11-15")).toBe(3);
    // Missed Wed 11 → only Fri counts.
    expect(workoutStreak(mwf, [], [session("2026-11-09"), session("2026-11-13")], "2026-11-15")).toBe(1);
  });

  it("emergency rest days don't break it, and today isn't missed yet", () => {
    const s = [session("2026-11-09"), session("2026-11-13")];
    const rest = [{ day: "2026-11-11", type: "rest" as const, reason: "emergencyRest" as const }];
    expect(workoutStreak(mwf, rest, s, "2026-11-15")).toBe(2);
    expect(workoutStreak(mwf, [], [session("2026-11-11")], "2026-11-13")).toBe(1); // Fri 13 is today
    expect(workoutStreak(mwf, [], [], "2026-11-15")).toBe(0);
  });

  it("has a message for every streak length", () => {
    expect(streakMessage(1).title).toBe("Great start!");
    expect(streakMessage(2).title).toBe("Keep it up!");
    expect(streakMessage(5).title).toBe("You are on fire!");
    expect(streakMessage(9).title).toBe("Unstoppable!");
    expect(streakMessage(20).title).toBe("Legend in the making!");
  });
});
