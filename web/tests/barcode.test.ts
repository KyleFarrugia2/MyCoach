import { readFileSync } from "node:fs";
import { beforeAll, describe, expect, it } from "vitest";
import { isValidGTIN, lookupBarcode, normalizeBarcode, parseOpenFoodFacts } from "../src/engines/barcode";

const nutella = JSON.parse(readFileSync(new URL("./fixtures/off-nutella.json", import.meta.url), "utf-8"));

describe("barcode validation", () => {
  it("accepts valid EAN-13 / EAN-8 / UPC-A and rejects bad check digits", () => {
    expect(isValidGTIN("3017620422003")).toBe(true); // Nutella EAN-13
    expect(isValidGTIN("96385074")).toBe(true); // EAN-8
    expect(isValidGTIN("036000291452")).toBe(true); // UPC-A
    expect(isValidGTIN("3017620422004")).toBe(false);
    expect(normalizeBarcode(" 3017-6204-22003 ")).toBe("3017620422003");
    expect(normalizeBarcode("12345")).toBeUndefined();
  });
});

describe("Open Food Facts parsing", () => {
  it("maps a product to a per-100 g food with allergens", () => {
    const parsed = parseOpenFoodFacts(nutella, "3017620422003")!;
    expect(parsed.complete).toBe(true);
    const f = parsed.food;
    expect(f.name).toBe("Nutella");
    expect(f.brand).toBe("Ferrero");
    expect(f.servingGrams).toBe(100);
    expect(f.calories).toBe(539);
    expect(f.proteinGrams).toBe(6.3);
    expect(f.carbohydrateGrams).toBe(57.5);
    expect(f.fatGrams).toBe(30.9);
    expect(f.source).toBe("barcode");
    expect(f.barcode).toBe("3017620422003");
    expect(f.isVerified).toBe(false);
    expect(f.allergenTags.sort()).toEqual(["dairy", "soy", "treeNuts"]);
  });

  it("derives kcal from kJ, accepts string numbers, flags missing macros", () => {
    const p = parseOpenFoodFacts({ status: 1, product: { product_name: "Bar", nutriments: { energy_100g: "418.4", proteins_100g: "10" } } }, "96385074")!;
    expect(p.food.calories).toBe(100);
    expect(p.food.proteinGrams).toBe(10);
    expect(p.complete).toBe(false);
  });

  it("returns undefined for unknown products", () => {
    expect(parseOpenFoodFacts({ status: 0, status_verbose: "product not found" }, "96385074")).toBeUndefined();
  });
});

describe("lookup", () => {
  beforeAll(() => {
    (globalThis as { navigator?: unknown }).navigator ??= { onLine: true };
  });
  const fakeFetch = (status: number, body: unknown) =>
    (async () => new Response(JSON.stringify(body), { status })) as unknown as typeof fetch;

  it("handles found / not found / network failure", async () => {
    expect((await lookupBarcode("3017620422003", fakeFetch(200, nutella))).status).toBe("found");
    expect((await lookupBarcode("96385074", fakeFetch(404, { status: 0 }))).status).toBe("notFound");
    expect((await lookupBarcode("96385074", fakeFetch(200, { status: 0 }))).status).toBe("notFound");
    const failing = (async () => {
      throw new TypeError("network");
    }) as unknown as typeof fetch;
    expect((await lookupBarcode("96385074", failing)).status).toBe("error");
  });
});
