import Foundation

/// Personal adaptive energy-balance model (on-device machine learning).
///
/// Line-for-line port of the reference implementation in `web/src/engines/adaptive.ts`. Keep the two
/// numerically identical — `AdaptiveModelTests` checks this port against the TypeScript-generated
/// `AdaptiveModelFixture`.
///
/// Two learners, both Bayesian and updated online as data arrives:
///
/// 1. **Weight trend** — local-linear-trend Kalman filter + Rauch–Tung–Striebel smoother over morning
///    weigh-ins. Separates tissue change (level, slope) from day-to-day water noise and handles gaps.
/// 2. **Energy expenditure** — Bayesian linear regression learned with a Kalman filter over its parameters
///    (recursive least squares with random-walk drift, so it tracks metabolic adaptation). Each ~weekly
///    window yields the user's *implied* expenditure
///
///        y = mean logged intake − ρ · Δtrend / days        (ρ ≈ 7700 kcal/kg)
///
///    regressed on x = [1, (steps − 8000)/1000, (trailing 14-day intake − prior maintenance)/1000], so
///    θ = [personal maintenance, kcal per extra 1000 steps, expenditure response per +1000 kcal eaten].
///
/// The posterior (θ, Σ) predicts the weekly rate — with uncertainty — for any intake/steps plan, and
/// the controller inverts it to find the intake that hits the goal rate.
enum AdaptiveConfig {
    static let kcalPerKg = 7700.0
    static let windowDays = 7
    static let minLoggedIntakeDays = 4
    static let minWeighInsPerWindow = 3
    static let adaptationLookbackDays = 14
    static let referenceSteps = 8000.0

    // Weight-trend Kalman filter (kg, per day).
    static let trendLevelProcessVar = 0.005
    static let trendSlopeProcessVar = 2e-5
    static let weighInNoiseVar = 0.3
    static let trendInitialLevelVar = 1.0
    static let trendInitialSlopeVar = 0.01

    // Parameter priors and drift (per observation ≈ per week).
    static let priorMaintenanceSD = 350.0
    static let priorStepCoefficientPerKg = 0.45
    static let priorStepCoefficientSD = 25.0
    static let priorAdaptationMean = 100.0
    static let priorAdaptationSD = 120.0
    static let driftMaintenanceSD = 25.0
    static let driftStepSD = 1.0
    static let driftAdaptationSD = 5.0
    static let intakeReportingSD = 200.0
    static let modelResidualSD = 100.0

    // Confidence thresholds on the posterior SD of maintenance at current habits.
    static let highConfidenceMaxSD = 120.0
    static let highConfidenceMinObservations = 5
    static let mediumConfidenceMaxSD = 160.0
    static let mediumConfidenceMinObservations = 3

    // Controller.
    static let cutRatePercentPerWeek = 0.7
    static let cutRateMinKg = 0.35
    static let cutRateMaxKg = 1.0
    static let gainRatePercentPerWeek = 0.25
    static let gainRateMinKg = 0.15
    static let gainRateMaxKg = 0.5
    static let goalApproachWeeks = 4.0
    static let adaptationClampMin = -200.0
    static let adaptationClampMax = 500.0
    static let adjustmentDeadbandKcal = 50.0
    static let maxAdjustmentKcal = 300.0
    static let minDaysBetweenAutoAdjustments = 7.0
}

struct AdaptiveDay: Codable, Equatable, Sendable {
    var weightKg: Double?
    var intakeKcal: Double?
    var steps: Double?
}

struct AdaptiveFitInput: Sendable {
    /// Consecutive calendar days, oldest first; the last element is "today".
    var days: [AdaptiveDay]
    /// Formula maintenance estimate (Mifflin–St Jeor × activity) used as the prior mean.
    var priorMaintenanceKcal: Double
    var bodyWeightKg: Double
    var fallbackSteps: Double
    var fallbackIntakeKcal: Double
}

enum AdaptiveModelConfidence: String, Codable, Sendable {
    case low
    case medium
    case high
}

struct AdaptiveTrendPoint: Equatable, Sendable {
    var day: Int
    var levelKg: Double
    var slopeKgPerDay: Double
    var levelVar: Double
}

struct AdaptiveObservation: Codable, Equatable, Sendable {
    var endDay: Int
    var impliedExpenditure: Double
    var features: [Double]
    var noiseVar: Double
    /// One-step-ahead prediction error before the update.
    var residual: Double
}

struct AdaptiveTrendSummary: Codable, Equatable, Sendable {
    var levelKg: Double
    var slopeKgPerWeek: Double
    var slopeSDKgPerWeek: Double
}

struct AdaptiveModelSnapshot: Codable, Equatable, Sendable {
    var priorMaintenanceKcal: Double
    var theta: [Double]
    var covariance: [[Double]]
    var observations: Int
    var loggedIntakeDays: Int
    var weighIns: Int
    var trend: AdaptiveTrendSummary?
    var currentSteps: Double
    var currentIntakeKcal: Double
    var maintenanceKcal: Double
    var maintenanceSD: Double
    var confidence: AdaptiveModelConfidence
    var rmseKcal: Double?
    var history: [AdaptiveObservation]
}

struct AdaptiveRatePrediction: Equatable, Sendable {
    var meanKgPerWeek: Double
    var sdKgPerWeek: Double
    var expenditureKcal: Double
}

struct AdaptivePlanCalories: Equatable, Sendable {
    var trainingKcal: Double
    var restKcal: Double
    var trainingDaysPerWeek: Int
}

struct AdaptiveRecommendation: Equatable, Sendable {
    var targetKgPerWeek: Double
    var currentAverageIntake: Double
    var predictedCurrent: AdaptiveRatePrediction
    var requiredAverageIntake: Double
    /// Change to apply to the training-day target (rest day follows); 0 inside the deadband.
    var deltaKcal: Int
    var predictedAfter: AdaptiveRatePrediction
    var shouldAdjust: Bool
    var confidence: AdaptiveModelConfidence
    var summary: String
}

struct AdaptiveForecastPoint: Equatable, Sendable {
    var week: Int
    var meanKg: Double
    var sdKg: Double
}

enum AdaptiveModel {
    // MARK: - Linear algebra (3×3 / 2×2, explicit for parity with TypeScript)

    private static func matVec3(_ m: [[Double]], _ v: [Double]) -> [Double] {
        [
            m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2],
            m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2],
            m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2],
        ]
    }

    private static func dot3(_ a: [Double], _ b: [Double]) -> Double {
        a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
    }

    private static func quad3(_ m: [[Double]], _ v: [Double]) -> Double {
        dot3(v, matVec3(m, v))
    }

    private static func mean(_ xs: [Double]) -> Double {
        xs.reduce(0, +) / Double(xs.count)
    }

    // MARK: - 1. Weight trend: Kalman filter + RTS smoother

    static func smoothWeightTrend(_ days: [AdaptiveDay]) -> [AdaptiveTrendPoint] {
        guard let first = days.firstIndex(where: { $0.weightKg != nil }) else { return [] }
        let n = days.count - first

        // Covariances stored as (a, b, d) for [[a, b], [b, d]].
        var mp: [(Double, Double)] = []
        var pp: [(Double, Double, Double)] = []
        var mf: [(Double, Double)] = []
        var pf: [(Double, Double, Double)] = []
        mp.reserveCapacity(n); pp.reserveCapacity(n); mf.reserveCapacity(n); pf.reserveCapacity(n)

        var m = (days[first].weightKg!, 0.0)
        var p = (AdaptiveConfig.trendInitialLevelVar, 0.0, AdaptiveConfig.trendInitialSlopeVar)

        for i in 0..<n {
            if i > 0 {
                m = (m.0 + m.1, m.1)
                p = (
                    p.0 + 2 * p.1 + p.2 + AdaptiveConfig.trendLevelProcessVar,
                    p.1 + p.2,
                    p.2 + AdaptiveConfig.trendSlopeProcessVar
                )
            }
            mp.append(m)
            pp.append(p)
            if let w = days[first + i].weightKg {
                let s = p.0 + AdaptiveConfig.weighInNoiseVar
                let k0 = p.0 / s
                let k1 = p.1 / s
                let innov = w - m.0
                m = (m.0 + k0 * innov, m.1 + k1 * innov)
                p = (p.0 - k0 * p.0, p.1 - k0 * p.1, p.2 - k1 * p.1)
            }
            mf.append(m)
            pf.append(p)
        }

        var ms = mf
        var ps = pf
        if n >= 2 {
            for i in stride(from: n - 2, through: 0, by: -1) {
                let (fa, fb, fd) = pf[i]
                let a00 = fa + fb
                let a01 = fb
                let a10 = fb + fd
                let a11 = fd
                let (pa, pb, pd) = pp[i + 1]
                let det = pa * pd - pb * pb
                let i00 = pd / det
                let i01 = -pb / det
                let i11 = pa / det
                let c00 = a00 * i00 + a01 * i01
                let c01 = a00 * i01 + a01 * i11
                let c10 = a10 * i00 + a11 * i01
                let c11 = a10 * i01 + a11 * i11
                let d0 = ms[i + 1].0 - mp[i + 1].0
                let d1 = ms[i + 1].1 - mp[i + 1].1
                ms[i] = (mf[i].0 + c00 * d0 + c01 * d1, mf[i].1 + c10 * d0 + c11 * d1)
                let e00 = ps[i + 1].0 - pa
                let e01 = ps[i + 1].1 - pb
                let e11 = ps[i + 1].2 - pd
                let t00 = c00 * e00 + c01 * e01
                let t01 = c00 * e01 + c01 * e11
                let t10 = c10 * e00 + c11 * e01
                let t11 = c10 * e01 + c11 * e11
                ps[i] = (
                    fa + t00 * c00 + t01 * c01,
                    fb + t00 * c10 + t01 * c11,
                    fd + t10 * c10 + t11 * c11
                )
            }
        }

        return (0..<n).map { i in
            AdaptiveTrendPoint(
                day: first + i,
                levelKg: ms[i].0,
                slopeKgPerDay: ms[i].1,
                levelVar: max(ps[i].0, 1e-6)
            )
        }
    }

    /// Forward-filter slope SD at the last day.
    private static func trendSlopeSD(_ days: [AdaptiveDay]) -> Double {
        guard let first = days.firstIndex(where: { $0.weightKg != nil }) else { return 0 }
        var p = (AdaptiveConfig.trendInitialLevelVar, 0.0, AdaptiveConfig.trendInitialSlopeVar)
        for i in first..<days.count {
            if i > first {
                p = (
                    p.0 + 2 * p.1 + p.2 + AdaptiveConfig.trendLevelProcessVar,
                    p.1 + p.2,
                    p.2 + AdaptiveConfig.trendSlopeProcessVar
                )
            }
            if days[i].weightKg != nil {
                let s = p.0 + AdaptiveConfig.weighInNoiseVar
                let k0 = p.0 / s
                let k1 = p.1 / s
                p = (p.0 - k0 * p.0, p.1 - k0 * p.1, p.2 - k1 * p.1)
            }
        }
        return max(p.2, 0).squareRoot()
    }

    // MARK: - 2. Training data → Bayesian regression

    private static func trailingIntake(_ days: [AdaptiveDay], endExclusive: Int, lookback: Int) -> Double? {
        var vals: [Double] = []
        var d = max(0, endExclusive - lookback)
        while d < endExclusive {
            if let v = days[d].intakeKcal { vals.append(v) }
            d += 1
        }
        return vals.count >= AdaptiveConfig.minLoggedIntakeDays ? mean(vals) : nil
    }

    static func buildObservations(_ input: AdaptiveFitInput, trend: [AdaptiveTrendPoint]) -> [AdaptiveObservation] {
        guard let firstPoint = trend.first else { return [] }
        let first = firstPoint.day
        let days = input.days
        let w = AdaptiveConfig.windowDays
        var obs: [AdaptiveObservation] = []
        guard days.count - 1 >= first + w else { return [] }
        for e in stride(from: days.count - 1, through: first + w, by: -w) {
            let s = e - w
            var intakes: [Double] = []
            var stepSum = 0.0
            for d in s..<e {
                if let v = days[d].intakeKcal { intakes.append(v) }
                stepSum += days[d].steps ?? AdaptiveConfig.referenceSteps
            }
            if intakes.count < AdaptiveConfig.minLoggedIntakeDays { continue }
            var weighIns = 0
            for d in s...e where days[d].weightKg != nil { weighIns += 1 }
            if weighIns < AdaptiveConfig.minWeighInsPerWindow { continue }

            let meanIntake = mean(intakes)
            let ts = trend[s - first]
            let te = trend[e - first]
            let deltaKg = te.levelKg - ts.levelKg
            let y = meanIntake - (AdaptiveConfig.kcalPerKg * deltaKg) / Double(w)
            let stepsK = (stepSum / Double(w) - AdaptiveConfig.referenceSteps) / 1000
            let trailing = trailingIntake(days, endExclusive: e, lookback: AdaptiveConfig.adaptationLookbackDays) ?? meanIntake
            let adapt = (trailing - input.priorMaintenanceKcal) / 1000
            let weightVar = (AdaptiveConfig.kcalPerKg * AdaptiveConfig.kcalPerKg * (ts.levelVar + te.levelVar))
                / Double(w * w)
            let noiseVar = weightVar
                + (AdaptiveConfig.intakeReportingSD * AdaptiveConfig.intakeReportingSD) / Double(intakes.count)
                + AdaptiveConfig.modelResidualSD * AdaptiveConfig.modelResidualSD
            obs.append(
                AdaptiveObservation(
                    endDay: e,
                    impliedExpenditure: y,
                    features: [1, stepsK, adapt],
                    noiseVar: noiseVar,
                    residual: 0
                )
            )
        }
        return obs.reversed()
    }

    static func prior(for input: AdaptiveFitInput) -> (theta: [Double], cov: [[Double]]) {
        (
            [
                input.priorMaintenanceKcal,
                AdaptiveConfig.priorStepCoefficientPerKg * input.bodyWeightKg,
                AdaptiveConfig.priorAdaptationMean,
            ],
            [
                [AdaptiveConfig.priorMaintenanceSD * AdaptiveConfig.priorMaintenanceSD, 0, 0],
                [0, AdaptiveConfig.priorStepCoefficientSD * AdaptiveConfig.priorStepCoefficientSD, 0],
                [0, 0, AdaptiveConfig.priorAdaptationSD * AdaptiveConfig.priorAdaptationSD],
            ]
        )
    }

    /// Train (or re-train) the personal model on everything logged so far. Deterministic, O(days).
    static func fit(_ input: AdaptiveFitInput) -> AdaptiveModelSnapshot {
        let trend = smoothWeightTrend(input.days)
        let raw = buildObservations(input, trend: trend)
        var (theta, cov) = prior(for: input)
        let drift = [
            AdaptiveConfig.driftMaintenanceSD * AdaptiveConfig.driftMaintenanceSD,
            AdaptiveConfig.driftStepSD * AdaptiveConfig.driftStepSD,
            AdaptiveConfig.driftAdaptationSD * AdaptiveConfig.driftAdaptationSD,
        ]

        var history: [AdaptiveObservation] = []
        for (i, o) in raw.enumerated() {
            if i > 0 {
                for r in 0..<3 { cov[r][r] += drift[r] }
            }
            let x = o.features
            let px = matVec3(cov, x)
            let s = dot3(x, px) + o.noiseVar
            let residual = o.impliedExpenditure - dot3(x, theta)
            let k = [px[0] / s, px[1] / s, px[2] / s]
            theta = [theta[0] + k[0] * residual, theta[1] + k[1] * residual, theta[2] + k[2] * residual]
            var updated = cov
            for r in 0..<3 {
                for c in 0..<3 { updated[r][c] = cov[r][c] - k[r] * px[c] }
            }
            var symmetric = updated
            for r in 0..<3 {
                for c in 0..<3 { symmetric[r][c] = (updated[r][c] + updated[c][r]) / 2 }
            }
            cov = symmetric
            var done = o
            done.residual = residual
            history.append(done)
        }

        let n = input.days.count
        let recent = input.days.suffix(14)
        let stepVals = recent.compactMap(\.steps)
        let currentSteps = stepVals.count >= 5 ? mean(stepVals) : input.fallbackSteps
        let currentIntake = trailingIntake(input.days, endExclusive: n, lookback: 14) ?? input.fallbackIntakeKcal

        var trendSummary: AdaptiveTrendSummary?
        if let last = trend.last {
            trendSummary = AdaptiveTrendSummary(
                levelKg: last.levelKg,
                slopeKgPerWeek: last.slopeKgPerDay * 7,
                slopeSDKgPerWeek: trendSlopeSD(input.days) * 7
            )
        }

        let x = features(prior: input.priorMaintenanceKcal, intakeKcal: currentIntake, steps: currentSteps)
        let maintenance = dot3(x, theta)
        let maintenanceSD = max(quad3(cov, x), 0).squareRoot()
        var rmse: Double?
        if history.count >= 2 {
            rmse = mean(history.dropFirst().map { $0.residual * $0.residual }).squareRoot()
        }
        let confidence: AdaptiveModelConfidence
        if history.count >= AdaptiveConfig.highConfidenceMinObservations, maintenanceSD <= AdaptiveConfig.highConfidenceMaxSD {
            confidence = .high
        } else if history.count >= AdaptiveConfig.mediumConfidenceMinObservations,
                  maintenanceSD <= AdaptiveConfig.mediumConfidenceMaxSD {
            confidence = .medium
        } else {
            confidence = .low
        }

        return AdaptiveModelSnapshot(
            priorMaintenanceKcal: input.priorMaintenanceKcal,
            theta: theta,
            covariance: cov,
            observations: history.count,
            loggedIntakeDays: input.days.filter { $0.intakeKcal != nil }.count,
            weighIns: input.days.filter { $0.weightKg != nil }.count,
            trend: trendSummary,
            currentSteps: currentSteps,
            currentIntakeKcal: currentIntake,
            maintenanceKcal: maintenance,
            maintenanceSD: maintenanceSD,
            confidence: confidence,
            rmseKcal: rmse,
            history: history
        )
    }

    private static func features(prior: Double, intakeKcal: Double, steps: Double) -> [Double] {
        [1, (steps - AdaptiveConfig.referenceSteps) / 1000, (intakeKcal - prior) / 1000]
    }

    // MARK: - 3. Prediction + controller

    static func predictWeeklyRate(_ model: AdaptiveModelSnapshot, intakeKcal: Double, steps: Double) -> AdaptiveRatePrediction {
        let x = features(prior: model.priorMaintenanceKcal, intakeKcal: intakeKcal, steps: steps)
        let tdee = dot3(x, model.theta)
        let k = 7 / AdaptiveConfig.kcalPerKg
        return AdaptiveRatePrediction(
            meanKgPerWeek: (intakeKcal - tdee) * k,
            sdKgPerWeek: max(quad3(model.covariance, x), 0).squareRoot() * k,
            expenditureKcal: tdee
        )
    }

    /// Intake (kcal/day) the model expects to produce `targetKgPerWeek`, given steps.
    static func requiredIntake(_ model: AdaptiveModelSnapshot, targetKgPerWeek: Double, steps: Double) -> Double {
        let t0 = model.theta[0]
        let t1 = model.theta[1]
        let t2 = min(max(model.theta[2], AdaptiveConfig.adaptationClampMin), AdaptiveConfig.adaptationClampMax) / 1000
        let stepsK = (steps - AdaptiveConfig.referenceSteps) / 1000
        return ((AdaptiveConfig.kcalPerKg * targetKgPerWeek) / 7 + t0 + t1 * stepsK - t2 * model.priorMaintenanceKcal)
            / (1 - t2)
    }

    /// Goal rate in kg/week; tapers to zero as the trend approaches the desired weight.
    static func targetWeeklyRate(goal: GoalPhase, trendWeightKg: Double, desiredWeightKg: Double?) -> Double {
        if goal == .maintenance { return 0 }
        func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(max(v, lo), hi) }
        var magnitude = goal == .cut
            ? clamp(trendWeightKg * AdaptiveConfig.cutRatePercentPerWeek / 100, AdaptiveConfig.cutRateMinKg, AdaptiveConfig.cutRateMaxKg)
            : clamp(trendWeightKg * AdaptiveConfig.gainRatePercentPerWeek / 100, AdaptiveConfig.gainRateMinKg, AdaptiveConfig.gainRateMaxKg)
        if let desired = desiredWeightKg, desired > 0 {
            let remaining = goal == .cut ? trendWeightKg - desired : desired - trendWeightKg
            if remaining <= 0 { return 0 }
            magnitude = min(magnitude, remaining / AdaptiveConfig.goalApproachWeeks)
        }
        return goal == .cut ? -magnitude : magnitude
    }

    static func planAverage(_ plan: AdaptivePlanCalories) -> Double {
        let nT = Double(min(max(plan.trainingDaysPerWeek, 0), 7))
        return (nT * plan.trainingKcal + (7 - nT) * plan.restKcal) / 7
    }

    static func recommend(
        _ model: AdaptiveModelSnapshot,
        plan: AdaptivePlanCalories,
        goal: GoalPhase,
        desiredWeightKg: Double?,
        steps: Double
    ) -> AdaptiveRecommendation {
        let target = model.trend.map {
            targetWeeklyRate(goal: goal, trendWeightKg: $0.levelKg, desiredWeightKg: desiredWeightKg)
        } ?? 0
        let currentAvg = planAverage(plan)
        let predictedCurrent = predictWeeklyRate(model, intakeKcal: currentAvg, steps: steps)
        let required = requiredIntake(model, targetKgPerWeek: target, steps: steps)
        var delta = required - currentAvg
        delta = min(max(delta, -AdaptiveConfig.maxAdjustmentKcal), AdaptiveConfig.maxAdjustmentKcal)
        // floor(x + 0.5) mirrors JavaScript's Math.round.
        delta = abs(delta) < AdaptiveConfig.adjustmentDeadbandKcal ? 0 : (delta / 10 + 0.5).rounded(.down) * 10
        let deltaInt = Int(delta)
        let predictedAfter = predictWeeklyRate(model, intakeKcal: currentAvg + delta, steps: steps)
        let shouldAdjust = deltaInt != 0 && model.confidence != .low

        func signed(_ v: Double) -> String {
            "\(v >= 0 ? "+" : "−")\(String(format: "%.2f", abs(v)))"
        }
        let weeksWord = model.observations == 1 ? "week" : "weeks"
        let goalReached = model.trend != nil && goal != .maintenance && target == 0
        let versus = goalReached
            ? "but you've reached your goal weight, so the aim is now to hold steady"
            : "versus a \(signed(target)) kg/week target"
        let onTarget = goalReached ? "holding at your goal weight" : "on target (\(signed(target)))"
        let maintenance = Int(model.maintenanceKcal.rounded())
        let summary: String
        if model.confidence == .low {
            summary = "Still learning your metabolism (\(model.observations) training \(weeksWord)). Keep logging weight and food to unlock personal adjustments."
        } else if deltaInt == 0 {
            summary = "Your model estimates maintenance at ~\(maintenance) kcal and predicts \(signed(predictedCurrent.meanKgPerWeek)) kg/week on this plan — \(onTarget). No change needed."
        } else {
            summary = "Your model estimates maintenance at ~\(maintenance) kcal and predicts \(signed(predictedCurrent.meanKgPerWeek)) kg/week on this plan \(versus). \(deltaInt > 0 ? "Adding" : "Removing") \(abs(deltaInt)) kcal/day should give \(signed(predictedAfter.meanKgPerWeek)) kg/week."
        }

        return AdaptiveRecommendation(
            targetKgPerWeek: target,
            currentAverageIntake: currentAvg,
            predictedCurrent: predictedCurrent,
            requiredAverageIntake: required,
            deltaKcal: deltaInt,
            predictedAfter: predictedAfter,
            shouldAdjust: shouldAdjust,
            confidence: model.confidence,
            summary: summary
        )
    }

    /// Trend-weight forecast `weeks` ahead on a given intake, with a ±1 SD band.
    static func forecast(_ model: AdaptiveModelSnapshot, intakeKcal: Double, steps: Double, weeks: Int) -> [AdaptiveForecastPoint] {
        guard let trend = model.trend else { return [] }
        let p = predictWeeklyRate(model, intakeKcal: intakeKcal, steps: steps)
        return (0...max(weeks, 0)).map { w in
            let wd = Double(w)
            return AdaptiveForecastPoint(
                week: w,
                meanKg: trend.levelKg + p.meanKgPerWeek * wd,
                sdKg: ((p.sdKgPerWeek * wd) * (p.sdKgPerWeek * wd) + 0.15 * 0.15).squareRoot()
            )
        }
    }
}
