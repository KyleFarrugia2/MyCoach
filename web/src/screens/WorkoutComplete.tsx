import { useEffect, useMemo, useState } from "react";
import { createPortal } from "react-dom";
import type { WorkoutSession } from "../engines/workout";
import { type ReviewStatus, reviewWorkout, sessionStats, streakMessage } from "../engines/workoutReview";
import { playEffect } from "../ui/clickSounds";
import { Button, useBackToClose } from "../ui/kit";

export interface WorkoutCompletion {
  session: WorkoutSession;
  previous?: WorkoutSession;
  streakBefore: number;
  streakAfter: number;
  /** Exercises with no progress for several sessions in a row (the coach's stagnation check). */
  stagnant: string[];
}

const reduceMotion = () =>
  typeof window !== "undefined" && window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;

/** Animates a number from `from` to `to` after `delay` ms. */
function useCountUp(to: number, { from = 0, duration = 900, delay = 0 } = {}) {
  const [v, setV] = useState(reduceMotion() ? to : from);
  useEffect(() => {
    if (reduceMotion()) {
      setV(to);
      return;
    }
    let raf = 0;
    const start = performance.now() + delay;
    const tick = (t: number) => {
      const p = Math.min(1, Math.max(0, (t - start) / duration));
      const eased = 1 - Math.pow(1 - p, 3);
      setV(from + (to - from) * eased);
      if (p < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [to, from, duration, delay]);
  return v;
}

const CONFETTI_COLORS = ["var(--primary)", "var(--success)", "var(--protein)", "var(--fat)", "var(--warning)", "#ff6b9a"];

function Confetti({ count = 48 }: { count?: number }) {
  const pieces = useMemo(
    () =>
      Array.from({ length: count }, (_, i) => {
        const angle = (i / count) * Math.PI * 2 + Math.random() * 0.4;
        const dist = 110 + Math.random() * 150;
        return {
          dx: Math.cos(angle) * dist,
          dy: Math.sin(angle) * dist - 60,
          rot: Math.round(Math.random() * 720 - 360),
          delay: Math.random() * 120,
          color: CONFETTI_COLORS[i % CONFETTI_COLORS.length],
          round: i % 3 === 0,
        };
      }),
    [count],
  );
  return (
    <div className="wc-confetti" aria-hidden="true">
      {pieces.map((p, i) => (
        <span
          key={i}
          className={p.round ? "round" : ""}
          style={
            {
              "--dx": `${p.dx}px`,
              "--dy": `${p.dy}px`,
              "--rot": `${p.rot}deg`,
              background: p.color,
              animationDelay: `${p.delay}ms`,
            } as React.CSSProperties
          }
        />
      ))}
    </div>
  );
}

function formatDuration(sec: number) {
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  return h > 0 ? `${h}h ${m}m` : `${m}m`;
}

function Stat({ label, value, delay }: { label: string; value: string; delay: number }) {
  return (
    <div className="wc-stat" style={{ animationDelay: `${delay}ms` }}>
      <div className="wc-stat-value">{value}</div>
      <div className="caption">{label}</div>
    </div>
  );
}

function CompleteStep({ completion }: { completion: WorkoutCompletion }) {
  const stats = sessionStats(completion.session);
  const volume = useCountUp(stats.volumeKg, { delay: 700, duration: 1100 });
  useEffect(() => playEffect("celebration"), []);
  const sets = useCountUp(stats.sets, { delay: 600, duration: 700 });
  return (
    <>
      <Confetti />
      <div className="wc-badge">
        <svg viewBox="0 0 52 52" width="96" height="96" aria-hidden="true">
          <circle className="wc-ring" cx="26" cy="26" r="24" />
          <path className="wc-check" d="M15 27 l7 7 l15 -16" />
        </svg>
      </div>
      <h1 className="wc-title wc-pop" style={{ animationDelay: "350ms" }}>
        Workout Complete!
      </h1>
      <p className="wc-sub wc-rise" style={{ animationDelay: "500ms" }}>
        {completion.session.templateName} saved.
      </p>
      <div className="wc-stats">
        <Stat label="Time" value={formatDuration(stats.durationSeconds)} delay={600} />
        <Stat label="Sets" value={String(Math.round(sets))} delay={680} />
        <Stat label="Volume" value={`${Math.round(volume).toLocaleString()} kg`} delay={760} />
        <Stat label="Exercises" value={String(stats.exercises)} delay={840} />
      </div>
    </>
  );
}

const STATUS: Record<ReviewStatus, { icon: string; label: string }> = {
  progressed: { icon: "▲", label: "Progressed" },
  same: { icon: "=", label: "Same as last week" },
  less: { icon: "▼", label: "A bit less than last week" },
  new: { icon: "★", label: "New baseline" },
};

function ReviewStep({ completion }: { completion: WorkoutCompletion }) {
  const review = reviewWorkout(completion.previous, completion.session);
  const progressed = review.progressed > 0;
  useEffect(() => playEffect("whoosh"), []);
  return (
    <>
      <div className={`wc-emblem wc-pop ${progressed ? "up" : "steady"}`} aria-hidden="true">
        {progressed ? "💪" : "🌱"}
      </div>
      <h1 className="wc-title wc-pop" style={{ animationDelay: "120ms" }}>
        {review.headline}
      </h1>
      <p className="wc-sub wc-rise" style={{ animationDelay: "220ms" }}>
        {review.subline}
      </p>
      <ul className="wc-review">
        {review.exercises.map((e, i) => (
          <li key={e.id} className={`wc-row ${e.status}`} style={{ animationDelay: `${300 + i * 90}ms` }}>
            <span className="wc-row-icon">{STATUS[e.status].icon}</span>
            <div className="wc-row-text">
              <div className="wc-row-name">{e.name}</div>
              <div className="caption">
                <strong>{STATUS[e.status].label}</strong> · {e.detail}
              </div>
            </div>
          </li>
        ))}
      </ul>
      {review.encouragement && (
        <div className="wc-encourage wc-rise" style={{ animationDelay: `${400 + review.exercises.length * 90}ms` }}>
          <div className="wc-encourage-mark" aria-hidden="true">
            “
          </div>
          <p>{review.encouragement}</p>
        </div>
      )}
      {completion.stagnant.length > 0 && (
        <p className="caption wc-rise wc-note" style={{ animationDelay: `${500 + review.exercises.length * 90}ms` }}>
          Your coach noticed {completion.stagnant.join(", ")} {completion.stagnant.length === 1 ? "has" : "have"} held steady for a
          few sessions — try adding one rep or a small weight jump next time.
        </p>
      )}
    </>
  );
}

function StreakStep({ completion }: { completion: WorkoutCompletion }) {
  const [shown, setShown] = useState(reduceMotion() ? completion.streakAfter : completion.streakBefore);
  const [bumped, setBumped] = useState(false);
  useEffect(() => {
    if (reduceMotion()) {
      playEffect("fire");
      return;
    }
    const t = setTimeout(() => {
      setShown(completion.streakAfter);
      setBumped(true);
      playEffect("fire");
    }, 900);
    return () => clearTimeout(t);
  }, [completion.streakAfter]);
  const msg = streakMessage(completion.streakAfter);
  return (
    <>
      <div className="wc-flame" aria-hidden="true">
        <span className="wc-flame-glow" />
        <span className="wc-flame-emoji">🔥</span>
      </div>
      <div className={`wc-streak${bumped ? " bump" : ""}`} aria-live="polite">
        <span key={shown} className="wc-streak-num">
          {shown}
        </span>
      </div>
      <div className="caption wc-rise" style={{ animationDelay: "200ms" }}>
        workout streak
      </div>
      {bumped && completion.streakAfter > completion.streakBefore && <div className="wc-plus">+{completion.streakAfter - completion.streakBefore}</div>}
      <h1 className="wc-title wc-pop" style={{ animationDelay: reduceMotion() ? "0ms" : "1150ms" }}>
        {msg.title}
      </h1>
      <p className="wc-sub wc-rise" style={{ animationDelay: reduceMotion() ? "0ms" : "1300ms" }}>
        {msg.subtitle}
      </p>
      {bumped && <Confetti count={28} />}
    </>
  );
}

/** Full-screen celebration after a workout saves: Complete → Progress review → Streak. */
export function WorkoutComplete({ completion, onDone }: { completion: WorkoutCompletion; onDone: () => void }) {
  const [step, setStep] = useState(0);
  const [leaving, setLeaving] = useState(false);
  useBackToClose(onDone);
  useEffect(() => {
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = prev;
    };
  }, []);

  function next() {
    if (leaving) return;
    if (step === 2) return onDone();
    if (reduceMotion()) return setStep(step + 1);
    setLeaving(true);
    setTimeout(() => {
      setStep((x) => x + 1);
      setLeaving(false);
    }, 320);
  }

  return createPortal(
    <div className={`wc-overlay step-${step}`} role="dialog" aria-modal="true" aria-label="Workout complete">
      <div className="wc-dots" aria-hidden="true">
        {[0, 1, 2].map((i) => (
          <span key={i} className={i === step ? "on" : i < step ? "done" : ""} />
        ))}
      </div>
      <div key={step} className={`wc-step${leaving ? " leaving" : ""}`}>
        {step === 0 && <CompleteStep completion={completion} />}
        {step === 1 && <ReviewStep completion={completion} />}
        {step === 2 && <StreakStep completion={completion} />}
      </div>
      <div className={`wc-footer${leaving ? " leaving" : ""}`}>
        <Button onClick={next}>{step === 2 ? "Done" : "Continue"}</Button>
      </div>
    </div>,
    document.body,
  );
}
