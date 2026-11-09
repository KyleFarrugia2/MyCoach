import { CoachingConfig } from "../core/config";
import type {
  CoachAIContext,
  CoachAIStructuredResponse,
  CoachAdjustment,
  CoachChatMessage,
  CoachDecision,
  CoachReasonCode,
  MacroGrams,
} from "../core/models";

/**
 * Port of LocalDeterministicCoachAI (CoachAIProvider.swift).
 * Explains engine decisions in plain language — it never invents or overrides engine numbers.
 */
export const OFFLINE_COACH_MESSAGE = "Coach AI is temporarily unavailable. Your plan and tracking are still available.";

const r = (n: number) => Math.round(n);

export function chat(
  messages: CoachChatMessage[],
  decision: CoachDecision | undefined,
  context: CoachAIContext,
): CoachAIStructuredResponse {
  const lastUser = [...messages].reverse().find((m) => m.role === "user")?.text;
  if (!decision) {
    const model = modelLines(context);
    const ready = context.model && context.model.confidence !== "low";
    return {
      summary: ready ? modelHeadline(context) : "Your current plan is active.",
      recommendation: ready
        ? modelRecommendation(context)
        : "Continue logging weight, food, and weekly check-ins so the engine can review progress.",
      reasoning: [
        `Training target: ${context.trainingCalories} kcal.`,
        `Rest target: ${context.restCalories} kcal.`,
        `Protein: ${r(context.protein)} g · Carbs: ${r(context.carbs)} g · Fat: ${r(context.fat)} g.`,
        `Step target: ${context.stepTarget}.`,
        ...model,
      ],
      userMessage: ready
        ? `${lastUser ? `Regarding “${lastUser}”: ` : ""}${modelHeadline(context)} ${modelRecommendation(context)}`
        : lastUser
          ? `Regarding “${lastUser}”: stick to your engine targets while we gather more data.`
          : "Stick to your engine targets while we gather more data.",
    };
  }
  return validatePreferringEngine(build(decision, context, lastUser), decision, context);
}

export function explain(decision: CoachDecision, context: CoachAIContext): CoachAIStructuredResponse {
  return validatePreferringEngine(build(decision, context, undefined), decision, context);
}

function build(decision: CoachDecision, context: CoachAIContext, userPrompt?: string): CoachAIStructuredResponse {
  const actionLine = describeAction(decision.action, decision, context);
  const summary = decision.summary || actionLine;
  const reasoning = [...decision.reasons.map(describeReason), ...numberAnchors(decision, context)];
  for (const a of decision.secondaryActions) reasoning.push(`Also: ${describeAction(a, decision, context)}`);
  const userMessage = userPrompt ? `You asked: “${userPrompt}”. ${summary} ${actionLine}` : `${summary} ${actionLine}`;
  return { summary, recommendation: actionLine, reasoning, userMessage };
}

function engineMacros(decision: CoachDecision, context: CoachAIContext): MacroGrams {
  return decision.suggestedMacros ?? { protein: context.protein, carbohydrates: context.carbs, fat: context.fat };
}

function numberAnchors(decision: CoachDecision, context: CoachAIContext): string[] {
  const lines = [
    `Training calories (engine): ${decision.suggestedTrainingCalories ?? context.trainingCalories} kcal.`,
    `Rest calories (engine): ${decision.suggestedRestCalories ?? context.restCalories} kcal.`,
  ];
  const m = engineMacros(decision, context);
  lines.push(`Macros (engine): ${r(m.protein)} g protein, ${r(m.carbohydrates)} g carbs, ${r(m.fat)} g fat.`);
  lines.push(`Step target (engine): ${decision.suggestedSteps ?? context.stepTarget}.`);
  if (context.weeklyRateKg !== undefined) {
    lines.push(`Weekly average change (logged): ${context.weeklyRateKg.toFixed(2)} kg.`);
  }
  lines.push(...modelLines(context));
  if (decision.refeed) {
    lines.push(
      `Refeed day calories (engine): ${decision.refeed.refeedTarget.calories} kcal vs normal ${decision.refeed.normalTarget.calories} kcal.`,
    );
  }
  return lines;
}

const signed = (v: number) => `${v >= 0 ? "+" : "−"}${Math.abs(v).toFixed(2)}`;

function modelHeadline(c: CoachAIContext): string {
  const m = c.model!;
  return `Based on your own data, your maintenance is about ${r(m.maintenanceKcal)} kcal/day and you're on track for ${signed(m.predictedKgPerWeek)} kg/week (goal ${signed(m.targetKgPerWeek)}).`;
}

function modelRecommendation(c: CoachAIContext): string {
  const d = c.model!.recommendedDeltaKcal;
  return d === 0
    ? "Your current calories already match your goal rate — keep going."
    : `Your personal model recommends ${d > 0 ? "adding" : "removing"} ${Math.abs(d)} kcal/day.`;
}

/** Personal-model facts — numbers come from the trained model, never invented here. */
function modelLines(c: CoachAIContext): string[] {
  const m = c.model;
  if (!m) return [];
  if (m.confidence === "low") {
    return [`Personal model: still learning (${m.observations} training ${m.observations === 1 ? "week" : "weeks"} so far).`];
  }
  return [
    `Personal model (${m.confidence} confidence, ${m.observations} weeks): maintenance ${r(m.maintenanceKcal)} ± ${r(m.maintenanceSD)} kcal/day.`,
    `Predicted on current plan: ${signed(m.predictedKgPerWeek)} kg/week vs goal ${signed(m.targetKgPerWeek)} kg/week.`,
  ];
}

export function describeAction(action: CoachAdjustment, decision: CoachDecision, context: CoachAIContext): string {
  switch (action.type) {
    case "maintain":
      return `Maintain current targets (${context.trainingCalories} / ${context.restCalories} kcal training/rest).`;
    case "increaseCalories":
      return `Increase calories by ${action.amount} kcal (suggested training day: ${decision.suggestedTrainingCalories ?? context.trainingCalories + action.amount} kcal).`;
    case "decreaseCalories":
      return `Decrease calories by ${action.amount} kcal (suggested training day: ${decision.suggestedTrainingCalories ?? context.trainingCalories - action.amount} kcal).`;
    case "increaseSteps":
      return `Increase steps by ${action.amount} (suggested target: ${decision.suggestedSteps ?? Math.min(CoachingConfig.maxStepTarget, context.stepTarget + action.amount)}).`;
    case "decreaseSteps":
      return `Decrease steps by ${action.amount} (suggested target: ${decision.suggestedSteps ?? Math.max(0, context.stepTarget - action.amount)}).`;
    case "suggestRefeed":
      return decision.refeed
        ? `Consider a refeed at ${decision.refeed.refeedTarget.calories} kcal (${decision.refeed.reason}).`
        : "Consider a controlled refeed day using the engine refeed targets.";
    case "requireMoreData":
      return "Keep logging morning weigh-ins; the engine needs more data before adjusting.";
    case "reviewAdherence":
      return "Focus on adherence to the current plan before changing calories.";
    case "reviewRecovery":
      return "Review recovery, sleep, and training stress before further calorie cuts.";
    case "recommendNutritionIncreaseReview":
      return "Review a measured nutrition increase using the engine’s suggested calories.";
    case "recommendNutritionDecreaseReview":
      return "Review a measured nutrition decrease using the engine’s suggested calories.";
  }
}

export function describeReason(code: CoachReasonCode): string {
  const map: Record<CoachReasonCode, string> = {
    rateOnTarget: "Weekly rate of change is on target.",
    rateTooFastLoss: "Weekly loss is faster than the preferred range.",
    rateTooFastGain: "Weekly gain is faster than the preferred range.",
    rateTooSlow: "Weekly change is slower than expected for the goal.",
    highAdherence: "Adherence has been high.",
    poorAdherence: "Adherence has been inconsistent.",
    insufficientWeighIns: "Not enough morning weigh-ins this week.",
    performanceStable: "Training performance is stable.",
    performanceDeclining: "Training performance is declining.",
    appearanceFlat: "Appearance feedback suggests a flatter look.",
    appearanceSoft: "Appearance feedback suggests a softer look.",
    appearanceImproving: "Appearance feedback suggests improvement.",
    extremeWeeklyChange: "Weekly average change was extreme.",
    stepCapReached: "Step target is already at the configured cap.",
    userFeelingHungry: "Hunger feedback is elevated.",
    recoveryConcern: "Recovery indicators warrant caution.",
    modelPrediction: "Your personal metabolism model, trained on your own logs, drove this recommendation.",
  };
  return map[code];
}

/** Re-anchor calorie/macro/step figures to the engine decision. */
function validatePreferringEngine(
  response: CoachAIStructuredResponse,
  decision: CoachDecision,
  context: CoachAIContext,
): CoachAIStructuredResponse {
  const training = decision.suggestedTrainingCalories ?? context.trainingCalories;
  const rest = decision.suggestedRestCalories ?? context.restCalories;
  const steps = decision.suggestedSteps ?? context.stepTarget;
  const m = engineMacros(decision, context);
  const anchor = `Engine numbers: training ${training} kcal, rest ${rest} kcal, steps ${steps}, P/C/F ${r(m.protein)}/${r(m.carbohydrates)}/${r(m.fat)} g.`;
  const reasoning = response.reasoning.includes(anchor) ? response.reasoning : [...response.reasoning, anchor];
  const summary = response.summary || decision.summary;
  return {
    summary,
    recommendation: response.recommendation.trim() || decision.summary,
    reasoning,
    userMessage: response.userMessage || summary,
  };
}
