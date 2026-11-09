import { useState } from "react";
import { AdaptiveConfig } from "../engines/adaptive";
import { describeReason } from "../engines/coachAI";
import {
  actions,
  adaptiveModel,
  adaptiveRecommendation,
  hasCoachAccess,
  nextAutoAdjustEligibleDate,
  useApp,
} from "../state/store";
import { Button, Card, Icon, Sheet, toast } from "../ui/kit";

const signed = (v: number, digits = 2) => `${v >= 0 ? "+" : "−"}${Math.abs(v).toFixed(digits)}`;

/** "Your Metabolism" — what the personal adaptive model has learned and what it recommends. */
export function ModelCard({ onUnlock }: { onUnlock: () => void }) {
  const s = useApp();
  const [details, setDetails] = useState(false);
  const model = adaptiveModel(s);
  const rec = adaptiveRecommendation(s);
  const access = hasCoachAccess(s);

  const badge = model ? { low: "Learning", medium: "Medium confidence", high: "High confidence" }[model.confidence] : "No data yet";
  const badgeClass = model?.confidence === "high" ? "ok" : model?.confidence === "medium" ? "training" : "";
  const nextEligible = nextAutoAdjustEligibleDate(s);
  const waiting = nextEligible && nextEligible.getTime() > Date.now();

  return (
    <Card>
      <div className="row-between">
        <h3 className="headline row" style={{ gap: 8 }}>
          <span className="accent">
            <Icon name="sparkle" />
          </span>
          Your Metabolism Model
        </h3>
        <span className={`badge ${badgeClass}`}>{badge}</span>
      </div>

      {!model ? (
        <p className="sub">Log your morning weight and food each day. Your coach trains a personal model of how your body responds to calories.</p>
      ) : (
        <>
          <div className="grid-2">
            <div className="stack-sm" style={{ gap: 2 }}>
              <span className="caption">Learned maintenance</span>
              <span className="num-md">{Math.round(model.maintenanceKcal).toLocaleString()} kcal</span>
              <span className="caption2">± {Math.round(model.maintenanceSD)} kcal · formula said {model.priorMaintenanceKcal.toLocaleString()}</span>
            </div>
            {rec && (
              <div className="stack-sm" style={{ gap: 2 }}>
                <span className="caption">Predicted on current plan</span>
                <span className="num-md">{signed(rec.predictedCurrent.meanKgPerWeek)} kg/wk</span>
                <span className="caption2">
                  ± {rec.predictedCurrent.sdKgPerWeek.toFixed(2)} · goal {signed(rec.targetKgPerWeek)}
                </span>
              </div>
            )}
          </div>

          {!access ? (
            <>
              <p className="sub">Your model is learning from your logs. Coach AI uses it to adjust your calories automatically.</p>
              <Button variant="secondary" onClick={onUnlock}>
                Unlock Personal Adjustments
              </Button>
            </>
          ) : rec ? (
            <>
              <p className="sub">{rec.summary}</p>
              {rec.shouldAdjust && (
                <span className="caption">
                  {s.preferences.adaptiveAutoAdjust
                    ? waiting
                      ? `Auto-adjust is on — next change allowed ${nextEligible!.toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" })} (max one change per week).`
                      : "Auto-adjust is on — this will apply automatically."
                    : "Auto-adjust is off — apply it yourself when ready."}
                </span>
              )}
              {rec.shouldAdjust && (!s.preferences.adaptiveAutoAdjust || waiting) && (
                <Button
                  onClick={() => {
                    if (actions.applyAdaptiveRecommendation(false)) toast("Plan updated from your model");
                  }}
                >
                  Apply {signed(rec.deltaKcal, 0)} kcal/day
                </Button>
              )}
            </>
          ) : null}

          <button className="link-btn" style={{ alignSelf: "flex-start" }} onClick={() => setDetails(true)}>
            How it works & what it learned
          </button>
        </>
      )}

      {details && model && (
        <Sheet title="Your Metabolism Model" onClose={() => setDetails(false)}>
          <div className="list">
            <Row label="Maintenance at your current habits" value={`${Math.round(model.maintenanceKcal)} ± ${Math.round(model.maintenanceSD)} kcal`} />
            <Row label="Base maintenance (8,000 steps)" value={`${Math.round(model.theta[0])} kcal`} />
            <Row label="Each extra 1,000 steps burns" value={`${Math.round(model.theta[1])} kcal`} />
            <Row label="Expenditure change per +1,000 kcal eaten" value={`${signed(model.theta[2], 0)} kcal`} />
            {model.trend && (
              <Row
                label="Trend weight · current rate"
                value={`${model.trend.levelKg.toFixed(1)} kg · ${signed(model.trend.slopeKgPerWeek)} kg/wk`}
              />
            )}
            <Row label="Training weeks used" value={String(model.observations)} />
            <Row label="Complete food-log days" value={String(model.loggedIntakeDays)} />
            <Row label="Weigh-ins" value={String(model.weighIns)} />
            {model.rmseKcal !== undefined && <Row label="Prediction error (RMSE)" value={`${Math.round(model.rmseKcal)} kcal/day`} />}
          </div>
          <p className="caption">
            Your coach runs a Kalman filter that smooths daily weigh-ins into a true trend. A Bayesian regression then
            learns your own energy expenditure: what you logged eating minus the energy stored or lost as weight. It
            starts from the standard formula and updates every time you log, giving more weight to recent weeks so it
            follows metabolic adaptation. Food-log days only count when they look complete (marked done, or at least
            half your target). Changes are capped at {AdaptiveConfig.maxAdjustmentKcal} kcal, made at most once a week,
            and never go below safety minimums.
          </p>
          {s.planAdjustments.some((a) => a.source === "adaptiveModel") && (
            <>
              <p className="section-title">Model adjustments</p>
              <div className="list">
                {s.planAdjustments
                  .filter((a) => a.source === "adaptiveModel")
                  .slice(0, 6)
                  .map((a) => (
                    <div key={a.id} className="list-row">
                      <span className="grow caption">{new Date(a.date).toLocaleDateString()}</span>
                      <span className="num">
                        {a.oldCalories} → {a.newCalories}
                      </span>
                    </div>
                  ))}
              </div>
            </>
          )}
          <p className="caption2">{describeReason("modelPrediction")}</p>
        </Sheet>
      )}
    </Card>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="list-row">
      <span className="grow caption">{label}</span>
      <span className="num" style={{ fontSize: 14, textAlign: "right" }}>
        {value}
      </span>
    </div>
  );
}
