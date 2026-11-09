import { CoachingConfig } from "../core/config";
import type { Day } from "../core/dates";
import {
  type AdherenceBand,
  AdherenceInfo,
  type AppearanceFeedback,
  type BiologicalSex,
  type CoachAdjustment,
  type CoachConfidence,
  type CoachDecision,
  type CoachReasonCode,
  type CoachingWeek,
  type DailyNutritionTarget,
  type GoalPhase,
  type MacroGrams,
  type RefeedPlan,
  type TrainingPerformance,
  type WeeklyRateOfChange,
  NutritionMath,
  makeTarget,
  uuid,
} from "../core/models";
import { adjustedStepTarget, applyCalorieAdjustment } from "./nutrition";

/** Port of CoachingDecisionEngine.swift. */
export interface DecisionInput {
  goal: GoalPhase;
  previousWeek: CoachingWeek;
  currentWeek: CoachingWeek;
  rate?: WeeklyRateOfChange;
  currentTrainingCalories: number;
  currentRestCalories: number;
  currentMacros: MacroGrams;
  stepTarget: number;
  adherence: AdherenceBand;
  performance: TrainingPerformance;
  appearance: AppearanceFeedback;
  hunger: number;
  energy: number;
  weightKg: number;
  sex: BiologicalSex;
  recentRefeed: boolean;
}

function decision(d: {
  weekStart: Day;
  action: CoachAdjustment;
  secondaryActions?: CoachAdjustment[];
  confidence: CoachConfidence;
  reasons: CoachReasonCode[];
  summary: string;
  suggestedTrainingCalories?: number;
  suggestedRestCalories?: number;
  suggestedMacros?: MacroGrams;
  suggestedSteps?: number;
  refeed?: RefeedPlan;
}): CoachDecision {
  return { id: uuid(), secondaryActions: [], createdAt: new Date().toISOString(), ...d };
}

function currentTraining(input: DecisionInput): DailyNutritionTarget {
  return makeTarget({
    calories: input.currentTrainingCalories,
    macros: input.currentMacros,
    isTrainingDay: true,
    stepTarget: input.stepTarget,
  });
}

const isHigh = (a: AdherenceBand) => AdherenceInfo[a].isHigh;

export function evaluate(input: DecisionInput): CoachDecision {
  const weekStart = input.currentWeek.startDate;
  const rate = input.rate;

  // Insufficient weigh-ins — never punish, never adjust strongly.
  if (
    input.currentWeek.completeness === "empty" ||
    input.currentWeek.completeness === "insufficientForAdjustment" ||
    !rate
  ) {
    return decision({
      weekStart,
      action: { type: "requireMoreData" },
      confidence: "low",
      reasons: ["insufficientWeighIns"],
      summary: "Not enough consistent weigh-ins to confidently adjust your plan this week.",
    });
  }

  // Poor adherence — do not modify calories from weight noise.
  if (AdherenceInfo[input.adherence].isPoor) {
    return decision({
      weekStart,
      action: { type: "reviewAdherence" },
      confidence: "medium",
      reasons: ["poorAdherence"],
      summary: "Your current plan hasn't had enough consistent execution for me to confidently change calories.",
    });
  }

  const magnitude = Math.abs(rate.absoluteChangeKg);
  if (magnitude > CoachingConfig.extremeWeeklyChangeKg) return extremeChangeDecision(input, rate, weekStart, false);
  if (magnitude === CoachingConfig.extremeWeeklyChangeKg) return extremeChangeDecision(input, rate, weekStart, true);
  return standardDecision(input, rate, weekStart);
}

function extremeChangeDecision(
  input: DecisionInput,
  rate: WeeklyRateOfChange,
  weekStart: Day,
  exactThreshold: boolean,
): CoachDecision {
  const reasons: CoachReasonCode[] = ["extremeWeeklyChange"];
  const changeText = Math.abs(rate.absoluteChangeKg).toFixed(1);

  switch (input.goal) {
    case "cut": {
      if (rate.absoluteChangeKg < 0) {
        reasons.push("rateTooFastLoss");
        if (input.appearance === "flatter") reasons.push("appearanceFlat");
        if (input.performance === "slightlyWorse" || input.performance === "muchWorse") {
          reasons.push("performanceDeclining");
        }
        const pair = applyCalorieAdjustment(
          currentTraining(input),
          CoachingConfig.largeCalorieAdjustment,
          input.weightKg,
          input.goal,
          input.sex,
        );
        const secondary: CoachAdjustment[] = [];
        let refeed: RefeedPlan | undefined;
        if (shouldSuggestRefeed(input, rate)) {
          secondary.push({ type: "suggestRefeed" });
          refeed = makeRefeed(pair.training, input.weightKg);
        }
        return decision({
          weekStart,
          action: { type: "recommendNutritionIncreaseReview" },
          secondaryActions: [...secondary, { type: "increaseCalories", amount: CoachingConfig.largeCalorieAdjustment }],
          confidence: exactThreshold ? "medium" : "high",
          reasons,
          summary: `Your weekly average decreased by ${changeText} kg. Before reducing food further, let's review recovery, appearance and adherence.`,
          suggestedTrainingCalories: pair.training.calories,
          suggestedRestCalories: pair.rest.calories,
          suggestedMacros: pair.training.macros,
          suggestedSteps: input.stepTarget,
          refeed,
        });
      }
      reasons.push("appearanceSoft");
      return decision({
        weekStart,
        action: { type: "reviewRecovery" },
        confidence: "medium",
        reasons,
        summary: `Weight rose ${changeText} kg on your weekly average during a cut. We'll review adherence, sodium, sleep and unusual meals before changing food.`,
      });
    }
    case "gain": {
      if (rate.absoluteChangeKg > 0) {
        reasons.push("rateTooFastGain");
        const pair = applyCalorieAdjustment(
          currentTraining(input),
          -CoachingConfig.largeCalorieAdjustment,
          input.weightKg,
          input.goal,
          input.sex,
        );
        return decision({
          weekStart,
          action: { type: "recommendNutritionDecreaseReview" },
          secondaryActions: [{ type: "decreaseCalories", amount: CoachingConfig.largeCalorieAdjustment }],
          confidence: exactThreshold ? "medium" : "high",
          reasons,
          summary: `You gained ${changeText} kg on your weekly average. Let's review your physique and adherence before adding any more food.`,
          suggestedTrainingCalories: pair.training.calories,
          suggestedRestCalories: pair.rest.calories,
          suggestedMacros: pair.training.macros,
          suggestedSteps: input.stepTarget,
        });
      }
      reasons.push("rateTooSlow");
      const pair = applyCalorieAdjustment(
        currentTraining(input),
        CoachingConfig.defaultCalorieAdjustment,
        input.weightKg,
        input.goal,
        input.sex,
      );
      return decision({
        weekStart,
        action: { type: "recommendNutritionIncreaseReview" },
        secondaryActions: [{ type: "increaseCalories", amount: CoachingConfig.defaultCalorieAdjustment }],
        confidence: "medium",
        reasons,
        summary:
          "Weight fell during a gaining phase. With solid adherence, increasing food — primarily carbohydrates — is the measured next step.",
        suggestedTrainingCalories: pair.training.calories,
        suggestedRestCalories: pair.rest.calories,
        suggestedMacros: pair.training.macros,
        suggestedSteps: input.stepTarget,
      });
    }
    case "maintenance":
      return decision({
        weekStart,
        action: { type: "reviewRecovery" },
        confidence: "medium",
        reasons,
        summary: `Weekly change of ${changeText} kg is larger than expected for maintenance. Review adherence before adjusting.`,
      });
  }
}

function standardDecision(input: DecisionInput, rate: WeeklyRateOfChange, weekStart: Day): CoachDecision {
  const reasons: CoachReasonCode[] = [];
  if (isHigh(input.adherence)) reasons.push("highAdherence");
  if (input.performance === "same" || input.performance === "better" || input.performance === "muchBetter") {
    reasons.push("performanceStable");
  }
  const holdNumbers = {
    suggestedTrainingCalories: input.currentTrainingCalories,
    suggestedRestCalories: input.currentRestCalories,
    suggestedMacros: input.currentMacros,
    suggestedSteps: input.stepTarget,
  };
  const change = rate.absoluteChangeKg;

  switch (input.goal) {
    case "cut": {
      if (change <= -0.25 && change >= -1.2) {
        reasons.push("rateOnTarget");
        const secondary: CoachAdjustment[] = [];
        let refeed: RefeedPlan | undefined;
        if (shouldSuggestRefeed(input, rate)) {
          secondary.push({ type: "suggestRefeed" });
          refeed = makeRefeed(currentTraining(input), input.weightKg);
        }
        return decision({
          weekStart,
          action: { type: "maintain" },
          secondaryActions: secondary,
          confidence: "high",
          reasons: [...reasons, ...(input.appearance === "flatter" ? (["appearanceFlat"] as const) : [])],
          summary: "Right on target. No calorie adjustment.",
          ...holdNumbers,
          refeed,
        });
      }

      if (change > 0.2 && isHigh(input.adherence)) {
        const stepDelta = CoachingConfig.defaultStepIncrement;
        const newSteps = adjustedStepTarget(input.stepTarget, stepDelta);
        if (newSteps === input.stepTarget && input.stepTarget >= CoachingConfig.maxStepTarget) {
          reasons.push("stepCapReached");
          const pair = applyCalorieAdjustment(
            currentTraining(input),
            -CoachingConfig.defaultCalorieAdjustment,
            input.weightKg,
            input.goal,
            input.sex,
          );
          return decision({
            weekStart,
            action: { type: "decreaseCalories", amount: CoachingConfig.defaultCalorieAdjustment },
            confidence: "medium",
            reasons,
            summary:
              "Trend is stalled upward with strong adherence. Modest calorie reduction primarily from carbohydrates.",
            suggestedTrainingCalories: pair.training.calories,
            suggestedRestCalories: pair.rest.calories,
            suggestedMacros: pair.training.macros,
            suggestedSteps: input.stepTarget,
          });
        }
        return decision({
          weekStart,
          action: { type: "increaseSteps", amount: stepDelta },
          confidence: "medium",
          reasons,
          summary:
            "Weight trend is flat/up with strong adherence. A gradual step increase is preferred before cutting food.",
          ...holdNumbers,
          suggestedSteps: newSteps,
        });
      }

      if (change > -0.2) {
        reasons.push("rateTooSlow");
        return decision({
          weekStart,
          action: { type: "maintain" },
          confidence: "medium",
          reasons,
          summary:
            "Loss is slower than ideal this week. Hold calories and reassess next week unless the trend persists.",
          ...holdNumbers,
        });
      }
      break;
    }
    case "gain": {
      if (change >= 0.15 && change <= 0.75) {
        reasons.push("rateOnTarget");
        if (input.appearance === "better") reasons.push("appearanceImproving");
        return decision({
          weekStart,
          action: { type: "maintain" },
          confidence: "high",
          reasons,
          summary: "Right on target. No calorie adjustment.",
          ...holdNumbers,
        });
      }
      if (change < 0 && isHigh(input.adherence)) {
        const pair = applyCalorieAdjustment(
          currentTraining(input),
          CoachingConfig.defaultCalorieAdjustment,
          input.weightKg,
          input.goal,
          input.sex,
        );
        return decision({
          weekStart,
          action: { type: "increaseCalories", amount: CoachingConfig.defaultCalorieAdjustment },
          confidence: "medium",
          reasons: [...reasons, "rateTooSlow"],
          summary: "Weight drifted down while gaining. Increase calories primarily from carbohydrates.",
          suggestedTrainingCalories: pair.training.calories,
          suggestedRestCalories: pair.rest.calories,
          suggestedMacros: pair.training.macros,
          suggestedSteps: input.stepTarget,
        });
      }
      break;
    }
    case "maintenance":
      reasons.push("rateOnTarget");
      return decision({
        weekStart,
        action: { type: "maintain" },
        confidence: "medium",
        reasons,
        summary: "Hold the current plan and monitor the weekly average.",
        ...holdNumbers,
      });
  }

  reasons.push("rateOnTarget");
  return decision({
    weekStart,
    action: { type: "maintain" },
    confidence: "medium",
    reasons,
    summary: "Hold steady. Consistency beats reacting to one noisy week.",
    ...holdNumbers,
  });
}

function shouldSuggestRefeed(input: DecisionInput, rate: WeeklyRateOfChange): boolean {
  if (input.goal !== "cut" || !isHigh(input.adherence) || input.recentRefeed) return false;
  const losing = rate.absoluteChangeKg < -0.3;
  const flatOrTired =
    input.appearance === "flatter" ||
    input.performance === "slightlyWorse" ||
    input.performance === "muchWorse" ||
    input.hunger >= 4 ||
    input.energy <= 2;
  return losing && flatOrTired;
}

function makeRefeed(normal: DailyNutritionTarget, weightKg: number): RefeedPlan {
  const refeedCalories = normal.calories + CoachingConfig.largeCalorieAdjustment + 100;
  const protein = normal.macros.protein;
  const fat = Math.max(normal.macros.fat, weightKg * CoachingConfig.minimumFatGramsPerKg);
  const carbs = NutritionMath.carbohydratesFromRemainingCalories(refeedCalories, protein, fat);
  return {
    id: uuid(),
    normalTarget: normal,
    refeedTarget: makeTarget({
      calories: refeedCalories,
      macros: { protein, carbohydrates: carbs, fat },
      isTrainingDay: true,
      stepTarget: normal.stepTarget,
      source: "coachRecommendation",
      includesIntraWorkout: normal.includesIntraWorkout,
    }),
    reason: "A higher-carbohydrate day may help support training performance and adherence.",
    accepted: false,
  };
}

/** Whether the check-in result screen should offer "Apply Coach Recommendation". */
export function isApplicable(action: CoachAdjustment): boolean {
  return !["maintain", "requireMoreData", "reviewAdherence", "reviewRecovery", "suggestRefeed"].includes(action.type);
}
