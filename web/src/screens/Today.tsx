import { useState } from "react";
import { AppIdentity, CoachingConfig } from "../core/config";
import { formatLong, today } from "../core/dates";
import { WeightUnitShort, mealSlots } from "../core/models";
import { UnitConversion, parseDecimal } from "../engines/units";
import {
  actions,
  diaryFor,
  displayWeight,
  greeting,
  hasCoachAccess,
  isTrainingDay,
  stepsOn,
  targetFor,
  useApp,
  weightEntryOn,
} from "../state/store";
import { Button, Card, DayTypeBadge, EmptyState, Icon, MacroMeta, NumberInput, Sheet, toast } from "../ui/kit";
import { Settings } from "./Settings";

export function Today() {
  const s = useApp();
  const day = today();
  const target = targetFor(s, day);
  const weightEntry = weightEntryOn(s, day);
  const steps = stepsOn(s, day)?.steps ?? 0;
  const stepTarget = target?.stepTarget ?? s.profile.stepTarget;
  const [weightText, setWeightText] = useState(() =>
    UnitConversion.displayWeight(weightEntry?.weightKg ?? s.profile.currentWeightKg, s.profile.weightUnit).toFixed(1),
  );
  const [editingWeight, setEditingWeight] = useState(false);
  const [stepsOpen, setStepsOpen] = useState(false);
  const [stepsText, setStepsText] = useState("");
  const [settingsOpen, setSettingsOpen] = useState(false);

  const slots = mealSlots(target?.isTrainingDay ?? isTrainingDay(s, day));
  const logged = new Set(diaryFor(s, day).entries.map((e) => e.mealSlot));
  const complete = slots.filter((slot) => logged.has(slot) || (slot === "preWorkout" && logged.has("intraWorkout"))).length;
  const planMeals = s.mealPlanDays[day]?.meals.length ?? slots.length;

  const showInput = !weightEntry || editingWeight;
  const parsedWeight = parseDecimal(weightText);

  function logWeight() {
    if (parsedWeight === undefined || parsedWeight <= 0) return;
    actions.logMorningWeight(parsedWeight, s.profile.weightUnit);
    setEditingWeight(false);
    toast("Morning weight logged");
  }

  return (
    <div className="screen">
      <div className="screen-header">
        <h1 className="screen-title">{AppIdentity.displayName}</h1>
        <button className="icon-btn" aria-label="Settings" onClick={() => setSettingsOpen(true)}>
          <Icon name="gear" />
        </button>
      </div>

      <div className="stack-sm">
        <h2 className="title">{greeting(s)}</h2>
        <span className="sub">{formatLong(day)}</span>
      </div>

      {/* Morning weight */}
      <Card>
        <div className="row-between">
          <h3 className="headline">Morning Weight</h3>
          {weightEntry && (
            <span className="row caption success">
              <Icon name="check" size={14} /> Logged
            </span>
          )}
        </div>
        {showInput ? (
          <div className="input-unit">
            <NumberInput big value={weightText} onChange={setWeightText} placeholder="0.0" ariaLabel="Morning weight" />
            <span className="unit">{WeightUnitShort[s.profile.weightUnit]}</span>
          </div>
        ) : (
          <span className="num-lg accent">{displayWeight(s, weightEntry!.weightKg)}</span>
        )}
        <p className="caption">For the most consistent readings, weigh yourself under similar morning conditions.</p>
        {showInput ? (
          <Button onClick={logWeight} disabled={parsedWeight === undefined || parsedWeight <= 0}>
            {weightEntry ? "Save Weight" : "Log Weight"}
          </Button>
        ) : (
          <Button
            onClick={() => {
              setWeightText(UnitConversion.displayWeight(weightEntry!.weightKg, s.profile.weightUnit).toFixed(1));
              setEditingWeight(true);
            }}
          >
            Update Weight
          </Button>
        )}
      </Card>

      {/* Plan */}
      {target ? (
        <Card>
          <div className="row-between">
            <h3 className="headline">Today's Plan</h3>
            <div className="row" style={{ gap: 6 }}>
              {target.source === "adaptiveModel" && <span className="badge ok">Personalised</span>}
              <DayTypeBadge training={target.isTrainingDay} />
            </div>
          </div>
          <div className="row" style={{ alignItems: "baseline", gap: 4 }}>
            <span className="num" style={{ fontSize: 40, color: "var(--primary)" }}>
              {target.calories.toLocaleString()}
            </span>
            <span className="title2 muted">kcal</span>
          </div>
          <div className="row" style={{ gap: 8 }}>
            {(["protein", "carbohydrates", "fat"] as const).map((k) => (
              <div
                key={k}
                className="grow center stack-sm"
                style={{
                  gap: 2,
                  padding: "8px 4px",
                  borderRadius: "var(--r-sm)",
                  background: `color-mix(in srgb, ${MacroMeta[k].color} 12%, transparent)`,
                }}
              >
                <span className="caption">{MacroMeta[k].label}</span>
                <span className="num" style={{ fontSize: 15 }}>{Math.round(target.macros[k])} g</span>
              </div>
            ))}
          </div>
        </Card>
      ) : (
        <Card>
          <EmptyState
            icon="fork"
            title="No plan yet"
            message="Your coach hasn't built today's nutrition targets."
            actionTitle="Generate Meal Plan"
            onAction={() => {
              actions.rebuildTargetsFromProfile();
              actions.generateMealPlan(day);
            }}
          />
        </Card>
      )}

      {/* Steps */}
      <Card>
        <div className="row-between">
          <h3 className="headline">Steps</h3>
          <button
            className="link-btn"
            onClick={() => {
              setStepsText(steps ? String(steps) : "");
              setStepsOpen(true);
            }}
          >
            Edit
          </button>
        </div>
        <span className="num-md">
          {steps.toLocaleString()} / {stepTarget.toLocaleString()}
        </span>
        <div className="bar">
          <div style={{ width: `${Math.min(steps / Math.max(stepTarget, 1), 1) * 100}%`, background: "var(--primary)" }} />
        </div>
      </Card>

      {/* Meals */}
      <Card>
        <div className="row-between">
          <div className="stack-sm" style={{ gap: 2 }}>
            <h3 className="headline">Meals</h3>
            <span className="sub">
              {complete} / {Math.max(planMeals, CoachingConfig.requiredMealCount)} logged
            </span>
          </div>
          <button className="btn btn-secondary btn-sm" onClick={() => actions.selectTab("log")}>
            Open Log
          </button>
        </div>
      </Card>

      {/* Coach */}
      <Card>
        <h3 className="headline">Coach</h3>
        <p className="sub">{s.coachStatusMessage}</p>
        <button className="link-btn" style={{ alignSelf: "flex-start" }} onClick={() => actions.selectTab("coach")}>
          {hasCoachAccess(s) ? "View Coach Analysis" : "Unlock Coach AI"}
        </button>
      </Card>

      {stepsOpen && (
        <Sheet title="Log Steps" onClose={() => setStepsOpen(false)}>
          <NumberInput integer big autoFocus value={stepsText} onChange={setStepsText} placeholder="0" ariaLabel="Steps today" />
          <p className="caption">Your current step target is {stepTarget.toLocaleString()} steps.</p>
          <Button
            disabled={stepsText === "" || !Number.isFinite(Number(stepsText))}
            onClick={() => {
              actions.logSteps(Math.round(Number(stepsText)));
              setStepsOpen(false);
            }}
          >
            Save
          </Button>
        </Sheet>
      )}

      {settingsOpen && (
        <Sheet title="Settings" full onClose={() => setSettingsOpen(false)}>
          <Settings />
        </Sheet>
      )}
    </div>
  );
}
