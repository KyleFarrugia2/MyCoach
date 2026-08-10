# Privacy Policy (Placeholder)

**Status:** Placeholder — replace with a lawyer-reviewed policy hosted at a public HTTPS URL before App Store submission.

**Legal entity:** `[Legal entity / developer name — replace before App Store submission]`

**Effective date:** `[Insert date]`

**Contact:** `[Your support email — replace before App Store submission]`

## Overview

My Coach (“the App”) helps you track nutrition, body weight, steps, progress photos, and coaching decisions related to physique goals.

This placeholder describes the categories of data the App is designed to handle. It is not legal advice and must not be published as a finished policy.

## Data the App May Process

- Account or profile details you enter (e.g. name or display preferences, biological sex for calorie floors, height, goal type).
- Body weight entries and weekly averages.
- Food diary entries, custom foods, and meal plan selections.
- Optional HealthKit step counts (read-only) when you grant permission; manual step entry always works without Health access.
- Weekly check-in answers (adherence, appearance, training performance, hunger, energy).
- Progress photos captured with the camera for your own tracking (front / side / back).
- Subscription entitlement status from StoreKit / App Store.
- Optional Coach AI chat messages and structured coaching explanations when you use Coach AI.

## How Data Is Used

- To calculate nutrition targets, meal plans, and coaching recommendations on-device using deterministic engines.
- To sync or restore purchases via Apple.
- To optionally call a **secure backend proxy** for Coach AI explanations (no third-party AI API keys are embedded in the App).
- To improve reliability of the product (crash diagnostics only if you later enable a privacy-preserving tooling stack and disclose it).

## What We Do Not Do (Product Intent)

- The App does not require HealthKit for core coaching or paid features.
- Progress photos and exact body weight should not be sold or used for unrelated advertising analytics.
- Private AI API keys must never ship inside the iOS binary.

## Sharing

- Apple processes payments and subscription status.
- If Coach AI is enabled against a production backend, messages and limited coaching context are sent to **your** HTTPS proxy — configure retention and subprocessors in the final policy.
- Commercial food database providers (if configured) receive search queries only as needed to return nutrition results.

## Retention & Deletion

Document how long data is stored on device and on any backend, and how users request deletion. If accounts are introduced, provide an in-app account deletion path.

## Permissions

- **Camera:** weekly progress photos.
- **Health (optional share):** read step counts to compare against your step target.

## Changes

Replace this file with the live policy text and update `AppIdentity.privacyPolicyURLPlaceholder` to the public URL.
