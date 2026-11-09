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
