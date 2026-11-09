import type { FoodAllergy, FoodItem } from "../core/models";
import { uuid } from "../core/models";

/**
 * Barcode → food lookup. Port target: `MyCoach/Services/FoodDatabase/BarcodeLookup.swift` (keep in sync).
 *
 * Product data comes from Open Food Facts (https://openfoodfacts.org) — an open, community-maintained
 * database (ODbL). Values are user-contributed, so scanned foods are always shown to the user to check
 * against the label before they're saved, and are never marked "verified".
 */
export const OPEN_FOOD_FACTS_ATTRIBUTION = "Product data from Open Food Facts (ODbL) — check it against the label.";

const OFF_FIELDS = "product_name,product_name_en,generic_name,brands,nutriments,allergens_tags";

/** Digits only; accepts EAN-8, UPC-A (12), EAN-13 and GTIN-14 with a valid check digit. */
export function normalizeBarcode(raw: string): string | undefined {
  const code = raw.replace(/\D/g, "");
  if (![8, 12, 13, 14].includes(code.length)) return undefined;
  return isValidGTIN(code) ? code : undefined;
}

/** GS1 mod-10 check digit (weights 3,1,3,… from the right, excluding the check digit). */
export function isValidGTIN(code: string): boolean {
  if (!/^\d+$/.test(code) || code.length < 8) return false;
  const digits = code.split("").map(Number);
  const check = digits.pop()!;
  let sum = 0;
  digits.reverse().forEach((d, i) => (sum += d * (i % 2 === 0 ? 3 : 1)));
  return (10 - (sum % 10)) % 10 === check;
}

const ALLERGEN_MAP: Record<string, FoodAllergy> = {
  "en:milk": "dairy",
  "en:eggs": "eggs",
  "en:peanuts": "peanuts",
  "en:nuts": "treeNuts",
  "en:fish": "fish",
  "en:crustaceans": "shellfish",
  "en:molluscs": "shellfish",
  "en:gluten": "glutenWheat",
  "en:soybeans": "soy",
};

function num(v: unknown): number | undefined {
  const n = typeof v === "string" ? Number(v.replace(",", ".")) : typeof v === "number" ? v : NaN;
  return Number.isFinite(n) && n >= 0 ? n : undefined;
}

function text(v: unknown): string | undefined {
  return typeof v === "string" && v.trim() ? v.trim() : undefined;
}

export interface ParsedProduct {
  food: FoodItem;
  /** All of calories, protein, carbs and fat were present. */
  complete: boolean;
}

/** Map an Open Food Facts v2 product response to a per-100 g FoodItem. */
export function parseOpenFoodFacts(json: unknown, barcode: string): ParsedProduct | undefined {
  const root = json as { status?: number; product?: Record<string, unknown> } | null;
  if (!root || root.status !== 1 || !root.product) return undefined;
  const p = root.product;
  const n = (p.nutriments ?? {}) as Record<string, unknown>;
  const kj = num(n["energy-kj_100g"]) ?? num(n["energy_100g"]);
  const kcalRaw = num(n["energy-kcal_100g"]) ?? (kj !== undefined ? kj / 4.184 : undefined);
  const kcal = kcalRaw !== undefined ? Math.round(kcalRaw * 10) / 10 : undefined;
  const protein = num(n["proteins_100g"]);
  const carbs = num(n["carbohydrates_100g"]);
  const fat = num(n["fat_100g"]);
  const fibre = num(n["fiber_100g"]);
  const brand = text(p.brands)?.split(",")[0]?.trim();
  const allergens = Array.isArray(p.allergens_tags)
    ? [...new Set((p.allergens_tags as unknown[]).map((t) => ALLERGEN_MAP[String(t)]).filter(Boolean))]
    : [];

  const food: FoodItem = {
    id: uuid(),
    name: text(p.product_name_en) ?? text(p.product_name) ?? text(p.generic_name) ?? "Scanned product",
    brand,
    source: "barcode",
    servingDescription: "100 g",
    servingGrams: 100,
    calories: kcal,
    proteinGrams: protein,
    carbohydrateGrams: carbs,
    fatGrams: fat,
    fibreGrams: fibre,
    measurementState: "package",
    barcode,
    isCustom: true,
    isVerified: false,
    allergenTags: allergens,
    isFavorite: false,
  };
  return { food, complete: kcal !== undefined && protein !== undefined && carbs !== undefined && fat !== undefined };
}

export type BarcodeLookupResult =
  | { status: "found"; product: ParsedProduct }
  | { status: "notFound" }
  | { status: "offline" | "error"; message: string };

export async function lookupBarcode(
  barcode: string,
  fetchImpl: typeof fetch = fetch,
  signal?: AbortSignal,
): Promise<BarcodeLookupResult> {
  if (typeof navigator !== "undefined" && navigator.onLine === false) {
    return { status: "offline", message: "You're offline — enter the nutrition from the label instead." };
  }
  try {
    const res = await fetchImpl(
      `https://world.openfoodfacts.org/api/v2/product/${encodeURIComponent(barcode)}.json?fields=${OFF_FIELDS}`,
      { signal, headers: { Accept: "application/json" } },
    );
    if (res.status === 404) return { status: "notFound" };
    if (!res.ok) return { status: "error", message: `Lookup failed (${res.status}). Enter the label values instead.` };
    const parsed = parseOpenFoodFacts(await res.json(), barcode);
    return parsed ? { status: "found", product: parsed } : { status: "notFound" };
  } catch (e) {
    if ((e as Error).name === "AbortError") throw e;
    return { status: "error", message: "Couldn't reach the product database. Enter the label values instead." };
  }
}

/** Blank food for a barcode the database doesn't know — the user fills in the label. */
export function blankScannedFood(barcode: string): FoodItem {
  return {
    id: uuid(),
    name: "",
    source: "barcode",
    servingDescription: "100 g",
    servingGrams: 100,
    measurementState: "package",
    barcode,
    isCustom: true,
    isVerified: false,
    allergenTags: [],
    isFavorite: false,
  };
}
