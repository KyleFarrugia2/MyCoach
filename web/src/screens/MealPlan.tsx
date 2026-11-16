import { useState } from "react";
import { type Day, datesInWeek, formatLong, formatMinutesOfDay, today } from "../core/dates";
import { type Meal, type MealItem, MeasurementLabel, fmt, mealCalories, mealMacros, mealName, planCalories, planMacros } from "../core/models";
import { specForFood, swapOptionsFor } from "../engines/mealPlanner";
import { intraWorkoutTargets } from "../engines/nutrition";
import { actions, hasCoachAccess, isTrainingDay, useApp } from "../state/store";
import { Brief, Eyebrow, Fuel, Hex, MacroChips, Section, WeekStrip } from "../ui/brief";
import { Card, EmptyState, FoodRow, Icon, Sheet, Toggle, macroLine, toast } from "../ui/kit";
import { Paywall } from "./Paywall";

export function MealPlan() {
  const s = useApp();
  const [day, setDay] = useState<Day>(today());
  const [swapItem, setSwapItem] = useState<MealItem | null>(null);
  const [paywall, setPaywall] = useState(false);
  const plan = s.mealPlanDays[day];
  const access = hasCoachAccess(s);

  function generate() {
    if (!access) return setPaywall(true);
    if (!s.targets) actions.rebuildTargetsFromProfile();
    actions.generateMealPlan(day);
    toast(plan ? "Week regenerated" : "Meal plan generated");
  }

  return (
    <div className="screen">
      <div className="screen-header">
        <h1 className="screen-title">Meal Plan</h1>
        <button className="btn btn-secondary btn-sm" onClick={generate}>
          {plan ? "Regenerate" : "Generate"}
        </button>
      </div>
      <p className="sub">Built around your targets and the foods you enjoy.</p>

      <WeekStrip
        days={datesInWeek(day)}
        selected={day}
        today={today()}
        onSelect={setDay}
        marker={(d) => ((s.mealPlanDays[d]?.isTrainingDay ?? isTrainingDay(s, d)) ? "training" : "rest")}
      />

      {plan ? (
        <>
          <Brief className={plan.isTrainingDay ? "is-training" : "is-rest"} label="Plan totals">
            <div className="brief-head">
              <div className="stack-sm" style={{ gap: 4 }}>
                <Eyebrow>{formatLong(plan.localDate)}</Eyebrow>
                <h2 className="brief-title">
                  <Icon name={plan.isTrainingDay ? "dumbbell" : "sun"} size={22} />
                  {plan.isTrainingDay ? "Training Day" : "Rest Day"}
                </h2>
              </div>
            </div>
            <Fuel mode="plan" calories={planCalories(plan)} target={plan.target.calories} macros={planMacros(plan)} targetMacros={plan.target.macros} />
          </Brief>
          {plan.solverMessage && <p className="caption">{plan.solverMessage}</p>}

          <Section label={`${plan.meals.length} meals`} aside={<span className="section-count">Weigh everything raw</span>}>
            <ol className="rail">
              {plan.meals.map((meal, i) => (
                <PlanMeal
                  key={meal.id}
                  index={i + 1}
                  meal={meal}
                  name={mealName(s.preferences, meal.slot)}
                  onSwap={access ? setSwapItem : undefined}
                  onToggleLock={access ? (item) => actions.toggleLock(item.id, day) : undefined}
                  onSwapMeal={access ? () => actions.swapMeal(meal.id, day) : undefined}
                  isFixed={(item) => specForFood(item.food).role === "supplement"}
                  onLogMeal={() => {
                    actions.logPlannedMeal(meal, day);
                    toast(`${mealName(s.preferences, meal.slot)} logged`);
                  }}
                />
              ))}
            </ol>
          </Section>

          {plan.isTrainingDay && (
            <Section label="Around training">
              <Card className="tight">
                <div className="list" style={{ boxShadow: "none", margin: "-12px -16px 0" }}>
                  <Toggle
                    label="Intra in Pre Workout Meal"
                    checked={s.profile.intraWorkoutEnabled}
                    onChange={(v) => actions.setIntraWorkoutEnabled(v)}
                  />
                </div>
                <p className="caption">
                  When on, dextrose and EAAs are included in Pre Workout / Intra Workout. They count toward your daily macros.
                </p>
                {s.profile.intraWorkoutEnabled &&
                  (() => {
                    const intra = intraWorkoutTargets(s.profile.currentWeightKg, s.profile.goalPhase);
                    return (
                      <>
                        <span className="callout">
                          EAAs: {intra.eaaGrams} g · Dextrose: {intra.dextroseGrams} g · Water: {intra.waterMl[0]}–{intra.waterMl[1]} mL
                        </span>
                        <span className="caption2">Highly recommended for users prioritising gym performance — entirely optional.</span>
                      </>
                    );
                  })()}
              </Card>
            </Section>
          )}

          <div className="offplan">
            <div className="stack-sm" style={{ gap: 2 }}>
              <h3 className="headline">Can't Follow The Plan Today?</h3>
              <p className="sub">You don't need your exact meal plan today. Aim to stay near your targets.</p>
            </div>
            <button className="btn btn-secondary btn-sm" onClick={() => actions.selectTab("log")}>
              Track Freely Instead
            </button>
          </div>
        </>
      ) : (
        <Card>
          <EmptyState
            icon="fork"
            title="Your coach hasn't built a meal plan yet."
            message="Generate a structured plan around your targets and preferred foods."
            actionTitle={access ? "Generate Meal Plan" : "Unlock Meal Plans"}
            onAction={generate}
          />
        </Card>
      )}

      {swapItem && (
        <Sheet title={`Swap ${swapItem.food.name}`} onClose={() => setSwapItem(null)}>
          <p className="caption">
            Same kind of food, weighed raw or dry. Portions and the day's totals are recalculated after the swap.
          </p>
          <div className="list">
            {swapOptionsFor(swapItem, s.customFoods, s.profile.allergies).map((food) => (
              <FoodRow
                key={food.id}
                food={food}
                chevron
                onClick={() => {
                  const note = actions.swapFood(swapItem.id, food, day);
                  setSwapItem(null);
                  toast(note ?? `Swapped to ${food.name}`);
                }}
              />
            ))}
          </div>
          <span className="caption2 row" style={{ gap: 4 }}>
            <Icon name="info" size={14} /> Add your own foods in the Foods tab to see them here.
          </span>
        </Sheet>
      )}
      {paywall && <Paywall onClose={() => setPaywall(false)} />}
    </div>
  );
}

/** How much to weigh, split from what it is, so the scale number leads each row. */
function splitItem(item: MealItem): { qty: string; name: string; state?: string } {
  if (item.grams !== undefined) {
    const st = item.food.measurementState;
    const state = st === "raw" || st === "dry" || st === "cooked" ? MeasurementLabel[st] : undefined;
    return { qty: `${fmt(item.grams, 1)} g`, name: item.food.name, state };
  }
  if (item.servings !== undefined) return { qty: `${fmt(item.servings, 2)} ×`, name: item.food.servingDescription };
  return { qty: "", name: item.food.name };
}

function PlanMeal({
  index,
  meal,
  name,
  onSwap,
  onToggleLock,
  onLogMeal,
  onSwapMeal,
  isFixed,
}: {
  index: number;
  meal: Meal;
  name: string;
  onSwap?: (item: MealItem) => void;
  onToggleLock?: (item: MealItem) => void;
  onLogMeal: () => void;
  onSwapMeal?: () => void;
  /** Items that can't be swapped or locked (e.g. intra-workout supplements). */
  isFixed: (item: MealItem) => boolean;
}) {
  return (
    <li className="rail-item done">
      <span className="rail-node">
        <Hex>{index}</Hex>
      </span>
      <div className="rail-body">
        <div className="rail-head">
          <h3 className="rail-title">
            {name}
            {meal.scheduledTimeMinutes !== undefined && <span className="rail-time">{formatMinutesOfDay(meal.scheduledTimeMinutes)}</span>}
          </h3>
          <span className="rail-kcal">
            {Math.round(mealCalories(meal))} <small>kcal</small>
          </span>
        </div>
        <MacroChips macros={mealMacros(meal)} />
        <div className="rail-rows">
          {meal.items.map((item) => {
            const { qty, name: itemName, state } = splitItem(item);
            const fixed = isFixed(item);
            return (
              <div key={item.id} className="plan-item">
                <span className="plan-qty">{qty}</span>
                <div className="entry-text">
                  <span className="entry-name">
                    {itemName}
                    {state && <span className="state-tag">{state}</span>}
                  </span>
                  <span className="caption2">
                    {Math.round(item.calories)} kcal · {macroLine(item.macros)}
                  </span>
                </div>
                <div className="plan-tools">
                  {onToggleLock && !fixed && (
                    <button
                      className={`tool-btn${item.isLocked ? " on" : ""}`}
                      aria-label={item.isLocked ? "Unlock quantity" : "Lock quantity"}
                      onClick={() => onToggleLock(item)}
                    >
                      <Icon name={item.isLocked ? "lock" : "unlock"} size={16} />
                    </button>
                  )}
                  {onSwap && !fixed && (
                    <button className="tool-btn" aria-label={`Swap ${item.food.name}`} onClick={() => onSwap(item)}>
                      <Icon name="swap" size={16} />
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
        <div className="rail-foot">
          <button className="btn btn-tint btn-sm" aria-label="Log meal" onClick={onLogMeal}>
            <Icon name="check" size={15} /> Log meal
          </button>
          {onSwapMeal && (
            <button className="link-btn row" style={{ gap: 5 }} onClick={onSwapMeal}>
              <Icon name="swap" size={15} /> Swap meal
            </button>
          )}
        </div>
      </div>
    </li>
  );
}
