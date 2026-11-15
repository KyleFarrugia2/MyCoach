import { useEffect, useState } from "react";
import { AppIdentity, CoachingConfig } from "../core/config";
import { type Day, addDays, formatLong, fromDay, today } from "../core/dates";
import { WeightUnitShort, mealSlots } from "../core/models";
import { cardioRecommendation, fmtHours } from "../engines/cardio";
import { type Quote, loadQuotes, quoteIndexFor } from "../engines/quotes";
import { UnitConversion, parseDecimal, parseHours } from "../engines/units";
import { TemplateName } from "../engines/workout";
import {
  actions,
  adaptiveModel,
  adaptiveRecommendation,
  diaryFor,
  displayWeight,
  greeting,
  hasCoachAccess,
  isTrainingDay,
  nextWorkoutTemplate,
  overrideOn,
  sleepOn,
  stepsOn,
  targetFor,
  useApp,
  weightEntryOn,
} from "../state/store";
import { Button, Card, DayTypeBadge, EmptyState, Icon, MacroMeta, NumberInput, Sheet, confirmDialog, toast, CoachAvatar } from "../ui/kit";
import { Settings } from "./Settings";

const MAX_DAYS_BACK = 60;

function dayLabel(day: Day): string {
  if (day === today()) return "Today";
  if (day === addDays(today(), -1)) return "Yesterday";
  return fromDay(day).toLocaleDateString(undefined, { weekday: "short", day: "numeric", month: "short" });
}

const shortWeekday = (day: Day) => fromDay(day).toLocaleDateString(undefined, { weekday: "long" });

export function Today() {
  const s = useApp();
  const [day, setDay] = useState<Day>(today());
  const [settingsOpen, setSettingsOpen] = useState(false);
  const isToday = day === today();
  const oldest = addDays(today(), -MAX_DAYS_BACK);

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
        <span className="sub">{formatLong(today())}</span>
      </div>

      <QuoteCard />

      {/* Day navigator — look back and catch up on missed days */}
      <div className="card row-between day-nav" style={{ flexDirection: "row", padding: "6px 8px" }}>
        <button className="icon-btn" aria-label="Previous day" disabled={day <= oldest} onClick={() => setDay(addDays(day, -1))}>
          <Icon name="chevronLeft" />
        </button>
        <div className="stack-sm center" style={{ gap: 0 }}>
          <span className="headline">{dayLabel(day)}</span>
          {!isToday && (
            <button className="link-btn" style={{ padding: 0, fontSize: 13 }} onClick={() => setDay(today())}>
              Back to today
            </button>
          )}
        </div>
        <button className="icon-btn" aria-label="Next day" disabled={isToday} onClick={() => setDay(addDays(day, 1))}>
          <Icon name="chevronRight" />
        </button>
      </div>
      {!isToday && (
        <div className="banner">
          <Icon name="calendar" size={18} />
          <span>Catching up on {dayLabel(day)} — anything you log here is saved to that day and used by your coach.</span>
        </div>
      )}

      <DayTypeCard day={day} />
      <SleepAdvice day={day} />
      <WeightCard key={`w-${day}`} day={day} />
      <SleepCard key={`s-${day}`} day={day} />
      <TargetsCard day={day} />
      {isToday && <CardioCard />}
      <StepsCard day={day} />
      <RecentDays selected={day} onSelect={setDay} />

      {isToday && <MealsAndCoach />}

      {settingsOpen && (
        <Sheet title="Settings" full onClose={() => setSettingsOpen(false)}>
          <Settings />
        </Sheet>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------

function QuoteCard() {
  const [quote, setQuote] = useState<Quote>();
  useEffect(() => {
    let alive = true;
    loadQuotes().then((qs) => {
      if (alive && qs.length) setQuote(qs[quoteIndexFor(today(), qs.length)]);
    });
    return () => {
      alive = false;
    };
  }, []);
  if (!quote) return null;
  return (
    <section className="card quote-card" aria-label="Quote of the day">
      <span className="caption row" style={{ gap: 6 }}>
        <Icon name="sparkle" size={14} /> Quote of the day
      </span>
      <blockquote className="quote-text">“{quote.t}”</blockquote>
      <span className="caption">— {quote.a}</span>
    </section>
  );
}

function DayTypeCard({ day }: { day: Day }) {
  const s = useApp();
  const training = isTrainingDay(s, day);
  const override = overrideOn(s, day);
  const isToday = day === today();
  const sessionThatDay = s.workoutSessions.find((w) => w.localDate === day && w.completedAt);
  const nextWorkout = TemplateName[nextWorkoutTemplate(s)];

  async function takeRest() {
    const ok = await confirmDialog({
      title: "Take an emergency rest day?",
      message:
        "Today switches to rest-day calories and no training. Your coach moves the session to a free day later this week if there's a good slot.",
      confirm: "Take Rest Day",
    });
    if (!ok) return;
    const { movedTo } = actions.takeEmergencyRestDay(day);
    toast(movedTo ? `Rest day taken — session moved to ${shortWeekday(movedTo)}` : "Rest day taken");
  }

  return (
    <section className={`card day-type ${training ? "is-training" : "is-rest"}`}>
      <div className="row-between">
        <div className="stack-sm" style={{ gap: 2 }}>
          <span className="caption">{isToday ? "Today's plan" : `${dayLabel(day)}'s plan`}</span>
          <span className="title2 row" style={{ gap: 8 }}>
            <Icon name={training ? "dumbbell" : "sun"} />
            {training ? "Training Day" : "Rest Day"}
          </span>
        </div>
        <DayTypeBadge training={training} />
      </div>

      {training && isToday && !sessionThatDay && (
        <span className="sub">
          On the plan: <strong>{nextWorkout}</strong>
          {override?.reason === "movedSession" && override.linkedDay ? ` · moved here from ${shortWeekday(override.linkedDay)}` : ""}
        </span>
      )}
      {sessionThatDay && <span className="sub success">✓ {sessionThatDay.templateName} completed</span>}
      {!training && override?.reason === "emergencyRest" && (
        <span className="sub">
          Emergency rest day{override.linkedDay ? ` — session moved to ${shortWeekday(override.linkedDay)}` : ""}. Rest-day calories apply.
        </span>
      )}
      {!training && !override && <span className="sub">Recover, hit your steps and eat to your rest-day targets.</span>}

      {isToday && training && !sessionThatDay && (
        <div className="row" style={{ gap: 8 }}>
          <button className="btn btn-primary btn-sm grow" onClick={() => actions.startWorkout(nextWorkoutTemplate(s))}>
            Start {nextWorkout}
          </button>
          <button className="btn btn-secondary btn-sm grow" onClick={takeRest}>
            Emergency rest day
          </button>
        </div>
      )}
      {isToday && override?.reason === "emergencyRest" && (
        <button
          className="link-btn"
          style={{ alignSelf: "flex-start" }}
          onClick={() => {
            actions.undoEmergencyRestDay(day);
            toast("Back on the original plan");
          }}
        >
          Undo rest day
        </button>
      )}
    </section>
  );
}

function SleepAdvice({ day }: { day: Day }) {
  const s = useApp();
  const [dismissed, setDismissed] = useState(false);
  const sleep = sleepOn(s, day);
  if (dismissed || day !== today() || !sleep || sleep.hours > 5 || !isTrainingDay(s, day)) return null;
  return (
    <div className="banner warn advice">
      <Icon name="warning" size={18} />
      <div className="stack-sm grow">
        <span>
          <strong>You slept {fmtHours(sleep.hours)}.</strong> With 5 hours or less, your coach recommends taking today as a rest
          day — training on that little sleep raises injury risk and slows recovery.
        </span>
        <div className="row" style={{ gap: 8 }}>
          <button
            className="btn btn-primary btn-sm"
            onClick={() => {
              const { movedTo } = actions.takeEmergencyRestDay(day);
              toast(movedTo ? `Rest day taken — session moved to ${shortWeekday(movedTo)}` : "Rest day taken");
            }}
          >
            Make it a rest day
          </button>
          <button className="btn btn-secondary btn-sm" onClick={() => setDismissed(true)}>
            Train anyway
          </button>
        </div>
      </div>
    </div>
  );
}

function WeightCard({ day }: { day: Day }) {
  const s = useApp();
  const entry = weightEntryOn(s, day);
  const isToday = day === today();
  const [editing, setEditing] = useState(false);
  const [text, setText] = useState(() =>
    entry ? UnitConversion.displayWeight(entry.weightKg, s.profile.weightUnit).toFixed(1) : isToday ? UnitConversion.displayWeight(s.profile.currentWeightKg, s.profile.weightUnit).toFixed(1) : "",
  );
  const parsed = parseDecimal(text);
  const showInput = !entry || editing;

  function save() {
    if (parsed === undefined || parsed <= 0) return;
    actions.logMorningWeight(parsed, s.profile.weightUnit, day);
    setEditing(false);
    toast(isToday ? "Morning weight logged" : `Weight saved for ${dayLabel(day)}`);
  }

  return (
    <Card>
      <div className="row-between">
        <h3 className="headline">Morning Weight</h3>
        {entry ? (
          <span className="row caption success">
            <Icon name="check" size={14} /> Logged
          </span>
        ) : (
          !isToday && <span className="badge warn">Missing</span>
        )}
      </div>
      {showInput ? (
        <div className="input-unit">
          <NumberInput big value={text} onChange={setText} placeholder="0.0" ariaLabel={`Morning weight for ${dayLabel(day)}`} />
          <span className="unit">{WeightUnitShort[s.profile.weightUnit]}</span>
        </div>
      ) : (
        <span className="num-lg accent pop-in">{displayWeight(s, entry!.weightKg)}</span>
      )}
      {isToday && <p className="caption">For the most consistent readings, weigh yourself under similar morning conditions.</p>}
      {showInput ? (
        <Button onClick={save} disabled={parsed === undefined || parsed <= 0}>
          {entry ? "Save Weight" : "Log Weight"}
        </Button>
      ) : (
        <Button
          variant="secondary"
          onClick={() => {
            setText(UnitConversion.displayWeight(entry!.weightKg, s.profile.weightUnit).toFixed(1));
            setEditing(true);
          }}
        >
          Edit Weight
        </Button>
      )}
    </Card>
  );
}

function SleepCard({ day }: { day: Day }) {
  const s = useApp();
  const entry = sleepOn(s, day);
  const [hoursText, setHoursText] = useState(entry ? String(Math.round(entry.hours * 100) / 100) : "");
  const [wakeText, setWakeText] = useState(entry?.wakeUps !== undefined ? String(entry.wakeUps) : "");
  const [editing, setEditing] = useState(!entry);
  const hours = parseHours(hoursText);
  const wakeUps = wakeText.trim() === "" ? undefined : Number(wakeText);
  const valid = hours !== undefined && (wakeUps === undefined || (Number.isInteger(wakeUps) && wakeUps >= 0 && wakeUps < 50));

  return (
    <Card>
      <div className="row-between">
        <h3 className="headline row" style={{ gap: 8 }}>
          <Icon name="moon" /> Sleep
        </h3>
        {entry && !editing && (
          <button className="link-btn" onClick={() => setEditing(true)}>
            Edit
          </button>
        )}
      </div>
      {entry && !editing ? (
        <div className="row" style={{ gap: 16, alignItems: "baseline" }}>
          <span className={`num-lg pop-in ${entry.hours <= 5 ? "warning" : "accent"}`}>{fmtHours(entry.hours)}</span>
          <span className="sub">
            {entry.wakeUps === undefined ? "Wake-ups not logged" : `${entry.wakeUps} wake-up${entry.wakeUps === 1 ? "" : "s"}`}
          </span>
        </div>
      ) : (
        <>
          <div className="grid-2">
            <label className="field">
              <span>Enter sleep (hours)</span>
              <input
                className="input"
                inputMode="decimal"
                placeholder="e.g. 7.5 or 7:30"
                value={hoursText}
                onChange={(e) => setHoursText(e.target.value.replace(/[^0-9.,:h ]/gi, ""))}
                aria-label="Hours slept"
              />
            </label>
            <label className="field">
              <span>Wake-ups (optional)</span>
              <NumberInput integer value={wakeText} onChange={setWakeText} placeholder="0" ariaLabel="Wake-ups" />
            </label>
          </div>
          <span className="caption">Sleep for the night before {day === today() ? "today" : dayLabel(day)}.</span>
          <Button
            disabled={!valid}
            onClick={() => {
              actions.logSleep(hours!, wakeUps, day);
              setEditing(false);
              toast("Sleep saved");
            }}
          >
            Save Sleep
          </Button>
        </>
      )}
    </Card>
  );
}

function TargetsCard({ day }: { day: Day }) {
  const s = useApp();
  const target = targetFor(s, day);
  if (!target) {
    return (
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
    );
  }
  return (
    <Card>
      <div className="row-between">
        <h3 className="headline">{day === today() ? "Today's Targets" : `${dayLabel(day)}'s Targets`}</h3>
        {target.source === "adaptiveModel" && <span className="badge ok">Personalised</span>}
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
            className="grow center stack-sm macro-pill"
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
  );
}

function CardioCard() {
  const s = useApp();
  const day = today();
  const model = adaptiveModel(s);
  const rec = adaptiveRecommendation(s);
  const confident = model && rec && model.confidence !== "low";
  const cardio = cardioRecommendation({
    goal: s.profile.goalPhase,
    isTrainingDay: isTrainingDay(s, day),
    emergencyRest: overrideOn(s, day)?.reason === "emergencyRest",
    sleepHours: sleepOn(s, day)?.hours,
    stepsSoFar: stepsOn(s, day)?.steps ?? 0,
    stepTarget: targetFor(s, day)?.stepTarget ?? s.profile.stepTarget,
    predictedKgPerWeek: confident ? rec!.predictedCurrent.meanKgPerWeek : undefined,
    targetKgPerWeek: confident ? rec!.targetKgPerWeek : undefined,
  });
  return (
    <section className={`card cardio tone-${cardio.tone}`}>
      <div className="row-between">
        <span className="caption row" style={{ gap: 6 }}>
          <Icon name="heart" size={14} /> Coach's cardio for today
        </span>
        {cardio.minutes > 0 && <span className="badge training">{cardio.minutes} min</span>}
      </div>
      <span className="title2">{cardio.title}</span>
      <span className="callout">{cardio.activity}</span>
      <span className="caption">{cardio.intensity}</span>
      <ul className="reasons">
        {cardio.reasons.map((r) => (
          <li key={r} className="caption2">
            {r}
          </li>
        ))}
      </ul>
    </section>
  );
}

function StepsCard({ day }: { day: Day }) {
  const s = useApp();
  const steps = stepsOn(s, day)?.steps;
  const stepTarget = targetFor(s, day)?.stepTarget ?? s.profile.stepTarget;
  const [open, setOpen] = useState(false);
  const [text, setText] = useState("");
  const value = steps ?? 0;
  return (
    <Card>
      <div className="row-between">
        <h3 className="headline">Steps</h3>
        <button
          className="link-btn"
          onClick={() => {
            setText(steps !== undefined ? String(steps) : "");
            setOpen(true);
          }}
        >
          {steps === undefined ? "Add" : "Edit"}
        </button>
      </div>
      <span className="num-md">
        {value.toLocaleString()} / {stepTarget.toLocaleString()}
      </span>
      <div className="bar">
        <div style={{ width: `${Math.min(value / Math.max(stepTarget, 1), 1) * 100}%`, background: "var(--primary)" }} />
      </div>
      {open && (
        <Sheet title={`Steps — ${dayLabel(day)}`} onClose={() => setOpen(false)}>
          <NumberInput integer big autoFocus value={text} onChange={setText} placeholder="0" ariaLabel="Steps" />
          <p className="caption">Your step target is {stepTarget.toLocaleString()} steps.</p>
          <Button
            disabled={text === "" || !Number.isFinite(Number(text))}
            onClick={() => {
              actions.logSteps(Math.round(Number(text)), day);
              setOpen(false);
            }}
          >
            Save
          </Button>
        </Sheet>
      )}
    </Card>
  );
}

function RecentDays({ selected, onSelect }: { selected: Day; onSelect: (d: Day) => void }) {
  const s = useApp();
  const days = Array.from({ length: 7 }, (_, i) => addDays(today(), -i));
  const missingWeight = days.filter((d) => d !== today() && !weightEntryOn(s, d)).length;
  return (
    <Card>
      <div className="row-between">
        <h3 className="headline">Last 7 Days</h3>
        {missingWeight > 0 && <span className="badge warn">{missingWeight} weigh-in{missingWeight === 1 ? "" : "s"} missing</span>}
      </div>
      <div className="recent-table" role="table" aria-label="Recent days">
        <div className="recent-row head" role="row">
          <span>Day</span>
          <span>Weight</span>
          <span>Sleep</span>
          <span>Steps</span>
        </div>
        {days.map((d) => {
          const w = weightEntryOn(s, d);
          const sl = sleepOn(s, d);
          const st = stepsOn(s, d);
          return (
            <button key={d} role="row" className={`recent-row${d === selected ? " selected" : ""}`} onClick={() => onSelect(d)}>
              <span className="row" style={{ gap: 6 }}>
                <span className={`dot ${isTrainingDay(s, d) ? "dot-training" : "dot-rest"}`} />
                {dayLabel(d)}
              </span>
              <span className={w ? "num" : "missing"}>{w ? displayWeight(s, w.weightKg) : "—"}</span>
              <span className={sl ? "num" : "missing"}>{sl ? fmtHours(sl.hours) : "—"}</span>
              <span className={st ? "num" : "missing"}>{st ? st.steps.toLocaleString() : "—"}</span>
            </button>
          );
        })}
      </div>
      <span className="caption">Tap a day to view or fill in what you missed.</span>
    </Card>
  );
}

function MealsAndCoach() {
  const s = useApp();
  const day = today();
  const target = targetFor(s, day);
  const slots = mealSlots(target?.isTrainingDay ?? isTrainingDay(s, day));
  const logged = new Set(diaryFor(s, day).entries.map((e) => e.mealSlot));
  const complete = slots.filter((slot) => logged.has(slot) || (slot === "preWorkout" && logged.has("intraWorkout"))).length;
  const planMeals = s.mealPlanDays[day]?.meals.length ?? slots.length;
  return (
    <>
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
      <Card>
        <div className="row" style={{ alignItems: "flex-start", gap: 12 }}>
          <CoachAvatar size={40} />
          <div className="stack-sm grow" style={{ gap: 4 }}>
            <h3 className="headline">Coach</h3>
            <p className="sub">{s.coachStatusMessage}</p>
          </div>
        </div>
        <button className="link-btn" style={{ alignSelf: "flex-start" }} onClick={() => actions.selectTab("coach")}>
          {hasCoachAccess(s) ? "View Coach Analysis" : "Unlock Coach AI"}
        </button>
      </Card>
    </>
  );
}
