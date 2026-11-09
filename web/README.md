# My Coach — Web / Android (PWA)

A web port of the iOS app that runs on Windows for development and installs on Android phones as an app (a Progressive Web App). It has the same deterministic engines as the Swift app — nutrition targets, the weekly coaching decision engine, the meal-plan solver and workout stagnation tracking — with a React UI.

- **Offline-first:** after the first load, the installed app works with no connection.
- **Local data:** everything is saved in the browser's `localStorage` on the device. Use **Settings → Export My Data** for backups and **Restore From Backup…** to move to another phone.
- **No payments:** "Start 14-Day Free Trial" unlocks Coach AI features locally. Nothing is charged.

## Personal adaptive model

The coach learns each user's own metabolism from their logged weight, food and steps. It uses a Kalman-filtered weight trend plus an online Bayesian regression, both trained on the device. It predicts their weekly rate of change and automatically adjusts calorie targets toward their goal, at most once a week and within safety caps. See [docs/ADAPTIVE_MODEL.md](../docs/ADAPTIVE_MODEL.md). The same model runs on iOS (`MyCoach/Services/Adaptive/AdaptiveModel.swift`), and `npm run fixtures` keeps the two implementations numerically identical.

## Requirements (Windows)

- Node.js 20+ (`node --version`)
- Chrome on the Android phone

## Run it on Windows

```powershell
cd web
npm install        # first time only
npm run dev        # opens http://localhost:5173 in your browser
```

To get a phone-sized view in desktop Chrome, press `F12`, then `Ctrl+Shift+M`, and pick a Pixel device.

Other scripts:

| Command | What it does |
|---|---|
| `npm test` | Runs the engine, model and state tests (Vitest) |
| `npm run fixtures` | With `GEN_FIXTURE=1`, regenerates the iOS/Android parity fixture after changing `adaptive.ts` |
| `npm run typecheck` | TypeScript check |
| `npm run build` | Production build into `web/dist/` |
| `npm run preview` | Serves the production build on port 4173 (offline mode and installability only work in this build) |

## Open it on an Android phone

There are three ways to do it. Installing as an app plus offline mode needs **HTTPS or `localhost`**, so option A or C gives the full app experience.

### A. USB cable (full PWA, best for testing)

1. On the phone, enable **Developer options → USB debugging**.
2. Install [Android platform-tools](https://developer.android.com/tools/releases/platform-tools) on Windows (it provides `adb`).
3. Run:
   ```powershell
   npm run build
   npm run preview
   adb reverse tcp:4173 tcp:4173
   ```
4. On the phone, open Chrome and go to `http://localhost:4173`. Then choose **⋮ → Add to Home screen → Install**.

### B. Same Wi-Fi (quick look, no install)

`npm run dev` and `npm run preview` also listen on your LAN. Vite prints a `Network:` address such as `http://192.168.1.20:5173`. Open that address in Chrome on the phone.

- If Windows asks, allow Node.js through the firewall on **Private networks**.
- Over plain `http://` on a LAN address, Chrome won't install the app or enable offline mode. Everything else works.

### C. Host it on HTTPS (for real use)

`npm run build` outputs a static site in `web/dist/`. It uses relative paths, so it works from any folder. Upload it to any static host with HTTPS (GitHub Pages, Netlify, Cloudflare Pages, Vercel). Then open the URL on the phone and **Install app**.

## What's Android-specific

- **Back button / back gesture:** closes the open sheet or dialog instead of leaving the app.
- **Number fields:** open the numeric keypad and accept `82,5` as well as `82.5`.
- **During a workout:** the screen stays awake (Wake Lock), and the phone vibrates when the 3-minute rest timer ends.
- **Barcode scanning:** the Foods tab (and Add Food) scans food barcodes with the phone camera, using Chrome's built-in barcode detector or the ZXing decoder as a fallback. Products are looked up on [Open Food Facts](https://openfoodfacts.org); only the barcode number is sent. You check the values before saving, and saved products scan instantly offline afterwards. The camera needs HTTPS or `localhost` (options A or C below); on a plain LAN address, type the number instead.
- **Progress photos:** taken with the camera or picked from the gallery. They are downscaled and never leave the device.
- **Data export:** uses the Android share sheet (Drive, Gmail and so on).
- **Status bar colour:** follows the Light/Dark appearance setting.

## Differences from the iOS app

| iOS | Web / Android |
|---|---|
| StoreKit subscription | Local trial toggle. No payments. |
| HealthKit steps | Manual step entry |
| Local notifications | Reminder toggles are saved, but nothing is scheduled yet |
| Remote Coach AI proxy (optional) | Local deterministic coach only |

## Project layout

```
web/
  public/            manifest, service worker, icons
  src/core/          models, config, date helpers (ported from Swift)
  src/engines/       nutrition, coaching, meal plan, weight, workout, coach AI
  src/state/store.ts app state + actions + persistence (port of AppEnvironment.swift)
  src/ui/kit.tsx     design-system components (port of MCComponents/MCTheme)
  src/screens/       Today, Meal Plan, Food Log, Workout, Progress, Coach, Settings, Onboarding
  tests/             Vitest tests for engines and store
```

The engines must stay numerically identical to the Swift ones. If you change a constant in `CoachingConfig.swift`, mirror it in `src/core/config.ts`.
