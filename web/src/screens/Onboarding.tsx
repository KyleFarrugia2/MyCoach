import { useState } from "react";
import { AppIdentity, CoachingConfig } from "../core/config";
import { type Weekday, addMonths, ageYears, today } from "../core/dates";
import {
  ACTIVITY_BANDS,
  ActivityBandInfo,
  BiologicalSexLabel,
  FOOD_ALLERGIES,
  FoodAllergyLabel,
  GoalPhaseInfo,
  TRAINING_TIMES,
  TrainingTimeLabel,
  type UserProfile,
  WEEKDAYS,
  WeekdayFull,
  WeightUnitShort,
  initialStepTarget,
} from "../core/models";
import { UnitConversion, parseDecimal } from "../engines/units";
import { actions, getState } from "../state/store";
import { Button, Card, Icon, NumberInput, Segmented, SelectRow, confirmDialog } from "../ui/kit";

const STEPS = [
  "welcome",
  "name",
  "dob",
  "sex",
  "height",
  "weight",
  "desiredWeight",
  "goal",
  "trainingDays",
  "activity",
  "cleanFoods",
  "allergies",
  "trainingTime",
  "generatePlan",
] as const;
type Step = (typeof STEPS)[number];

const TITLES: Record<Step, string> = {
  welcome: AppIdentity.displayName,
  name: "What should your coach call you?",
  dob: "When were you born?",
  sex: "Biological sex",
  height: "How tall are you?",
  weight: "Current weight",
  desiredWeight: "What weight are you working toward?",
  goal: "What is your goal?",
  trainingDays: "How often do you train?",
  activity: "Average daily steps",
  cleanFoods: "What foods do you want to work with?",
  allergies: "Do you have any food allergies?",
  trainingTime: "When do you usually train?",
  generatePlan: "Ready to build your plan",
};

const FOOD_SUGGESTIONS = [
  "Chicken Breast",
  "Lean Beef (5% fat)",
  "White Rice",
  "Potato",
  "Pasta",
  "Oats (rolled)",
  "Egg",
  "Egg Whites",
  "Greek Yogurt (0% fat)",
  "Banana",
  "Apple",
  "Mixed Berries",
  "Mixed Vegetables",
  "Bread (white)",
  "Peanut Butter",
  "Olive Oil",
];

const PRESETS: Record<number, Weekday[]> = {
  2: [1, 4],
  3: [1, 3, 5],
  4: [1, 2, 4, 5],
  5: [1, 2, 3, 5, 6],
  6: [1, 2, 3, 4, 5, 6],
};

export function Onboarding() {
  const [stepIndex, setStepIndex] = useState(0);
  const [draft, setDraft] = useState<UserProfile>(() => getState().profile);
  const [metricHeight, setMetricHeight] = useState(true);
  const [heightCm, setHeightCm] = useState(String(Math.round(draft.heightCm)));
  const [feet, setFeet] = useState(5);
  const [inches, setInches] = useState(9);
  const [weightText, setWeightText] = useState(UnitConversion.displayWeight(draft.currentWeightKg, draft.weightUnit).toFixed(1));
  const [desiredText, setDesiredText] = useState(UnitConversion.displayWeight(draft.desiredWeightKg, draft.weightUnit).toFixed(1));
  const [customFood, setCustomFood] = useState("");
  const [preset, setPreset] = useState<number | null>(draft.trainingDays.length);
  const [generateForMe, setGenerateForMe] = useState(false);

  const step = STEPS[stepIndex];
  const patch = (p: Partial<UserProfile>) => setDraft((d) => ({ ...d, ...p }));

  function synced(): UserProfile {
    const d = { ...draft };
    if (metricHeight) {
      const cm = parseDecimal(heightCm);
      if (cm !== undefined) d.heightCm = cm;
    } else {
      d.heightCm = UnitConversion.centimeters(feet, inches);
    }
    const w = parseDecimal(weightText);
    if (w !== undefined) d.currentWeightKg = UnitConversion.kilograms(w, d.weightUnit);
    const g = parseDecimal(desiredText);
    if (g !== undefined) d.desiredWeightKg = UnitConversion.kilograms(g, d.weightUnit);
    d.stepTarget = Math.min(initialStepTarget(d.activityBand), CoachingConfig.maxStepTarget);
    d.mealCount = CoachingConfig.requiredMealCount;
    return d;
  }

  const canContinue = (() => {
    switch (step) {
      case "name":
        return draft.displayName.trim().length > 0;
      case "dob":
        return !!draft.dateOfBirth;
      case "height":
        return metricHeight ? (parseDecimal(heightCm) ?? 0) > 50 : true;
      case "weight":
        return (parseDecimal(weightText) ?? 0) > 20;
      case "desiredWeight":
        return (parseDecimal(desiredText) ?? 0) > 20;
      case "trainingDays":
        return draft.trainingDays.length > 0;
      case "cleanFoods":
        return draft.preferredFoods.length > 0;
      case "allergies":
        return draft.allergies.length > 0;
      default:
        return true;
    }
  })();

  async function advance() {
    const d = synced();
    setDraft(d);
    if (step === "dob" && d.dateOfBirth && ageYears(d.dateOfBirth) < 18) {
      await confirmDialog({
        title: "My Coach is for adults",
        message: "This app is designed for adult gym users (18+). Please confirm an adult date of birth to continue.",
        cancel: "",
      });
      return;
    }
    if (stepIndex < STEPS.length - 1) {
      setStepIndex(stepIndex + 1);
      window.scrollTo(0, 0);
    }
  }

  function finish() {
    const d = synced();
    actions.updateProfile(d);
    actions.completeOnboarding();
  }

  function toggleFood(food: string) {
    patch({
      preferredFoods: draft.preferredFoods.includes(food)
        ? draft.preferredFoods.filter((f) => f !== food)
        : [...draft.preferredFoods, food],
    });
  }

  function toggleAllergy(a: (typeof FOOD_ALLERGIES)[number]) {
    if (a === "none") return patch({ allergies: ["none"] });
    const selected = draft.allergies.includes(a);
    let next = draft.allergies.filter((x) => x !== "none");
    next = selected ? next.filter((x) => x !== a) : [...next, a];
    patch({ allergies: next.length ? next : ["none"] });
  }

  const weightFields = (text: string, setText: (v: string) => void, label: string) => (
    <div className="stack">
      <Segmented
        options={[
          { value: "kilogram" as const, label: "kg" },
          { value: "pound" as const, label: "lb" },
        ]}
        value={draft.weightUnit}
        onChange={(unit) => {
          // Convert both typed values when switching units so numbers stay meaningful.
          const conv = (t: string) => {
            const v = parseDecimal(t);
            if (v === undefined) return t;
            return UnitConversion.displayWeight(UnitConversion.kilograms(v, draft.weightUnit), unit).toFixed(1);
          };
          setWeightText(conv(weightText));
          setDesiredText(conv(desiredText));
          patch({ weightUnit: unit });
        }}
      />
      <div className="input-unit">
        <NumberInput big value={text} onChange={setText} ariaLabel={label} />
        <span className="unit">{WeightUnitShort[draft.weightUnit]}</span>
      </div>
    </div>
  );

  const content = (() => {
    switch (step) {
      case "welcome":
        return (
          <div className="stack center" style={{ gap: 24, marginTop: "12vh" }}>
            <img className="logo" src="./icons/logo-256.png" alt={`${AppIdentity.displayName} logo`} width={112} height={112} />
            <div className="stack-sm">
              <h1 className="hero">{AppIdentity.displayName}</h1>
              <p className="title2">Your physique. Your plan. Your coach.</p>
              <p className="sub">Structured nutrition and coaching built around your progress.</p>
            </div>
          </div>
        );
      case "name":
        return (
          <div className="stack">
            <input
              className="input"
              style={{ fontSize: 20, fontWeight: 600 }}
              placeholder="Your name"
              autoComplete="given-name"
              value={draft.displayName}
              onChange={(e) => patch({ displayName: e.target.value })}
            />
            <p className="sub">Your coach will use this throughout the app.</p>
          </div>
        );
      case "dob":
        return (
          <div className="stack">
            <input
              className="input"
              type="date"
              max={addMonths(today(), -13 * 12)}
              value={draft.dateOfBirth ?? ""}
              onChange={(e) => patch({ dateOfBirth: e.target.value || undefined })}
              aria-label="Date of birth"
            />
            <p className="sub">Used only for energy estimates. My Coach is intended for adult gym users.</p>
          </div>
        );
      case "sex":
        return (
          <div className="stack">
            <p className="sub">This helps estimate energy needs. You can choose Prefer not to say.</p>
            {(["female", "male", "preferNotToSay"] as const).map((s) => (
              <SelectRow
                key={s}
                title={BiologicalSexLabel[s]}
                selected={draft.biologicalSex === s}
                onClick={() => patch({ biologicalSex: s })}
              />
            ))}
          </div>
        );
      case "height":
        return (
          <div className="stack">
            <Segmented
              options={[
                { value: true, label: "cm" },
                { value: false, label: "ft/in" },
              ]}
              value={metricHeight}
              onChange={setMetricHeight}
            />
            {metricHeight ? (
              <div className="input-unit">
                <NumberInput big value={heightCm} onChange={setHeightCm} ariaLabel="Height in centimetres" />
                <span className="unit">cm</span>
              </div>
            ) : (
              <div className="grid-2">
                <label className="field">
                  <span>Feet</span>
                  <select className="input" value={feet} onChange={(e) => setFeet(Number(e.target.value))}>
                    {[4, 5, 6, 7].map((f) => (
                      <option key={f}>{f}</option>
                    ))}
                  </select>
                </label>
                <label className="field">
                  <span>Inches</span>
                  <select className="input" value={inches} onChange={(e) => setInches(Number(e.target.value))}>
                    {Array.from({ length: 12 }, (_, i) => (
                      <option key={i}>{i}</option>
                    ))}
                  </select>
                </label>
              </div>
            )}
          </div>
        );
      case "weight":
        return weightFields(weightText, setWeightText, "Current weight");
      case "desiredWeight":
        return weightFields(desiredText, setDesiredText, "Desired weight");
      case "goal":
        return (
          <div className="stack">
            {(["cut", "gain"] as const).map((g) => (
              <SelectRow
                key={g}
                title={GoalPhaseInfo[g].name}
                subtitle={GoalPhaseInfo[g].subtitle}
                selected={draft.goalPhase === g}
                onClick={() => patch({ goalPhase: g })}
              />
            ))}
          </div>
        );
      case "trainingDays":
        return (
          <div className="stack">
            <p className="sub">Select how many days, then mark your training days.</p>
            <div className="wrap">
              {[2, 3, 4, 5, 6].map((n) => (
                <button
                  key={n}
                  className={`chip${preset === n ? " on" : ""}`}
                  onClick={() => {
                    setPreset(n);
                    patch({ trainingDays: PRESETS[n] });
                  }}
                >
                  {n} days
                </button>
              ))}
              <button className={`chip${preset === null ? " on" : ""}`} onClick={() => setPreset(null)}>
                Custom
              </button>
            </div>
            {WEEKDAYS.map((day) => {
              const on = draft.trainingDays.includes(day);
              return (
                <button
                  key={day}
                  className={`select-row${on ? " on" : ""}`}
                  onClick={() => {
                    setPreset(null);
                    patch({
                      trainingDays: on
                        ? draft.trainingDays.filter((d) => d !== day)
                        : [...draft.trainingDays, day].sort(),
                    });
                  }}
                >
                  <span className="grow">{WeekdayFull[day]}</span>
                  <span className={`caption${on ? " accent" : ""}`}>{on ? "Training" : "Rest"}</span>
                  <span className="check">{on && <Icon name="check" size={14} />}</span>
                </button>
              );
            })}
          </div>
        );
      case "activity":
        return (
          <div className="stack">
            <p className="sub">About how many steps do you take on an average day?</p>
            {ACTIVITY_BANDS.map((b) => (
              <SelectRow
                key={b}
                title={ActivityBandInfo[b].name}
                selected={draft.activityBand === b}
                onClick={() => patch({ activityBand: b, stepTarget: initialStepTarget(b) })}
              />
            ))}
          </div>
        );
      case "cleanFoods":
        return (
          <div className="stack">
            <p className="sub">Tell your coach what foods you actually enjoy eating.</p>
            <div className="wrap">
              {FOOD_SUGGESTIONS.map((f) => (
                <button key={f} className={`chip${draft.preferredFoods.includes(f) ? " on" : ""}`} onClick={() => toggleFood(f)}>
                  {f}
                </button>
              ))}
              {draft.preferredFoods
                .filter((f) => !FOOD_SUGGESTIONS.includes(f))
                .map((f) => (
                  <button key={f} className="chip on" onClick={() => toggleFood(f)}>
                    {f}
                  </button>
                ))}
            </div>
            <form
              className="row"
              onSubmit={(e) => {
                e.preventDefault();
                const t = customFood.trim();
                if (t && !draft.preferredFoods.includes(t)) patch({ preferredFoods: [...draft.preferredFoods, t] });
                setCustomFood("");
              }}
            >
              <input className="input grow" placeholder="Add food" value={customFood} onChange={(e) => setCustomFood(e.target.value)} />
              <button type="submit" className="btn btn-secondary btn-sm">
                Add Food
              </button>
            </form>
            {draft.preferredFoods.length > 0 && (
              <p className="caption">Selected: {draft.preferredFoods.join(", ")}</p>
            )}
            <Button
              variant="secondary"
              onClick={() => {
                setGenerateForMe(true);
                patch({ preferredFoods: FOOD_SUGGESTIONS.slice(0, 10) });
              }}
            >
              Generate My Foods For Me
            </Button>
            {generateForMe && (
              <input
                className="input"
                placeholder="Foods you dislike (comma separated)"
                defaultValue={draft.dislikedFoods.join(", ")}
                onChange={(e) =>
                  patch({
                    dislikedFoods: e.target.value
                      .split(",")
                      .map((s) => s.trim())
                      .filter(Boolean),
                  })
                }
              />
            )}
          </div>
        );
      case "allergies":
        return (
          <div className="stack">
            {FOOD_ALLERGIES.map((a) => (
              <SelectRow key={a} title={FoodAllergyLabel[a]} selected={draft.allergies.includes(a)} onClick={() => toggleAllergy(a)} />
            ))}
            {draft.allergies.includes("other") && (
              <input
                className="input"
                placeholder="Describe other allergies"
                value={draft.customAllergyNotes}
                onChange={(e) => patch({ customAllergyNotes: e.target.value })}
              />
            )}
          </div>
        );
      case "trainingTime":
        return (
          <div className="stack">
            {TRAINING_TIMES.map((t) => (
              <SelectRow key={t} title={TrainingTimeLabel[t]} selected={draft.trainingTime === t} onClick={() => patch({ trainingTime: t })} />
            ))}
          </div>
        );
      case "generatePlan": {
        const rows: [string, string][] = [
          ["Name", draft.displayName],
          ["Goal", GoalPhaseInfo[draft.goalPhase].name],
          ["Training", `${draft.trainingDays.length} days / week`],
          ["Meals", `${CoachingConfig.requiredMealCount} / day`],
          ["Steps target", draft.stepTarget.toLocaleString()],
          ["Foods", `${draft.preferredFoods.length} selected`],
        ];
        return (
          <div className="stack">
            <p className="sub">
              We'll estimate starting calories and macros from your profile. Targets adapt after consistent weigh-ins — the
              first number is never treated as perfect.
            </p>
            <Card>
              {rows.map(([k, v]) => (
                <div key={k} className="row-between callout">
                  <span className="muted">{k}</span>
                  <span style={{ fontWeight: 600 }}>{v}</span>
                </div>
              ))}
            </Card>
          </div>
        );
      }
    }
  })();

  const progress = stepIndex / (STEPS.length - 1);

  return (
    <div className="onboarding">
      {step !== "welcome" && (
        <div className="stack-sm">
          <button className="link-btn row" style={{ alignSelf: "flex-start" }} onClick={() => setStepIndex(stepIndex - 1)}>
            <Icon name="chevronLeft" size={18} /> Back
          </button>
          <div className="row-between" style={{ alignItems: "flex-start" }}>
            <h1 className="title">{TITLES[step]}</h1>
            <span className="caption" style={{ flexShrink: 0 }}>
              {stepIndex}/{STEPS.length - 1}
            </span>
          </div>
          <div className="bar">
            <div style={{ width: `${progress * 100}%`, background: "var(--primary)" }} />
          </div>
        </div>
      )}
      <div className="onboarding-body">{content}</div>
      <div className="stack-sm">
        {step === "welcome" ? (
          <>
            <Button onClick={advance}>Get Started</Button>
            <Button variant="secondary" onClick={advance}>
              I Already Have an Account
            </Button>
          </>
        ) : step === "generatePlan" ? (
          <Button onClick={finish}>Generate My Plan</Button>
        ) : (
          <Button onClick={advance} disabled={!canContinue}>
            Continue
          </Button>
        )}
      </div>
    </div>
  );
}
