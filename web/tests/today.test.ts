import { describe, expect, it } from "vitest";
import { cardioRecommendation } from "../src/engines/cardio";
import { dayType, takeEmergencyRest, undoEmergencyRest } from "../src/engines/dayPlan";
import { dayNumber, mulberry32, quoteIndexFor, shuffledOrder } from "../src/engines/quotes";
import { parseHours } from "../src/engines/units";

describe("emergency rest days", () => {
  const schedule = [1, 2, 4, 5] as const; // Mon Tue Thu Fri

  it("turns today into rest and moves the session to the next free rest day this week", () => {
    // Tue 2026-11-10 → Wed is between Tue(rest now) and Thu(training): Wed ok (Tue is rest after override).
    const r = takeEmergencyRest([...schedule], [], "2026-11-10");
    expect(dayType([...schedule], r.overrides, "2026-11-10")).toBe("rest");
    expect(r.movedTo).toBe("2026-11-11");
    expect(dayType([...schedule], r.overrides, "2026-11-11")).toBe("training");
  });

  it("prefers short training runs, never creates 4+ in a row, and skips if nothing fits", () => {
    // Mon/Wed/Fri: emergency on Mon → Tue would make Tue-Wed (2), fine and earliest.
    expect(takeEmergencyRest([1, 3, 5] as never, [], "2026-11-09").movedTo).toBe("2026-11-10");
    // Mon–Sat schedule, emergency on Fri: Sun would join Sat→Thu into a 7-day streak → skipped.
    const six = [1, 2, 3, 4, 5, 6];
    expect(takeEmergencyRest(six as never, [], "2026-11-13").movedTo).toBeUndefined();
    // Emergency on Sun with Sun scheduled: no later day this week → skipped.
    const r2 = takeEmergencyRest([7] as never, [], "2026-11-15");
    expect(r2.movedTo).toBeUndefined();
    expect(dayType([7] as never, r2.overrides, "2026-11-15")).toBe("rest");
  });

  it("undo restores both days and is a no-op on rest days", () => {
    const r = takeEmergencyRest([...schedule], [], "2026-11-10");
    const undone = undoEmergencyRest(r.overrides, "2026-11-10");
    expect(undone).toEqual([]);
    expect(takeEmergencyRest([...schedule], [], "2026-11-11").overrides).toEqual([]); // Wed is already rest
  });
});

describe("cardio coach", () => {
  const base = { goal: "cut" as const, isTrainingDay: false, emergencyRest: false, stepsSoFar: 4000, stepTarget: 9000 };

  it("recommends recovery only after ≤5 h sleep or an emergency rest day", () => {
    expect(cardioRecommendation({ ...base, sleepHours: 4.5 }).tone).toBe("recovery");
    expect(cardioRecommendation({ ...base, emergencyRest: true }).tone).toBe("recovery");
  });

  it("scales with goal, day type and the adaptive model", () => {
    expect(cardioRecommendation({ ...base }).minutes).toBe(35);
    expect(cardioRecommendation({ ...base, isTrainingDay: true }).minutes).toBe(20);
    expect(cardioRecommendation({ ...base, goal: "gain", isTrainingDay: true }).minutes).toBe(0);
    expect(cardioRecommendation({ ...base, predictedKgPerWeek: -0.2, targetKgPerWeek: -0.6 }).minutes).toBe(45);
    expect(cardioRecommendation({ ...base, predictedKgPerWeek: -1.1, targetKgPerWeek: -0.6 }).minutes).toBe(25);
    expect(cardioRecommendation({ ...base, sleepHours: 6 }).minutes).toBe(25);
  });
});

describe("quote of the day", () => {
  it("visits every quote once before repeating, deterministically", () => {
    const order = shuffledOrder(929);
    expect(new Set(order).size).toBe(929);
    expect(shuffledOrder(929)).toEqual(order);
    const days = Array.from({ length: 929 }, (_, i) => quoteIndexFor(dayAfter("2026-11-15", i), 929, order));
    expect(new Set(days).size).toBe(929);
  });

  it("matches the values the Swift port checks", () => {
    const r = mulberry32(20261115);
    console.log("mulberry32 first values:", [r(), r(), r()].map((x) => Math.floor(x * 4294967296)));
    console.log("dayNumber 2026-11-15:", dayNumber("2026-11-15"));
    console.log("indexes:", ["2026-01-01", "2026-11-15", "2027-03-01"].map((d) => quoteIndexFor(d, 929)));
    expect(dayNumber("2026-01-01")).toBe(0);
    expect(dayNumber("2026-11-15")).toBe(318);
  });
});

describe("sleep input", () => {
  it("accepts decimals, commas and h:mm", () => {
    expect(parseHours("7.5")).toBe(7.5);
    expect(parseHours("7,5")).toBe(7.5);
    expect(parseHours("7:30")).toBe(7.5);
    expect(parseHours("6h45")).toBe(6.75);
    expect(parseHours("8h")).toBe(8);
    expect(parseHours("25")).toBeUndefined();
    expect(parseHours("7:75")).toBeUndefined();
    expect(parseHours("")).toBeUndefined();
  });
});

function dayAfter(day: string, n: number): string {
  const [y, m, d] = day.split("-").map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d + n));
  return dt.toISOString().slice(0, 10);
}
