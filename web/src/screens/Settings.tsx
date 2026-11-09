import { useRef, useState } from "react";
import { AppIdentity, CoachingConfig } from "../core/config";
import { ageYears, today } from "../core/dates";
import {
  type AppearancePreference,
  AppearanceLabel,
  type FoodItem,
  GoalPhaseInfo,
  type MealSlot,
  MealSlotLabel,
  type NotificationSettings,
  type SubscriptionStatus,
  WEEKDAYS,
  WeekdayShort,
  hasCoachAIAccess,
} from "../core/models";
import { actions, useApp } from "../state/store";
import { FoodRow, Icon, Segmented, Sheet, Toggle, confirmDialog, toast } from "../ui/kit";
import { CustomFoodEditor } from "./FoodSheets";
import { PRIVACY, Paywall, TERMS } from "./Paywall";

const SUBSCRIPTION_LABEL: Record<SubscriptionStatus, string> = {
  trial: "Trial",
  active: "My Coach AI",
  gracePeriod: "Grace period",
  billingRetry: "Billing retry",
  expired: "Expired",
  pending: "Pending",
  notSubscribed: "Free (Food Log)",
};

const MEAL_NAME_FIELDS: [MealSlot, string][] = [
  ["breakfast", "Meal 1 name"],
  ["snack", "Meal 2 name"],
  ["lunch", "Meal 3 name (rest days)"],
  ["afternoonSnack", "Meal 4 name (rest days)"],
  ["dinner", "Meal 5 name"],
  ["preWorkout", "Pre / Intra Workout name"],
  ["postWorkout", "Post Workout name"],
];

const NOTIFICATION_FIELDS: [keyof NotificationSettings, string][] = [
  ["morningWeighInEnabled", "Morning weigh-in"],
  ["mealRemindersEnabled", "Meal reminders"],
  ["stepRemindersEnabled", "Step reminders"],
  ["weeklyCheckInEnabled", "Weekly check-in"],
  ["progressPhotosEnabled", "Progress photos"],
];

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="list-row">
      <span className="grow">{label}</span>
      <span className="muted">{value}</span>
    </div>
  );
}

function ButtonRow({ label, onClick, danger }: { label: string; onClick: () => void; danger?: boolean }) {
  return (
    <button className="list-row" onClick={onClick} style={{ color: danger ? "var(--danger)" : "var(--primary)" }}>
      {label}
    </button>
  );
}

export function Settings() {
  const s = useApp();
  const p = s.profile;
  const [customFoods, setCustomFoods] = useState(false);
  const [paywall, setPaywall] = useState(false);
  const [legal, setLegal] = useState<"terms" | "privacy" | null>(null);
  const importRef = useRef<HTMLInputElement>(null);

  const rebuild = () => {
    actions.rebuildTargetsFromProfile();
    if (hasCoachAIAccess(s.subscription)) actions.generateMealPlan(today());
  };

  function exportData() {
    const blob = new Blob([actions.exportDataJSON()], { type: "application/json" });
    const file = new File([blob], `MyCoach-Export-${today()}.json`, { type: "application/json" });
    // Android Chrome: share sheet (Drive, email, …). Fallback: plain download.
    const nav = navigator as Navigator & { canShare?: (d: { files: File[] }) => boolean };
    if (nav.canShare?.({ files: [file] })) {
      navigator.share({ files: [file], title: "My Coach export" }).catch(() => {});
      return;
    }
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = file.name;
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  async function importData(file: File) {
    if (
      !(await confirmDialog({
        title: "Restore from backup?",
        message: "This replaces all My Coach data on this device with the contents of the file.",
        confirm: "Restore",
        destructive: true,
      }))
    ) {
      return;
    }
    const ok = actions.importDataJSON(await file.text());
    toast(ok ? "Backup restored" : "That file isn't a My Coach export");
  }

  return (
    <>
      <p className="section-title">Profile</p>
      <div className="list">
        <label className="list-row">
          <span className="grow">Name</span>
          <input
            className="input"
            style={{ maxWidth: 180, minHeight: 38, textAlign: "right" }}
            value={p.displayName}
            onChange={(e) => actions.updateProfile({ displayName: e.target.value })}
          />
        </label>
        {p.dateOfBirth && <Row label="Age" value={String(ageYears(p.dateOfBirth))} />}
        <Row label="Height" value={`${Math.round(p.heightCm)} cm`} />
        <div className="list-row">
          <span className="grow">Weight unit</span>
          <div style={{ width: 120 }}>
            <Segmented
              options={[
                { value: "kilogram" as const, label: "kg" },
                { value: "pound" as const, label: "lb" },
              ]}
              value={p.weightUnit}
              onChange={(u) => actions.updateProfile({ weightUnit: u })}
            />
          </div>
        </div>
        <div className="list-row">
          <span className="grow">Goal</span>
          <select
            className="input"
            style={{ maxWidth: 170, minHeight: 38 }}
            value={p.goalPhase}
            onChange={(e) => {
              actions.updateProfile({ goalPhase: e.target.value as "cut" | "gain" });
              rebuild();
            }}
          >
            {(["cut", "gain", "maintenance"] as const).map((g) => (
              <option key={g} value={g}>
                {GoalPhaseInfo[g].name}
              </option>
            ))}
          </select>
        </div>
      </div>

      <p className="section-title">Coaching</p>
      <div className="list">
        <div className="list-row" style={{ flexDirection: "column", alignItems: "stretch", gap: 8 }}>
          <span>Training days ({p.trainingDays.length} / week)</span>
          <div className="row" style={{ gap: 6 }}>
            {WEEKDAYS.map((d) => {
              const on = p.trainingDays.includes(d);
              return (
                <button
                  key={d}
                  className={`chip grow${on ? " on" : ""}`}
                  style={{ padding: "8px 0" }}
                  aria-pressed={on}
                  onClick={() => {
                    const next = on ? p.trainingDays.filter((x) => x !== d) : [...p.trainingDays, d].sort();
                    if (next.length === 0) return toast("Keep at least one training day");
                    actions.updateProfile({ trainingDays: next });
                    rebuild();
                  }}
                >
                  {WeekdayShort[d]}
                </button>
              );
            })}
          </div>
        </div>
        <div className="list-row">
          <span className="grow">Step target</span>
          <div className="row">
            <button
              className="icon-btn"
              style={{ width: 34, height: 34 }}
              aria-label="Decrease step target"
              onClick={() => {
                actions.updateProfile({ stepTarget: Math.max(1_000, p.stepTarget - CoachingConfig.defaultStepIncrement) });
                rebuild();
              }}
            >
              <Icon name="minus" size={16} />
            </button>
            <span className="num" style={{ minWidth: 56, textAlign: "center" }}>
              {p.stepTarget.toLocaleString()}
            </span>
            <button
              className="icon-btn"
              style={{ width: 34, height: 34 }}
              aria-label="Increase step target"
              onClick={() => {
                actions.updateProfile({
                  stepTarget: Math.min(CoachingConfig.maxStepTarget, p.stepTarget + CoachingConfig.defaultStepIncrement),
                });
                rebuild();
              }}
            >
              <Icon name="plus" size={16} />
            </button>
          </div>
        </div>
        <Row label="Meals per day" value={String(CoachingConfig.requiredMealCount)} />
        <Row label="Preferred foods" value={String(p.preferredFoods.length)} />
        <Row label="Avoided foods" value={String(p.dislikedFoods.length)} />
        <Toggle label="Intra-workout nutrition" checked={p.intraWorkoutEnabled} onChange={(v) => actions.setIntraWorkoutEnabled(v)} />
        <Toggle
          label="Auto-adjust calories from my model"
          sub="Your personal metabolism model updates targets at most once a week (Coach AI)."
          checked={s.preferences.adaptiveAutoAdjust}
          onChange={(v) => actions.updatePreferences({ adaptiveAutoAdjust: v })}
        />
      </div>

      <p className="section-title">Nutrition</p>
      <div className="list">
        {MEAL_NAME_FIELDS.map(([slot, label]) => (
          <label key={slot} className="list-row">
            <span className="grow caption">{label}</span>
            <input
              className="input"
              style={{ maxWidth: 190, minHeight: 38 }}
              placeholder={MealSlotLabel[slot]}
              defaultValue={s.preferences.customMealNames[slot] ?? ""}
              onBlur={(e) => actions.setMealName(slot, e.target.value)}
            />
          </label>
        ))}
        <button className="list-row" onClick={() => setCustomFoods(true)}>
          <span className="grow">Custom foods ({s.customFoods.length})</span>
          <Icon name="chevronRight" size={16} className="muted" />
        </button>
      </div>

      <p className="section-title">Appearance</p>
      <Segmented
        options={(["system", "light", "dark"] as AppearancePreference[]).map((a) => ({ value: a, label: AppearanceLabel[a] }))}
        value={p.appearance}
        onChange={(a) => actions.updateProfile({ appearance: a })}
      />

      <p className="section-title">Reminders</p>
      <div className="list">
        {NOTIFICATION_FIELDS.map(([key, label]) => (
          <Toggle
            key={key}
            label={label}
            checked={s.preferences.notifications[key]}
            onChange={(v) => actions.updatePreferences({ notifications: { ...s.preferences.notifications, [key]: v } })}
          />
        ))}
      </div>
      <p className="caption" style={{ padding: "0 4px" }}>
        Saved as preferences. The web version doesn't send scheduled reminders yet.
      </p>

      <p className="section-title">Subscription</p>
      <div className="list">
        <Row label="Current plan" value={SUBSCRIPTION_LABEL[s.subscription.status]} />
        {s.subscription.expirationDate && hasCoachAIAccess(s.subscription) && (
          <Row label="Renews / ends" value={new Date(s.subscription.expirationDate).toLocaleDateString()} />
        )}
        <ButtonRow label="Manage Subscription / Upgrade" onClick={() => setPaywall(true)} />
        <ButtonRow
          label="Restore Purchases"
          onClick={() => {
            actions.restorePurchasesLocally();
            toast(hasCoachAIAccess(s.subscription) ? "Subscription restored." : "No active subscription found to restore.");
          }}
        />
        {hasCoachAIAccess(s.subscription) && (
          <ButtonRow
            label="Cancel Trial"
            danger
            onClick={async () => {
              if (await confirmDialog({ title: "End Coach AI trial?", message: "Food logging stays free.", confirm: "End Trial", destructive: true })) {
                actions.cancelSubscriptionLocally();
              }
            }}
          />
        )}
      </div>

      <p className="section-title">Privacy &amp; Data</p>
      <div className="list">
        <ButtonRow label="Privacy Policy" onClick={() => setLegal("privacy")} />
        <ButtonRow label="Export My Data" onClick={exportData} />
        <ButtonRow label="Restore From Backup…" onClick={() => importRef.current?.click()} />
        <ButtonRow
          label="Delete Coaching Data"
          danger
          onClick={async () => {
            if (
              await confirmDialog({
                title: "Delete coaching data?",
                message: "This removes weigh-ins, meal plans, diaries, photos and check-ins from this device. Custom foods are kept.",
                confirm: "Delete Weight, Meals, Photos & Check-Ins",
                destructive: true,
              })
            ) {
              actions.deleteCoachingData();
              toast("Coaching data deleted");
            }
          }}
        />
      </div>
      <input
        ref={importRef}
        type="file"
        accept="application/json,.json"
        className="sr-only"
        onChange={(e) => {
          const f = e.target.files?.[0];
          e.target.value = "";
          if (f) importData(f);
        }}
      />
      <p className="caption" style={{ padding: "0 4px" }}>
        All data is stored only in this browser on this device. Export regularly to keep a backup.
      </p>

      <p className="section-title">Account</p>
      <div className="list">
        <ButtonRow
          label="Delete Account"
          danger
          onClick={async () => {
            if (
              await confirmDialog({
                title: "Delete your My Coach account?",
                message:
                  "This permanently deletes your local My Coach profile, coaching history, foods and preferences on this device. This cannot be undone.",
                confirm: "Delete Account & All Local Data",
                destructive: true,
              })
            ) {
              actions.deleteAccountLocally();
            }
          }}
        />
      </div>

      <p className="section-title">About</p>
      <div className="list">
        <Row label="Version" value={__APP_VERSION__} />
        <ButtonRow label="Terms of Use" onClick={() => setLegal("terms")} />
        <Row label="Support" value={AppIdentity.supportContactPlaceholder} />
      </div>

      {customFoods && <CustomFoodsList onClose={() => setCustomFoods(false)} />}
      {paywall && <Paywall onClose={() => setPaywall(false)} />}
      {legal && (
        <Sheet title={legal === "terms" ? "Terms of Use" : "Privacy Policy"} onClose={() => setLegal(null)}>
          <p className="sub" style={{ whiteSpace: "pre-wrap" }}>
            {legal === "terms" ? TERMS : PRIVACY}
          </p>
        </Sheet>
      )}
    </>
  );
}

function CustomFoodsList({ onClose }: { onClose: () => void }) {
  const s = useApp();
  const [editing, setEditing] = useState<FoodItem | "new" | null>(null);
  return (
    <Sheet
      title="Custom Foods"
      full
      onClose={onClose}
      right={
        <button className="link-btn" onClick={() => setEditing("new")}>
          Create
        </button>
      }
    >
      {s.customFoods.length === 0 ? (
        <p className="sub center">No custom foods yet.</p>
      ) : (
        <div className="list">
          {s.customFoods.map((f) => (
            <FoodRow key={f.id} food={f} chevron onClick={() => setEditing(f)} />
          ))}
        </div>
      )}
      {editing && (
        <CustomFoodEditor
          existing={editing === "new" ? undefined : editing}
          onClose={() => setEditing(null)}
          onSave={(food) => {
            actions.saveCustomFood(food);
            setEditing(null);
          }}
          onDelete={
            editing === "new"
              ? undefined
              : async () => {
                  if (await confirmDialog({ title: `Delete ${editing.name}?`, confirm: "Delete", destructive: true })) {
                    actions.deleteCustomFood(editing.id);
                    setEditing(null);
                  }
                }
          }
        />
      )}
    </Sheet>
  );
}
