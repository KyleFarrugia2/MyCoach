import { useState } from "react";
import { type Day, addDays, datesInWeek, formatLong, today } from "../core/dates";
import { type FoodLogEntry, type MealSlot, Macros, MeasurementLabel, fmt, mealName, mealSlots } from "../core/models";
import { parseDecimal } from "../engines/units";
import { actions, diaryFor, isTrainingDay, targetFor, useApp } from "../state/store";
import { Brief, Eyebrow, Fuel, Hex, MacroChips, Section, WeekStrip } from "../ui/brief";
import { Button, Icon, NumberInput, Sheet, confirmDialog, toast } from "../ui/kit";
import { AddFoodFlow, CustomFoodEditor } from "./FoodSheets";

function amountLabel(e: FoodLogEntry): string {
  return e.amountIsServings
    ? `${fmt(e.amount, 2)} × ${e.food.servingDescription}`
    : `${fmt(e.amount, 1)} g ${MeasurementLabel[e.food.measurementState].toLowerCase()}`;
}

export function FoodLog() {
  const s = useApp();
  const [day, setDay] = useState<Day>(today());
  const [addSlot, setAddSlot] = useState<MealSlot | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const [quickOpen, setQuickOpen] = useState(false);
  const [createOpen, setCreateOpen] = useState(false);

  const diary = diaryFor(s, day);
  const target = targetFor(s, day);
  const training = isTrainingDay(s, day);
  const slots = mealSlots(training);
  const consumed = diary.entries.reduce((sum, e) => sum + e.loggedCalories, 0);
  const macros = Macros.sum(diary.entries.map((e) => e.loggedMacros));

  const meals = slots.map((slot) => ({
    slot,
    name: mealName(s.preferences, slot),
    entries: diary.entries.filter(
      (e) =>
        e.mealSlot === slot ||
        (slot === "preWorkout" && e.mealSlot === "intraWorkout") ||
        (slot === "afternoonSnack" && e.mealSlot === "custom") ||
        // Entries logged on a different day type (e.g. "lunch" on a training day) still need a home.
        (!slots.includes(e.mealSlot) && e.mealSlot !== "intraWorkout" && e.mealSlot !== "custom" && slot === slots[slots.length - 1]),
    ),
  }));
  const mealsLogged = meals.filter((m) => m.entries.length > 0).length;

  function copyYesterday() {
    if (diaryFor(s, addDays(day, -1)).entries.length === 0) {
      toast("Nothing logged the day before");
      return;
    }
    actions.copyYesterday(day);
    toast("Copied previous day's foods");
  }

  return (
    <div className="screen">
      <div className="screen-header">
        <h1 className="screen-title">Food Log</h1>
        <button className="icon-btn" aria-label="Add" onClick={() => setMenuOpen(true)}>
          <Icon name="plus" />
        </button>
      </div>

      <div className="stack-sm">
        <WeekStrip
          days={datesInWeek(day)}
          selected={day}
          today={today()}
          onSelect={setDay}
          marker={(d) => {
            const dd = diaryFor(s, d);
            return dd.markedComplete ? "done" : dd.entries.length > 0 ? "some" : "none";
          }}
          onPrev={() => setDay(addDays(day, -7))}
          onNext={() => setDay(addDays(day, 7))}
        />
        <div className="day-line">
          <Eyebrow>{day === today() ? `Today · ${formatLong(day)}` : formatLong(day)}</Eyebrow>
          {day !== today() && (
            <button className="link-btn" onClick={() => setDay(today())}>
              Jump to today
            </button>
          )}
        </div>
      </div>

      <Brief className={training ? "is-training" : "is-rest"} label="Calories and macros">
        <div className="brief-head">
          <Eyebrow>{training ? "Training day budget" : "Rest day budget"}</Eyebrow>
          {diary.markedComplete && (
            <span className="brief-tag ok">
              <Icon name="check" size={13} /> Complete
            </span>
          )}
        </div>
        {target ? (
          <Fuel flush calories={consumed} target={target.calories} macros={macros} targetMacros={target.macros} />
        ) : (
          <div className="brief-empty" style={{ borderTop: "none", paddingTop: 0 }}>
            <strong>{Math.round(consumed).toLocaleString()} kcal eaten</strong>
            <span>No targets yet — finish setup to see what's left for the day.</span>
          </div>
        )}
      </Brief>

      <Section label="Meals" aside={<span className={`section-count${mealsLogged === meals.length ? " ok" : ""}`}>{mealsLogged} of {meals.length} logged</span>}>
        <ol className="rail">
          {meals.map(({ slot, name, entries }, i) => {
            const kcal = entries.reduce((sum, e) => sum + e.loggedCalories, 0);
            const empty = entries.length === 0;
            const addButton = (
              <button className="add-row" aria-label={`Add food to ${name}`} onClick={() => setAddSlot(slot)}>
                <Icon name="plus" size={16} /> Add food
              </button>
            );
            return (
              <li key={slot} className={`rail-item ${empty ? "is-empty" : "done"}`}>
                <span className="rail-node">
                  <Hex tone={empty ? "muted" : "primary"} solid={!empty}>
                    {i + 1}
                  </Hex>
                </span>
                {empty ? (
                  <div className="rail-body">
                    <h3 className="rail-title">{name}</h3>
                    {addButton}
                  </div>
                ) : (
                  <div className="rail-body">
                    <div className="rail-head">
                      <h3 className="rail-title">{name}</h3>
                      <span className="rail-kcal">
                        {Math.round(kcal)} <small>kcal</small>
                      </span>
                    </div>
                    <MacroChips macros={Macros.sum(entries.map((e) => e.loggedMacros))} />
                    <div className="rail-rows">
                      {entries.map((entry) => (
                        <div key={entry.id} className="entry">
                          <div className="entry-text">
                            <span className="entry-name">{entry.food.name}</span>
                            <span className="caption2">{amountLabel(entry)}</span>
                          </div>
                          <span className="entry-kcal">{Math.round(entry.loggedCalories)} kcal</span>
                          <button
                            className="tool-btn danger"
                            aria-label={`Delete ${entry.food.name}`}
                            onClick={async () => {
                              if (await confirmDialog({ title: `Remove ${entry.food.name}?`, confirm: "Remove", destructive: true })) {
                                actions.deleteFoodEntry(entry);
                              }
                            }}
                          >
                            <Icon name="trash" size={16} />
                          </button>
                        </div>
                      ))}
                    </div>
                    {addButton}
                  </div>
                )}
              </li>
            );
          })}
        </ol>
      </Section>

      <div className="pair">
        <button className="btn btn-secondary" onClick={copyYesterday}>
          <Icon name="copy" size={17} /> Copy Yesterday
        </button>
        <button
          className={`btn ${diary.markedComplete ? "btn-done" : "btn-secondary"}`}
          aria-pressed={diary.markedComplete}
          onClick={() => actions.setDiaryComplete(day, !diary.markedComplete)}
        >
          <Icon name="check" size={17} /> {diary.markedComplete ? "Day complete" : "Mark day complete"}
        </button>
      </div>
      <p className="footnote">Food logging is free forever — no subscription required.</p>

      {menuOpen && (
        <Sheet title="Add" onClose={() => setMenuOpen(false)}>
          <div className="list">
            {(
              [
                ["plus", "Add Food", () => setAddSlot(slots[0])],
                ["bolt", "Quick Add", () => setQuickOpen(true)],
                ["edit", "Create Food", () => setCreateOpen(true)],
                ["copy", "Copy Yesterday", copyYesterday],
              ] as const
            ).map(([icon, label, fn]) => (
              <button
                key={label}
                className="list-row"
                onClick={() => {
                  setMenuOpen(false);
                  fn();
                }}
              >
                <span className="accent">
                  <Icon name={icon} />
                </span>
                <span className="grow">{label}</span>
              </button>
            ))}
          </div>
        </Sheet>
      )}

      {addSlot && <AddFoodFlow slot={addSlot} day={day} onClose={() => setAddSlot(null)} />}
      {quickOpen && <QuickAdd slots={slots} day={day} onClose={() => setQuickOpen(false)} />}
      {createOpen && (
        <CustomFoodEditor
          onClose={() => setCreateOpen(false)}
          onSave={(food) => {
            actions.saveCustomFood(food);
            setCreateOpen(false);
            toast(`${food.name} saved to My Foods`);
          }}
        />
      )}
    </div>
  );
}

function QuickAdd({ slots, day, onClose }: { slots: MealSlot[]; day: Day; onClose: () => void }) {
  const s = useApp();
  const [cal, setCal] = useState("");
  const [p, setP] = useState("");
  const [c, setC] = useState("");
  const [f, setF] = useState("");
  const [slot, setSlot] = useState<MealSlot>(slots[0]);
  const field = (label: string, v: string, set: (x: string) => void) => (
    <label className="field">
      <span>{label}</span>
      <NumberInput value={v} onChange={set} ariaLabel={label} />
    </label>
  );
  return (
    <Sheet title="Quick Add" onClose={onClose}>
      <div className="grid-2">
        {field("Calories", cal, setCal)}
        {field("Protein (g)", p, setP)}
        {field("Carbs (g)", c, setC)}
        {field("Fat (g)", f, setF)}
      </div>
      <label className="field">
        <span>Meal</span>
        <select className="input" value={slot} onChange={(e) => setSlot(e.target.value as MealSlot)}>
          {slots.map((sl) => (
            <option key={sl} value={sl}>
              {mealName(s.preferences, sl)}
            </option>
          ))}
        </select>
      </label>
      <Button
        disabled={parseDecimal(cal) === undefined}
        onClick={() => {
          actions.quickAdd(parseDecimal(cal) ?? 0, parseDecimal(p) ?? 0, parseDecimal(c) ?? 0, parseDecimal(f) ?? 0, slot, day);
          onClose();
        }}
      >
        Add
      </Button>
    </Sheet>
  );
}
