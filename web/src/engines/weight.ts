import { CoachingConfig } from "../core/config";
import { type Day, weekEnd, weekStart } from "../core/dates";
import type { CoachingWeek, WeekCompleteness, WeeklyRateOfChange, WeightEntry } from "../core/models";

/** Port of WeightAnalytics in WeightModels.swift. */

/** Average of valid morning check-ins only — never fabricate missing days. */
export function weeklyAverage(entries: WeightEntry[]): number | undefined {
  const valid = entries.filter((e) => e.isOfficialMorningCheckIn);
  if (valid.length === 0) return undefined;
  return valid.reduce((s, e) => s + e.weightKg, 0) / valid.length;
}

export function makeWeek(
  containing: Day,
  entries: WeightEntry[],
  minimumForAdjustment: number = CoachingConfig.minimumWeighInsForAdjustment,
): CoachingWeek {
  const start = weekStart(containing);
  const end = weekEnd(containing);
  const inWeek = entries.filter((e) => e.isOfficialMorningCheckIn && e.localDate >= start && e.localDate <= end);
  // One official entry per local day (latest wins if duplicates slipped through).
  const byDay = new Map<Day, WeightEntry>();
  for (const e of [...inWeek].sort((a, b) => a.timestamp.localeCompare(b.timestamp))) byDay.set(e.localDate, e);
  const unique = [...byDay.values()].sort((a, b) => a.localDate.localeCompare(b.localDate));
  const count = unique.length;
  let completeness: WeekCompleteness;
  if (count === 0) completeness = "empty";
  else if (count < minimumForAdjustment) completeness = "insufficientForAdjustment";
  else if (count < 7) completeness = "sufficientForAdjustment";
  else completeness = "complete";
  return { startDate: start, endDate: end, entries: unique, averageKg: weeklyAverage(unique), entryCount: count, completeness };
}

export function rateOfChange(previous: CoachingWeek, current: CoachingWeek): WeeklyRateOfChange | undefined {
  const prev = previous.averageKg;
  const curr = current.averageKg;
  if (prev === undefined || curr === undefined || prev === 0) return undefined;
  const absolute = curr - prev;
  return {
    previousAverageKg: prev,
    currentAverageKg: curr,
    absoluteChangeKg: absolute,
    percentChange: (absolute / prev) * 100,
  };
}
