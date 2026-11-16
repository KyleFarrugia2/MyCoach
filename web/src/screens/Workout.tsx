import { useEffect, useRef, useState } from "react";
import { formatClock, formatMedium } from "../core/dates";
import { parseDecimal } from "../engines/units";
import {
  type ExerciseLog,
  TemplateFocus,
  TemplateName,
  TrainingProgramInfo,
  TRAINING_PROGRAMS,
  TRAINING_STYLES,
  TrainingStyleInfo,
  type TrainingProgramID,
  type WorkoutTemplateID,
  setSummary,
  trainingProgramOf,
  trainingStyleOf,
} from "../engines/workout";
import {
  GYM_EQUIPMENT,
  GymEquipmentInfo,
  MuscleGroupName,
  TRAINING_GOALS,
  TRAINING_VOLUMES,
  TYPICAL_GYM,
  TrainingGoalInfo,
  TrainingVolumeInfo,
  catalogEntry,
  generateWorkoutPlan as buildGeneratedPlan,
  planSummary,
  type GeneratedWorkoutPlan,
  type GymEquipment,
  type TrainingGoal,
  type TrainingVolume,
} from "../engines/exerciseCatalog";
import {
  actions,
  getState,
  lastCompletedSession,
  nextWorkoutTemplate,
  previousPerformance,
  replacementOptions,
  resolvedEquipment,
  resolvedGoal,
  resolvedTemplate,
  resolvedVolume,
  useApp,
} from "../state/store";
import { workoutStreak } from "../engines/workoutReview";
import { type WorkoutCompletion, WorkoutComplete } from "./WorkoutComplete";
import { Button, Card, Icon, type IconName, NumberInput, SelectRow, Sheet, Stepper, confirmDialog, toast, useTick } from "../ui/kit";
import { Brief, Eyebrow, Hex, Section } from "../ui/brief";

const TEMPLATE_ICON: Record<WorkoutTemplateID, { icon: IconName; tone: "primary" | "success" | "warning" | "fat" }> = {
  pushA: { icon: "bolt", tone: "primary" },
  pullA: { icon: "swap", tone: "primary" },
  legsA: { icon: "steps", tone: "warning" },
  upper: { icon: "dumbbell", tone: "fat" },
  legsB: { icon: "steps", tone: "success" },
  fwPush: { icon: "bolt", tone: "primary" },
  fwPull: { icon: "swap", tone: "primary" },
  fwLegs: { icon: "steps", tone: "warning" },
  ulUpperA: { icon: "dumbbell", tone: "primary" },
  ulLowerA: { icon: "steps", tone: "warning" },
  ulUpperB: { icon: "dumbbell", tone: "fat" },
  ulLowerB: { icon: "steps", tone: "success" },
  fbA: { icon: "dumbbell", tone: "primary" },
  fbB: { icon: "bolt", tone: "success" },
  fbC: { icon: "steps", tone: "warning" },
  bwFullA: { icon: "heart", tone: "primary" },
  bwFullB: { icon: "swap", tone: "success" },
  bwFullC: { icon: "bolt", tone: "warning" },
};

function stagnationMessage(names: string[]) {
  return `No progress for 3 ${names.length === 1 ? "workout" : "workouts"} in a row on: ${names.join(
    ", ",
  )}. Keep form quality and consider a small load increase next time.`;
}

export function Workout() {
  const s = useApp();
  const [preview, setPreview] = useState<WorkoutTemplateID | null>(null);
  const [activeOpen, setActiveOpen] = useState(!!s.activeWorkout);
  const [completion, setCompletion] = useState<WorkoutCompletion | null>(null);
  const [programOpen, setProgramOpen] = useState(false);
  const [generatorOpen, setGeneratorOpen] = useState(false);
  const program = trainingProgramOf(s.preferences);
  const style = trainingStyleOf(s.preferences);
  const programInfo = TrainingProgramInfo[program];
  const generated = s.generatedWorkoutPlan;

  useEffect(() => {
    if (s.pendingStagnationAlerts.length === 0) return;
    confirmDialog({ title: "No Progress", message: stagnationMessage(s.pendingStagnationAlerts), confirm: "Okay", cancel: "" }).then(
      () => actions.acknowledgeStagnationAlerts(),
    );
  }, [s.pendingStagnationAlerts]);

  return (
    <div className="screen">
      <div className="screen-header">
        <h1 className="screen-title">Workout</h1>
      </div>

      {s.activeWorkout && (
        <button className="card card-link" onClick={() => setActiveOpen(true)} style={{ border: "2px solid var(--primary)" }}>
          <div className="row-between">
            <div className="stack-sm" style={{ gap: 2 }}>
              <span className="caption accent">Workout in progress</span>
              <span className="headline">{s.activeWorkout.templateName}</span>
            </div>
            <span className="btn btn-primary btn-sm">Resume</span>
          </div>
        </button>
      )}

      <Brief className="is-training" label="Your program">
        <div className="row" style={{ alignItems: "flex-start", gap: 12 }}>
          <Hex icon="dumbbell" tone="primary" solid size={44} />
          <div className="grow stack-sm" style={{ gap: 4 }}>
            <Eyebrow>{generated ? "Generated plan" : "Your program"}</Eyebrow>
            <h2 className="brief-title">{generated ? TrainingGoalInfo[generated.goal].name : programInfo.name}</h2>
            <p className="brief-note">
              {generated
                ? planSummary(generated)
                : `${TrainingStyleInfo[style].name} · ${programInfo.templateIDs.length} sessions`}
            </p>
          </div>
        </div>
        <Button onClick={() => setGeneratorOpen(true)}>Generate a new plan</Button>
        <Button variant="secondary" onClick={() => setProgramOpen(true)}>
          Change program or style
        </Button>
      </Brief>

      <Section label="Start a workout">
        <div className="stack-sm">
          {programInfo.templateIDs.map((id) => {
            const t = resolvedTemplate(s, id);
            const last = lastCompletedSession(s, id);
            const chrome = TEMPLATE_ICON[id];
            const upNext = nextWorkoutTemplate(s) === id;
            const sets = t.exercises.reduce((n, e) => n + e.defaultSets, 0);
            return (
              <button key={id} className={`workout-launch${upNext ? " up-next" : ""}`} onClick={() => setPreview(id)}>
                <Hex icon={chrome.icon} tone={chrome.tone} solid size={48} />
                <div className="grow stack-sm" style={{ gap: 4, minWidth: 0 }}>
                  <div className="row" style={{ gap: 6 }}>
                    <span className="headline">{t.name}</span>
                    {upNext && <span className="workout-next">Up next</span>}
                  </div>
                  <span className="caption">{TemplateFocus[id]}</span>
                  <span className="caption2">
                    {t.exercises.length} moves · {sets} sets
                    {last ? ` · Last ${formatMedium(last.localDate)}` : ""}
                  </span>
                </div>
                <Icon name="chevronRight" className="muted" />
              </button>
            );
          })}
        </div>
      </Section>

      {programOpen && <TrainingSetup onClose={() => setProgramOpen(false)} />}
      {generatorOpen && <PlanGenerator onClose={() => setGeneratorOpen(false)} />}
      {preview && (
        <TemplateDetail
          id={preview}
          onClose={() => setPreview(null)}
          onStart={async () => {
            if (
              s.activeWorkout &&
              !(await confirmDialog({
                title: "Replace current workout?",
                message: `${s.activeWorkout.templateName} is still in progress and will be discarded.`,
                confirm: "Start New",
                destructive: true,
              }))
            ) {
              return;
            }
            actions.startWorkout(preview);
            setPreview(null);
            setActiveOpen(true);
          }}
        />
      )}
      {activeOpen && s.activeWorkout && (
        <ActiveWorkout
          onClose={() => setActiveOpen(false)}
          onFinished={(c) => {
            setActiveOpen(false);
            setCompletion(c);
          }}
        />
      )}
      {completion && <WorkoutComplete completion={completion} onDone={() => setCompletion(null)} />}
    </div>
  );
}

function TemplateDetail({ id, onClose, onStart }: { id: WorkoutTemplateID; onClose: () => void; onStart: () => void }) {
  const s = useApp();
  const t = resolvedTemplate(s, id);
  const last = lastCompletedSession(s, id);
  const chrome = TEMPLATE_ICON[id];
  const sets = t.exercises.reduce((n, e) => n + e.defaultSets, 0);
  const [swapId, setSwapId] = useState<string | null>(null);
  return (
    <Sheet title={t.name} full onClose={onClose}>
      <Brief className="is-training" label={t.name}>
        <div className="row" style={{ alignItems: "flex-start", gap: 12 }}>
          <Hex icon={chrome.icon} tone={chrome.tone} solid size={54} />
          <div className="grow stack-sm" style={{ gap: 4 }}>
            <Eyebrow>Ready to train</Eyebrow>
            <h2 className="brief-title">{t.name}</h2>
            <p className="brief-note">{TemplateFocus[id]}</p>
          </div>
        </div>
        <div className="brief-tags" style={{ justifyContent: "flex-start" }}>
          <span className="brief-tag">{t.exercises.length} exercises</span>
          <span className="brief-tag">{sets} sets</span>
          {last && <span className="brief-tag">{formatMedium(last.localDate)}</span>}
        </div>
        <p className="brief-note">A workout timer starts with you. Logging a set starts a 3-minute rest.</p>
      </Brief>
      <Section label="Exercises" aside={<span className="caption">{t.exercises.length}</span>}>
        <div className="stack-sm">
          {t.exercises.map((e, i) => {
            const prev = last?.exercises.find((x) => x.id === e.id);
            return (
              <div key={e.id} className="workout-ex">
                <Hex tone={chrome.tone}>{i + 1}</Hex>
                <div className="grow stack-sm" style={{ gap: 3, minWidth: 0 }}>
                  <span className="headline">{e.name}</span>
                  <span className="caption">
                    {prev && prev.sets.length
                      ? `Last: ${prev.sets.map(setSummary).join(" · ")}`
                      : e.isBodyweightMaxReps
                        ? "Bodyweight · max reps"
                        : "No previous log"}
                  </span>
                  <button className="link-btn" onClick={() => setSwapId(e.id)}>
                    I don’t have this
                  </button>
                </div>
                <Stepper
                  label={`${e.name} sets`}
                  value={e.defaultSets}
                  min={1}
                  max={12}
                  onChange={(v) => actions.updatePlannedSets(id, e.id, v)}
                />
              </div>
            );
          })}
        </div>
      </Section>
      <Button onClick={onStart}>Start {t.name}</Button>
      {swapId && <ReplacementSheet templateID={id} exerciseID={swapId} onClose={() => setSwapId(null)} />}
    </Sheet>
  );
}

export function TrainingSetup({ onClose }: { onClose: () => void }) {
  const s = useApp();
  const current = trainingProgramOf(s.preferences);
  const style = trainingStyleOf(s.preferences);
  const days = s.profile.trainingDays.length;

  async function chooseProgram(id: TrainingProgramID) {
    if (id === current) return;
    const rotation = TrainingProgramInfo[id].templateIDs;
    if (s.activeWorkout && !rotation.includes(s.activeWorkout.templateID)) {
      const ok = await confirmDialog({
        title: "Switch program?",
        message: "A workout is in progress. Switching programs discards that session.",
        confirm: "Switch Program",
        destructive: true,
      });
      if (!ok) return;
    }
    actions.setTrainingProgram(id);
    toast(`${TrainingProgramInfo[id].name} is now your program`);
  }

  return (
    <Sheet title="Your training" full onClose={onClose}>
      <Section label="Training style">
        <div className="stack-sm">
          {TRAINING_STYLES.map((id) => {
            const on = style === id;
            const info = TrainingStyleInfo[id];
            return (
              <button key={id} className={`workout-launch${on ? " up-next" : ""}`} onClick={() => actions.setTrainingStyle(id)}>
                <div className="grow stack-sm" style={{ gap: 4, textAlign: "left" }}>
                  <span className="headline">{info.name}</span>
                  <span className="caption">{info.subtitle}</span>
                </div>
                {on && <Icon name="check" />}
              </button>
            );
          })}
        </div>
      </Section>
      <p className="caption">Want something built around your gym? Generate a custom plan from the Workout tab.</p>
      <Section label="Workout program">
        <p className="caption">Unhappy with the split? Switch anytime. Your old sessions stay in Progress.</p>
        <div className="stack-sm">
          {TRAINING_PROGRAMS.map((id) => {
            const on = current === id;
            const info = TrainingProgramInfo[id];
            const fit = info.recommendedDays === days;
            return (
              <button key={id} className={`workout-launch${on ? " up-next" : ""}`} onClick={() => chooseProgram(id)}>
                <div className="grow stack-sm" style={{ gap: 4, textAlign: "left" }}>
                  <span className="headline">{info.name}</span>
                  <span className="caption">{info.subtitle}</span>
                  <span className="caption2">
                    {info.templateIDs.length} sessions · {info.equipment}
                    {fit ? ` · Matches your ${days}× week` : ""}
                  </span>
                </div>
                {on && <Icon name="check" />}
              </button>
            );
          })}
        </div>
      </Section>
    </Sheet>
  );
}

export function PlanGenerator({ onClose }: { onClose: () => void }) {
  const s = useApp();
  const [step, setStep] = useState(0);
  const [volume, setVolume] = useState<TrainingVolume>(resolvedVolume(s));
  const [goal, setGoal] = useState<TrainingGoal>(resolvedGoal(s));
  const [equipment, setEquipment] = useState<GymEquipment[]>(resolvedEquipment(s));
  const [preview, setPreview] = useState<GeneratedWorkoutPlan | null>(null);

  function toggleEquipment(id: GymEquipment) {
    setEquipment((current) => {
      if (current.includes(id)) return current.length === 1 ? current : current.filter((x) => x !== id);
      return GYM_EQUIPMENT.filter((item) => item === id || current.includes(item));
    });
  }

  function build(regenerate: boolean) {
    const blocked = s.generatedWorkoutPlan?.blockedExerciseIDs ?? [];
    const seed = regenerate ? (preview?.seed ?? s.generatedWorkoutPlan?.seed ?? 0) + 1 : 1;
    setPreview(
      buildGeneratedPlan({
        seed: Math.max(1, seed),
        volume,
        goal,
        equipment,
        daysPerWeek: s.profile.trainingDays.length,
        blockedIDs: blocked,
      }),
    );
  }

  const title = step === 0 ? "Volume" : step === 1 ? "Your goal" : step === 2 ? "Equipment" : "Your plan";

  return (
    <Sheet title={title} full onClose={onClose}>
      <div className="bar" style={{ marginBottom: 16 }}>
        <div style={{ width: `${((step + 1) / 4) * 100}%`, background: "var(--primary)" }} />
      </div>
      {step === 0 && (
        <div className="stack">
          <p className="sub">Do you want high volume or low volume?</p>
          {TRAINING_VOLUMES.map((id) => (
            <SelectRow
              key={id}
              title={TrainingVolumeInfo[id].name}
              subtitle={TrainingVolumeInfo[id].subtitle}
              selected={volume === id}
              onClick={() => setVolume(id)}
            />
          ))}
        </div>
      )}
      {step === 1 && (
        <div className="stack">
          <p className="sub">What are you training for?</p>
          {TRAINING_GOALS.map((id) => (
            <SelectRow
              key={id}
              title={TrainingGoalInfo[id].name}
              subtitle={TrainingGoalInfo[id].subtitle}
              selected={goal === id}
              onClick={() => setGoal(id)}
            />
          ))}
        </div>
      )}
      {step === 2 && (
        <div className="stack">
          <p className="sub">What equipment do you have? Pick everything you can use.</p>
          <div className="wrap">
            {[
              ["Full gym", TYPICAL_GYM],
              ["Free weights", ["barbell", "dumbbells"]],
              ["Machines", ["machines", "cables"]],
              ["Home", ["bodyweight", "dumbbells"]],
            ].map(([label, set]) => (
              <button
                key={String(label)}
                className={`chip${equipment.join() === (set as GymEquipment[]).join() ? " on" : ""}`}
                onClick={() => setEquipment(set as GymEquipment[])}
              >
                {label as string}
              </button>
            ))}
          </div>
          {GYM_EQUIPMENT.map((id) => (
            <SelectRow
              key={id}
              title={GymEquipmentInfo[id].name}
              subtitle={GymEquipmentInfo[id].subtitle}
              selected={equipment.includes(id)}
              onClick={() => toggleEquipment(id)}
            />
          ))}
        </div>
      )}
      {step === 3 && preview && (
        <div className="stack">
          <Brief className="is-training" label="Generated plan">
            <Eyebrow>Generated plan</Eyebrow>
            <h2 className="brief-title">{TrainingGoalInfo[preview.goal].name}</h2>
            <p className="brief-note">{planSummary(preview)}</p>
            <p className="brief-note">Not happy? Regenerate and we’ll shuffle different exercises that still match your answers.</p>
          </Brief>
          {preview.days.map((day) => (
            <Section key={day.templateID} label={TemplateName[day.templateID]}>
              <div className="stack-sm">
                {day.exercises.map((exercise) => (
                  <div key={exercise.catalogID} className="workout-ex">
                    <div className="grow stack-sm" style={{ gap: 2 }}>
                      <span className="headline">{exercise.name}</span>
                      <span className="caption">
                        {MuscleGroupName[exercise.muscle]} · {GymEquipmentInfo[exercise.equipment].name} · {exercise.defaultSets} sets
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </Section>
          ))}
        </div>
      )}
      <div className="stack-sm" style={{ marginTop: 16 }}>
        {step < 3 ? (
          <Button
            onClick={() => {
              if (step === 2) build(false);
              setStep(step + 1);
            }}
            disabled={step === 2 && equipment.length === 0}
          >
            Continue
          </Button>
        ) : (
          <>
            <Button
              onClick={() => {
                if (preview) {
                  actions.applyGeneratedPlan(preview);
                  toast(`${TrainingGoalInfo[preview.goal].name} is now your plan`);
                }
                onClose();
              }}
            >
              Use this plan
            </Button>
            <Button variant="secondary" onClick={() => build(true)}>
              Regenerate
            </Button>
          </>
        )}
        {step > 0 && (
          <Button variant="secondary" onClick={() => setStep(step - 1)}>
            Back
          </Button>
        )}
      </div>
    </Sheet>
  );
}

function ReplacementSheet({
  templateID,
  exerciseID,
  onClose,
}: {
  templateID: WorkoutTemplateID;
  exerciseID: string;
  onClose: () => void;
}) {
  const s = useApp();
  const options = replacementOptions(s, templateID, exerciseID);
  const current = catalogEntry(exerciseID);
  return (
    <Sheet title="I don’t have this" full onClose={onClose}>
      <p className="sub">
        Pick something else for {current ? MuscleGroupName[current.muscle] : "this muscle"}. We’ll remember this machine is missing when you
        regenerate.
      </p>
      {options.length === 0 && (
        <p className="caption">No alternatives for this muscle with your equipment. Generate a new plan or add more equipment.</p>
      )}
      <div className="stack-sm">
        {options.map((option) => (
          <button
            key={option.id}
            className="workout-launch"
            onClick={() => {
              actions.replaceExercise(templateID, exerciseID, option.id);
              toast(`Swapped for ${option.name}`);
              onClose();
            }}
          >
            <div className="grow stack-sm" style={{ gap: 4, textAlign: "left" }}>
              <span className="headline">{option.name}</span>
              <span className="caption">
                {MuscleGroupName[option.muscle]} · {GymEquipmentInfo[option.equipment].name}
              </span>
            </div>
            <Icon name="check" />
          </button>
        ))}
      </div>
    </Sheet>
  );
}

/** Keep the screen awake during a workout (Android Chrome supports the Screen Wake Lock API). */
function useWakeLock() {
  useEffect(() => {
    let lock: { release: () => Promise<void> } | null = null;
    let cancelled = false;
    const request = async () => {
      try {
        const wl = (navigator as Navigator & { wakeLock?: { request: (t: "screen") => Promise<{ release: () => Promise<void> }> } }).wakeLock;
        if (wl && document.visibilityState === "visible") {
          const l = await wl.request("screen");
          if (cancelled) l.release();
          else lock = l;
        }
      } catch {
        /* denied or unsupported */
      }
    };
    request();
    document.addEventListener("visibilitychange", request);
    return () => {
      cancelled = true;
      document.removeEventListener("visibilitychange", request);
      lock?.release().catch(() => {});
    };
  }, []);
}

function ActiveWorkout({ onClose, onFinished }: { onClose: () => void; onFinished: (c: WorkoutCompletion) => void }) {
  const s = useApp();
  const session = s.activeWorkout!;
  useTick(1000);
  useWakeLock();
  const now = Date.now();
  const elapsed = Math.floor((now - new Date(session.startedAt).getTime()) / 1000);
  const restRemaining = s.workoutRestEndsAt ? Math.max(0, Math.ceil((new Date(s.workoutRestEndsAt).getTime() - now) / 1000)) : null;

  // Buzz once when the rest timer reaches zero.
  const buzzedFor = useRef<string | undefined>(undefined);
  useEffect(() => {
    if (restRemaining === 0 && s.workoutRestEndsAt && buzzedFor.current !== s.workoutRestEndsAt) {
      buzzedFor.current = s.workoutRestEndsAt;
      try {
        navigator.vibrate?.([300, 120, 300]);
      } catch {
        /* ignore */
      }
      toast("Rest complete — next set!");
    }
  }, [restRemaining, s.workoutRestEndsAt]);

  async function finish() {
    if (!(await confirmDialog({ title: "Finish workout?", confirm: "Save Workout" }))) return;
    const before = getState();
    const previous = lastCompletedSession(before, session.templateID);
    const streakBefore = workoutStreak(before.profile.trainingDays, before.dayOverrides, before.workoutSessions);
    const stagnant = actions.finishActiveWorkout();
    // The review screen covers stagnation, so skip the separate "No Progress" dialog.
    actions.acknowledgeStagnationAlerts();
    const after = getState();
    const saved = after.workoutSessions.find((w) => w.id === session.id);
    if (!saved) {
      onClose();
      toast("Workout saved");
      return;
    }
    const streakAfter = workoutStreak(after.profile.trainingDays, after.dayOverrides, after.workoutSessions);
    onFinished({ session: saved, previous, streakBefore, streakAfter, stagnant });
  }

  async function discard() {
    if (await confirmDialog({ title: "Discard workout?", message: "Logged sets will be lost.", confirm: "Discard", destructive: true })) {
      actions.discardActiveWorkout();
      onClose();
    }
  }

  return (
    <Sheet
      title={session.templateName}
      full
      onClose={onClose}
      right={
        <button className="link-btn" style={{ color: "var(--danger)" }} onClick={discard}>
          Discard
        </button>
      }
    >
      <div
        className="card tight"
        style={{ position: "sticky", top: -16, zIndex: 2, flexDirection: "row", alignItems: "center", justifyContent: "space-between" }}
      >
        <div className="stack-sm" style={{ gap: 0 }}>
          <span className="caption row" style={{ gap: 4 }}>
            <Icon name="timer" size={14} /> Workout
          </span>
          <span className="num-md">{formatClock(elapsed)}</span>
        </div>
        <div className="stack-sm" style={{ gap: 0, alignItems: "flex-end" }}>
          <span className="caption">Rest</span>
          {restRemaining !== null && restRemaining > 0 ? (
            <div className="row">
              <span className="num-md warning">{formatClock(restRemaining)}</span>
              <button className="btn btn-secondary btn-sm" onClick={() => actions.skipRestTimer()}>
                Skip
              </button>
            </div>
          ) : (
            <span className="num-md success">Ready</span>
          )}
        </div>
      </div>

      {session.exercises.map((e) => (
        <ExerciseCard key={e.id} exercise={e} templateID={session.templateID} />
      ))}

      <Button onClick={finish}>Finish Workout</Button>
    </Sheet>
  );
}

function ExerciseCard({ exercise, templateID }: { exercise: ExerciseLog; templateID: WorkoutTemplateID }) {
  const s = useApp();
  const previous = previousPerformance(s, templateID, exercise.id);
  const prevLast = previous?.sets[previous.sets.length - 1];
  const myLast = exercise.sets[exercise.sets.length - 1];
  const hintWeight = myLast?.weightKg ?? prevLast?.weightKg;
  const hintReps = myLast?.reps ?? prevLast?.reps;
  const [weight, setWeight] = useState(hintWeight ? String(hintWeight) : "");
  const [reps, setReps] = useState(hintReps ? String(hintReps) : "");
  const done = exercise.sets.length >= exercise.plannedSets;
  const repsNum = Number(reps);

  return (
    <Card className="tight">
      <div className="row-between" style={{ alignItems: "flex-start" }}>
        <div className="stack-sm" style={{ gap: 2 }}>
          <span className="headline">{exercise.name}</span>
          <span className={`caption${done ? " success" : ""}`}>
            {exercise.sets.length} / {exercise.plannedSets} sets
          </span>
        </div>
        <Stepper
          label="Planned sets"
          value={exercise.plannedSets}
          min={1}
          max={12}
          onChange={(v) => actions.updatePlannedSets(templateID, exercise.id, v)}
        />
      </div>
      {previous && previous.sets.length > 0 && (
        <span className="caption">Last time: {previous.sets.map(setSummary).join(" · ")}</span>
      )}
      {exercise.sets.map((set, i) => (
        <div key={set.id} className="row-between callout">
          <span className="muted">Set {set.setNumber}</span>
          <span className="row">
            {setSummary(set)}
            {i === exercise.sets.length - 1 && (
              <button
                className="icon-btn"
                style={{ width: 28, height: 28, color: "var(--text-2)" }}
                aria-label="Undo last set"
                onClick={() => actions.deleteLastSet(exercise.id)}
              >
                <Icon name="close" size={14} />
              </button>
            )}
          </span>
        </div>
      ))}
      {done ? (
        <span className="caption success row" style={{ gap: 4 }}>
          <Icon name="check" size={14} /> All sets logged
        </span>
      ) : (
        <form
          className="set-grid"
          style={exercise.isBodyweightMaxReps ? { gridTemplateColumns: "1fr auto" } : undefined}
          onSubmit={(e) => {
            e.preventDefault();
            if (!(repsNum > 0)) return;
            actions.logSet(exercise.id, parseDecimal(weight), Math.round(repsNum));
          }}
        >
          {!exercise.isBodyweightMaxReps && (
            <label className="field">
              <span>kg</span>
              <NumberInput value={weight} onChange={setWeight} placeholder="kg" ariaLabel="Weight in kg" />
            </label>
          )}
          <label className="field">
            <span>Reps</span>
            <NumberInput integer value={reps} onChange={setReps} placeholder="reps" ariaLabel="Reps" />
          </label>
          <button type="submit" className="btn btn-primary" style={{ width: "auto", minHeight: 48 }} disabled={!(repsNum > 0)}>
            Log Set
          </button>
        </form>
      )}
    </Card>
  );
}
