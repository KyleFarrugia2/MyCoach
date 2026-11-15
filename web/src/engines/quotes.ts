/**
 * Quote of the Day. The bundled collection (public/data/quotes.json, built by Scripts/build_quotes.py) is
 * shuffled once with a fixed seed, then walked one quote per calendar day — so every quote appears once
 * before any repeats, and iOS (QuoteOfTheDay.swift) shows the same quote on the same day.
 */
import type { Day } from "../core/dates";

export interface Quote {
  t: string;
  a: string;
}

export const QUOTE_SEED = 20261115;

/** mulberry32 — tiny deterministic PRNG, reproduced bit-for-bit in Swift. */
export function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Fisher–Yates order of quote indexes for the seed. */
export function shuffledOrder(count: number, seed = QUOTE_SEED): number[] {
  const order = Array.from({ length: count }, (_, i) => i);
  const rand = mulberry32(seed);
  for (let i = count - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [order[i], order[j]] = [order[j], order[i]];
  }
  return order;
}

/** Whole days since 2026-01-01 for a local YYYY-MM-DD (calendar arithmetic, timezone-independent). */
export function dayNumber(day: Day): number {
  const [y, m, d] = day.split("-").map(Number);
  return Math.round((Date.UTC(y, m - 1, d) - Date.UTC(2026, 0, 1)) / 86_400_000);
}

export function quoteIndexFor(day: Day, count: number, order = shuffledOrder(count)): number {
  const n = ((dayNumber(day) % count) + count) % count;
  return order[n];
}

let cache: Promise<Quote[]> | undefined;

export function loadQuotes(): Promise<Quote[]> {
  cache ??= fetch("./data/quotes.json")
    .then((r) => (r.ok ? (r.json() as Promise<Quote[]>) : []))
    .catch(() => {
      cache = undefined;
      return [];
    });
  return cache;
}
