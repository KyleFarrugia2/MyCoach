import { useMemo, useRef, useState } from "react";
import { addDays, addMonths, formatMedium, formatWithWeekday, fromDay, today, weekStart } from "../core/dates";
import { GoalPhaseInfo, type ProgressPhotoSet, type WeeklyCheckIn, type WeightEntry, WeightUnitShort } from "../core/models";
import { UnitConversion } from "../engines/units";
import { forecast } from "../engines/adaptive";
import { weeklyAverage } from "../engines/weight";
import { actions, adaptiveModel, adaptiveRecommendation, currentWeek, displayWeight, useApp, weeklyRate } from "../state/store";
import { Card, EmptyState, Icon, SectionHeader, Segmented, Sheet, StatCard, confirmDialog } from "../ui/kit";

type Range = "1M" | "3M" | "6M" | "1Y" | "All";
const RANGE_MONTHS: Record<Range, number | null> = { "1M": 1, "3M": 3, "6M": 6, "1Y": 12, All: null };

function calorieChangeLabel(c: WeeklyCheckIn): string {
  const a = c.decision?.action;
  if (!a) return "No analysis";
  switch (a.type) {
    case "maintain":
      return "Calories: No change";
    case "increaseCalories":
      return `Calories: +${a.amount}`;
    case "decreaseCalories":
      return `Calories: -${a.amount}`;
    case "increaseSteps":
      return `Steps: +${a.amount}`;
    case "decreaseSteps":
      return `Steps: -${a.amount}`;
    case "suggestRefeed":
      return "Refeed suggested";
    case "requireMoreData":
      return "Need more data";
    case "reviewAdherence":
      return "Review adherence";
    case "reviewRecovery":
      return "Review recovery";
    case "recommendNutritionIncreaseReview":
      return "Calories: review +";
    case "recommendNutritionDecreaseReview":
      return "Calories: review −";
  }
}

export function Progress() {
  const s = useApp();
  const [tab, setTab] = useState<"overview" | "weights">("overview");
  const [range, setRange] = useState<Range>("3M");
  const [photoSet, setPhotoSet] = useState<ProgressPhotoSet | null>(null);
  const unit = s.profile.weightUnit;
  const official = useMemo(() => s.weightEntries.filter((e) => e.isOfficialMorningCheckIn), [s.weightEntries]);

  const signed = (kg: number, withSign = true) => {
    const v = UnitConversion.displayWeight(Math.abs(kg), unit).toFixed(1);
    const sign = !withSign ? "" : kg > 0 ? "+" : kg < 0 ? "−" : "";
    return `${sign}${v} ${WeightUnitShort[unit]}`;
  };

  const current = official[official.length - 1]?.weightKg ?? s.profile.currentWeightKg;
  const starting = official[0]?.weightKg ?? s.profile.currentWeightKg;
  const week = currentWeek(s);
  const rate = weeklyRate(s);

  const months = RANGE_MONTHS[range];
  const cutoff = months ? addMonths(today(), -months) : null;
  const filtered = cutoff ? official.filter((e) => e.localDate >= cutoff) : official;

  // 4-week forecast from the personal model on the current plan.
  const model = adaptiveModel(s);
  const rec = adaptiveRecommendation(s);
  const projection =
    model && rec && model.observations > 0
      ? forecast(model, rec.currentAverageIntake, model.currentSteps, 4).map((p) => ({
          day: addDays(today(), p.week * 7),
          meanKg: p.meanKg,
          sdKg: p.sdKg,
        }))
      : undefined;

  return (
    <div className="screen">
      <div className="screen-header">
        <h1 className="screen-title">Progress</h1>
      </div>
      <Segmented
        options={[
          { value: "overview" as const, label: "Overview" },
          { value: "weights" as const, label: "Weights" },
        ]}
        value={tab}
        onChange={setTab}
      />

      {tab === "overview" ? (
        <>
          <div className="grid-2">
            <StatCard title="Current Weight" value={displayWeight(s, current)} />
            <StatCard title="Starting Weight" value={displayWeight(s, starting)} />
            <StatCard title="Goal Weight" value={displayWeight(s, s.profile.desiredWeightKg)} />
            <StatCard
              title="Weekly Average"
              value={week.averageKg !== undefined ? displayWeight(s, week.averageKg) : "—"}
              subtitle={`${week.entryCount}/7 weigh-ins`}
            />
            <StatCard
              title="Weekly Change"
              value={rate ? signed(rate.absoluteChangeKg) : "—"}
              subtitle={rate ? `${rate.percentChange >= 0 ? "+" : ""}${rate.percentChange.toFixed(1)}%` : undefined}
              accent={(rate?.absoluteChangeKg ?? 0) < 0 ? "var(--success)" : "var(--primary)"}
            />
            <StatCard
              title="Overall Change"
              value={signed(current - starting)}
              subtitle={GoalPhaseInfo[s.profile.goalPhase].name}
            />
          </div>

          <Card>
            <h3 className="headline">Weight Trend</h3>
            <Segmented
              options={(Object.keys(RANGE_MONTHS) as Range[]).map((r) => ({ value: r, label: r }))}
              value={range}
              onChange={setRange}
            />
            {filtered.length === 0 ? (
              <EmptyState
                icon="chart"
                title="Your progress starts with your first weigh-in."
                message="Log morning weight on Today to see your chart."
                actionTitle="Log Weight"
                onAction={() => actions.selectTab("today")}
              />
            ) : (
              <WeightChart entries={filtered} unit={unit} projection={projection} />
            )}
          </Card>

          <div className="stack-sm">
            <SectionHeader title="Check-In History" />
            {s.checkIns.length === 0 ? (
              <p className="sub">Weekly coach reviews will appear here after your first check-in.</p>
            ) : (
              <div className="list">
                {s.checkIns.map((c) => (
                  <div key={c.id} className="list-row">
                    <div className="grow stack-sm" style={{ gap: 2 }}>
                      <span className="callout">{formatMedium(c.weekStart)}</span>
                      {c.rateKg !== undefined && (
                        <span className="caption">
                          {c.rateKg >= 0 ? "+" : ""}
                          {c.rateKg.toFixed(1)} kg
                        </span>
                      )}
                    </div>
                    <div className="stack-sm" style={{ gap: 2, alignItems: "flex-end" }}>
                      <span className="callout">{calorieChangeLabel(c)}</span>
                      {c.userApprovedAdjustment && <span className="caption success">Applied</span>}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="stack-sm">
            <SectionHeader title="Progress Photos" />
            {s.photoSets.length === 0 ? (
              <Card>
                <EmptyState
                  icon="camera"
                  title="Add your first progress photos when you're ready."
                  message="Take them fasted in the morning under similar lighting during your weekly check-in. Photos stay private on this device."
                />
              </Card>
            ) : (
              <div className="list">
                {s.photoSets.map((set) => {
                  const imgs = [set.front, set.side, set.back].filter(Boolean) as string[];
                  return (
                    <button key={set.id} className="list-row" onClick={() => setPhotoSet(set)}>
                      <div className="grow stack-sm" style={{ gap: 2 }}>
                        <span className="callout">Week of {formatMedium(set.weekStart)}</span>
                        <span className="caption">
                          {[set.front && "Front", set.side && "Side", set.back && "Back"].filter(Boolean).join(" · ") ||
                            "No photos attached"}
                        </span>
                      </div>
                      <div className="row" style={{ gap: 4 }}>
                        {imgs.slice(0, 3).map((src, i) => (
                          <img key={i} src={src} alt="" style={{ width: 32, height: 42, objectFit: "cover", borderRadius: 6 }} />
                        ))}
                      </div>
                      <Icon name="chevronRight" size={16} className="muted" />
                    </button>
                  );
                })}
              </div>
            )}
          </div>
        </>
      ) : (
        <WeightHistory entries={official} signed={signed} />
      )}

      {photoSet && (
        <Sheet title={`Week of ${formatMedium(photoSet.weekStart)}`} onClose={() => setPhotoSet(null)}>
          {(["front", "side", "back"] as const).map((pose) =>
            photoSet[pose] ? (
              <figure key={pose} className="stack-sm" style={{ margin: 0 }}>
                <img src={photoSet[pose]} alt={`${pose} progress photo`} style={{ width: "100%", borderRadius: "var(--r-md)" }} />
                <figcaption className="caption" style={{ textTransform: "capitalize" }}>
                  {pose}
                </figcaption>
              </figure>
            ) : null,
          )}
          <button
            className="btn btn-danger"
            onClick={async () => {
              if (await confirmDialog({ title: "Delete these photos?", confirm: "Delete", destructive: true })) {
                actions.deletePhotoSet(photoSet.id);
                setPhotoSet(null);
              }
            }}
          >
            Delete Photos
          </button>
        </Sheet>
      )}
    </div>
  );
}

function WeightHistory({ entries, signed }: { entries: WeightEntry[]; signed: (kg: number) => string }) {
  const s = useApp();
  const sorted = [...entries].sort((a, b) => b.localDate.localeCompare(a.localDate));
  if (sorted.length === 0) {
    return (
      <Card>
        <EmptyState
          icon="scale"
          title="No weigh-ins yet"
          message="Log your morning weight on Today to build your history."
          actionTitle="Log Weight"
          onAction={() => actions.selectTab("today")}
        />
      </Card>
    );
  }
  return (
    <div className="stack-sm">
      <SectionHeader title="Previous Weights" />
      <span className="caption" style={{ padding: "0 4px" }}>
        {sorted.length} morning check-ins
      </span>
      <div className="list">
        {sorted.map((entry, i) => {
          const prev = sorted[i + 1];
          const delta = prev ? entry.weightKg - prev.weightKg : undefined;
          return (
            <div key={entry.id} className="list-row">
              <div className="grow stack-sm" style={{ gap: 2 }}>
                <span className="callout">{formatWithWeekday(entry.localDate)}</span>
                {entry.localDate === today() && <span className="caption accent">Today</span>}
              </div>
              <div className="stack-sm" style={{ gap: 2, alignItems: "flex-end" }}>
                <span className="num">{displayWeight(s, entry.weightKg)}</span>
                {delta !== undefined && (
                  <span
                    className="caption"
                    style={{ color: delta < 0 ? "var(--success)" : delta > 0 ? "var(--warning)" : undefined }}
                  >
                    {signed(delta)}
                  </span>
                )}
              </div>
              <button
                className="icon-btn"
                style={{ width: 34, height: 34, color: "var(--text-2)" }}
                aria-label="Delete weigh-in"
                onClick={async () => {
                  if (
                    await confirmDialog({
                      title: "Delete this weigh-in?",
                      message: formatWithWeekday(entry.localDate),
                      confirm: "Delete",
                      destructive: true,
                    })
                  ) {
                    actions.deleteWeightEntry(entry.id);
                  }
                }}
              >
                <Icon name="trash" size={16} />
              </button>
            </div>
          );
        })}
      </div>
    </div>
  );
}

/** Daily weigh-ins (dots) + Monday–Sunday weekly averages (thick line). Tap/drag to inspect. */
function WeightChart({
  entries,
  unit,
  projection,
}: {
  entries: WeightEntry[];
  unit: "kilogram" | "pound";
  projection?: { day: string; meanKg: number; sdKg: number }[];
}) {
  const [selected, setSelected] = useState<WeightEntry | null>(null);
  const svgRef = useRef<SVGSVGElement>(null);
  const W = 340;
  const H = 200;
  const pad = { l: 36, r: 10, t: 10, b: 24 };

  const toDisplay = (kg: number) => UnitConversion.displayWeight(kg, unit);
  const time = (d: string) => fromDay(d).getTime();

  const weeks = useMemo(() => {
    const groups = new Map<string, WeightEntry[]>();
    for (const e of entries) {
      const k = weekStart(e.localDate);
      groups.set(k, [...(groups.get(k) ?? []), e]);
    }
    return [...groups.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([start, es]) => ({ start, value: toDisplay(weeklyAverage(es)!) }));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [entries, unit]);

  const proj = (projection ?? []).map((p) => ({
    t: time(p.day),
    mean: toDisplay(p.meanKg),
    lo: toDisplay(p.meanKg - p.sdKg),
    hi: toDisplay(p.meanKg + p.sdKg),
  }));
  const values = [
    ...entries.map((e) => toDisplay(e.weightKg)),
    ...weeks.map((w) => w.value),
    ...proj.flatMap((p) => [p.lo, p.hi]),
  ];
  let minY = Math.min(...values);
  let maxY = Math.max(...values);
  // At least 2 units of range so the 4 one-decimal tick labels never repeat.
  const spread = Math.max(maxY - minY, 2);
  minY -= spread * 0.15;
  maxY += spread * 0.15;
  const times = [...entries.map((e) => time(e.localDate)), ...weeks.map((w) => time(w.start)), ...proj.map((p) => p.t)];
  let minX = Math.min(...times);
  let maxX = Math.max(...times);
  if (maxX === minX) {
    minX -= 3 * 86_400_000;
    maxX += 3 * 86_400_000;
  }
  const x = (t: number) => pad.l + ((t - minX) / (maxX - minX)) * (W - pad.l - pad.r);
  const y = (v: number) => pad.t + (1 - (v - minY) / (maxY - minY)) * (H - pad.t - pad.b);

  const ticks = Array.from({ length: 4 }, (_, i) => minY + ((maxY - minY) * (i + 0.5)) / 4);
  const weekPath = weeks.map((w, i) => `${i ? "L" : "M"}${x(time(w.start)).toFixed(1)},${y(w.value).toFixed(1)}`).join(" ");
  const dailyPath = entries.map((e, i) => `${i ? "L" : "M"}${x(time(e.localDate)).toFixed(1)},${y(toDisplay(e.weightKg)).toFixed(1)}`).join(" ");

  function pick(clientX: number) {
    const svg = svgRef.current;
    if (!svg) return;
    const rect = svg.getBoundingClientRect();
    const px = ((clientX - rect.left) / rect.width) * W;
    let best = entries[0];
    for (const e of entries) if (Math.abs(x(time(e.localDate)) - px) < Math.abs(x(time(best.localDate)) - px)) best = e;
    setSelected(best);
  }

  const first = entries[0].localDate;
  const last = projection?.length ? projection[projection.length - 1].day : entries[entries.length - 1].localDate;
  const short = (d: string) => fromDay(d).toLocaleDateString(undefined, { month: "short", day: "numeric" });

  return (
    <div className="stack-sm">
      <svg
        ref={svgRef}
        viewBox={`0 0 ${W} ${H}`}
        className="chart"
        role="img"
        aria-label={`Weight trend chart, ${entries.length} weigh-ins`}
        style={{ touchAction: "pan-y" }}
        onPointerDown={(e) => pick(e.clientX)}
        onPointerMove={(e) => e.buttons && pick(e.clientX)}
      >
        {ticks.map((t) => (
          <g key={t}>
            <line x1={pad.l} x2={W - pad.r} y1={y(t)} y2={y(t)} stroke="var(--border)" strokeWidth={1} />
            <text x={pad.l - 6} y={y(t) + 3.5} textAnchor="end" fontSize={10} fill="var(--text-2)">
              {t.toFixed(1)}
            </text>
          </g>
        ))}
        <text x={pad.l} y={H - 6} fontSize={10} fill="var(--text-2)">
          {short(first)}
        </text>
        <text x={W - pad.r} y={H - 6} fontSize={10} fill="var(--text-2)" textAnchor="end">
          {short(last)}
        </text>
        {proj.length > 0 && (
          <>
            <path
              d={`${proj.map((p, i) => `${i ? "L" : "M"}${x(p.t).toFixed(1)},${y(p.hi).toFixed(1)}`).join(" ")} ${[...proj]
                .reverse()
                .map((p) => `L${x(p.t).toFixed(1)},${y(p.lo).toFixed(1)}`)
                .join(" ")} Z`}
              fill="var(--primary)"
              fillOpacity={0.12}
            />
            <path
              d={proj.map((p, i) => `${i ? "L" : "M"}${x(p.t).toFixed(1)},${y(p.mean).toFixed(1)}`).join(" ")}
              fill="none"
              stroke="var(--primary)"
              strokeWidth={2}
              strokeDasharray="5 4"
            />
          </>
        )}
        <path d={dailyPath} fill="none" stroke="var(--primary)" strokeOpacity={0.35} strokeWidth={1.5} />
        {entries.map((e) => (
          <circle key={e.id} cx={x(time(e.localDate))} cy={y(toDisplay(e.weightKg))} r={3} fill="var(--primary)" fillOpacity={0.55} />
        ))}
        <path d={weekPath} fill="none" stroke="var(--text)" strokeWidth={3} strokeLinejoin="round" strokeLinecap="round" />
        {weeks.map((w) => (
          <circle key={w.start} cx={x(time(w.start))} cy={y(w.value)} r={4.5} fill="var(--text)" stroke="var(--elevated)" strokeWidth={1.5} />
        ))}
        {selected && (
          <>
            <line
              x1={x(time(selected.localDate))}
              x2={x(time(selected.localDate))}
              y1={pad.t}
              y2={H - pad.b}
              stroke="var(--primary)"
              strokeDasharray="3 3"
            />
            <circle cx={x(time(selected.localDate))} cy={y(toDisplay(selected.weightKg))} r={5.5} fill="var(--primary)" stroke="var(--elevated)" strokeWidth={2} />
          </>
        )}
      </svg>
      <span className="caption" style={{ minHeight: 16 }}>
        {selected ? `${formatMedium(selected.localDate)}: ${formatWeightLocal(selected.weightKg, unit)}` : "Tap the chart to inspect a day."}
      </span>
      <div className="row caption" style={{ gap: 16 }}>
        <span className="row" style={{ gap: 6 }}>
          <span className="dot" style={{ background: "var(--primary)", opacity: 0.55 }} /> Daily weight
        </span>
        <span className="row" style={{ gap: 6 }}>
          <span className="dot" style={{ background: "var(--text)" }} /> Weekly average
        </span>
        {proj.length > 0 && (
          <span className="row" style={{ gap: 6 }}>
            <span style={{ width: 14, borderTop: "2px dashed var(--primary)" }} /> Model forecast
          </span>
        )}
      </div>
    </div>
  );
}

function formatWeightLocal(kg: number, unit: "kilogram" | "pound") {
  return `${UnitConversion.displayWeight(kg, unit).toFixed(1)} ${WeightUnitShort[unit]}`;
}
