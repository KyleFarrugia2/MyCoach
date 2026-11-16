import { useEffect, useState } from "react";
import { CoachingConfig } from "../core/config";
import { type Day, addDays, formatLong, fromDay, today } from "../core/dates";
import { Macros, WeightUnitShort, mealSlots } from "../core/models";
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
import { Brief, Eyebrow, Fuel, Hex, Section, WeekStrip } from "../ui/brief";
import { Button, CoachAvatar, Icon, type IconName, NumberInput, Sheet, confirmDialog, toast } from "../ui/kit";
import { Settings } from "./Settings";

const MAX_DAYS_BACK = 60;

function dayLabel(day: Day): string {
  if (day === today()) return "Today";
  if (day === addDays(today(), -1)) return "Yesterday";
  return fromDay(day).toLocaleDateString(undefined, { weekday: "short", day: "numeric", month: "short" });
}

const longWeekday = (day: Day) => fromDay(day).toLocaleDateString(undefined, { weekday: "long" });
const shortWeekday = (day: Day) => fromDay(day).toLocaleDateString(undefined, { weekday: "short" });
const daysBetween = (later: Day, earlier: Day) => Math.round((fromDay(later).getTime() - fromDay(earlier).getTime()) / 86_400_000);

/** The seven days (oldest first) of the page that contains `day`; page 0 ends today. */
function weekWindow(day: Day): Day[] {
  const page = Math.floor(Math.max(daysBetween(today(), day), 0) / 7);
  const end = addDays(today(), -7 * page);
  return Array.from({ length: 7 }, (_, i) => addDays(end, i - 6));
}

export function Today() {
  const s = useApp();
  const [day, setDay] = useState<Day>(today());
  const [settingsOpen, setSettingsOpen] = useState(false);
  const isToday = day === today();
  const oldest = addDays(today(), -MAX_DAYS_BACK);
  const days = weekWindow(day);

  return (
    <div className="screen today">
      <header className="masthead">
        <div className="masthead-text">
          <Eyebrow>{formatLong(today())}</Eyebrow>
          <h1 className="masthead-title">{greeting(s)}</h1>
        </div>
        <button className="icon-btn" aria-label="Settings" onClick={() => setSettingsOpen(true)}>
          <Icon name="gear" />
        </button>
      </header>

      <QuoteLine />

      {/* Day navigator — look back and catch up on missed days */}
      <div className="stack-sm">
        <WeekStrip
          days={days}
          selected={day}
          today={today()}
          onSelect={setDay}
          isDisabled={(d) => d < oldest}
          marker={(d) => (isTrainingDay(s, d) ? "training" : "rest")}
          onPrev={() => setDay(addDays(day, -7) < oldest ? oldest : addDays(day, -7))}
          onNext={() => setDay(addDays(day, 7) > today() ? today() : addDays(day, 7))}
          prevDisabled={days[0] <= oldest}
          nextDisabled={days[6] === today()}
        />
        {!isToday && (
          <div className="catchup">
            <Icon name="calendar" size={16} />
            <span className="grow">
              Catching up on <strong>{dayLabel(day)}</strong> — what you log here is saved to that day and used by your coach.
            </span>
            <button className="link-btn" onClick={() => setDay(today())}>
              Back to today
            </button>
          </div>
        )}
      </div>

      <PlanBrief day={day} />
      <SleepAdvice day={day} />
      <CheckIn key={day} day={day} />
      {isToday && <CoachThread />}
      <WeekBoard days={days} selected={day} onSelect={setDay} />

      {settingsOpen && (
        <Sheet title="Settings" full onClose={() => setSettingsOpen(false)}>
          <Settings />
        </Sheet>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Masthead quote
// ---------------------------------------------------------------------------

function QuoteLine() {
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
    <figure className="quote-line" aria-label="Quote of the day">
      <blockquote className="quote-text">“{quote.t}”</blockquote>
      <figcaption>{quote.a}</figcaption>
    </figure>
  );
}

// ---------------------------------------------------------------------------
// The day's brief: training / rest, fuel, and what to do
// ---------------------------------------------------------------------------

function PlanBrief({ day }: { day: Day }) {
  const s = useApp();
  const training = isTrainingDay(s, day);
  const override = overrideOn(s, day);
  const isToday = day === today();
  const sessionThatDay = s.workoutSessions.find((w) => w.localDate === day && w.completedAt);
  const nextWorkout = TemplateName[nextWorkoutTemplate(s)];
  const target = targetFor(s, day);
  const diary = diaryFor(s, day);
  const eaten = diary.entries.reduce((sum, e) => sum + e.loggedCalories, 0);
  const eatenMacros = Macros.sum(diary.entries.map((e) => e.loggedMacros));

  async function takeRest() {
    const ok = await confirmDialog({
      title: "Take an emergency rest day?",
      message:
        "Today switches to rest-day calories and no training. Your coach moves the session to a free day later this week if there's a good slot.",
      confirm: "Take Rest Day",
    });
    if (!ok) return;
    const { movedTo } = actions.takeEmergencyRestDay(day);
    toast(movedTo ? `Rest day taken — session moved to ${longWeekday(movedTo)}` : "Rest day taken");
  }

  let note: string;
  if (sessionThatDay) note = `${sessionThatDay.templateName} completed.`;
  else if (training && isToday) {
    note =
      override?.reason === "movedSession" && override.linkedDay
        ? `${nextWorkout} is on the plan — moved here from ${longWeekday(override.linkedDay)}.`
        : `${nextWorkout} is on the plan.`;
  } else if (training) note = "A training day with training-day calories.";
  else if (override?.reason === "emergencyRest") {
    note = `Emergency rest day${override.linkedDay ? ` — session moved to ${longWeekday(override.linkedDay)}` : ""}. Rest-day calories apply.`;
  } else note = "Recover, hit your steps and eat to your rest-day targets.";

  return (
    <Brief className={`day-type ${training ? "is-training" : "is-rest"}`} label={isToday ? "Today's plan" : `${dayLabel(day)}'s plan`}>
      <div className="brief-head">
        <div className="stack-sm" style={{ gap: 4 }}>
          <Eyebrow>{isToday ? "Today's plan" : `${dayLabel(day)}'s plan`}</Eyebrow>
          <h2 className="brief-title">
            <Icon name={training ? "dumbbell" : "sun"} size={22} />
            {training ? "Training Day" : "Rest Day"}
          </h2>
        </div>
        <div className="brief-tags">
          {sessionThatDay && (
            <span className="brief-tag ok">
              <Icon name="check" size={13} /> Done
            </span>
          )}
          {target?.source === "adaptiveModel" && <span className="brief-tag">Personalised</span>}
        </div>
      </div>
      <p className="brief-note">{note}</p>

      {target ? (
        <Fuel calories={eaten} target={target.calories} macros={eatenMacros} targetMacros={target.macros} />
      ) : (
        <div className="brief-empty">
          <strong>No plan yet</strong>
          <span>Your coach hasn't built today's nutrition targets.</span>
          <button
            className="btn btn-primary btn-sm"
            onClick={() => {
              actions.rebuildTargetsFromProfile();
              actions.generateMealPlan(day);
            }}
          >
            Generate Meal Plan
          </button>
        </div>
      )}

      {isToday && training && !sessionThatDay && (
        <div className="brief-actions">
          <button className="btn btn-primary btn-sm grow" onClick={() => actions.startWorkout(nextWorkoutTemplate(s))}>
            Start {nextWorkout}
          </button>
          <button className="btn btn-ghost btn-sm" onClick={takeRest}>
            Emergency rest day
          </button>
        </div>
      )}
      {isToday && override?.reason === "emergencyRest" && (
        <button
          className="btn btn-ghost btn-sm"
          style={{ alignSelf: "flex-start" }}
          onClick={() => {
            actions.undoEmergencyRestDay(day);
            toast("Back on the original plan");
          }}
        >
          Undo rest day
        </button>
      )}
    </Brief>
  );
}

function SleepAdvice({ day }: { day: Day }) {
  const s = useApp();
  const [dismissed, setDismissed] = useState(false);
  const sleep = sleepOn(s, day);
  if (dismissed || day !== today() || !sleep || sleep.hours > 5 || !isTrainingDay(s, day)) return null;
  return (
    <div className="coach-thread advice">
      <CoachAvatar size={36} />
      <div className="coach-msg warn">
        <span>
          <strong>You slept {fmtHours(sleep.hours)}.</strong> With 5 hours or less, your coach recommends taking today as a rest
          day — training on that little sleep raises injury risk and slows recovery.
        </span>
        <div className="row" style={{ gap: 8, flexWrap: "wrap" }}>
          <button
            className="btn btn-primary btn-sm"
            onClick={() => {
              const { movedTo } = actions.takeEmergencyRestDay(day);
              toast(movedTo ? `Rest day taken — session moved to ${longWeekday(movedTo)}` : "Rest day taken");
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

// ---------------------------------------------------------------------------
// Check-in: weight, sleep, steps, meals
// ---------------------------------------------------------------------------

function Tile({
  icon,
  label,
  done,
  flag,
  value,
  unit,
  prompt,
  note,
  tone = "primary",
  onClick,
  ariaLabel,
  children,
}: {
  icon: IconName;
  label: string;
  done: boolean;
  /** Small amber tag, e.g. "Missing" on a past day. */
  flag?: string;
  value?: string;
  unit?: string;
  /** Shown instead of the value when nothing is logged yet. */
  prompt: string;
  note?: string;
  tone?: "primary" | "warning";
  onClick: () => void;
  ariaLabel: string;
  children?: React.ReactNode;
}) {
  return (
    <button className={`tile${done ? " done" : " todo"}`} onClick={onClick} aria-label={ariaLabel}>
      <span className="tile-head">
        <Hex icon={icon} tone={done ? (tone === "warning" ? "warning" : "primary") : "muted"} size={30} />
        <span className="tile-label">{label}</span>
        {done ? (
          <span className="tile-state ok">
            <Icon name="check" size={13} />
          </span>
        ) : flag ? (
          <span className="tile-state flag">{flag}</span>
        ) : (
          <span className="tile-state add">
            <Icon name="plus" size={13} />
          </span>
        )}
      </span>
      {value !== undefined ? (
        <span className={`tile-value pop-in${tone === "warning" ? " warning" : ""}`}>
          {value}
          {unit && <small> {unit}</small>}
        </span>
      ) : (
        <span className="tile-prompt">{prompt}</span>
      )}
      {children}
      {note && <span className="tile-note">{note}</span>}
    </button>
  );
}

function CheckIn({ day }: { day: Day }) {
  const s = useApp();
  const isToday = day === today();
  const [sheet, setSheet] = useState<"weight" | "sleep" | "steps" | null>(null);

  const weight = weightEntryOn(s, day);
  const sleep = sleepOn(s, day);
  const steps = stepsOn(s, day)?.steps;
  const stepTarget = targetFor(s, day)?.stepTarget ?? s.profile.stepTarget;
  const unit = s.profile.weightUnit;

  // Change since the previous weigh-in.
  const previous = s.weightEntries
    .filter((e) => e.isOfficialMorningCheckIn && e.localDate < day)
    .sort((a, b) => b.localDate.localeCompare(a.localDate))[0];
  let weightNote: string | undefined;
  if (weight && previous) {
    const delta = UnitConversion.displayWeight(weight.weightKg, unit) - UnitConversion.displayWeight(previous.weightKg, unit);
    const rounded = Math.round(delta * 10) / 10;
    weightNote =
      rounded === 0
        ? `Same as ${shortWeekday(previous.localDate)}`
        : `${rounded > 0 ? "▲" : "▼"} ${Math.abs(rounded).toFixed(1)} ${WeightUnitShort[unit]} since ${shortWeekday(previous.localDate)}`;
  } else if (weight) weightNote = "First weigh-in";
  else if (isToday) weightNote = "Morning, before eating";

  // Meals logged (today only).
  const target = targetFor(s, day);
  const slots = mealSlots(target?.isTrainingDay ?? isTrainingDay(s, day));
  const logged = new Set(diaryFor(s, day).entries.map((e) => e.mealSlot));
  const mealsDone = slots.filter((slot) => logged.has(slot) || (slot === "preWorkout" && logged.has("intraWorkout"))).length;
  const mealsTotal = Math.max(s.mealPlanDays[day]?.meals.length ?? slots.length, CoachingConfig.requiredMealCount);

  const doneCount = [weight, sleep, steps !== undefined].filter(Boolean).length;

  return (
    <Section
      label={isToday ? "Check-in" : `${dayLabel(day)}'s check-in`}
      aside={<span className={`section-count${doneCount === 3 ? " ok" : ""}`}>{doneCount} of 3 logged</span>}
    >
      <div className="tiles">
        <Tile
          icon="scale"
          label="Weight"
          done={!!weight}
          flag={!isToday ? "Missing" : undefined}
          value={weight ? UnitConversion.displayWeight(weight.weightKg, unit).toFixed(1) : undefined}
          unit={WeightUnitShort[unit]}
          prompt="Log weight"
          note={weightNote}
          onClick={() => setSheet("weight")}
          ariaLabel={weight ? `Morning weight ${displayWeight(s, weight.weightKg)}. Edit` : "Log morning weight"}
        />
        <Tile
          icon="moon"
          label="Sleep"
          done={!!sleep}
          value={sleep ? fmtHours(sleep.hours) : undefined}
          tone={sleep && sleep.hours <= 5 ? "warning" : "primary"}
          prompt="Log sleep"
          note={
            sleep
              ? sleep.wakeUps === undefined
                ? "Wake-ups not logged"
                : `${sleep.wakeUps} wake-up${sleep.wakeUps === 1 ? "" : "s"}`
              : "Last night"
          }
          onClick={() => setSheet("sleep")}
          ariaLabel={sleep ? `Sleep ${fmtHours(sleep.hours)}. Edit` : "Log sleep"}
        />
        <Tile
          icon="steps"
          label="Steps"
          done={steps !== undefined}
          value={steps !== undefined ? steps.toLocaleString() : undefined}
          prompt="Add steps"
          note={`Goal ${stepTarget.toLocaleString()}`}
          onClick={() => setSheet("steps")}
          ariaLabel={steps !== undefined ? `Steps ${steps} of ${stepTarget}. Edit` : "Add steps"}
        >
          <span className="tile-meter">
            <span style={{ width: `${Math.min((steps ?? 0) / Math.max(stepTarget, 1), 1) * 100}%` }} />
          </span>
        </Tile>
        {isToday && (
          <Tile
            icon="fork"
            label="Meals"
            done={mealsDone >= mealsTotal}
            value={`${mealsDone} / ${mealsTotal}`}
            prompt=""
            note="Open log"
            onClick={() => actions.selectTab("log")}
            ariaLabel={`Meals: ${mealsDone} of ${mealsTotal} logged. Open Log`}
          >
            <span className="tile-pips">
              {Array.from({ length: mealsTotal }, (_, i) => (
                <span key={i} className={i < mealsDone ? "on" : ""} />
              ))}
            </span>
          </Tile>
        )}
      </div>

      {sheet === "weight" && <WeightSheet day={day} onClose={() => setSheet(null)} />}
      {sheet === "sleep" && <SleepSheet day={day} onClose={() => setSheet(null)} />}
      {sheet === "steps" && <StepsSheet day={day} onClose={() => setSheet(null)} />}
    </Section>
  );
}

function WeightSheet({ day, onClose }: { day: Day; onClose: () => void }) {
  const s = useApp();
  const entry = weightEntryOn(s, day);
  const isToday = day === today();
  const unit = s.profile.weightUnit;
  const [text, setText] = useState(() =>
    entry
      ? UnitConversion.displayWeight(entry.weightKg, unit).toFixed(1)
      : isToday
        ? UnitConversion.displayWeight(s.profile.currentWeightKg, unit).toFixed(1)
        : "",
  );
  const parsed = parseDecimal(text);
  const valid = parsed !== undefined && parsed > 0;
  return (
    <Sheet title={`Morning weight — ${dayLabel(day)}`} onClose={onClose}>
      <div className="input-unit">
        <NumberInput big autoFocus value={text} onChange={setText} placeholder="0.0" ariaLabel={`Morning weight for ${dayLabel(day)}`} />
        <span className="unit">{WeightUnitShort[unit]}</span>
      </div>
      <p className="caption">For the most consistent readings, weigh yourself under similar morning conditions.</p>
      <Button
        disabled={!valid}
        onClick={() => {
          if (!valid) return;
          actions.logMorningWeight(parsed!, unit, day);
          onClose();
          toast(isToday ? "Morning weight logged" : `Weight saved for ${dayLabel(day)}`);
        }}
      >
        {entry ? "Save Weight" : "Log Weight"}
      </Button>
    </Sheet>
  );
}

function SleepSheet({ day, onClose }: { day: Day; onClose: () => void }) {
  const s = useApp();
  const entry = sleepOn(s, day);
  const [hoursText, setHoursText] = useState(entry ? String(Math.round(entry.hours * 100) / 100) : "");
  const [wakeText, setWakeText] = useState(entry?.wakeUps !== undefined ? String(entry.wakeUps) : "");
  const hours = parseHours(hoursText);
  const wakeUps = wakeText.trim() === "" ? undefined : Number(wakeText);
  const valid = hours !== undefined && (wakeUps === undefined || (Number.isInteger(wakeUps) && wakeUps >= 0 && wakeUps < 50));
  return (
    <Sheet title={`Sleep — ${dayLabel(day)}`} onClose={onClose}>
      <div className="grid-2">
        <label className="field">
          <span>Enter sleep (hours)</span>
          <input
            className="input"
            inputMode="decimal"
            autoFocus
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
          onClose();
          toast("Sleep saved");
        }}
      >
        Save Sleep
      </Button>
    </Sheet>
  );
}

function StepsSheet({ day, onClose }: { day: Day; onClose: () => void }) {
  const s = useApp();
  const steps = stepsOn(s, day)?.steps;
  const stepTarget = targetFor(s, day)?.stepTarget ?? s.profile.stepTarget;
  const [text, setText] = useState(steps !== undefined ? String(steps) : "");
  return (
    <Sheet title={`Steps — ${dayLabel(day)}`} onClose={onClose}>
      <NumberInput integer big autoFocus value={text} onChange={setText} placeholder="0" ariaLabel="Steps" />
      <p className="caption">Your step target is {stepTarget.toLocaleString()} steps.</p>
      <Button
        disabled={text === "" || !Number.isFinite(Number(text))}
        onClick={() => {
          actions.logSteps(Math.round(Number(text)), day);
          onClose();
        }}
      >
        Save
      </Button>
    </Sheet>
  );
}

// ---------------------------------------------------------------------------
// From your coach: today's cardio and status
// ---------------------------------------------------------------------------

function CoachThread() {
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
    <Section label="From your coach">
      <div className="coach-thread">
        <CoachAvatar size={36} />
        <div className="coach-msgs">
          <div className={`coach-msg cardio tone-${cardio.tone}`}>
            <div className="row-between">
              <Eyebrow>Coach's cardio for today</Eyebrow>
              {cardio.minutes > 0 && <span className="minutes">{cardio.minutes} min</span>}
            </div>
            <span className="coach-msg-title">{cardio.title}</span>
            <span className="callout">{cardio.activity}</span>
            <span className="caption">{cardio.intensity}</span>
            <ul className="reasons">
              {cardio.reasons.map((r) => (
                <li key={r} className="caption2">
                  {r}
                </li>
              ))}
            </ul>
          </div>
          <div className="coach-msg">
            <span>{s.coachStatusMessage}</span>
            <button className="link-btn" style={{ alignSelf: "flex-start", padding: 0 }} onClick={() => actions.selectTab("coach")}>
              {hasCoachAccess(s) ? "View Coach Analysis" : "Unlock Coach AI"}
            </button>
          </div>
        </div>
      </div>
    </Section>
  );
}

// ---------------------------------------------------------------------------
// The week at a glance
// ---------------------------------------------------------------------------

const compactSteps = (n: number) => (n < 1000 ? String(n) : n < 10_000 ? `${(n / 1000).toFixed(1)}k` : `${Math.round(n / 1000)}k`);
const compactHours = (h: number) => `${Math.round(h * 10) / 10}h`;

function WeekBoard({ days, selected, onSelect }: { days: Day[]; selected: Day; onSelect: (d: Day) => void }) {
  const s = useApp();
  const unit = s.profile.weightUnit;
  const oldest = addDays(today(), -MAX_DAYS_BACK);
  const missingWeight = days.filter((d) => d < today() && d >= oldest && !weightEntryOn(s, d)).length;
  const range =
    days[6] === today()
      ? "Last 7 days"
      : `${fromDay(days[0]).toLocaleDateString(undefined, { day: "numeric", month: "short" })} – ${fromDay(days[6]).toLocaleDateString(undefined, { day: "numeric", month: "short" })}`;
  return (
    <Section
      label={range}
      aside={missingWeight > 0 && <span className="badge warn">{missingWeight} weigh-in{missingWeight === 1 ? "" : "s"} missing</span>}
    >
      <div className="board" aria-label="Recent days">
        <div className="board-labels" aria-hidden="true">
          <span />
          <Icon name="scale" size={15} />
          <Icon name="moon" size={15} />
          <Icon name="steps" size={15} />
        </div>
        {days.map((d) => {
          const w = weightEntryOn(s, d);
          const sl = sleepOn(s, d);
          const st = stepsOn(s, d);
          const wText = w ? UnitConversion.displayWeight(w.weightKg, unit).toFixed(1) : undefined;
          return (
            <button
              key={d}
              className={`board-col recent-row${d === selected ? " selected" : ""}${d === today() ? " today" : ""}`}
              disabled={d < oldest}
              onClick={() => onSelect(d)}
              aria-label={`${dayLabel(d)}: weight ${w ? displayWeight(s, w.weightKg) : "missing"}, sleep ${sl ? fmtHours(sl.hours) : "missing"}, steps ${st ? st.steps : "missing"}`}
            >
              <span className="board-day">
                <i className={`dot ${isTrainingDay(s, d) ? "dot-training" : "dot-rest"}`} />
                {d === today() ? "Today" : shortWeekday(d)}
              </span>
              <span className={wText ? "board-cell" : "board-cell missing"}>{wText ?? "–"}</span>
              <span className={sl ? `board-cell${sl.hours <= 5 ? " low" : ""}` : "board-cell blank"}>{sl ? compactHours(sl.hours) : "–"}</span>
              <span className={st ? "board-cell" : "board-cell blank"}>{st ? compactSteps(st.steps) : "–"}</span>
            </button>
          );
        })}
      </div>
      <span className="caption board-legend">
        <i className="dot dot-training" /> Training <i className="dot dot-rest" /> Rest · Tap a day to view or fill in what you missed.
      </span>
    </Section>
  );
}
