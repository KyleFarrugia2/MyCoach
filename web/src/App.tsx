import { useEffect } from "react";
import { type MainTab, actions, useApp } from "./state/store";
import { Icon, type IconName, OverlayHost } from "./ui/kit";
import { Coach } from "./screens/Coach";
import { FoodLog } from "./screens/FoodLog";
import { Foods } from "./screens/Foods";
import { MealPlan } from "./screens/MealPlan";
import { Onboarding } from "./screens/Onboarding";
import { Progress } from "./screens/Progress";
import { Today } from "./screens/Today";
import { Workout } from "./screens/Workout";

const TABS: { id: MainTab; label: string; icon: IconName }[] = [
  { id: "today", label: "Today", icon: "sun" },
  { id: "mealPlan", label: "Meal Plan", icon: "fork" },
  { id: "log", label: "Log", icon: "list" },
  { id: "foods", label: "Foods", icon: "basket" },
  { id: "workout", label: "Workout", icon: "dumbbell" },
  { id: "progress", label: "Progress", icon: "chart" },
  { id: "coach", label: "Coach", icon: "chat" },
];

/** Applies the Light/Dark/System appearance preference and keeps the Android status bar colour in sync. */
function useAppearance(pref: "system" | "light" | "dark") {
  useEffect(() => {
    const root = document.documentElement;
    if (pref === "system") root.removeAttribute("data-theme");
    else root.setAttribute("data-theme", pref);
    const media = window.matchMedia("(prefers-color-scheme: dark)");
    const sync = () => {
      const dark = pref === "dark" || (pref === "system" && media.matches);
      document.querySelector('meta[name="theme-color"]')?.setAttribute("content", dark ? "#0d121f" : "#1f73f2");
    };
    sync();
    media.addEventListener("change", sync);
    return () => media.removeEventListener("change", sync);
  }, [pref]);
}

export function App() {
  const s = useApp();
  useAppearance(s.profile.appearance);

  useEffect(() => {
    window.scrollTo(0, 0);
  }, [s.selectedTab]);

  if (!s.profile.hasCompletedOnboarding) {
    return (
      <>
        <Onboarding />
        <OverlayHost />
      </>
    );
  }

  const screen = {
    today: <Today />,
    mealPlan: <MealPlan />,
    log: <FoodLog />,
    foods: <Foods />,
    workout: <Workout />,
    progress: <Progress />,
    coach: <Coach />,
  }[s.selectedTab];

  return (
    <div className="app">
      <main key={s.selectedTab}>{screen}</main>
      <nav className="tabbar" aria-label="Main">
        <div className="tabbar-inner">
          {TABS.map((t) => (
            <button
              key={t.id}
              className={s.selectedTab === t.id ? "on" : ""}
              aria-current={s.selectedTab === t.id ? "page" : undefined}
              onClick={() => actions.selectTab(t.id)}
            >
              <Icon name={t.icon} />
              {t.label}
            </button>
          ))}
        </div>
      </nav>
      <OverlayHost />
    </div>
  );
}
