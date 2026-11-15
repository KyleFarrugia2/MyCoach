import type { WeightUnit } from "../core/models";
import { WeightUnitShort } from "../core/models";

export const UnitConversion = {
  poundsPerKilogram: 2.2046226218,
  cmPerInch: 2.54,
  inchesPerFoot: 12,

  kilograms(value: number, unit: WeightUnit): number {
    return unit === "kilogram" ? value : value / UnitConversion.poundsPerKilogram;
  },
  displayWeight(kg: number, unit: WeightUnit): number {
    return unit === "kilogram" ? kg : kg * UnitConversion.poundsPerKilogram;
  },
  centimeters(feet: number, inches: number): number {
    return (feet * UnitConversion.inchesPerFoot + inches) * UnitConversion.cmPerInch;
  },
};

export function formatWeight(kg: number, unit: WeightUnit): string {
  return `${UnitConversion.displayWeight(kg, unit).toFixed(1)} ${WeightUnitShort[unit]}`;
}

/** Parses user-typed decimals, accepting a comma as the decimal separator. */
export function parseDecimal(text: string): number | undefined {
  const trimmed = text.trim().replace(",", ".");
  if (trimmed === "") return undefined;
  const n = Number(trimmed);
  return Number.isFinite(n) ? n : undefined;
}

/** Sleep duration typed as "7.5", "7,5", "7:30", "7h30" or "7h" → hours. */
export function parseHours(text: string): number | undefined {
  const t = text.trim().toLowerCase().replace(/\s+/g, "");
  if (!t) return undefined;
  const hm = t.match(/^(\d{1,2})(?::|h)(\d{1,2})?m?$/);
  if (hm) {
    const h = Number(hm[1]);
    const m = hm[2] ? Number(hm[2]) : 0;
    return m < 60 && h <= 24 ? h + m / 60 : undefined;
  }
  const n = parseDecimal(t.replace(/h$/, ""));
  return n !== undefined && n >= 0 && n <= 24 ? n : undefined;
}
