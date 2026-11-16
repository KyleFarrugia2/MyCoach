import { describe, expect, it } from "vitest";
import {
  TrainingProgramInfo,
  applyTrainingStyle,
  recommendedProgram,
  WORKOUT_LIBRARY,
} from "../src/engines/workout";
import { actions, getState, nextWorkoutTemplate } from "../src/state/store";

describe("training programs", () => {
  it("defaults to the original gym-machine split", () => {
    actions.deleteAccountLocally();
    expect(getState().preferences.trainingProgramID).toBeUndefined();
    expect(TrainingProgramInfo.gymMachines.templateIDs).toEqual(["pushA", "pullA", "legsA", "upper", "legsB"]);
  });

  it("recommends a split from days per week", () => {
    expect(recommendedProgram(3)).toBe("fullBody");
    expect(recommendedProgram(4)).toBe("upperLower");
    expect(recommendedProgram(5)).toBe("gymMachines");
  });

  it("strength style adds compound sets", () => {
    const base = WORKOUT_LIBRARY.find((t) => t.id === "fwPush")!;
    const styled = applyTrainingStyle("strength", base);
    expect(styled.exercises[0].defaultSets).toBeGreaterThanOrEqual(4);
    expect(styled.exercises[1].defaultSets).toBeGreaterThanOrEqual(4);
    expect(applyTrainingStyle("hypertrophy", base).exercises.map((e) => e.defaultSets)).toEqual(base.exercises.map((e) => e.defaultSets));
  });

  it("athletic style adds a single finisher", () => {
    const base = WORKOUT_LIBRARY.find((t) => t.id === "fbA")!;
    const styled = applyTrainingStyle("athletic", base);
    expect(styled.exercises.some((e) => e.id === "conditioning finisher")).toBe(true);
    expect(applyTrainingStyle("athletic", styled).exercises.filter((e) => e.id === "conditioning finisher")).toHaveLength(1);
  });

  it("rotates next workout inside the selected program", () => {
    actions.setTrainingProgram("gymMachines");
    actions.startWorkout("pushA");
    actions.finishActiveWorkout();
    expect(nextWorkoutTemplate(getState())).toBe("pullA");

    actions.setTrainingProgram("fullBody");
    expect(nextWorkoutTemplate(getState())).toBe("fbA");
  });

  it("every program has library templates", () => {
    for (const program of Object.values(TrainingProgramInfo)) {
      expect(program.templateIDs.length).toBeGreaterThan(0);
      for (const id of program.templateIDs) {
        expect(WORKOUT_LIBRARY.find((t) => t.id === id)?.exercises.length).toBeGreaterThan(0);
      }
    }
  });
});
