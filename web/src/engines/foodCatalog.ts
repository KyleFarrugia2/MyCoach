import type { FoodAllergy, FoodItem, MeasurementState } from "../core/models";

/**
 * Port of BundledFoodCatalog in FoodCatalogProvider.swift — local generic staples.
 * Values are per listed serving. Dry vs cooked entries are separate on purpose.
 * Stable IDs keep meal plans / logs consistent across sessions.
 */
type Row = [
  id: string,
  name: string,
  serving: string,
  grams: number,
  kcal: number,
  protein: number,
  carbs: number,
  fat: number,
  state: MeasurementState,
  opts?: { fibre?: number; allergens?: FoodAllergy[]; favorite?: boolean },
];

const ROWS: Row[] = [
  // Proteins
  ["A1000001-0001-4000-8000-000000000001", "Chicken Breast", "100 g raw", 100, 110, 23.1, 0, 1.2, "raw", { favorite: true }],
  ["A1000001-0001-4000-8000-000000000002", "Chicken Breast", "100 g cooked", 100, 165, 31.0, 0, 3.6, "cooked", { favorite: true }],
  ["A1000001-0001-4000-8000-000000000003", "Lean Beef (5% fat)", "100 g raw", 100, 137, 21.4, 0, 5.0, "raw"],
  ["A1000001-0001-4000-8000-000000000004", "Lean Beef (5% fat)", "100 g cooked", 100, 176, 26.0, 0, 8.0, "cooked"],
  ["A1000001-0001-4000-8000-000000000005", "Turkey Breast", "100 g raw", 100, 104, 24.0, 0, 0.7, "raw"],
  ["A1000001-0001-4000-8000-000000000006", "White Fish (cod)", "100 g raw", 100, 82, 17.8, 0, 0.7, "raw", { allergens: ["fish"] }],
  ["A1000001-0001-4000-8000-000000000007", "Egg", "1 large (50 g edible)", 50, 72, 6.3, 0.4, 4.8, "raw", { allergens: ["eggs"], favorite: true }],
  ["A1000001-0001-4000-8000-000000000008", "Egg Whites", "100 g liquid", 100, 52, 10.9, 0.7, 0.2, "raw", { allergens: ["eggs"], favorite: true }],
  ["A1000001-0001-4000-8000-000000000009", "Greek Yogurt (0% fat)", "100 g", 100, 59, 10.3, 3.6, 0.4, "prepared", { allergens: ["dairy"], favorite: true }],
  ["A1000001-0001-4000-8000-00000000000A", "Cottage Cheese (low fat)", "100 g", 100, 72, 12.4, 2.7, 1.0, "prepared", { allergens: ["dairy"] }],
  ["A1000001-0001-4000-8000-00000000000B", "Whey Protein Powder", "30 g scoop", 30, 120, 24.0, 2.0, 1.5, "serving", { allergens: ["dairy"] }],
  ["A1000001-0001-4000-8000-00000000000C", "Tuna (canned in water, drained)", "100 g", 100, 86, 19.0, 0, 1.0, "prepared", { allergens: ["fish"] }],
  // Carbs — dry and cooked are SEPARATE
  ["A1000002-0001-4000-8000-000000000001", "White Rice", "100 g dry", 100, 365, 7.1, 80.0, 0.7, "dry", { fibre: 1.3, favorite: true }],
  ["A1000002-0001-4000-8000-000000000002", "White Rice", "100 g cooked", 100, 130, 2.7, 28.2, 0.3, "cooked", { fibre: 0.4, favorite: true }],
  ["A1000002-0001-4000-8000-000000000003", "Brown Rice", "100 g dry", 100, 370, 7.9, 77.2, 2.9, "dry", { fibre: 3.5 }],
  ["A1000002-0001-4000-8000-000000000004", "Brown Rice", "100 g cooked", 100, 112, 2.3, 23.5, 0.8, "cooked", { fibre: 1.8 }],
  ["A1000002-0001-4000-8000-000000000005", "Potato", "100 g raw", 100, 77, 2.0, 17.5, 0.1, "raw", { fibre: 2.1 }],
  ["A1000002-0001-4000-8000-000000000006", "Potato", "100 g boiled", 100, 87, 1.9, 20.1, 0.1, "cooked", { fibre: 1.8 }],
  ["A1000002-0001-4000-8000-000000000007", "Sweet Potato", "100 g raw", 100, 86, 1.6, 20.1, 0.1, "raw", { fibre: 3.0 }],
  ["A1000002-0001-4000-8000-000000000008", "Pasta", "100 g dry", 100, 371, 13.0, 74.7, 1.5, "dry", { fibre: 3.2, allergens: ["glutenWheat"], favorite: true }],
  ["A1000002-0001-4000-8000-000000000009", "Pasta", "100 g cooked", 100, 131, 5.0, 25.0, 1.1, "cooked", { fibre: 1.8, allergens: ["glutenWheat"] }],
  ["A1000002-0001-4000-8000-00000000000A", "Oats (rolled)", "100 g dry", 100, 389, 16.9, 66.3, 6.9, "dry", { fibre: 10.6, allergens: ["glutenWheat"], favorite: true }],
  ["A1000002-0001-4000-8000-00000000000B", "Oats (rolled)", "100 g cooked with water", 100, 71, 2.5, 12.0, 1.5, "cooked", { fibre: 1.7, allergens: ["glutenWheat"] }],
  ["A1000002-0001-4000-8000-00000000000C", "Bread (white)", "1 slice (30 g)", 30, 79, 2.7, 14.7, 1.0, "prepared", { fibre: 0.8, allergens: ["glutenWheat"] }],
  ["A1000002-0001-4000-8000-00000000000D", "Banana", "100 g edible", 100, 89, 1.1, 22.8, 0.3, "raw", { fibre: 2.6, favorite: true }],
  ["A1000002-0001-4000-8000-00000000000E", "Apple", "100 g edible", 100, 52, 0.3, 13.8, 0.2, "raw", { fibre: 2.4 }],
  ["A1000002-0001-4000-8000-00000000000F", "Mixed Berries", "100 g", 100, 57, 0.7, 14.5, 0.3, "raw", { fibre: 2.4 }],
  ["A1000002-0001-4000-8000-000000000010", "Mixed Vegetables", "100 g raw", 100, 35, 2.0, 7.0, 0.2, "raw", { fibre: 2.5 }],
  ["A1000002-0001-4000-8000-000000000011", "Broccoli", "100 g raw", 100, 34, 2.8, 6.6, 0.4, "raw", { fibre: 2.6 }],
  // Fats
  ["A1000003-0001-4000-8000-000000000001", "Peanut Butter", "32 g (2 tbsp)", 32, 188, 8.0, 6.0, 16.0, "serving", { fibre: 2.0, allergens: ["peanuts"], favorite: true }],
  ["A1000003-0001-4000-8000-000000000002", "Olive Oil", "14 g (1 tbsp)", 14, 119, 0, 0, 13.5, "serving"],
  ["A1000003-0001-4000-8000-000000000003", "Almonds", "28 g (1 oz)", 28, 164, 6.0, 6.1, 14.2, "serving", { fibre: 3.5, allergens: ["treeNuts"] }],
  ["A1000003-0001-4000-8000-000000000004", "Avocado", "100 g edible", 100, 160, 2.0, 8.5, 14.7, "raw", { fibre: 6.7 }],
  // Intra / supplements
  ["A1000004-0001-4000-8000-000000000001", "Dextrose", "100 g powder", 100, 380, 0, 95.0, 0, "dry", { favorite: true }],
  ["A1000004-0001-4000-8000-000000000002", "Essential Amino Acids (EAAs)", "10 g serving", 10, 40, 10.0, 0, 0, "serving", { favorite: true }],
  ["A1000004-0001-4000-8000-000000000003", "Creatine Monohydrate", "5 g", 5, 0, 0, 0, 0, "serving"],
];

export const BUNDLED_FOODS: FoodItem[] = ROWS.map(([id, name, serving, grams, kcal, p, c, f, state, opts]) => ({
  id: id.toLowerCase(),
  name,
  source: "bundledGeneric",
  servingDescription: serving,
  servingGrams: grams,
  calories: kcal,
  proteinGrams: p,
  carbohydrateGrams: c,
  fatGrams: f,
  fibreGrams: opts?.fibre,
  measurementState: state,
  isCustom: false,
  isVerified: true,
  allergenTags: opts?.allergens ?? [],
  isFavorite: opts?.favorite ?? false,
}));

function matches(item: FoodItem, tokens: string[], includeState: boolean): boolean {
  const parts = [item.name, item.brand ?? "", item.servingDescription, item.barcode ?? ""];
  if (includeState) parts.push(item.measurementState);
  const haystack = parts.join(" ").toLowerCase();
  return tokens.every((t) => haystack.includes(t));
}

/** Custom foods first, then bundled generics — deduplicated by id (CompositeFoodCatalog). */
export function searchFoods(query: string, customFoods: FoodItem[]): FoodItem[] {
  const tokens = query.trim().toLowerCase().split(/\s+/).filter(Boolean);
  const custom = tokens.length ? customFoods.filter((f) => matches(f, tokens, false)) : customFoods;
  const bundled = tokens.length ? BUNDLED_FOODS.filter((f) => matches(f, tokens, true)) : BUNDLED_FOODS;
  const seen = new Set<string>();
  return [...custom, ...bundled].filter((f) => (seen.has(f.id) ? false : (seen.add(f.id), true)));
}
