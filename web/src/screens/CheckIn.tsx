import { useState } from "react";
import { today, weekStart } from "../core/dates";
import {
  ADHERENCE_BANDS,
  APPEARANCE_OPTIONS,
  AdherenceInfo,
  AppearanceInfo,
  type AdherenceBand,
  type AppearanceFeedback,
  type CoachDecision,
  DIGESTION_OPTIONS,
  type DigestionFeedback,
  DigestionLabel,
  PERFORMANCE_OPTIONS,
  PerformanceLabel,
  type ProgressPhotoSet,
  type TrainingPerformance,
  uuid,
} from "../core/models";
import { isApplicable } from "../engines/coaching";
import { actions, currentWeek, previousWeek, useApp, weeklyRate } from "../state/store";
import { Button, Card, Icon, SelectRow, Sheet, toast } from "../ui/kit";
import { fileToSmallDataURL } from "../ui/photo";

const STEPS = ["photos", "appearance", "adherence", "performance", "hunger", "energy", "digestion", "result"] as const;
type Step = (typeof STEPS)[number];
const TITLES: Record<Step, string> = {
  photos: "Progress Photos",
  appearance: "How do you feel you look?",
  adherence: "How closely did you follow your plan?",
  performance: "How was training performance?",
  hunger: "How was hunger?",
  energy: "How were energy levels?",
  digestion: "How was digestion?",
  result: "Coach Check-In",
};

type Pose = "front" | "side" | "back";

export function PhotoSlot({
  label,
  value,
  onChange,
}: {
  label: string;
  value?: string;
  onChange: (dataURL: string | undefined) => void;
}) {
  const [busy, setBusy] = useState(false);
  return (
    <div className="stack-sm">
      <label className="photo-slot" aria-label={`${label} photo`}>
        {value ? (
          <img src={value} alt={`${label} progress photo`} />
        ) : (
          <span className="stack-sm center muted" style={{ alignItems: "center" }}>
            <Icon name="camera" size={24} />
            <span className="caption">{busy ? "Processing…" : "Add"}</span>
          </span>
        )}
        <input
          type="file"
          accept="image/*"
          className="sr-only"
          onChange={async (e) => {
            const file = e.target.files?.[0];
            e.target.value = "";
            if (!file) return;
            setBusy(true);
            try {
              onChange(await fileToSmallDataURL(file));
            } catch {
              toast("Couldn't read that image");
            } finally {
              setBusy(false);
            }
          }}
        />
      </label>
      <div className="row-between">
        <span className="caption">{label}</span>
        {value && (
          <button className="link-btn" style={{ fontSize: 12, padding: 0 }} onClick={() => onChange(undefined)}>
            Remove
          </button>
        )}
      </div>
    </div>
  );
}

export function CheckIn({ onClose }: { onClose: () => void }) {
  const s = useApp();
  const [i, setI] = useState(0);
  const step = STEPS[i];
  const [photos, setPhotos] = useState<Partial<Record<Pose, string>>>({});
  const [appearance, setAppearance] = useState<AppearanceFeedback>("aboutTheSame");
  const [adherence, setAdherence] = useState<AdherenceBand>("seventyTo84");
  const [performance, setPerformance] = useState<TrainingPerformance>("same");
  const [hunger, setHunger] = useState(3);
  const [energy, setEnergy] = useState(3);
  const [digestion, setDigestion] = useState<DigestionFeedback>("okay");
  const [notes, setNotes] = useState("");
  const [decision, setDecision] = useState<CoachDecision>();

  function submit() {
    let photoSetID: string | undefined;
    if (photos.front || photos.side || photos.back) {
      const set: ProgressPhotoSet = {
        id: uuid(),
        weekStart: weekStart(today()),
        ...photos,
        createdAt: new Date().toISOString(),
      };
      actions.savePhotoSet(set);
      photoSetID = set.id;
    }
    const d = actions.submitWeeklyCheckIn({
      appearance,
      adherence,
      adherencePercent: AdherenceInfo[adherence].percent,
      performance,
      hunger,
      energy,
      digestion,
      notes,
      photoSetID,
    });
    setDecision(d);
    setI(STEPS.indexOf("result"));
    try {
      navigator.vibrate?.([20, 40, 20]);
    } catch {
      /* ignore */
    }
  }

  const scale = (value: number, set: (n: number) => void, low: string, high: string) => (
    <div className="stack">
      <div className="row" style={{ gap: 8 }}>
        {[1, 2, 3, 4, 5].map((n) => (
          <button
            key={n}
            className={`grow chip${value === n ? " on" : ""}`}
            style={{ height: 52, fontSize: 18, fontWeight: 700, borderRadius: "var(--r-md)" }}
            onClick={() => set(n)}
          >
            {n}
          </button>
        ))}
      </div>
      <div className="row-between caption">
        <span>{low}</span>
        <span>{high}</span>
      </div>
    </div>
  );

  const content = (() => {
    switch (step) {
      case "photos":
        return (
          <>
            <p className="sub">
              Take these fasted in the morning under similar lighting and conditions. Photos are optional and stay private on
              your device.
            </p>
            <div className="row" style={{ gap: 10, alignItems: "flex-start" }}>
              {(["front", "side", "back"] as const).map((pose) => (
                <div key={pose} className="grow">
                  <PhotoSlot
                    label={pose[0].toUpperCase() + pose.slice(1)}
                    value={photos[pose]}
                    onChange={(v) => setPhotos((p) => ({ ...p, [pose]: v }))}
                  />
                </div>
              ))}
            </div>
          </>
        );
      case "appearance":
        return APPEARANCE_OPTIONS.map((o) => (
          <SelectRow
            key={o}
            title={AppearanceInfo[o].title}
            subtitle={AppearanceInfo[o].subtitle}
            selected={appearance === o}
            onClick={() => setAppearance(o)}
          />
        ));
      case "adherence":
        return ADHERENCE_BANDS.map((b) => (
          <SelectRow key={b} title={AdherenceInfo[b].name} selected={adherence === b} onClick={() => setAdherence(b)} />
        ));
      case "performance":
        return PERFORMANCE_OPTIONS.map((o) => (
          <SelectRow key={o} title={PerformanceLabel[o]} selected={performance === o} onClick={() => setPerformance(o)} />
        ));
      case "hunger":
        return scale(hunger, setHunger, "Not hungry", "Very hungry");
      case "energy":
        return scale(energy, setEnergy, "Low energy", "High energy");
      case "digestion":
        return (
          <>
            {DIGESTION_OPTIONS.map((o) => (
              <SelectRow key={o} title={DigestionLabel[o]} selected={digestion === o} onClick={() => setDigestion(o)} />
            ))}
            <textarea className="input" placeholder="Optional notes" value={notes} onChange={(e) => setNotes(e.target.value)} />
          </>
        );
      case "result": {
        if (!decision) return null;
        const prev = previousWeek(s).averageKg;
        const curr = currentWeek(s).averageKg;
        const rate = weeklyRate(s);
        const training = decision.suggestedTrainingCalories ?? s.targets?.training.calories;
        const rest = decision.suggestedRestCalories ?? s.targets?.rest.calories;
        return (
          <Card>
            <h3 className="headline">Progress</h3>
            {prev !== undefined && curr !== undefined ? (
              <>
                <span className="callout">
                  Average: {prev.toFixed(1)} → {curr.toFixed(1)} kg
                </span>
                {rate && (
                  <span className="sub">
                    Change: {rate.absoluteChangeKg >= 0 ? "+" : ""}
                    {rate.absoluteChangeKg.toFixed(1)} kg
                  </span>
                )}
              </>
            ) : (
              <span className="sub">Not enough weekly averages yet.</span>
            )}
            <div className="divider" />
            <h3 className="headline">Assessment</h3>
            <p>{decision.summary}</p>
            {training !== undefined && rest !== undefined && (
              <span className="callout accent">
                Training: {training} kcal · Rest: {rest} kcal
              </span>
            )}
            <span className="sub">Steps: {(decision.suggestedSteps ?? s.profile.stepTarget).toLocaleString()} daily</span>
            {decision.refeed && (
              <div className="banner">
                <Icon name="sparkle" size={18} />
                <span>
                  Refeed Available — a higher-carbohydrate day may help support training performance and adherence.
                </span>
              </div>
            )}
          </Card>
        );
      }
    }
  })();

  const footer =
    step === "result" ? (
      <div className="stack-sm">
        {decision && isApplicable(decision.action) ? (
          <>
            <Button
              onClick={() => {
                actions.applyCoachDecision(decision);
                toast("Updated plan applied");
                onClose();
              }}
            >
              Apply Coach Recommendation
            </Button>
            <Button variant="secondary" onClick={onClose}>
              Keep Current Plan
            </Button>
          </>
        ) : (
          <Button onClick={onClose}>Done</Button>
        )}
        <button
          className="link-btn"
          onClick={() => {
            onClose();
            actions.selectTab("coach");
          }}
        >
          Ask Coach
        </button>
      </div>
    ) : step === "digestion" ? (
      <Button onClick={submit}>See Coach Analysis</Button>
    ) : (
      <Button onClick={() => setI(i + 1)}>{step === "photos" ? "Continue" : "Next"}</Button>
    );

  return (
    <Sheet
      title="Weekly Check-In"
      full
      onClose={onClose}
      right={
        i > 0 && step !== "result" ? (
          <button className="link-btn" onClick={() => setI(i - 1)}>
            Back
          </button>
        ) : undefined
      }
    >
      <div className="stack-sm">
        <div className="row-between" style={{ alignItems: "flex-start" }}>
          <h2 className="title2">{TITLES[step]}</h2>
          <span className="caption">
            {i + 1}/{STEPS.length}
          </span>
        </div>
        <div className="bar">
          <div style={{ width: `${(i / (STEPS.length - 1)) * 100}%`, background: "var(--primary)" }} />
        </div>
      </div>
      <div className="stack">{content}</div>
      {footer}
    </Sheet>
  );
}
