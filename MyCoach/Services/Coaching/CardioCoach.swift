import Foundation

/// Coach cardio recommendation for today. Port of `web/src/engines/cardio.ts` (keep in sync).
///
/// Low-intensity steady-state (LISS) is the default — it supports fat loss and recovery without eating into
/// lifting performance. Poor sleep or an emergency rest day always means recovery-only movement.
enum CardioCoach {
    struct Input: Sendable {
        var goal: GoalPhase
        var isTrainingDay: Bool
        var emergencyRest: Bool
        /// Hours slept last night, if logged.
        var sleepHours: Double?
        var stepsSoFar: Int
        var stepTarget: Int
        /// From the adaptive model, when confident.
        var predictedKgPerWeek: Double?
        var targetKgPerWeek: Double?
    }

    enum Tone: String, Sendable {
        case recovery, steady, boost, light
    }

    struct Recommendation: Equatable, Sendable {
        var tone: Tone
        var minutes: Int
        var title: String
        var activity: String
        var intensity: String
        var reasons: [String]
    }

    private static let walkStepsPerMinute = 110.0

    static func formatHours(_ h: Double) -> String {
        let hours = Int(h.rounded(.down))
        let mins = Int(((h - Double(hours)) * 60).rounded())
        return mins == 0 ? "\(hours) h" : "\(hours) h \(mins) min"
    }

    static func recommend(_ input: Input) -> Recommendation {
        var reasons: [String] = []
        let stepsLeft = max(0, input.stepTarget - input.stepsSoFar)

        let poorSleep = input.sleepHours.map { $0 <= 5 } ?? false
        if poorSleep || input.emergencyRest {
            if poorSleep, let h = input.sleepHours { reasons.append("Only \(formatHours(h)) of sleep — recovery comes first.") }
            if input.emergencyRest { reasons.append("Emergency rest day — keep it easy.") }
            return Recommendation(
                tone: .recovery,
                minutes: 20,
                title: "Recovery walk only",
                activity: "Easy outdoor walk or gentle cycling",
                intensity: "Very easy — you could hold a conversation the whole time",
                reasons: reasons
            )
        }

        var minutes: Int
        let activity: String
        switch input.goal {
        case .cut:
            minutes = input.isTrainingDay ? 20 : 35
            activity = input.isTrainingDay ? "Incline walk after your session" : "Incline walk, bike or cross-trainer"
            reasons.append(input.isTrainingDay
                ? "Short LISS after lifting supports fat loss without hurting recovery."
                : "Rest days are the best time for longer, easy cardio.")
        case .gain:
            minutes = input.isTrainingDay ? 0 : 20
            activity = "Easy walk or bike"
            reasons.append(input.isTrainingDay
                ? "Gaining phase — save energy for lifting today."
                : "A little easy cardio keeps your heart healthy and appetite steady.")
        case .maintenance:
            minutes = input.isTrainingDay ? 10 : 25
            activity = "Walk, bike or cross-trainer"
            reasons.append("Maintenance — easy cardio for health and conditioning.")
        }

        if let predicted = input.predictedKgPerWeek, let target = input.targetKgPerWeek, input.goal != .maintenance {
            let gap = predicted - target
            if input.goal == .cut, gap > 0.15 {
                minutes += 10
                reasons.append("Your model predicts slower loss than your goal — a little more cardio helps.")
            } else if input.goal == .cut, gap < -0.25 {
                minutes = max(10, minutes - 10)
                reasons.append("You're losing faster than planned — keep cardio light to protect muscle.")
            } else if input.goal == .gain, gap < -0.15 {
                minutes = max(0, minutes - 10)
                reasons.append("Weight is rising slower than planned — less cardio leaves more energy for growth.")
            }
        }

        if let h = input.sleepHours, h < 6.5, minutes > 15 {
            minutes -= 10
            reasons.append("\(formatHours(h)) of sleep — trimmed to keep recovery on track.")
        }

        if stepsLeft > 0 {
            let walk = Int((Double(stepsLeft) / walkStepsPerMinute / 5).rounded()) * 5
            reasons.append("\(stepsLeft.formatted()) steps to go today (≈ \(max(5, walk)) min of walking).")
        }

        if minutes <= 0 {
            return Recommendation(
                tone: .light,
                minutes: 0,
                title: "No structured cardio today",
                activity: "Just hit your step target",
                intensity: "Everyday walking",
                reasons: reasons
            )
        }
        return Recommendation(
            tone: minutes >= 35 ? .boost : .steady,
            minutes: minutes,
            title: "\(minutes) min \(minutes >= 30 ? "steady" : "easy") cardio",
            activity: activity,
            intensity: "Zone 2 — breathing harder but still able to talk",
            reasons: reasons
        )
    }
}
