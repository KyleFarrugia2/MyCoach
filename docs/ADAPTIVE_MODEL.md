# Personal Adaptive Model

My Coach learns each user's own response to calories from their logged history and uses it to set calorie targets. The model is trained on the device, separately for every user. It needs no server and no LLM: it is a statistical model that is re-fitted every time new data is logged.

| | Path |
|---|---|
| Reference implementation (TypeScript) | `web/src/engines/adaptive.ts` |
| iOS port (Swift) | `MyCoach/Services/Adaptive/AdaptiveModel.swift` |
| App integration | `web/src/state/store.ts` · `MyCoach/App/AppEnvironment.swift` (extension at the end of the file) |
| Tests | `web/tests/adaptive*.test.ts` · `MyCoachTests/AdaptiveModelTests.swift` |

## What it learns

For each user, the model estimates three parameters, each with an uncertainty:

| Parameter | Meaning | Prior (before any data) |
|---|---|---|
| θ₀ | Maintenance calories at 8,000 steps/day | Mifflin–St Jeor × activity estimate, SD 350 kcal |
| θ₁ | Extra kcal burned per additional 1,000 steps | 0.45 kcal × body weight (kg), SD 25 |
| θ₂ | Change in expenditure per +1,000 kcal/day eaten (adaptive thermogenesis, NEAT) | +100 kcal, SD 120 |

Expenditure on any plan is modelled as:

```
TDEE(intake, steps) = θ₀ + θ₁·(steps − 8000)/1000 + θ₂·(intake − prior maintenance)/1000
```

## How it learns

1. **Weight trend (Kalman filter).** A local-linear-trend Kalman filter, followed by a Rauch–Tung–Striebel smoother, runs over the daily morning weigh-ins. It splits each reading into true tissue change (level and slope) and water noise (σ ≈ 0.55 kg), and it bridges missed days. In tests it cuts weight-tracking error by more than half compared with raw readings.

2. **Training examples.** Each 7-day window ending today becomes one training example, working backwards a week at a time. A window counts only if it has at least 4 complete food-log days and at least 3 weigh-ins. Its target is the *implied expenditure*:

   ```
   y = mean logged intake − 7700 kcal/kg × Δ(trend weight) / 7
   ```

   Each example also gets its own noise variance. That variance combines the smoother's uncertainty about the trend, intake-reporting noise (which shrinks as more days are logged), and a residual term. Sparse or noisy weeks therefore count for less.

3. **Bayesian regression updated online.** The parameters are updated with a Kalman filter in date order (recursive least squares). Before each week's update, a small random-walk drift is added to the parameters (25 kcal/week on maintenance). This lets the model follow real metabolic changes over a diet instead of averaging them away. The result is a posterior mean θ and a covariance Σ.

4. **Continuous updates.** Whenever weight, food or steps are logged, edited or deleted, and at app launch, the model is re-fitted over the full history (capped at 365 days). Re-fitting the stream is deterministic and costs O(days), so edits and deletions are handled correctly. The result is cached until the data changes.

### Which food logs count

A day's diary is used only if it looks complete: it is marked complete, or its total is at least 50% of that day's target and at least 600 kcal. Today is excluded until it's marked complete. A half-logged day would otherwise look like a big deficit and teach the model a falsely low maintenance.

Under-reporting that is *consistent* is absorbed by the model, and that is intended. The model learns the user's response to calories *as they log them*, which is the same scale the targets are set in.

## Prediction and control

- **Predicted rate** on any plan: `(intake − TDEE) × 7 / 7700` kg/week. Its uncertainty comes from `xᵀΣx`.
- **Goal rate:**
  - Cutting: −0.7% of trend body weight per week, clamped to 0.35–1.0 kg.
  - Gaining: +0.25% per week, clamped to 0.15–0.5 kg.
  - Near the goal weight, the rate tapers so the goal is reached in about 4 more weeks or later. Once the goal is reached, the target rate becomes 0 (hold steady).
- **Required intake:** the model is inverted analytically, including the adaptation term: `I = (ρr/7 + θ₀ + θ₁s − θ₂M₀) / (1 − θ₂)`. Here θ₂ is clamped to [−200, 500] kcal.
- **Plan change:** the change is the difference between the required intake and the plan's weekly-average intake. It is applied to the training-day target, and the rest day follows the existing ~500 kcal offset rule.

## Guardrails

| Rule | Value |
|---|---|
| Minimum confidence before acting | **Medium**: ≥ 3 training weeks *and* posterior SD of maintenance ≤ 160 kcal. **High**: ≥ 5 weeks and SD ≤ 120. With typical logging this is reached in about 5 and 8 weeks. |
| Maximum change per adjustment | 300 kcal (same as `CoachingConfig.maximumSingleWeekCalorieChange`) |
| Deadband | Changes under 50 kcal are ignored. |
| Frequency | At most one plan change per 7 days, counting check-in changes too. |
| Calorie floors | The existing sex-specific minimums (`clampCalories`) still apply. |
| Protein and fat | Macros are rebuilt with the existing engine. Calorie changes land mostly on carbohydrates. |
| Access and control | Requires Coach AI. Users can turn **Auto-adjust calories from my model** off in Settings and apply changes manually. |
| Weekly check-in | The rule engine still decides *whether* calories may change (too few weigh-ins, poor adherence, extreme swings, recovery). When it would make a standard fixed ±150 kcal move or "maintain", a confident model decides *how much* instead. The decision is tagged `modelPrediction`. |

Every automatic change is recorded as a `PlanAdjustment` with `source = adaptiveModel` and explained in the coach chat. The targets are tagged `adaptiveModel`, which shows as "Personalised" on Today. The coach chat only *quotes* the model's numbers; it never makes them up.

## Validation

`web/tests/adaptive.test.ts` uses a simulated person whose true metabolism differs from the formula. On noisy, incomplete logs, with 15% of weigh-ins and food days missing:

- The smoothed trend is more than twice as accurate as raw weigh-ins.
- After 12 weeks, learned maintenance is within 150 kcal of the truth, and much closer than the formula.
- The posterior SD shrinks and confidence rises as more data arrives.
- A 4-week forward prediction on a *new* intake beats the formula's prediction and is within 0.25 kg/week of the truth.
- The controller exactly inverts the prediction, and the cap and deadband hold.

Across 40 simulated users, maintenance error after 14 weeks was typically under 50 kcal, and the 95% interval covered the truth every time. In other words, the stated uncertainty is cautious rather than overconfident.

## Keeping iOS and Android identical

The TypeScript file is the reference implementation. After changing anything in `adaptive.ts`:

```powershell
cd web
$env:GEN_FIXTURE=1; npm run fixtures; Remove-Item Env:GEN_FIXTURE
```

This regenerates `web/tests/fixtures/adaptive-fixture.json` and `MyCoachTests/AdaptiveModelFixture.swift`. Mirror the change in `AdaptiveModel.swift`, then run the iOS tests in Xcode. `AdaptiveModelTests` checks every output to a relative error of 1e-6. Without `GEN_FIXTURE`, `npm test` fails if the committed fixture no longer matches the TypeScript code.

## Limits

- 7,700 kcal/kg is a population constant. The model learns *expenditure*, not body-composition-specific energy density, so for a lean user gaining muscle the absolute numbers are approximate. The error is consistent, however, so the controller still converges.
- The model needs logged food. Users who only weigh in keep the prior and the rule engine.
- Step counts are entered manually on Android. On iOS, HealthKit steps (`StepEntry.source = .healthKit`) feed the model automatically once that integration is enabled.
