import { useEffect, useRef, useState } from "react";
import { CoachingConfig } from "../core/config";
import { formatMedium } from "../core/dates";
import { actions, currentWeek, hasCoachAccess, useApp } from "../state/store";
import { Button, Card, CoachBubble, Icon, SectionHeader, Sheet } from "../ui/kit";
import { CheckIn } from "./CheckIn";
import { ModelCard } from "./ModelCard";
import { Paywall } from "./Paywall";

const PROMPTS = [
  "How is my progress?",
  "Should we change food?",
  "Can I have a refeed?",
  "Why did my calories change?",
  "What should I eat before training?",
  "I'm eating out tonight.",
  "I missed my meal plan today.",
  "My weight jumped overnight.",
  "I'm feeling flat.",
  "I'm very hungry.",
];

export function Coach() {
  const s = useApp();
  const access = hasCoachAccess(s);
  const [chat, setChat] = useState(false);
  const [checkIn, setCheckIn] = useState(false);
  const [paywall, setPaywall] = useState(false);
  const gate = (fn: () => void) => () => (access ? fn() : setPaywall(true));

  const week = currentWeek(s);
  const statusTitle = !access
    ? "Coach AI Locked"
    : week.completeness === "empty" || week.completeness === "insufficientForAdjustment"
      ? "Building Your Baseline"
      : "Plan On Track";

  return (
    <div className="screen">
      <div className="screen-header">
        <h1 className="screen-title">My Coach</h1>
        <button className="btn btn-secondary btn-sm" onClick={gate(() => setChat(true))}>
          Chat
        </button>
      </div>

      <Card>
        <div className="row" style={{ alignItems: "flex-start", gap: 14 }}>
          <span
            className="avatar"
            style={{ width: 52, height: 52, background: "linear-gradient(135deg, var(--primary), var(--navy))", color: "#fff" }}
          >
            <Icon name="dumbbell" size={24} />
          </span>
          <div className="stack-sm grow">
            <h3 className="headline">{statusTitle}</h3>
            <p className="sub">{s.coachStatusMessage}</p>
            {!access && (
              <button className="link-btn" style={{ alignSelf: "flex-start" }} onClick={() => setPaywall(true)}>
                Start {CoachingConfig.freeTrialDays}-Day Free Trial
              </button>
            )}
            {access && (
              <span className="caption">
                This week: {week.entryCount}/{CoachingConfig.minimumWeighInsForAdjustment}+ morning weigh-ins
              </span>
            )}
          </div>
        </div>
      </Card>

      <ModelCard onUnlock={() => setPaywall(true)} />

      <div className="stack-sm">
        <SectionHeader title="Suggested Prompts" />
        <div className="row" style={{ overflowX: "auto", gap: 8, paddingBottom: 6, margin: "0 calc(-1 * var(--gutter))", padding: "0 var(--gutter) 6px" }}>
          {PROMPTS.map((p) => (
            <button
              key={p}
              className="chip"
              style={{ whiteSpace: "nowrap", background: "var(--elevated)", boxShadow: "var(--shadow)" }}
              onClick={gate(() => {
                actions.sendCoachMessage(p);
                setChat(true);
              })}
            >
              {p}
            </button>
          ))}
        </div>
      </div>

      <Card>
        <h3 className="headline">Weekly Check-In</h3>
        <p className="sub">
          Review photos, appearance, adherence and performance. Your coach uses Monday–Sunday averages — never one noisy
          weigh-in.
        </p>
        <Button onClick={gate(() => setCheckIn(true))}>Start Weekly Check-In</Button>
      </Card>

      {s.checkIns.length > 0 && (
        <div className="stack-sm">
          <SectionHeader title="Check-In History" />
          <div className="list">
            {s.checkIns.slice(0, 5).map((c) => (
              <div key={c.id} className="list-row" style={{ alignItems: "flex-start" }}>
                <div className="grow stack-sm" style={{ gap: 2 }}>
                  <span className="callout">Week of {formatMedium(c.weekStart)}</span>
                  <span className="caption">{c.decision?.summary}</span>
                </div>
                {c.userApprovedAdjustment && <span className="badge ok">Applied</span>}
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="stack-sm">
        <SectionHeader title="Recent" action="Open Chat" onAction={gate(() => setChat(true))} />
        <div className="stack">
          {s.chatMessages.slice(-3).map((m) => (
            <CoachBubble key={m.id} text={m.text} role={m.role} structured={m.structured} />
          ))}
        </div>
      </div>

      {chat && <CoachChat onClose={() => setChat(false)} />}
      {checkIn && <CheckIn onClose={() => setCheckIn(false)} />}
      {paywall && <Paywall onClose={() => setPaywall(false)} />}
    </div>
  );
}

function CoachChat({ onClose }: { onClose: () => void }) {
  const s = useApp();
  const [draft, setDraft] = useState("");
  const endRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [s.chatMessages.length]);

  function send() {
    actions.sendCoachMessage(draft);
    setDraft("");
  }

  return (
    <Sheet title="Coach Chat" full onClose={onClose}>
      {!hasCoachAccess(s) && (
        <Card className="tight">
          <span className="headline">Coach AI subscription required.</span>
          <span className="sub">Your tracking data stays available. Upgrade for live coaching conversations.</span>
        </Card>
      )}
      <div className="stack grow">
        {s.chatMessages.map((m) => (
          <CoachBubble key={m.id} text={m.text} role={m.role} structured={m.structured} />
        ))}
        <div ref={endRef} />
      </div>
      <form
        className="row"
        style={{ position: "sticky", bottom: 0, background: "var(--grouped)", padding: "8px 0" }}
        onSubmit={(e) => {
          e.preventDefault();
          send();
        }}
      >
        <input
          className="input grow"
          placeholder="Ask your coach…"
          enterKeyHint="send"
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
        />
        <button
          type="submit"
          className="icon-btn"
          style={{ width: 48, height: 48, background: draft.trim() ? "var(--primary)" : "var(--fill)", color: draft.trim() ? "#fff" : "var(--text-2)" }}
          aria-label="Send"
          disabled={!draft.trim()}
        >
          <Icon name="send" />
        </button>
      </form>
    </Sheet>
  );
}
