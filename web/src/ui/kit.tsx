import { type ReactNode, useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { formatMinutesOfDay } from "../core/dates";
import {
  type CoachAIStructuredResponse,
  type FoodItem,
  type MacroGrams,
  type Meal,
  type MealItem,
  foodSubtitle,
  mealCalories,
  mealMacros,
  measurementLabel,
  quantityLabel,
} from "../core/models";

// ---------------------------------------------------------------------------
// Icons (inline SVG, stroke-based, currentColor)
// ---------------------------------------------------------------------------

const paths: Record<string, ReactNode> = {
  sun: (
    <>
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
    </>
  ),
  fork: <path d="M7 2v8a2 2 0 0 0 4 0V2M9 10v12M17 2c-1.7 0-3 2.2-3 5s1.3 4 3 4v11" />,
  list: <path d="M8 6h13M8 12h13M8 18h13M3.5 6h.01M3.5 12h.01M3.5 18h.01" />,
  dumbbell: <path d="M6.5 6.5v11M17.5 6.5v11M3 9v6M21 9v6M6.5 12h11" />,
  chart: <path d="M3 3v18h18M7 15l4-4 3 3 6-6" />,
  chat: <path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.4A8 8 0 1 1 21 12Z" />,
  plus: <path d="M12 5v14M5 12h14" />,
  minus: <path d="M5 12h14" />,
  check: <path d="M5 12.5l4.5 4.5L19 7.5" />,
  close: <path d="M6 6l12 12M18 6L6 18" />,
  chevronLeft: <path d="M15 18l-6-6 6-6" />,
  chevronRight: <path d="M9 18l6-6-6-6" />,
  gear: (
    <>
      <circle cx="12" cy="12" r="3" />
      <path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1Z" />
    </>
  ),
  lock: (
    <>
      <rect x="5" y="11" width="14" height="10" rx="2" />
      <path d="M8 11V7a4 4 0 0 1 8 0v4" />
    </>
  ),
  unlock: (
    <>
      <rect x="5" y="11" width="14" height="10" rx="2" />
      <path d="M8 11V7a4 4 0 0 1 7.8-1.2" />
    </>
  ),
  swap: <path d="M7 4L3 8l4 4M3 8h14M17 20l4-4-4-4M21 16H7" />,
  refresh: <path d="M21 12a9 9 0 1 1-2.6-6.4L21 8M21 3v5h-5" />,
  trash: <path d="M3 6h18M8 6V4h8v2M6 6l1 14h10l1-14" />,
  copy: (
    <>
      <rect x="9" y="9" width="12" height="12" rx="2" />
      <path d="M5 15V5a2 2 0 0 1 2-2h8" />
    </>
  ),
  search: (
    <>
      <circle cx="11" cy="11" r="7" />
      <path d="M20 20l-3.5-3.5" />
    </>
  ),
  bolt: <path d="M13 2L4 14h7l-1 8 9-12h-7l1-8Z" />,
  scale: (
    <>
      <rect x="3" y="4" width="18" height="16" rx="3" />
      <path d="M8 9a4 4 0 0 1 8 0M12 9l1.5-2" />
    </>
  ),
  steps: <path d="M8 14c-2 0-3-2-3-5s1-5 3-5 3 2 3 5-1 5-3 5ZM16 20c-2 0-3-2-3-5s1-5 3-5 3 2 3 5-1 5-3 5Z" />,
  camera: (
    <>
      <path d="M3 8a2 2 0 0 1 2-2h2l2-2h6l2 2h2a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z" />
      <circle cx="12" cy="13" r="4" />
    </>
  ),
  calendar: (
    <>
      <rect x="3" y="5" width="18" height="16" rx="2" />
      <path d="M3 10h18M8 3v4M16 3v4" />
    </>
  ),
  star: <path d="M12 3l2.8 5.7 6.2.9-4.5 4.4 1 6.2L12 17.3 6.5 20.2l1-6.2L3 9.6l6.2-.9Z" />,
  timer: (
    <>
      <circle cx="12" cy="13" r="8" />
      <path d="M12 9v4l2 2M9 2h6" />
    </>
  ),
  send: <path d="M4 12l16-8-6 16-2-7-8-1Z" />,
  sparkle: <path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8Z" />,
  info: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 11v6M12 7.5h.01" />
    </>
  ),
  warning: <path d="M12 3l10 18H2L12 3ZM12 10v5M12 18h.01" />,
  download: <path d="M12 3v12M7 10l5 5 5-5M4 21h16" />,
  upload: <path d="M12 21V9M7 14l5-5 5 5M4 3h16" />,
  edit: <path d="M4 20h4L19 9l-4-4L4 16v4ZM14 6l4 4" />,
  barcode: <path d="M3 5v14M6 5v14M10 5v14M13 5v14M15 5v14M19 5v14M21 5v14M8 5v14" strokeWidth={1.6} />,
  basket: (
    <>
      <path d="M4 9h16l-1.5 10.5a2 2 0 0 1-2 1.5h-9a2 2 0 0 1-2-1.5Z" />
      <path d="M8 9l4-6 4 6M9 13v4M15 13v4M12 13v4" />
    </>
  ),
};

export type IconName = keyof typeof paths;

export function Icon({ name, size = 20, className }: { name: IconName; size?: number; className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      fill="none"
      stroke="currentColor"
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden="true"
    >
      {paths[name]}
    </svg>
  );
}

// ---------------------------------------------------------------------------
// Basic building blocks
// ---------------------------------------------------------------------------

export function Card({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <section className={`card ${className}`}>{children}</section>;
}

export function Button({
  children,
  onClick,
  variant = "primary",
  disabled,
  small,
  type = "button",
}: {
  children: ReactNode;
  onClick?: () => void;
  variant?: "primary" | "secondary" | "danger";
  disabled?: boolean;
  small?: boolean;
  type?: "button" | "submit";
}) {
  return (
    <button type={type} className={`btn btn-${variant}${small ? " btn-sm" : ""}`} onClick={onClick} disabled={disabled}>
      {children}
    </button>
  );
}

export function SectionHeader({ title, action, onAction }: { title: string; action?: string; onAction?: () => void }) {
  return (
    <div className="row-between">
      <h2 className="headline">{title}</h2>
      {action && onAction && (
        <button className="link-btn" onClick={onAction}>
          {action}
        </button>
      )}
    </div>
  );
}

export function SelectRow({
  title,
  subtitle,
  selected,
  onClick,
}: {
  title: string;
  subtitle?: string;
  selected: boolean;
  onClick: () => void;
}) {
  return (
    <button className={`select-row${selected ? " on" : ""}`} onClick={onClick} aria-pressed={selected}>
      <div className="grow stack-sm">
        <span className="headline">{title}</span>
        {subtitle && <span className="sub">{subtitle}</span>}
      </div>
      <span className="check">{selected && <Icon name="check" size={14} />}</span>
    </button>
  );
}

export function Segmented<T extends string | number | boolean>({
  options,
  value,
  onChange,
}: {
  options: { value: T; label: string }[];
  value: T;
  onChange: (v: T) => void;
}) {
  return (
    <div className="segmented" role="tablist">
      {options.map((o) => (
        <button
          key={String(o.value)}
          role="tab"
          aria-selected={o.value === value}
          className={o.value === value ? "on" : ""}
          onClick={() => onChange(o.value)}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

export function Toggle({
  label,
  sub,
  checked,
  onChange,
}: {
  label: string;
  sub?: string;
  checked: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <label className="list-row">
      <div className="grow stack-sm">
        <span>{label}</span>
        {sub && <span className="caption">{sub}</span>}
      </div>
      <span className="toggle">
        <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} />
        <span />
      </span>
    </label>
  );
}

export function Stepper({
  value,
  min,
  max,
  onChange,
  label,
}: {
  value: number;
  min: number;
  max: number;
  onChange: (v: number) => void;
  label?: string;
}) {
  return (
    <div className="stepper" aria-label={label}>
      <button aria-label="Decrease" onClick={() => onChange(Math.max(min, value - 1))} disabled={value <= min}>
        −
      </button>
      <output>{value}</output>
      <button aria-label="Increase" onClick={() => onChange(Math.min(max, value + 1))} disabled={value >= max}>
        +
      </button>
    </div>
  );
}

/** Numeric text field that accepts comma decimals and opens the numeric keypad on Android. */
export function NumberInput({
  value,
  onChange,
  placeholder,
  big,
  integer,
  ariaLabel,
  autoFocus,
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  big?: boolean;
  integer?: boolean;
  ariaLabel?: string;
  autoFocus?: boolean;
}) {
  return (
    <input
      className={`input${big ? " input-big" : ""}`}
      inputMode={integer ? "numeric" : "decimal"}
      enterKeyHint="done"
      value={value}
      placeholder={placeholder}
      aria-label={ariaLabel}
      autoFocus={autoFocus}
      onChange={(e) => onChange(e.target.value.replace(integer ? /[^0-9]/g : /[^0-9.,]/g, ""))}
    />
  );
}

// ---------------------------------------------------------------------------
// Data displays
// ---------------------------------------------------------------------------

export type MacroKind = "calories" | "protein" | "carbohydrates" | "fat";
export const MacroMeta: Record<MacroKind, { label: string; unit: string; color: string }> = {
  calories: { label: "Calories", unit: "kcal", color: "var(--primary)" },
  protein: { label: "Protein", unit: "g", color: "var(--protein)" },
  carbohydrates: { label: "Carbs", unit: "g", color: "var(--carbs)" },
  fat: { label: "Fat", unit: "g", color: "var(--fat)" },
};

export function MacroBar({
  kind,
  current,
  target,
  showRemaining = true,
}: {
  kind: MacroKind;
  current: number;
  target: number;
  showRemaining?: boolean;
}) {
  const meta = MacroMeta[kind];
  const progress = target > 0 ? Math.min(Math.max(current / target, 0), 1) : 0;
  const remaining = target - current;
  return (
    <div className="stack-sm">
      <div className="row-between">
        <span className="row caption">
          <span className="dot" style={{ background: meta.color }} />
          {meta.label}
        </span>
        <span className="num" style={{ fontSize: 15 }}>
          {Math.round(current)} / {Math.round(target)} {meta.unit}
        </span>
      </div>
      <div className="bar" role="progressbar" aria-valuenow={Math.round(progress * 100)} aria-label={meta.label}>
        <div style={{ width: `${progress * 100}%`, background: meta.color }} />
      </div>
      {showRemaining && (
        <span className="caption2">
          {remaining >= 0
            ? `${Math.round(remaining)} ${meta.unit} remaining`
            : `${Math.round(-remaining)} ${meta.unit} over`}
        </span>
      )}
    </div>
  );
}

export function CalorieRing({ consumed, target, size = 140 }: { consumed: number; target: number; size?: number }) {
  const stroke = 14;
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const progress = target > 0 ? Math.min(consumed / target, 1) : 0;
  const remaining = Math.round(target - consumed);
  return (
    <div className="ring" style={{ width: size, height: size }} aria-label={`Calories ${Math.round(consumed)} of ${Math.round(target)}`}>
      <svg width={size} height={size}>
        <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke="var(--fill)" strokeWidth={stroke} />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="var(--primary)"
          strokeWidth={stroke}
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={circumference * (1 - progress)}
        />
      </svg>
      <div className="ring-label">
        <span className="num-lg">{Math.round(consumed)}</span>
        <span className="caption">of {Math.round(target)} kcal</span>
        <span className="caption2 accent">{remaining >= 0 ? `${remaining} left` : `${-remaining} over`}</span>
      </div>
    </div>
  );
}

export function StatCard({
  title,
  value,
  subtitle,
  accent = "var(--primary)",
}: {
  title: string;
  value: string;
  subtitle?: string;
  accent?: string;
}) {
  return (
    <Card className="tight">
      <span className="caption">{title}</span>
      <span className="num-md" style={{ color: accent, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
        {value}
      </span>
      {subtitle && <span className="caption2">{subtitle}</span>}
    </Card>
  );
}

export function DayTypeBadge({ training }: { training: boolean }) {
  return <span className={`badge${training ? " training" : ""}`}>{training ? "Training Day" : "Rest Day"}</span>;
}

export function EmptyState({
  icon = "list",
  title,
  message,
  actionTitle,
  onAction,
}: {
  icon?: IconName;
  title: string;
  message: string;
  actionTitle?: string;
  onAction?: () => void;
}) {
  return (
    <div className="empty">
      <Icon name={icon} />
      <h3 className="headline">{title}</h3>
      <p className="sub">{message}</p>
      {actionTitle && onAction && (
        <div style={{ width: "100%", marginTop: 8 }}>
          <Button onClick={onAction}>{actionTitle}</Button>
        </div>
      )}
    </div>
  );
}

export const macroLine = (m: MacroGrams) =>
  `P ${Math.round(m.protein)} · C ${Math.round(m.carbohydrates)} · F ${Math.round(m.fat)}`;

export function FoodRow({
  food,
  amountLabel,
  calories,
  macros,
  chevron,
  onClick,
  trailing,
}: {
  food: FoodItem;
  amountLabel?: string;
  calories?: number;
  macros?: MacroGrams;
  chevron?: boolean;
  onClick?: () => void;
  trailing?: ReactNode;
}) {
  const subtitle = [amountLabel, foodSubtitle(food), measurementLabel(food)].filter(Boolean).join(" · ");
  const kcal = calories ?? food.calories;
  const content = (
    <>
      <div className="grow stack-sm" style={{ gap: 2 }}>
        <span style={{ fontWeight: 600, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{food.name}</span>
        <span className="caption" style={{ whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
          {subtitle}
        </span>
      </div>
      <div className="stack-sm" style={{ gap: 2, alignItems: "flex-end", flexShrink: 0 }}>
        {kcal !== undefined && <span className="num" style={{ fontSize: 15 }}>{Math.round(kcal)} kcal</span>}
        {macros && <span className="caption2">{macroLine(macros)}</span>}
      </div>
      {trailing}
      {chevron && <Icon name="chevronRight" size={16} className="muted" />}
    </>
  );
  return onClick ? (
    <button className="list-row" onClick={onClick}>
      {content}
    </button>
  ) : (
    <div className="list-row">{content}</div>
  );
}

export function MealCard({
  meal,
  name,
  onSwap,
  onToggleLock,
  onLogMeal,
  onSwapMeal,
  isFixed,
}: {
  meal: Meal;
  name?: string;
  onSwap?: (item: MealItem) => void;
  onToggleLock?: (item: MealItem) => void;
  onLogMeal?: () => void;
  onSwapMeal?: () => void;
  /** Items that can't be swapped or locked (e.g. intra-workout supplements). */
  isFixed?: (item: MealItem) => boolean;
}) {
  const m = mealMacros(meal);
  return (
    <Card>
      <div className="row-between" style={{ alignItems: "flex-start" }}>
        <div className="stack-sm" style={{ gap: 2 }}>
          <span className="headline">{name ?? meal.name}</span>
          {meal.scheduledTimeMinutes !== undefined && (
            <span className="caption">{formatMinutesOfDay(meal.scheduledTimeMinutes)}</span>
          )}
        </div>
        <div className="stack-sm" style={{ gap: 2, alignItems: "flex-end" }}>
          <span className="num accent">{Math.round(mealCalories(meal))} kcal</span>
          <span className="caption2">
            P {Math.round(m.protein)}  C {Math.round(m.carbohydrates)}  F {Math.round(m.fat)}
          </span>
        </div>
      </div>
      {meal.items.map((item) => (
        <div key={item.id} className="row" style={{ alignItems: "flex-start" }}>
          <div className="grow stack-sm" style={{ gap: 2 }}>
            <span className="callout">{quantityLabel(item)}</span>
            <span className="caption2">
              {Math.round(item.calories)} kcal · {macroLine(item.macros)}
            </span>
          </div>
          {onToggleLock && !isFixed?.(item) && (
            <button
              className="icon-btn"
              style={{ width: 34, height: 34, color: item.isLocked ? "var(--primary)" : "var(--text-2)" }}
              aria-label={item.isLocked ? "Unlock quantity" : "Lock quantity"}
              onClick={() => onToggleLock(item)}
            >
              <Icon name={item.isLocked ? "lock" : "unlock"} size={16} />
            </button>
          )}
          {onSwap && !isFixed?.(item) && (
            <button className="btn btn-secondary btn-sm" onClick={() => onSwap(item)}>
              Swap
            </button>
          )}
        </div>
      ))}
      {(onLogMeal || onSwapMeal) && (
        <div className="row-between">
          {onLogMeal && (
            <button className="link-btn" onClick={onLogMeal}>
              Log Planned Meal
            </button>
          )}
          {onSwapMeal && (
            <button className="link-btn row" style={{ gap: 4 }} onClick={onSwapMeal}>
              <Icon name="refresh" size={16} /> Swap meal
            </button>
          )}
        </div>
      )}
    </Card>
  );
}

export function CoachBubble({
  text,
  role = "coach",
  structured,
}: {
  text: string;
  role?: "user" | "coach" | "system";
  structured?: CoachAIStructuredResponse;
}) {
  const isUser = role === "user";
  return (
    <div className={`bubble-row${isUser ? " user" : ""}`}>
      {!isUser && (
        <span className="avatar">
          <Icon name="dumbbell" size={16} />
        </span>
      )}
      <div className="bubble">
        {text}
        {structured && (
          <div className="stack-sm" style={{ marginTop: 6, gap: 3 }}>
            <span className="caption accent">{structured.recommendation}</span>
            {structured.reasoning.map((r) => (
              <span key={r} className="caption2">
                • {r}
              </span>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Overlays
// ---------------------------------------------------------------------------

/** Bottom sheet that also closes on Android's back gesture (via history state). */
export function Sheet({
  title,
  onClose,
  children,
  right,
  full,
}: {
  title: string;
  onClose: () => void;
  children: ReactNode;
  right?: ReactNode;
  full?: boolean;
}) {
  useBackToClose(onClose);
  useEffect(() => {
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = prev;
    };
  }, []);
  return createPortal(
    <div className="sheet-backdrop" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className={`sheet${full ? " sheet-full" : ""}`} role="dialog" aria-modal="true" aria-label={title}>
        <div className="sheet-header">
          <button className="link-btn" style={{ justifySelf: "start" }} onClick={onClose}>
            Close
          </button>
          <h2>{title}</h2>
          <div className="right">{right}</div>
        </div>
        <div className="sheet-body">{children}</div>
      </div>
    </div>,
    document.body,
  );
}

let backStack: (() => void)[] = [];
/** history.back() calls we issued ourselves; their popstate events must not close another overlay. */
let selfInitiatedPops = 0;
if (typeof window !== "undefined") {
  window.addEventListener("popstate", () => {
    if (selfInitiatedPops > 0) {
      selfInitiatedPops--;
      return;
    }
    const top = backStack[backStack.length - 1];
    if (top) top();
  });
}

/** Several overlays closing in one tick → one history.go(-n), since back-to-back history.back() calls get coalesced. */
let pendingBacks = 0;
function scheduleBack() {
  pendingBacks++;
  if (pendingBacks > 1) return;
  queueMicrotask(() => {
    const n = pendingBacks;
    pendingBacks = 0;
    selfInitiatedPops++;
    history.go(-n);
  });
}

/** Push a history entry so the Android back button/gesture dismisses the overlay instead of leaving the app. */
export function useBackToClose(onClose: () => void) {
  useEffect(() => {
    let closedByBack = false;
    const handler = () => {
      closedByBack = true;
      onClose();
    };
    backStack.push(handler);
    history.pushState({ overlay: backStack.length }, "");
    return () => {
      backStack = backStack.filter((h) => h !== handler);
      if (!closedByBack) scheduleBack();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
}

interface DialogOptions {
  title: string;
  message?: string;
  confirm?: string;
  cancel?: string;
  destructive?: boolean;
}

let dialogSetter: ((d: (DialogOptions & { resolve: (ok: boolean) => void }) | null) => void) | null = null;
let toastSetter: ((t: string | null) => void) | null = null;

/** Promise-based confirm/alert dialog. Pass `cancel: ""` for an alert with only one button. */
export function confirmDialog(opts: DialogOptions): Promise<boolean> {
  return new Promise((resolve) => dialogSetter?.({ ...opts, resolve }));
}

export function toast(text: string) {
  toastSetter?.(text);
}

export function OverlayHost() {
  const [dialog, setDialog] = useState<(DialogOptions & { resolve: (ok: boolean) => void }) | null>(null);
  const [toastText, setToast] = useState<string | null>(null);
  useEffect(() => {
    dialogSetter = setDialog;
    toastSetter = setToast;
    return () => {
      dialogSetter = null;
      toastSetter = null;
    };
  }, []);
  useEffect(() => {
    if (!toastText) return;
    const t = setTimeout(() => setToast(null), 2400);
    return () => clearTimeout(t);
  }, [toastText]);

  const close = (ok: boolean) => {
    dialog?.resolve(ok);
    setDialog(null);
  };

  return (
    <>
      {dialog &&
        createPortal(
          <div className="sheet-backdrop center" onClick={(e) => e.target === e.currentTarget && close(false)}>
            <div className="dialog" role="alertdialog" aria-label={dialog.title}>
              <h2 className="headline">{dialog.title}</h2>
              {dialog.message && <p className="sub">{dialog.message}</p>}
              <div className="stack-sm" style={{ marginTop: 4 }}>
                <Button variant={dialog.destructive ? "danger" : "primary"} onClick={() => close(true)}>
                  {dialog.confirm ?? "OK"}
                </Button>
                {dialog.cancel !== "" && (
                  <Button variant="secondary" onClick={() => close(false)}>
                    {dialog.cancel ?? "Cancel"}
                  </Button>
                )}
              </div>
            </div>
          </div>,
          document.body,
        )}
      {toastText && createPortal(<div className="toast" role="status">{toastText}</div>, document.body)}
    </>
  );
}

/** Re-render every `ms` milliseconds (for timers). */
export function useTick(ms: number, active = true) {
  const [, setN] = useState(0);
  useEffect(() => {
    if (!active) return;
    const id = setInterval(() => setN((n) => n + 1), ms);
    return () => clearInterval(id);
  }, [ms, active]);
}
