import { useState } from "react";
import { type Day, addDays, formatLong, today } from "../core/dates";
import { type FoodLogEntry, type MealSlot, Macros, MeasurementLabel, fmt, mealName, mealSlots } from "../core/models";
import { parseDecimal } from "../engines/units";
import { actions, diaryFor, isTrainingDay, targetFor, useApp } from "../state/store";
import { Button, CalorieRing, Card, FoodRow, Icon, MacroBar, NumberInput, SectionHeader, Sheet, confirmDialog, toast } from "../ui/kit";
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
  const slots = mealSlots(isTrainingDay(s, day));
  const consumed = diary.entries.reduce((sum, e) => sum + e.loggedCalories, 0);
  const macros = Macros.sum(diary.entries.map((e) => e.loggedMacros));
  const calorieTarget = target?.calories ?? 0;

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

      <div className="row-between card" style={{ flexDirection: "row", padding: "6px 8px" }}>
        <button className="icon-btn" aria-label="Previous day" onClick={() => setDay(addDays(day, -1))}>
          <Icon name="chevronLeft" />
        </button>
        <button className="headline" style={{ border: "none", background: "none" }} onClick={() => setDay(today())}>
          {day === today() ? "Today" : formatLong(day)}
        </button>
        <button className="icon-btn" aria-label="Next day" onClick={() => setDay(addDays(day, 1))}>
          <Icon name="chevronRight" />
        </button>
      </div>

      <Card>
        <div className="row" style={{ gap: 16 }}>
          <CalorieRing consumed={consumed} target={Math.max(calorieTarget, 1)} size={120} />
          <div className="stack-sm">
            <span className="caption">Remaining</span>
            <span className="num-md">{Math.round(calorieTarget - consumed)} kcal</span>
            <span className="caption2">Free forever — no subscription required.</span>
          </div>
        </div>
        <MacroBar kind="protein" current={macros.protein} target={Math.max(target?.macros.protein ?? 0, 1)} />
        <MacroBar kind="carbohydrates" current={macros.carbohydrates} target={Math.max(target?.macros.carbohydrates ?? 0, 1)} />
        <MacroBar kind="fat" current={macros.fat} target={Math.max(target?.macros.fat ?? 0, 1)} />
      </Card>

      {slots.map((slot) => {
        const entries = diary.entries.filter(
          (e) =>
            e.mealSlot === slot ||
            (slot === "preWorkout" && e.mealSlot === "intraWorkout") ||
            (slot === "afternoonSnack" && e.mealSlot === "custom") ||
            // Entries logged on a different day type (e.g. "lunch" on a training day) still need a home.
            (!slots.includes(e.mealSlot) && e.mealSlot !== "intraWorkout" && e.mealSlot !== "custom" && slot === slots[slots.length - 1]),
        );
        return (
          <div key={slot} className="stack-sm">
            <SectionHeader title={mealName(s.preferences, slot)} action="Add Food +" onAction={() => setAddSlot(slot)} />
            {entries.length === 0 ? (
              <span className="sub" style={{ padding: "0 4px" }}>
                Nothing logged yet.
              </span>
            ) : (
              <div className="list">
                {entries.map((entry) => (
                  <FoodRow
                    key={entry.id}
                    food={entry.food}
                    amountLabel={amountLabel(entry)}
                    calories={entry.loggedCalories}
                    macros={entry.loggedMacros}
                    trailing={
                      <button
                        className="icon-btn"
                        style={{ width: 34, height: 34, color: "var(--danger)" }}
                        aria-label={`Delete ${entry.food.name}`}
                        onClick={async () => {
                          if (await confirmDialog({ title: `Remove ${entry.food.name}?`, confirm: "Remove", destructive: true })) {
                            actions.deleteFoodEntry(entry);
                          }
                        }}
                      >
                        <Icon name="trash" size={16} />
                      </button>
                    }
                  />
                ))}
              </div>
            )}
          </div>
        );
      })}

      <Button variant="secondary" onClick={copyYesterday}>
        <Icon name="copy" size={18} /> Copy Yesterday
      </Button>
      <button className="link-btn" onClick={() => actions.setDiaryComplete(day, !diary.markedComplete)}>
        {diary.markedComplete ? "✓ Day marked complete" : "Mark day complete"}
      </button>

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
