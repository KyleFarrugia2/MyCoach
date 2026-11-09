import type { BiologicalSex, CoachDecision, DailyNutritionTarget, GoalPhase, NutritionTargetPair } from "../core/models";
import type { AdaptiveRecommendation } from "./adaptive";
import { applyCalorieAdjustment } from "./nutrition";

/**
 * Bridges the learned model and the rule-based weekly check-in.
 *
 * The rule engine stays in charge of *whether* calories may change (enough weigh-ins, adherence, extreme
 * swings, recovery). When it would otherwise make a standard fixed-size move (maintain / ±150 kcal) and the
 * personal model is confident, the model decides *how much*.
 */
const MODEL_OVERRIDABLE = new Set(["maintain", "increaseCalories", "decreaseCalories"]);

export function blendDecisionWithModel(
  decision: CoachDecision,
  rec: AdaptiveRecommendation | undefined,
  training: DailyNutritionTarget | undefined,
  weightKg: number,
  goal: GoalPhase,
  sex: BiologicalSex,
): CoachDecision {
  if (!rec || !training || rec.confidence === "low" || !MODEL_OVERRIDABLE.has(decision.action.type)) return decision;
  // Keep a rule-suggested refeed alongside a "maintain".
  const reasons = [...decision.reasons.filter((r) => r !== "rateOnTarget" && r !== "rateTooSlow"), "modelPrediction" as const];
  if (rec.deltaKcal === 0) {
    return { ...decision, action: { type: "maintain" }, reasons, summary: rec.summary, confidence: rec.confidence };
  }
  const pair = applyCalorieAdjustment(training, rec.deltaKcal, weightKg, goal, sex);
  return {
    ...decision,
    action: rec.deltaKcal > 0 ? { type: "increaseCalories", amount: rec.deltaKcal } : { type: "decreaseCalories", amount: -rec.deltaKcal },
    secondaryActions: decision.secondaryActions.filter((a) => a.type === "suggestRefeed"),
    confidence: rec.confidence,
    reasons,
    summary: rec.summary,
    suggestedTrainingCalories: pair.training.calories,
    suggestedRestCalories: pair.rest.calories,
    suggestedMacros: pair.training.macros,
  };
}

/** Apply a model-chosen delta and tag both targets as coming from the adaptive model. */
export function applyModelAdjustment(
  targets: NutritionTargetPair,
  deltaKcal: number,
  weightKg: number,
  goal: GoalPhase,
  sex: BiologicalSex,
): NutritionTargetPair {
  const pair = applyCalorieAdjustment(targets.training, deltaKcal, weightKg, goal, sex);
  return {
    training: { ...pair.training, source: "adaptiveModel" },
    rest: { ...pair.rest, source: "adaptiveModel" },
  };
}
