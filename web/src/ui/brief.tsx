/**
 * The app's signature layout pieces for Today, Log and Meal Plan (mirrors MCBrief.swift on iOS):
 *   - Brief      — the navy summary panel with the logo's cut corner and chevron watermark
 *   - Fuel       — calories ring + macro meters, drawn on the brief
 *   - WeekStrip  — seven-day navigator shared by all three screens
 *   - Hex        — hexagon marker (icon chips, timeline nodes), from the logo's outline
 *   - Section    — eyebrow-labelled group
 */
import type { ReactNode } from "react";
import { type Day, fromDay } from "../core/dates";
import type { MacroGrams } from "../core/models";
import { Icon, type IconName } from "./kit";

export function Eyebrow({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <span className={`eyebrow ${className}`}>{children}</span>;
}

export function Section({
  label,
  aside,
  children,
  className = "",
}: {
  label: string;
  aside?: ReactNode;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section className={`section ${className}`} aria-label={label}>
      <div className="section-head">
        <h2 className="eyebrow section-label">{label}</h2>
        {aside}
      </div>
      {children}
    </section>
  );
}

/** Hexagon marker — an icon, a number, or empty. */
export function Hex({
  icon,
  children,
  tone = "primary",
  size = 34,
  solid,
}: {
  icon?: IconName;
  children?: ReactNode;
  tone?: "primary" | "success" | "warning" | "muted" | "protein" | "carbs" | "fat";
  size?: number;
  solid?: boolean;
}) {
  return (
    <span className={`hex tone-${tone}${solid ? " solid" : ""}`} style={{ width: size, height: size }} aria-hidden="true">
      {icon ? <Icon name={icon} size={Math.round(size * 0.5)} /> : children}
    </span>
  );
}

/** Navy summary panel. `children` are laid out in a column on the ink background. */
export function Brief({ children, className = "", label }: { children: ReactNode; className?: string; label?: string }) {
  return (
    <section className={`brief ${className}`} aria-label={label}>
      <div className="brief-inner">
        <svg className="brief-mark" viewBox="0 0 200 200" aria-hidden="true">
          {/* The logo's roof chevron, repeated. */}
          <path d="M100 20 L190 92 L172 92 L100 46 L28 92 L10 92 Z" />
          <path d="M100 78 L190 150 L172 150 L100 104 L28 150 L10 150 Z" />
        </svg>
        {children}
      </div>
    </section>
  );
}

function MiniRing({ progress, size = 84, over }: { progress: number; size?: number; over?: boolean }) {
  const stroke = 9;
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const p = Math.min(Math.max(progress, 0), 1);
  return (
    <svg className="fuel-ring" width={size} height={size} aria-hidden="true">
      <circle cx={size / 2} cy={size / 2} r={r} fill="none" strokeWidth={stroke} className="track" />
      <circle
        cx={size / 2}
        cy={size / 2}
        r={r}
        fill="none"
        strokeWidth={stroke}
        strokeLinecap="round"
        strokeDasharray={c}
        strokeDashoffset={c * (1 - p)}
        className={over ? "value over" : "value"}
      />
    </svg>
  );
}

const MACROS = [
  ["protein", "Protein"],
  ["carbohydrates", "Carbs"],
  ["fat", "Fat"],
] as const;

/**
 * Calories + macros against a target.
 *  - mode "eaten": the big number is what's been eaten (Today, Log)
 *  - mode "plan":  the big number is the target, with the planned total beside it (Meal Plan)
 */
/** P / C / F with the macro colours, for light surfaces. */
export function MacroChips({ macros }: { macros: MacroGrams }) {
  return (
    <span className="macro-chips">
      {MACROS.map(([key, label]) => (
        <span key={key} className={`m-${key}`}>
          <i />
          {label[0]} {Math.round(macros[key])} g
        </span>
      ))}
    </span>
  );
}

export function Fuel({
  calories,
  target,
  macros,
  targetMacros,
  mode = "eaten",
  flush,
}: {
  calories: number;
  target: number;
  macros: MacroGrams;
  targetMacros: MacroGrams;
  mode?: "eaten" | "plan";
  /** No divider above — when the fuel block opens the brief. */
  flush?: boolean;
}) {
  const left = Math.round(target - calories);
  const over = left < 0;
  return (
    <div className={`fuel${flush ? " flush" : ""}`}>
      <div className="fuel-main">
        <div className="fuel-ring-wrap" aria-hidden="true">
          <MiniRing progress={target > 0 ? calories / target : 0} over={mode === "eaten" && over} />
          {/* Inside the ring: calories still to go (eaten vs target, or plan vs target). */}
          <span className={`fuel-pct stacked${mode === "eaten" && over ? " over" : ""}`}>
            {Math.abs(left).toLocaleString()}
            <small>cals {over ? "over" : "left"}</small>
          </span>
        </div>
        <div className="fuel-figures">
          {mode === "eaten" ? (
            <>
              <span className="fuel-big">
                {Math.round(calories).toLocaleString()}
                <small> kcal eaten</small>
              </span>
              <span className="fuel-sub">of your {Math.round(target).toLocaleString()} kcal target</span>
            </>
          ) : (
            <>
              <span className="fuel-big">
                {Math.round(target).toLocaleString()}
                <small> kcal target</small>
              </span>
              <span className="fuel-sub">Plan totals {Math.round(calories).toLocaleString()} kcal</span>
            </>
          )}
        </div>
      </div>
      <div className="fuel-macros">
        {MACROS.map(([key, label]) => {
          const cur = macros[key];
          const tgt = Math.max(targetMacros[key], 1);
          const diff = Math.round(tgt - cur);
          return (
            <div key={key} className={`fuel-macro m-${key}`}>
              <span className="fuel-macro-label">{label}</span>
              <span className="fuel-macro-value">
                {Math.round(cur)}
                <small> / {Math.round(targetMacros[key])} g</small>
              </span>
              <span
                className="fuel-meter"
                role="progressbar"
                aria-label={label}
                aria-valuenow={Math.round(Math.min(cur / tgt, 1) * 100)}
              >
                <span style={{ width: `${Math.min(cur / tgt, 1) * 100}%` }} />
              </span>
              <span className="fuel-macro-note">{diff >= 0 ? `${diff} g left` : `${-diff} g over`}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

const letter = (day: Day) => fromDay(day).toLocaleDateString(undefined, { weekday: "narrow" });
const longDay = (day: Day) => fromDay(day).toLocaleDateString(undefined, { weekday: "long", day: "numeric", month: "long" });

/** Seven-day navigator. `marker` draws the small indicator under each date. */
export function WeekStrip({
  days,
  selected,
  today,
  onSelect,
  isDisabled,
  marker,
  onPrev,
  onNext,
  prevDisabled,
  nextDisabled,
}: {
  days: Day[];
  selected: Day;
  today: Day;
  onSelect: (d: Day) => void;
  isDisabled?: (d: Day) => boolean;
  marker?: (d: Day) => "training" | "rest" | "done" | "some" | "none";
  onPrev?: () => void;
  onNext?: () => void;
  prevDisabled?: boolean;
  nextDisabled?: boolean;
}) {
  return (
    <nav className="weekstrip" aria-label="Choose a day">
      {onPrev && (
        <button className="weekstrip-arrow" aria-label="Previous week" disabled={prevDisabled} onClick={onPrev}>
          <Icon name="chevronLeft" size={18} />
        </button>
      )}
      <div className="weekstrip-days">
        {days.map((d) => {
          const m = marker?.(d) ?? "none";
          const cls = ["weekstrip-day", d === selected ? "on" : "", d === today ? "today" : ""].filter(Boolean).join(" ");
          return (
            <button
              key={d}
              className={cls}
              disabled={isDisabled?.(d)}
              aria-pressed={d === selected}
              aria-label={d === today ? `Today, ${longDay(d)}` : longDay(d)}
              onClick={() => onSelect(d)}
            >
              <span className="weekstrip-letter">{letter(d)}</span>
              <span className="weekstrip-num">{Number(d.slice(8))}</span>
              <span className={`weekstrip-mark mark-${m}`} />
            </button>
          );
        })}
      </div>
      {onNext && (
        <button className="weekstrip-arrow" aria-label="Next week" disabled={nextDisabled} onClick={onNext}>
          <Icon name="chevronRight" size={18} />
        </button>
      )}
    </nav>
  );
}
