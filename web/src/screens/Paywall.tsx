import { useState } from "react";
import { AppIdentity, CoachingConfig } from "../core/config";
import { actions, getState, useApp } from "../state/store";
import { Button, Icon, type IconName, Sheet, toast } from "../ui/kit";

const FEATURES: [IconName, string, string][] = [
  ["calendar", "Weekly Adjustments", "Your plan evolves with your average weight."],
  ["check", "Built Around You", "Macros and meals adapt to your foods."],
  ["dumbbell", "Bodybuilding Focused", "High-protein, performance-first nutrition."],
  ["chat", "Always Available", "Ask your coach questions whenever you need guidance."],
];

export function Paywall({ onClose }: { onClose: () => void }) {
  const s = useApp();
  const [status, setStatus] = useState<string>();
  const [legal, setLegal] = useState<"terms" | "privacy" | null>(null);
  const price = s.subscription.localizedPrice ?? `€${CoachingConfig.subscriptionMarketingComparisonEUR.toFixed(2)}`;
  const traditional = `€${CoachingConfig.traditionalCoachingComparisonEUR.toFixed(0)}+/month`;

  return (
    <Sheet title="My Coach AI" full onClose={onClose}>
      <div className="stack center">
        <h2 className="title">Coaching Without The {traditional} Price Tag</h2>
        <p className="sub">Full AI coaching, weekly check-ins, macro adjustments, meal plans and progress analysis.</p>
        <span className="badge training" style={{ alignSelf: "center" }}>
          {CoachingConfig.freeTrialDays} Days Free
        </span>
      </div>

      <div className="grid-2">
        <div className="card center tight" style={{ boxShadow: "none", border: "1px solid var(--border)" }}>
          <span className="caption">Traditional 1:1 Coaching</span>
          <span className="num-md muted">{traditional}*</span>
        </div>
        <div className="card center tight" style={{ border: "2px solid var(--primary)" }}>
          <span className="caption accent">My Coach AI</span>
          <span className="num-md accent">{price}/month</span>
        </div>
      </div>

      <div className="stack">
        {FEATURES.map(([icon, title, sub]) => (
          <div key={title} className="row" style={{ alignItems: "flex-start", gap: 12 }}>
            <span className="accent" style={{ paddingTop: 2 }}>
              <Icon name={icon} />
            </span>
            <div className="stack-sm" style={{ gap: 2 }}>
              <span className="headline">{title}</span>
              <span className="sub">{sub}</span>
            </div>
          </div>
        ))}
      </div>

      <div className="banner">
        <Icon name="info" size={18} />
        <span>
          Web preview: no payment is taken. Starting the trial unlocks Coach AI features locally on this device for{" "}
          {CoachingConfig.freeTrialDays} days.
        </span>
      </div>

      <div className="stack-sm">
        <Button
          onClick={() => {
            actions.startTrialLocally();
            toast("Trial started. Welcome to My Coach AI.");
            onClose();
          }}
        >
          {s.subscription.isTrialEligible ? `Start ${CoachingConfig.freeTrialDays}-Day Free Trial` : `Subscribe — ${price}/month`}
        </Button>
        <p className="caption center">Then {price}/month. Cancel anytime in Settings.</p>
        <button
          className="link-btn"
          onClick={() => {
            actions.restorePurchasesLocally();
            setStatus(getState().coachStatusMessage);
          }}
        >
          Restore Purchases
        </button>
        {status && <p className="caption center">{status}</p>}
      </div>

      <div className="stack-sm center">
        <p className="caption2">{CoachingConfig.traditionalCoachingFootnote}</p>
        <div className="row" style={{ justifyContent: "center", gap: 16 }}>
          <button className="link-btn" onClick={() => setLegal("terms")}>
            Terms
          </button>
          <button className="link-btn" onClick={() => setLegal("privacy")}>
            Privacy Policy
          </button>
        </div>
        <p className="caption2">Comparison figures are for marketing context only.</p>
      </div>

      {legal && (
        <Sheet title={legal === "terms" ? "Terms of Use" : "Privacy Policy"} onClose={() => setLegal(null)}>
          <p className="sub" style={{ whiteSpace: "pre-wrap" }}>
            {legal === "terms" ? TERMS : PRIVACY}
          </p>
        </Sheet>
      )}
    </Sheet>
  );
}

export const TERMS = `Terms of Use placeholder for ${AppIdentity.displayName}.

Replace this content with your final Terms before release.

Legal entity: ${AppIdentity.legalEntityPlaceholder}
Support: ${AppIdentity.supportContactPlaceholder}

Subscriptions renew automatically unless cancelled before the end of the current period.`;

export const PRIVACY = `Privacy Policy placeholder for ${AppIdentity.displayName}.

We collect information you enter (profile, weights, food logs, check-ins) to provide coaching. In this web version all data is stored only in this browser on this device. Progress photos never leave the device. When you scan a barcode, only the barcode number is sent to Open Food Facts to look up the product.

Health/fitness data is not used for advertising. Replace developer contact before release:
${AppIdentity.supportContactPlaceholder}

Full policy URL placeholder: ${AppIdentity.privacyPolicyURLPlaceholder}`;
