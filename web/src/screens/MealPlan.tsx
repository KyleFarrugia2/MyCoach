import { useState } from "react";
import { type Day, datesInWeek, formatLong, today, weekdayOf } from "../core/dates";
import { type MealItem, WeekdayShort, mealName, planCalories, planMacros } from "../core/models";
import { specForFood, swapOptionsFor } from "../engines/mealPlanner";
import { intraWorkoutTargets } from "../engines/nutrition";
import { actions, hasCoachAccess, useApp } from "../state/store";
import { Button, Card, DayTypeBadge, EmptyState, FoodRow, Icon, MacroBar, MealCard, Sheet, Toggle, toast } from "../ui/kit";
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

      <div className="row" style={{ gap: 6 }}>
        {datesInWeek(day).map((d) => {
          const selected = d === day;
          return (
            <button
              key={d}
              onClick={() => setDay(d)}
              className="grow stack-sm"
              style={{
                alignItems: "center",
                gap: 4,
                padding: "8px 0",
                border: "none",
                borderRadius: "var(--r-sm)",
                background: selected ? "color-mix(in srgb, var(--primary) 12%, transparent)" : "transparent",
                fontWeight: 600,
                color: d === today() ? "var(--primary)" : "var(--text)",
              }}
            >
              {WeekdayShort[weekdayOf(d)]}
              <span className="dot" style={{ background: selected ? "var(--primary)" : "transparent" }} />
            </button>
          );
        })}
      </div>

      {plan ? (
        <>
          <div className="row-between">
            <DayTypeBadge training={plan.isTrainingDay} />
            <span className="sub">{formatLong(plan.localDate)}</span>
          </div>
          <Card>
            <div className="row-between">
              <span className="num-md accent">{plan.target.calories} kcal</span>
              <span className="sub">Plan {Math.round(planCalories(plan))}</span>
            </div>
            <MacroBar kind="protein" current={planMacros(plan).protein} target={plan.target.macros.protein} />
            <MacroBar kind="carbohydrates" current={planMacros(plan).carbohydrates} target={plan.target.macros.carbohydrates} />
            <MacroBar kind="fat" current={planMacros(plan).fat} target={plan.target.macros.fat} />
          </Card>
          {plan.solverMessage && <p className="caption">{plan.solverMessage}</p>}
          {plan.meals.map((meal) => (
            <MealCard
              key={meal.id}
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
          {plan.isTrainingDay && (
            <Card>
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
          )}
          <Card>
            <h3 className="headline">Can't Follow The Plan Today?</h3>
            <p className="sub">You don't need your exact meal plan today. Aim to stay near your targets.</p>
            <Button variant="secondary" onClick={() => actions.selectTab("log")}>
              Track Freely Instead
            </Button>
          </Card>
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
