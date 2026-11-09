/**
 * Practical meal planner — reference implementation.
 * Port: `MyCoach/Services/Nutrition/MealPlanner.swift` (keep numerically identical; shared fixture
 * web/tests/fixtures/meal-planner-fixture.json, checked by MealPlannerTests on iOS).
 *
 * Rules (apply to new plans, regenerated plans and swaps):
 *  - Protein target = 1 g per lb of current bodyweight (set in the nutrition engine); the plan must meet it.
 *  - Calories are verified with 4 / 4 / 9 kcal per g of protein / carbs / fat.
 *  - Exactly one main protein source per meal (whole eggs + egg whites count as one). Incidental protein
 *    from rice, bread, oats, veg… counts toward the totals.
 *  - Every quantity is weighed RAW (meat, fish, eggs, potatoes, fruit, veg) or DRY (rice, pasta, oats)
 *    and uses the matching database entry — cooked entries are never used for planning.
 *  - Real meals from compatible ingredients, portions in practical increments within sensible ranges;
 *    no tiny unrelated foods added to force totals. A small macro tolerance is allowed instead.
 *  - Every plan is validated; failing meals are regenerated with alternative recipes.
 */
import type { Day, Weekday } from "../core/dates";
import type {
  DailyNutritionTarget,
  FoodAllergy,
  FoodItem,
  GoalPhase,
  MacroGrams,
  Meal,
  MealItem,
  MealPlanDay,
  MealSlot,
  MeasurementState,
  TrainingTimePreference,
} from "../core/models";
import { MealSlotLabel, mealSlots, uuid } from "../core/models";
import { intraWorkoutTargets } from "./nutrition";

export const PlannerConfig = {
  proteinUnderToleranceG: 8,
  proteinOverToleranceG: 20,
  calorieToleranceFraction: 0.04,
  calorieToleranceMinKcal: 80,
  carbToleranceFraction: 0.12,
  carbToleranceMinG: 20,
  fatToleranceFraction: 0.15,
  fatToleranceMinG: 8,
  /** Database rounding allowance when checking a food's kcal against 4/4/9 (per 100 g). */
  databaseKcalToleranceFraction: 0.1,
  databaseKcalToleranceMin: 10,
  maxAttempts: 12,
  maxIterations: 600,
  weightProtein: 4,
  weightCarbs: 1,
  weightFat: 2,
  weightKcal: 1,
  weightDistribution: 0.25,
  vegDefaultG: 150,
} as const;

export type PlannerRole = "protein" | "carb" | "fruit" | "veg" | "fat" | "supplement";
export type MealType = "breakfast" | "snack" | "main" | "pre" | "post";

/** A planning food: one database entry, weighed raw/dry, with a practical portion grid. */
export interface PlannerFood {
  key: string;
  id: string;
  name: string;
  state: MeasurementState;
  /** Unit foods (eggs, bread slices, whey scoops) are counted in units; others in grams. */
  unit: boolean;
  servingDescription: string;
  servingGrams: number;
  kcal: number;
  protein: number;
  carbs: number;
  fat: number;
  role: PlannerRole;
  step: number;
  min: number;
  max: number;
  /** 0 is allowed (item dropped) — side components: starch (low-carb days), fruit, added fat, extra egg whites. */
  optional: boolean;
  /** Foods in the same group form one protein source (whole eggs + egg whites). */
  group?: string;
  allergens: FoodAllergy[];
  keywords: string[];
}

type Row = [
  key: string,
  id: string,
  name: string,
  state: MeasurementState,
  unit: boolean,
  servingDescription: string,
  servingGrams: number,
  kcal: number,
  protein: number,
  carbs: number,
  fat: number,
  role: PlannerRole,
  step: number,
  min: number,
  max: number,
  optional: boolean,
  group: string | null,
  allergens: FoodAllergy[],
  keywords: string[],
];

// prettier-ignore
const ROWS: Row[] = [
  ["chicken", "a1000001-0001-4000-8000-000000000001", "Chicken Breast", "raw", false, "100 g raw", 100, 110, 23.1, 0, 1.2, "protein", 25, 75, 300, false, null, [], ["chicken"]],
  ["beef", "a1000001-0001-4000-8000-000000000003", "Lean Beef (5% fat)", "raw", false, "100 g raw", 100, 137, 21.4, 0, 5.0, "protein", 25, 75, 250, false, null, [], ["beef", "steak", "mince"]],
  ["turkey", "a1000001-0001-4000-8000-000000000005", "Turkey Breast", "raw", false, "100 g raw", 100, 104, 24.0, 0, 0.7, "protein", 25, 75, 300, false, null, [], ["turkey"]],
  ["whiteFish", "a1000001-0001-4000-8000-000000000006", "White Fish (cod)", "raw", false, "100 g raw", 100, 82, 17.8, 0, 0.7, "protein", 25, 100, 350, false, null, ["fish"], ["fish", "cod"]],
  ["egg", "a1000001-0001-4000-8000-000000000007", "Egg", "raw", true, "large egg, raw (50 g each)", 50, 72, 6.3, 0.4, 4.8, "protein", 1, 1, 4, false, "egg", ["eggs"], ["egg"]],
  ["eggWhites", "a1000001-0001-4000-8000-000000000008", "Egg Whites", "raw", false, "100 g raw", 100, 52, 10.9, 0.7, 0.2, "protein", 50, 100, 300, true, "egg", ["eggs"], ["egg white"]],
  ["greekYogurt", "a1000001-0001-4000-8000-000000000009", "Greek Yogurt (0% fat)", "prepared", false, "100 g", 100, 59, 10.3, 3.6, 0.4, "protein", 50, 150, 500, false, null, ["dairy"], ["yogurt", "yoghurt"]],
  ["cottageCheese", "a1000001-0001-4000-8000-00000000000a", "Cottage Cheese (low fat)", "prepared", false, "100 g", 100, 72, 12.4, 2.7, 1.0, "protein", 50, 150, 400, false, null, ["dairy"], ["cottage"]],
  ["whey", "a1000001-0001-4000-8000-00000000000b", "Whey Protein Powder", "serving", true, "scoop whey protein (30 g each)", 30, 120, 24.0, 2.0, 1.5, "protein", 0.5, 0.5, 2, false, null, ["dairy"], ["whey", "protein powder", "protein shake"]],
  ["whiteRice", "a1000002-0001-4000-8000-000000000001", "White Rice", "dry", false, "100 g dry", 100, 365, 7.1, 80.0, 0.7, "carb", 10, 40, 175, true, null, [], ["rice"]],
  ["brownRice", "a1000002-0001-4000-8000-000000000003", "Brown Rice", "dry", false, "100 g dry", 100, 370, 7.9, 77.2, 2.9, "carb", 10, 40, 175, true, null, [], ["brown rice"]],
  ["potato", "a1000002-0001-4000-8000-000000000005", "Potato", "raw", false, "100 g raw", 100, 77, 2.0, 17.5, 0.1, "carb", 50, 150, 600, true, null, [], ["potato"]],
  ["sweetPotato", "a1000002-0001-4000-8000-000000000007", "Sweet Potato", "raw", false, "100 g raw", 100, 86, 1.6, 20.1, 0.1, "carb", 50, 150, 500, true, null, [], ["sweet potato"]],
  ["pasta", "a1000002-0001-4000-8000-000000000008", "Pasta", "dry", false, "100 g dry", 100, 371, 13.0, 74.7, 1.5, "carb", 10, 50, 175, true, null, ["glutenWheat"], ["pasta", "spaghetti"]],
  ["oats", "a1000002-0001-4000-8000-00000000000a", "Oats (rolled)", "dry", false, "100 g dry", 100, 389, 16.9, 66.3, 6.9, "carb", 10, 30, 150, true, null, ["glutenWheat"], ["oat", "porridge"]],
  ["bread", "a1000002-0001-4000-8000-00000000000c", "Bread (white)", "prepared", true, "slice white bread (30 g each)", 30, 79, 2.7, 14.7, 1.0, "carb", 1, 1, 4, true, null, ["glutenWheat"], ["bread", "toast"]],
  ["banana", "a1000002-0001-4000-8000-00000000000d", "Banana", "raw", false, "100 g raw (peeled)", 100, 89, 1.1, 22.8, 0.3, "fruit", 25, 75, 250, true, null, [], ["banana"]],
  ["apple", "a1000002-0001-4000-8000-00000000000e", "Apple", "raw", false, "100 g raw", 100, 52, 0.3, 13.8, 0.2, "fruit", 25, 100, 250, true, null, [], ["apple"]],
  ["berries", "a1000002-0001-4000-8000-00000000000f", "Mixed Berries", "raw", false, "100 g raw", 100, 57, 0.7, 14.5, 0.3, "fruit", 25, 75, 250, true, null, [], ["berr"]],
  ["mixedVeg", "a1000002-0001-4000-8000-000000000010", "Mixed Vegetables", "raw", false, "100 g raw", 100, 35, 2.0, 7.0, 0.2, "veg", 25, 100, 250, false, null, [], ["vegetable", "veg"]],
  ["broccoli", "a1000002-0001-4000-8000-000000000011", "Broccoli", "raw", false, "100 g raw", 100, 34, 2.8, 6.6, 0.4, "veg", 25, 100, 250, false, null, [], ["broccoli"]],
  ["peanutButter", "a1000003-0001-4000-8000-000000000001", "Peanut Butter", "serving", false, "32 g (2 tbsp)", 32, 188, 8.0, 6.0, 16.0, "fat", 5, 10, 50, true, null, ["peanuts"], ["peanut"]],
  ["oliveOil", "a1000003-0001-4000-8000-000000000002", "Olive Oil", "serving", false, "14 g (1 tbsp)", 14, 119, 0, 0, 13.5, "fat", 5, 5, 30, true, null, [], ["olive oil", "oil"]],
  ["almonds", "a1000003-0001-4000-8000-000000000003", "Almonds", "raw", false, "28 g (1 oz)", 28, 164, 6.0, 6.1, 14.2, "fat", 5, 10, 50, true, null, ["treeNuts"], ["almond", "nuts"]],
  ["avocado", "a1000003-0001-4000-8000-000000000004", "Avocado", "raw", false, "100 g raw", 100, 160, 2.0, 8.5, 14.7, "fat", 25, 50, 200, true, null, [], ["avocado"]],
  ["dextrose", "a1000004-0001-4000-8000-000000000001", "Dextrose", "dry", false, "100 g dry powder", 100, 380, 0, 95.0, 0, "supplement", 1, 0, 200, false, null, [], ["dextrose"]],
  ["eaa", "a1000004-0001-4000-8000-000000000002", "Essential Amino Acids (EAAs)", "serving", false, "10 g serving", 10, 40, 10.0, 0, 0, "supplement", 1, 0, 50, false, null, [], ["eaa"]],
];

export const PLANNER_FOODS: PlannerFood[] = ROWS.map((r) => ({
  key: r[0],
  id: r[1],
  name: r[2],
  state: r[3],
  unit: r[4],
  servingDescription: r[5],
  servingGrams: r[6],
  kcal: r[7],
  protein: r[8],
  carbs: r[9],
  fat: r[10],
  role: r[11],
  step: r[12],
  min: r[13],
  max: r[14],
  optional: r[15],
  group: r[16] ?? undefined,
  allergens: r[17],
  keywords: r[18],
}));

const BY_KEY = new Map(PLANNER_FOODS.map((f) => [f.key, f]));
const BY_ID = new Map(PLANNER_FOODS.map((f) => [f.id, f]));
const food = (key: string) => BY_KEY.get(key)!;

export interface Recipe {
  id: string;
  type: MealType;
  /** Main protein source: one food, or the egg group (whole eggs + whites). */
  protein: string[];
  carb?: string;
  fruit?: string;
  veg?: string;
  fat?: string;
}

const R = (id: string, type: MealType, protein: string[], parts: Omit<Recipe, "id" | "type" | "protein"> = {}): Recipe => ({
  id,
  type,
  protein,
  ...parts,
});

// Real meals built from compatible ingredients. Order matters (deterministic tie-breaking).
export const RECIPES: Recipe[] = [
  R("eggs-toast-berries", "breakfast", ["egg", "eggWhites"], { carb: "bread", fruit: "berries" }),
  R("yogurt-oats-berries", "breakfast", ["greekYogurt"], { carb: "oats", fruit: "berries", fat: "almonds" }),
  R("eggs-oats-banana", "breakfast", ["egg", "eggWhites"], { carb: "oats", fruit: "banana" }),
  R("whey-oats-banana-pb", "breakfast", ["whey"], { carb: "oats", fruit: "banana", fat: "peanutButter" }),
  R("cottage-toast-apple", "breakfast", ["cottageCheese"], { carb: "bread", fruit: "apple" }),
  R("eggs-toast-avocado", "breakfast", ["egg", "eggWhites"], { carb: "bread", fat: "avocado" }),
  R("eggs-potato-veg", "breakfast", ["egg", "eggWhites"], { carb: "potato", veg: "mixedVeg" }),

  R("yogurt-berries-almonds", "snack", ["greekYogurt"], { fruit: "berries", fat: "almonds" }),
  R("cottage-apple", "snack", ["cottageCheese"], { fruit: "apple", fat: "almonds" }),
  R("whey-banana-pb", "snack", ["whey"], { fruit: "banana", fat: "peanutButter" }),
  R("yogurt-oats-banana", "snack", ["greekYogurt"], { carb: "oats", fruit: "banana" }),
  R("whey-apple-almonds", "snack", ["whey"], { fruit: "apple", fat: "almonds" }),
  R("turkey-toast", "snack", ["turkey"], { carb: "bread" }),

  R("chicken-rice-broccoli", "main", ["chicken"], { carb: "whiteRice", veg: "broccoli", fat: "oliveOil" }),
  R("beef-potato-veg", "main", ["beef"], { carb: "potato", veg: "mixedVeg", fat: "oliveOil" }),
  R("turkey-pasta-veg", "main", ["turkey"], { carb: "pasta", veg: "mixedVeg", fat: "oliveOil" }),
  R("fish-potato-broccoli", "main", ["whiteFish"], { carb: "potato", veg: "broccoli", fat: "oliveOil" }),
  R("chicken-sweetpotato-veg", "main", ["chicken"], { carb: "sweetPotato", veg: "mixedVeg", fat: "avocado" }),
  R("beef-rice-broccoli", "main", ["beef"], { carb: "whiteRice", veg: "broccoli" }),
  R("turkey-brownrice-veg", "main", ["turkey"], { carb: "brownRice", veg: "mixedVeg", fat: "avocado" }),
  R("fish-rice-veg", "main", ["whiteFish"], { carb: "whiteRice", veg: "mixedVeg", fat: "oliveOil" }),

  R("chicken-rice", "pre", ["chicken"], { carb: "whiteRice" }),
  R("turkey-toast-banana", "pre", ["turkey"], { carb: "bread", fruit: "banana" }),
  R("chicken-potato", "pre", ["chicken"], { carb: "potato" }),
  R("fish-rice", "pre", ["whiteFish"], { carb: "whiteRice" }),
  R("yogurt-oats-banana-pre", "pre", ["greekYogurt"], { carb: "oats", fruit: "banana" }),

  R("chicken-rice-broccoli-post", "post", ["chicken"], { carb: "whiteRice", veg: "broccoli" }),
  R("beef-potato-veg-post", "post", ["beef"], { carb: "potato", veg: "mixedVeg" }),
  R("turkey-pasta-veg-post", "post", ["turkey"], { carb: "pasta", veg: "mixedVeg" }),
  R("fish-potato-broccoli-post", "post", ["whiteFish"], { carb: "potato", veg: "broccoli" }),
  R("chicken-pasta-broccoli-post", "post", ["chicken"], { carb: "pasta", veg: "broccoli" }),
];

const RECIPE_BY_ID = new Map(RECIPES.map((r) => [r.id, r]));

export function mealTypeFor(slot: MealSlot): MealType {
  switch (slot) {
    case "breakfast":
      return "breakfast";
    case "snack":
    case "afternoonSnack":
      return "snack";
    case "preWorkout":
    case "intraWorkout":
      return "pre";
    case "postWorkout":
      return "post";
    default:
      return "main";
  }
}

const CARB_WEIGHT: Record<MealType, number> = { breakfast: 1, snack: 0.6, main: 1, pre: 1.3, post: 1.3 };

// ---------------------------------------------------------------------------
// Context, preferences, filters
// ---------------------------------------------------------------------------

export interface PlannerContext {
  allergies: FoodAllergy[];
  dislikedFoods: string[];
  preferredFoods: string[];
  trainingTime: TrainingTimePreference;
  intraWorkoutEnabled: boolean;
  weightKg: number;
  goal: GoalPhase;
}

const norm = (s: string) => s.trim().toLowerCase();

/** Does a user-entered food name refer to this planner food? */
export function matchesName(f: PlannerFood, text: string): boolean {
  const t = norm(text);
  if (!t) return false;
  const name = f.name.toLowerCase();
  return name.includes(t) || f.keywords.some((k) => t.includes(k));
}

function recipeKeys(r: Recipe): string[] {
  return [...r.protein, r.carb, r.fruit, r.veg, r.fat].filter((k): k is string => !!k);
}

function recipeAllowed(r: Recipe, ctx: PlannerContext): boolean {
  const banned: FoodAllergy[] = ctx.allergies.filter((a) => a !== "none");
  return recipeKeys(r).every((k) => {
    const f = food(k);
    if (f.allergens.some((a) => banned.includes(a))) return false;
    // Optional extra egg whites don't make a recipe "disliked"; everything else does.
    return !ctx.dislikedFoods.some((d) => matchesName(f, d));
  });
}

function recipeScore(r: Recipe, ctx: PlannerContext): number {
  if (ctx.preferredFoods.length === 0) return 0;
  return recipeKeys(r).filter((k) => ctx.preferredFoods.some((p) => matchesName(food(k), p))).length;
}

/** Candidate recipes for a meal type, best first. Falls back to main/pre meals if allergies rule all out. */
export function candidatesFor(type: MealType, ctx: PlannerContext): Recipe[] {
  const order: MealType[] = type === "main" ? ["main", "pre"] : [type, "main", "pre"];
  for (const t of order) {
    const list = RECIPES.filter((r) => r.type === t && recipeAllowed(r, ctx));
    if (list.length) {
      return list
        .map((r, i) => ({ r, i, s: recipeScore(r, ctx) }))
        .sort((a, b) => b.s - a.s || a.i - b.i)
        .map((x) => x.r);
    }
  }
  return [];
}

// ---------------------------------------------------------------------------
// Items, domains, nutrition
// ---------------------------------------------------------------------------

/** Spec for any food that can sit in a plan: planner foods by id, otherwise a sensible custom spec. */
export function specForFood(f: FoodItem): PlannerFood {
  const known = BY_ID.get(f.id.toLowerCase());
  if (known) return known;
  const grams = f.servingGrams && f.servingGrams > 0 ? f.servingGrams : undefined;
  const p = f.proteinGrams ?? 0;
  const c = f.carbohydrateGrams ?? 0;
  const fat = f.fatGrams ?? 0;
  return {
    key: `custom:${f.id}`,
    id: f.id,
    name: f.name,
    state: f.measurementState,
    unit: grams === undefined,
    servingDescription: f.servingDescription,
    servingGrams: grams ?? 1,
    kcal: f.calories ?? 4 * p + 4 * c + 9 * fat,
    protein: p,
    carbs: c,
    fat,
    role: roleForMacros(p, c, fat),
    step: grams === undefined ? 0.5 : 10,
    min: grams === undefined ? 0.5 : 20,
    max: grams === undefined ? 4 : 400,
    optional: false,
    allergens: f.allergenTags,
    keywords: [],
  };
}

export function roleForMacros(p: number, c: number, f: number): PlannerRole {
  const total = 4 * p + 4 * c + 9 * f;
  if (total <= 0) return "veg";
  if ((4 * p) / total >= 0.4) return "protein";
  if ((9 * f) / total >= 0.5) return "fat";
  return "carb";
}

export function plannerFoodItem(f: PlannerFood): FoodItem {
  return {
    id: f.id,
    name: f.name,
    source: f.key.startsWith("custom:") ? "customUser" : "bundledGeneric",
    servingDescription: f.servingDescription,
    servingGrams: f.servingGrams,
    calories: f.kcal,
    proteinGrams: f.protein,
    carbohydrateGrams: f.carbs,
    fatGrams: f.fat,
    measurementState: f.state,
    isCustom: false,
    isVerified: true,
    allergenTags: f.allergens,
    isFavorite: false,
  };
}

function factor(f: PlannerFood, amount: number): number {
  return f.unit ? amount : amount / f.servingGrams;
}

function macrosOf(f: PlannerFood, amount: number): { kcal: number; p: number; c: number; fat: number } {
  const k = factor(f, amount);
  return { kcal: f.kcal * k, p: f.protein * k, c: f.carbs * k, fat: f.fat * k };
}

/**
 * Allowed amounts: the practical grid min, min+step, …, max, plus 0 for optional components. Starch may only
 * be dropped from a meal that also has vegetables (protein + veg is still a real plate; "chicken & rice"
 * without rice is not).
 */
export function domainOf(f: PlannerFood, mealHasVeg = true): number[] {
  const values: number[] = f.optional && (f.role !== "carb" || mealHasVeg) ? [0] : [];
  const n = Math.round((f.max - f.min) / f.step);
  for (let i = 0; i <= n; i++) values.push(Math.round((f.min + i * f.step) * 1000) / 1000);
  return values;
}

function snap(domain: number[], value: number): number {
  let best = domain[0];
  for (const v of domain) if (Math.abs(v - value) < Math.abs(best - value) - 1e-9) best = v;
  return best;
}

interface WorkItem {
  id: string;
  meal: number;
  spec: PlannerFood;
  domain: number[];
  amount: number;
  locked: boolean;
}

interface Targets {
  p: number;
  c: number;
  f: number;
  kcal: number;
}

function totalsOf(items: WorkItem[]) {
  let p = 0;
  let c = 0;
  let f = 0;
  let kcal = 0;
  for (const it of items) {
    const m = macrosOf(it.spec, it.amount);
    p += m.p;
    c += m.c;
    f += m.fat;
    kcal += m.kcal;
  }
  return { p, c, f, kcal };
}

function objective(items: WorkItem[], t: Targets, mealCount: number): number {
  const cfg = PlannerConfig;
  const mealP = new Array<number>(mealCount).fill(0);
  let p = 0;
  let c = 0;
  let f = 0;
  for (const it of items) {
    const m = macrosOf(it.spec, it.amount);
    p += m.p;
    c += m.c;
    f += m.fat;
    mealP[it.meal] += m.p;
  }
  const kcal = 4 * p + 4 * c + 9 * f;
  const perMeal = t.p / mealCount;
  let dist = 0;
  for (const mp of mealP) dist += (mp - perMeal) * (mp - perMeal);
  const dk = (kcal - t.kcal) / 4;
  return (
    cfg.weightProtein * (p - t.p) * (p - t.p) +
    cfg.weightCarbs * (c - t.c) * (c - t.c) +
    cfg.weightFat * (f - t.f) * (f - t.f) +
    cfg.weightKcal * dk * dk +
    cfg.weightDistribution * dist
  );
}

/** Coordinate descent over the practical grids: one step at a time, best improvement first. */
function optimize(items: WorkItem[], t: Targets, mealCount: number): number {
  let current = objective(items, t, mealCount);
  for (let iter = 0; iter < PlannerConfig.maxIterations; iter++) {
    let bestJ = current;
    let bestItem = -1;
    let bestValue = 0;
    for (let i = 0; i < items.length; i++) {
      const it = items[i];
      if (it.locked || it.spec.role === "supplement") continue;
      const idx = it.domain.indexOf(it.amount);
      if (idx < 0) continue;
      for (const d of [-1, 1]) {
        const j = idx + d;
        if (j < 0 || j >= it.domain.length) continue;
        const saved = it.amount;
        it.amount = it.domain[j];
        const val = objective(items, t, mealCount);
        it.amount = saved;
        if (val < bestJ - 1e-9) {
          bestJ = val;
          bestItem = i;
          bestValue = it.domain[j];
        }
      }
    }
    if (bestItem < 0) break;
    items[bestItem].amount = bestValue;
    current = bestJ;
  }
  return current;
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

export interface PlanValidation {
  ok: boolean;
  /** Macro/calorie problems (whole day). */
  issues: string[];
  /** Meals breaking the portion or one-protein-source rules (indexes). */
  failingMeals: number[];
  totals: { protein: number; carbs: number; fat: number; kcal: number; databaseKcal: number };
  /** Foods whose label calories don't match 4/4/9 beyond normal rounding (informational). */
  databaseWarnings: string[];
}

function targetsOf(target: DailyNutritionTarget): Targets {
  const { protein, carbohydrates, fat } = target.macros;
  return { p: protein, c: carbohydrates, f: fat, kcal: 4 * protein + 4 * carbohydrates + 9 * fat };
}

export function databaseKcalConsistent(f: PlannerFood): boolean {
  const per = 100 / f.servingGrams;
  const label = f.kcal * per;
  const fromMacros = (4 * f.protein + 4 * f.carbs + 9 * f.fat) * per;
  return Math.abs(label - fromMacros) <= Math.max(PlannerConfig.databaseKcalToleranceFraction * label, PlannerConfig.databaseKcalToleranceMin);
}

function validateWork(items: WorkItem[], t: Targets, mealCount: number): PlanValidation {
  const cfg = PlannerConfig;
  const tot = totalsOf(items);
  const kcal = 4 * tot.p + 4 * tot.c + 9 * tot.f;
  const issues: string[] = [];
  if (tot.p < t.p - cfg.proteinUnderToleranceG) issues.push(`Protein ${Math.round(tot.p)} g is below the ${Math.round(t.p)} g target.`);
  if (tot.p > t.p + cfg.proteinOverToleranceG) issues.push(`Protein ${Math.round(tot.p)} g is well above the ${Math.round(t.p)} g target.`);
  if (Math.abs(kcal - t.kcal) > Math.max(cfg.calorieToleranceFraction * t.kcal, cfg.calorieToleranceMinKcal)) {
    issues.push(`Calories ${Math.round(kcal)} kcal miss the ${Math.round(t.kcal)} kcal target.`);
  }
  if (Math.abs(tot.c - t.c) > Math.max(cfg.carbToleranceFraction * t.c, cfg.carbToleranceMinG)) {
    issues.push(`Carbs ${Math.round(tot.c)} g miss the ${Math.round(t.c)} g target.`);
  }
  if (Math.abs(tot.f - t.f) > Math.max(cfg.fatToleranceFraction * t.f, cfg.fatToleranceMinG)) {
    issues.push(`Fat ${Math.round(tot.f)} g misses the ${Math.round(t.f)} g target.`);
  }

  const failing = new Set<number>();
  for (let m = 0; m < mealCount; m++) {
    const mealItems = items.filter((it) => it.meal === m && it.amount > 0);
    const sources = new Set(mealItems.filter((it) => it.spec.role === "protein").map((it) => it.spec.group ?? it.spec.key));
    if (sources.size !== 1) failing.add(m);
    for (const it of mealItems) {
      if (it.spec.state === "cooked") failing.add(m);
      if (it.spec.role !== "supplement" && !it.domain.includes(it.amount)) failing.add(m);
    }
  }
  const warnings = [
    ...new Set(items.filter((it) => !databaseKcalConsistent(it.spec)).map((it) => `${it.spec.name}: label calories don't match its macros.`)),
  ];
  return {
    ok: issues.length === 0 && failing.size === 0,
    issues,
    failingMeals: [...failing].sort((a, b) => a - b),
    totals: { protein: tot.p, carbs: tot.c, fat: tot.f, kcal, databaseKcal: tot.kcal },
    databaseWarnings: warnings,
  };
}

// ---------------------------------------------------------------------------
// Building meals
// ---------------------------------------------------------------------------

function timeForSlot(slot: MealSlot, trainingTime: TrainingTimePreference, index: number): number {
  const trainingMinutes = { morning: 8 * 60, midday: 12 * 60, afternoon: 15 * 60, evening: 18 * 60, variable: 17 * 60 }[trainingTime];
  switch (slot) {
    case "breakfast":
      return 8 * 60;
    case "snack":
      return 10 * 60 + 30;
    case "lunch":
      return 13 * 60;
    case "afternoonSnack":
      return 16 * 60;
    case "dinner":
      return 19 * 60;
    case "preWorkout":
      return trainingMinutes - 90;
    case "intraWorkout":
      return trainingMinutes;
    case "postWorkout":
      return trainingMinutes + 60;
    case "custom":
      return 10 * 60 + index * 180;
  }
}

/** Recipe components with starting amounts (protein sized to this meal's share of the day). */
function itemsForRecipe(recipe: Recipe, meal: number, perMealProtein: number): WorkItem[] {
  const out: WorkItem[] = [];
  const hasVeg = recipe.veg !== undefined;
  const add = (key: string, amount: number) => {
    const spec = food(key);
    const domain = domainOf(spec, hasVeg);
    out.push({ id: uuid(), meal, spec, domain, amount: snap(domain, amount), locked: false });
  };
  if (recipe.protein.length === 2 && recipe.protein[0] === "egg") {
    const egg = food("egg");
    const whites = food("eggWhites");
    add("egg", 2);
    add("eggWhites", ((perMealProtein - 2 * egg.protein) / whites.protein) * whites.servingGrams);
  } else {
    const p = food(recipe.protein[0]);
    add(recipe.protein[0], p.unit ? perMealProtein / p.protein : (perMealProtein / p.protein) * p.servingGrams);
  }
  if (recipe.veg) add(recipe.veg, PlannerConfig.vegDefaultG);
  if (recipe.fruit) add(recipe.fruit, food(recipe.fruit).min);
  if (recipe.fat) add(recipe.fat, food(recipe.fat).min);
  if (recipe.carb) add(recipe.carb, food(recipe.carb).min);
  return out;
}

function intraItems(meal: number, ctx: PlannerContext): WorkItem[] {
  const intra = intraWorkoutTargets(ctx.weightKg, ctx.goal);
  return [
    { key: "dextrose", amount: intra.dextroseGrams },
    { key: "eaa", amount: intra.eaaGrams },
  ].map(({ key, amount }) => ({ id: uuid(), meal, spec: food(key), domain: [amount], amount, locked: true }));
}

/** Size carbs to the remaining carb budget across meals, weighted toward training. */
function sizeCarbs(items: WorkItem[], t: Targets, types: MealType[]) {
  const carbItems = items.filter((it) => it.spec.role === "carb" && !it.locked);
  if (!carbItems.length) return;
  const nonCarb = items.filter((it) => !carbItems.includes(it));
  const fixedCarbs = totalsOf(nonCarb).c;
  const budget = Math.max(0, t.c - fixedCarbs);
  const weightSum = carbItems.reduce((s, it) => s + CARB_WEIGHT[types[it.meal]], 0);
  for (const it of carbItems) {
    const share = (budget * CARB_WEIGHT[types[it.meal]]) / weightSum;
    const perAmount = it.spec.unit ? it.spec.carbs : it.spec.carbs / it.spec.servingGrams;
    it.amount = snap(it.domain, perAmount > 0 ? share / perAmount : it.spec.min);
  }
}

function toMeals(items: WorkItem[], slots: MealSlot[], recipeIds: (string | undefined)[], names: string[], times: (number | undefined)[]): Meal[] {
  return slots.map((slot, m) => ({
    id: uuid(),
    slot,
    name: names[m],
    scheduledTimeMinutes: times[m],
    recipeId: recipeIds[m],
    items: items
      .filter((it) => it.meal === m && it.amount > 0)
      .map((it) => toMealItem(it)),
  }));
}

function toMealItem(it: WorkItem): MealItem {
  const m = macrosOf(it.spec, it.amount);
  const macros: MacroGrams = { protein: m.p, carbohydrates: m.c, fat: m.fat };
  return {
    id: it.id,
    food: plannerFoodItem(it.spec),
    grams: it.spec.unit ? undefined : it.amount,
    servings: it.spec.unit ? it.amount : undefined,
    isLocked: it.locked && it.spec.role !== "supplement",
    calories: m.kcal,
    macros,
  };
}

function messageFor(v: PlanValidation): string | undefined {
  const notes: string[] = [];
  if (!v.ok) {
    notes.push(
      v.issues.length
        ? `Closest practical plan with these foods: ${v.issues.join(" ")}`
        : "Some meals couldn't be built from practical portions with your current foods.",
    );
  }
  if (v.databaseWarnings.length) notes.push(v.databaseWarnings.join(" "));
  return notes.length ? notes.join(" ") : undefined;
}

export interface GenerateInput {
  date: Day;
  weekday: Weekday;
  isTrainingDay: boolean;
  target: DailyNutritionTarget;
  ctx: PlannerContext;
}

interface Built {
  items: WorkItem[];
  recipeIds: (string | undefined)[];
  validation: PlanValidation;
  score: number;
}

function buildDay(recipes: (Recipe | undefined)[], types: MealType[], slots: MealSlot[], t: Targets, ctx: PlannerContext): Built {
  const n = slots.length;
  const perMealProtein = t.p / n;
  let items: WorkItem[] = [];
  recipes.forEach((r, m) => {
    if (r) items = items.concat(itemsForRecipe(r, m, perMealProtein));
    if (slots[m] === "preWorkout" && ctx.intraWorkoutEnabled) items = items.concat(intraItems(m, ctx));
  });
  sizeCarbs(items, t, types);
  const j = optimize(items, t, n);
  const validation = validateWork(items, t, n);
  return {
    items,
    recipeIds: recipes.map((r) => r?.id),
    validation,
    score: j + (validation.issues.length + validation.failingMeals.length) * 1e6,
  };
}

/** Generate a validated day. Retries with alternative recipes for failing meals; keeps the best attempt. */
export function generatePlanDay(input: GenerateInput): MealPlanDay {
  const slots = mealSlots(input.isTrainingDay);
  const types = slots.map(mealTypeFor);
  const t = targetsOf(input.target);
  const cands = types.map((type) => candidatesFor(type, input.ctx));
  const dayIndex = input.weekday - 1;

  // Base choice: rotate by day for variety, prefer a main protein not already used today.
  const base: number[] = [];
  const used = new Set<string>();
  cands.forEach((list, m) => {
    if (!list.length) {
      base.push(0);
      return;
    }
    const topScore = recipeScore(list[0], input.ctx);
    const top = list.filter((r) => recipeScore(r, input.ctx) === topScore);
    const start = (dayIndex * 3 + m) % top.length;
    let pick: Recipe | undefined;
    for (let k = 0; k < top.length; k++) {
      const r = top[(start + k) % top.length];
      if (!used.has(r.protein[0])) {
        pick = r;
        break;
      }
    }
    // Every best match repeats a protein already used today → accept one fewer preferred food for variety.
    if (!pick) pick = list.find((r) => recipeScore(r, input.ctx) >= topScore - 1 && !used.has(r.protein[0])) ?? top[start];
    used.add(pick.protein[0]);
    base.push(list.indexOf(pick));
  });

  const offsets = new Array<number>(slots.length).fill(0);
  let best: Built | undefined;
  let last: Built | undefined;
  for (let attempt = 0; attempt < PlannerConfig.maxAttempts; attempt++) {
    if (attempt > 0) {
      // Regenerate the affected meals: failing meals first, otherwise rotate meals in turn.
      const failing = last?.validation.failingMeals ?? [];
      const m = failing.length ? failing[(attempt - 1) % failing.length] : (attempt - 1) % slots.length;
      offsets[m] += 1;
    }
    const recipes = cands.map((list, m) => (list.length ? list[(base[m] + offsets[m]) % list.length] : undefined));
    const built = buildDay(recipes, types, slots, t, input.ctx);
    last = built;
    if (!best || built.score < best.score) best = built;
    if (built.validation.ok) break;
  }

  const names = slots.map((s) => MealSlotLabel[s]);
  const times = slots.map((s, i) => timeForSlot(s, input.ctx.trainingTime, i));
  // Dinner comes at least 2.5 h after the post-workout meal on evening-training days.
  const post = slots.indexOf("postWorkout");
  const dinner = slots.indexOf("dinner");
  if (post >= 0 && dinner >= 0) times[dinner] = Math.max(times[dinner], times[post] + 150);
  return {
    id: uuid(),
    localDate: input.date,
    weekday: input.weekday,
    isTrainingDay: input.isTrainingDay,
    target: input.target,
    meals: toMeals(best!.items, slots, best!.recipeIds, names, times),
    solverMessage: messageFor(best!.validation),
  };
}

// ---------------------------------------------------------------------------
// Re-optimisation after swaps / locks
// ---------------------------------------------------------------------------

function workFromPlan(plan: MealPlanDay): WorkItem[] {
  const items: WorkItem[] = [];
  plan.meals.forEach((meal, m) => {
    const hasVeg = meal.items.some((i) => specForFood(i.food).role === "veg");
    for (const it of meal.items) {
      const spec = specForFood(it.food);
      const domain = spec.role === "supplement" ? [it.grams ?? it.servings ?? 0] : domainOf(spec, hasVeg);
      const amount = it.grams ?? it.servings ?? 0;
      items.push({ id: it.id, meal: m, spec, domain, amount: spec.role === "supplement" ? amount : snap(domain, amount), locked: it.isLocked || spec.role === "supplement" });
    }
  });
  return items;
}

/** Re-fit unlocked portions to the day's targets, then validate. Keeps every food and lock as chosen. */
export function reoptimizePlanDay(plan: MealPlanDay, extraMessage?: string): MealPlanDay {
  const t = targetsOf(plan.target);
  const items = workFromPlan(plan);
  optimize(items, t, plan.meals.length);
  const v = validateWork(items, t, plan.meals.length);
  const meals = plan.meals.map((meal, m) => ({
    ...meal,
    items: items.filter((it) => it.meal === m && it.amount > 0).map(toMealItem),
  }));
  const msg = [extraMessage, messageFor(v)].filter(Boolean).join(" ");
  return { ...plan, meals, solverMessage: msg || undefined };
}

export function validatePlanDay(plan: MealPlanDay): PlanValidation {
  return validateWork(workFromPlan(plan), targetsOf(plan.target), plan.meals.length);
}

/** Raw/dry planner foods that can replace an item of this role (custom foods of the same role too). */
export function swapOptionsFor(item: MealItem, customFoods: FoodItem[], allergies: FoodAllergy[]): FoodItem[] {
  const role = specForFood(item.food).role;
  const banned: FoodAllergy[] = allergies.filter((a) => a !== "none");
  const library = PLANNER_FOODS.filter((f) => f.role === role && f.key !== "eggWhites").map(plannerFoodItem);
  const custom = customFoods.filter((f) => specForFood(f).role === role && f.measurementState !== "cooked");
  return [...library, ...custom].filter((f) => f.id !== item.food.id && !f.allergenTags.some((a) => banned.includes(a)));
}

/** Map a food to the version the planner weighs: cooked catalog entries → their raw/dry planner entry. */
export function rawEquivalent(f: FoodItem): FoodItem | undefined {
  if (BY_ID.has(f.id.toLowerCase())) return plannerFoodItem(BY_ID.get(f.id.toLowerCase())!);
  if (f.measurementState !== "cooked") return f;
  const match = PLANNER_FOODS.find((p) => p.name.toLowerCase() === f.name.toLowerCase());
  return match ? plannerFoodItem(match) : undefined;
}

/** Swap one ingredient: keep roughly the same calories, re-fit the day, validate. */
export function swapPlanItem(plan: MealPlanDay, itemId: string, replacement: FoodItem): { plan: MealPlanDay; message?: string } {
  const raw = rawEquivalent(replacement);
  if (!raw) return { plan, message: `${replacement.name} is a cooked entry with no raw version — pick a raw or dry food so it can be weighed raw.` };
  let swapped = false;
  const meals = plan.meals.map((meal) => {
    const target = meal.items.find((i) => i.id === itemId);
    if (!target) return meal;
    const spec = specForFood(raw);
    const oldSpec = specForFood(target.food);
    const isEggGroup = oldSpec.group === "egg";
    const domain = domainOf(spec, meal.items.some((i) => specForFood(i.food).role === "veg"));
    const perAmount = macrosOf(spec, spec.unit ? 1 : spec.servingGrams).kcal / (spec.unit ? 1 : spec.servingGrams);
    const amount = snap(domain, perAmount > 0 ? target.calories / perAmount : spec.min);
    const replacementItem = toMealItem({ id: target.id, meal: 0, spec, domain, amount, locked: target.isLocked });
    swapped = true;
    // Replacing one half of an egg combo with another protein replaces the whole protein source.
    const items = meal.items
      .filter((i) => !(isEggGroup && spec.role === "protein" && i.id !== itemId && specForFood(i.food).group === "egg"))
      .map((i) => (i.id === itemId ? replacementItem : i));
    return { ...meal, recipeId: undefined, items };
  });
  if (!swapped) return { plan };
  const note = replacement.measurementState === "cooked" ? `Swapped to raw ${raw.name} — weigh it raw.` : undefined;
  return { plan: reoptimizePlanDay({ ...plan, meals }, note) };
}

/** Replace a whole meal with the next suitable recipe of its type, then re-fit the day. */
export function swapPlanMeal(plan: MealPlanDay, mealId: string, ctx: PlannerContext): MealPlanDay {
  const m = plan.meals.findIndex((x) => x.id === mealId);
  if (m < 0) return plan;
  const meal = plan.meals[m];
  const type = mealTypeFor(meal.slot);
  const list = candidatesFor(type, ctx);
  if (!list.length) return plan;
  const usedElsewhere = new Set(
    plan.meals
      .filter((_, i) => i !== m)
      .map((x) => (x.recipeId ? RECIPE_BY_ID.get(x.recipeId)?.protein[0] : undefined))
      .filter(Boolean),
  );
  const current = meal.recipeId ? list.findIndex((r) => r.id === meal.recipeId) : -1;
  let next = list[(current + 1) % list.length];
  for (let k = 1; k <= list.length; k++) {
    const r = list[(current + k + list.length) % list.length];
    if (r.id !== meal.recipeId && !usedElsewhere.has(r.protein[0])) {
      next = r;
      break;
    }
  }
  const t = targetsOf(plan.target);
  const work = itemsForRecipe(next, 0, t.p / plan.meals.length);
  if (meal.slot === "preWorkout" && ctx.intraWorkoutEnabled) work.push(...intraItems(0, ctx));
  const fresh = work.filter((it) => it.amount > 0).map(toMealItem);
  const meals = plan.meals.map((x, i) => (i === m ? { ...x, recipeId: next.id, items: fresh } : x));
  return reoptimizePlanDay({ ...plan, meals });
}

export const plannerFoodById = (id: string) => BY_ID.get(id.toLowerCase());
