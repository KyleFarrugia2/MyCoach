/**
 * Local calendar-day helpers. A "Day" is a `YYYY-MM-DD` string in the user's local
 * timezone — the web equivalent of `Calendar.startOfDay(for:)` dates in the Swift app.
 * Coaching weeks run Monday–Sunday.
 */
export type Day = string;

/** 1 = Monday … 7 = Sunday (matches the Swift `Weekday` raw values). */
export type Weekday = 1 | 2 | 3 | 4 | 5 | 6 | 7;

const pad = (n: number) => String(n).padStart(2, "0");

export function toDay(date: Date): Day {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

/** Parses a Day as local midnight. */
export function fromDay(day: Day): Date {
  const [y, m, d] = day.split("-").map(Number);
  return new Date(y, m - 1, d);
}

export function today(): Day {
  return toDay(new Date());
}

export function addDays(day: Day, n: number): Day {
  const d = fromDay(day);
  d.setDate(d.getDate() + n);
  return toDay(d);
}

export function addMonths(day: Day, n: number): Day {
  const d = fromDay(day);
  d.setMonth(d.getMonth() + n);
  return toDay(d);
}

export function weekdayOf(day: Day): Weekday {
  const js = fromDay(day).getDay(); // 0 = Sunday
  return (js === 0 ? 7 : js) as Weekday;
}

export function weekStart(day: Day): Day {
  return addDays(day, -(weekdayOf(day) - 1));
}

export function weekEnd(day: Day): Day {
  return addDays(weekStart(day), 6);
}

export function datesInWeek(day: Day): Day[] {
  const start = weekStart(day);
  return Array.from({ length: 7 }, (_, i) => addDays(start, i));
}

/** Whole years between a birth day and now. */
export function ageYears(dob: Day, now: Date = new Date()): number {
  const b = fromDay(dob);
  let age = now.getFullYear() - b.getFullYear();
  const m = now.getMonth() - b.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < b.getDate())) age--;
  return age;
}

// Formatting --------------------------------------------------------------

export function formatLong(day: Day): string {
  return fromDay(day).toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" });
}

export function formatMedium(day: Day): string {
  return fromDay(day).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" });
}

export function formatWithWeekday(day: Day): string {
  return fromDay(day).toLocaleDateString(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

export function formatMonthYear(day: Day): string {
  return fromDay(day).toLocaleDateString(undefined, { month: "long", year: "numeric" });
}

export function formatClock(totalSeconds: number): string {
  const s = Math.max(0, Math.floor(totalSeconds));
  return `${Math.floor(s / 60)}:${pad(s % 60)}`;
}

export function formatMinutesOfDay(minutes: number): string {
  return `${pad(Math.floor(minutes / 60))}:${pad(minutes % 60)}`;
}
