import { useEffect, useRef, useState } from "react";
import { formatClock, formatMedium } from "../core/dates";
import { parseDecimal } from "../engines/units";
import {
  type ExerciseLog,
  TEMPLATE_IDS,
  type WorkoutTemplateID,
  setSummary,
} from "../engines/workout";
import { actions, getState, lastCompletedSession, previousPerformance, resolvedTemplate, useApp } from "../state/store";
import { workoutStreak } from "../engines/workoutReview";
import { type WorkoutCompletion, WorkoutComplete } from "./WorkoutComplete";
import { Button, Card, Icon, NumberInput, Sheet, Stepper, confirmDialog, toast, useTick } from "../ui/kit";

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

      <div className="stack-sm">
        <h2 className="headline">Start a Workout</h2>
        {TEMPLATE_IDS.map((id) => {
          const t = resolvedTemplate(s, id);
          const last = lastCompletedSession(s, id);
          return (
            <button key={id} className="card card-link" onClick={() => setPreview(id)}>
              <div className="row-between">
                <div className="stack-sm" style={{ gap: 4 }}>
                  <span className="headline">{t.name}</span>
                  <span className="caption">
                    {t.exercises.length} exercises · {t.exercises.reduce((n, e) => n + e.defaultSets, 0)} sets
                  </span>
                  {last && <span className="caption2">Last: {formatMedium(last.localDate)}</span>}
                </div>
                <Icon name="chevronRight" className="muted" />
              </div>
            </button>
          );
        })}
      </div>

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
  return (
    <Sheet
      title={t.name}
      full
      onClose={onClose}
      right={
        <button className="link-btn" onClick={onStart}>
          Start
        </button>
      }
    >
      <p className="sub">
        Adjust sets below if you want. When you start, a workout timer runs and logging a set starts a 3-minute rest timer.
      </p>
      <div className="list">
        {t.exercises.map((e) => {
          const prev = last?.exercises.find((x) => x.id === e.id);
          return (
            <div key={e.id} className="list-row" style={{ alignItems: "flex-start" }}>
              <div className="grow stack-sm" style={{ gap: 3 }}>
                <span className="callout">{e.name}</span>
                <span className="caption">
                  {prev && prev.sets.length
                    ? `Last time: ${prev.sets.map(setSummary).join(" · ")}`
                    : e.isBodyweightMaxReps
                      ? "Bodyweight · max reps"
                      : "No previous log"}
                </span>
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
      <Button onClick={onStart}>Start Workout</Button>
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
