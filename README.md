# My Coach

iOS nutrition and physique coaching app: deterministic engines first, Coach AI second.

> **Blocked on this Mac until you accept the Xcode license.** See [`docs/SETUP.md`](docs/SETUP.md) — run `sudo xcodebuild -license accept` in Terminal, then ask the agent to compile and run tests.

> **Windows / Android:** a full web port lives in [`web/`](web/README.md). Run `cd web && npm install && npm run dev` on Windows, then install it on Android phones as an app (PWA).

## Requirements

- **Xcode 16+** (developed against Xcode 26 / iOS SDK shipping with it)
- **iOS deployment target:** 17.0
- **Swift:** 5.0 language mode (`SWIFT_VERSION = 5.0`)
- Apple Developer Program membership for device installs, TestFlight, and App Store distribution

Before building on a fresh Mac, accept the Xcode license:

```bash
sudo xcodebuild -license accept
```

## Open & build

1. Open `MyCoach.xcodeproj` in Xcode.
2. Select the **MyCoach** scheme and an iPhone simulator or device.
3. Set your **Team** under Signing & Capabilities (Automatic signing is enabled).
4. Product → Run (`⌘R`).

Regenerate the Xcode project after adding/removing Swift files:

```bash
python3 Scripts/generate_xcode_project.py
```

Optional XcodeGen alternative (if installed):

```bash
xcodegen generate
```

## Personal adaptive model

On both iOS and Android, the coach trains a per-user model on the device from logged weight, food and steps. A Kalman filter smooths the weight trend, and an online Bayesian regression learns the user's maintenance, step burn and adaptation. The model predicts the weekly rate of change and automatically adjusts calorie targets toward the goal, capped at 300 kcal and at most once a week. See [`docs/ADAPTIVE_MODEL.md`](docs/ADAPTIVE_MODEL.md).

## Architecture

```
UI (SwiftUI)
  → AppEnvironment / feature views
    → Deterministic engines (NutritionEngine, CoachingDecisionEngine, MealPlanSolver, …)
    → Local persistence / Keychain / StoreKit
    → Coach AI provider (local deterministic fallback OR HTTPS proxy)
```

**Rule:** calorie, macro, step, and weekly-adjustment math come from on-device engines. AI may explain or coach in natural language but must not invent or override engine numbers.

Free food logging remains available without a Coach AI subscription.

## Configuration placeholders

Replace before distribution (see `MyCoach/Core/Configuration/AppIdentity.swift` and related config):

| Placeholder | Current value | Action |
|---|---|---|
| Bundle ID | `com.company.mycoach` | Change to your reverse-DNS ID in Xcode / App Store Connect |
| Legal entity | `[Legal entity / developer name — replace…]` | Real publisher name |
| Support email | `[Your support email — replace…]` | Real contact |
| Privacy Policy URL | `https://example.com/privacy` | Hosted HTTPS policy |
| Terms URL | `https://example.com/terms` | Hosted HTTPS terms |
| Coach AI backend URL | (configure in `RemoteCoachAI` / environment) | Your secure proxy base URL — **no API keys in the app** |
| Food database API | Bundled local catalog by default | Wire a commercial provider + credentials **server-side or via licensed SDK**; never present mock data as production |
| Subscription product | `com.company.mycoach.coach.monthly` | Match App Store Connect + `MyCoach.storekit` |

## StoreKit local testing

The shared **MyCoach** scheme references:

`MyCoach/Resources/StoreKit/MyCoach.storekit`

- Product: `com.company.mycoach.coach.monthly`
- Group: Coach AI
- Introductory offer: 14-day free trial

Run the app from that scheme to exercise purchases in the local StoreKit configuration without App Store Connect sandbox initially. For device sandbox and TestFlight, create matching products in App Store Connect.

## Tests

In Xcode: Product → Test (`⌘U`), or:

```bash
xcodebuild test \
  -project MyCoach.xcodeproj \
  -scheme MyCoach \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Unit tests live in `MyCoachTests/`; UI tests in `MyCoachUITests/`.

## Archive for distribution

1. Select a real device destination or **Any iOS Device (arm64)**.
2. Product → Archive.
3. Organizer → Distribute App → App Store Connect (or export IPA).
4. Complete App Privacy, encryption, and content-rights questionnaires in App Store Connect.

Archiving and upload require a valid signing team, certificates, and App Store Connect app record. This repository does not fabricate certificate or account IDs.

## Unresolved external prerequisites

These are required for a production release but are **not** fully provisioned in-repo:

- Apple Developer Team + unique bundle identifier
- App Store Connect app, subscription group, and monthly product with trial
- Hosted Privacy Policy and Terms (placeholders under `MyCoach/Resources/Legal/`)
- Secure Coach AI HTTPS proxy and model credentials (see `docs/BACKEND_AI.md`)
- Licensed commercial food nutrition data (if replacing the bundled catalog)
- HealthKit capability / entitlements if you ship Health step import on device

Completing scaffolding and checklists does **not** guarantee App Store approval.
