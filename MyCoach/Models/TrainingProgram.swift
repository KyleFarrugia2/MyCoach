import Foundation

/// How the user likes to train. Changes default sets / finishers, not the exercise list.
enum TrainingStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case hypertrophy
    case strength
    case athletic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hypertrophy: "Build muscle"
        case .strength: "Get stronger"
        case .athletic: "Stay athletic"
        }
    }

    var subtitle: String {
        switch self {
        case .hypertrophy: "Moderate sets, more isolation, 8–12 reps."
        case .strength: "Heavier compounds, extra top sets, fewer extras."
        case .athletic: "The same lifts plus a short conditioning finisher."
        }
    }

    var systemImage: String {
        switch self {
        case .hypertrophy: "figure.strengthtraining.traditional"
        case .strength: "dumbbell.fill"
        case .athletic: "figure.run"
        }
    }
}

/// The split and equipment. Existing users keep the original gym-machine PPL.
enum TrainingProgramID: String, Codable, CaseIterable, Identifiable, Sendable {
    case gymMachines
    case freeWeights
    case upperLower
    case fullBody
    case bodyweight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gymMachines: "Gym machines"
        case .freeWeights: "Free weights"
        case .upperLower: "Upper / lower"
        case .fullBody: "Full body"
        case .bodyweight: "Home / bodyweight"
        }
    }

    var subtitle: String {
        switch self {
        case .gymMachines: "The original 5-day machine split (Push, Pull, Legs, Upper, Legs)."
        case .freeWeights: "Barbell and dumbbell Push / Pull / Legs."
        case .upperLower: "Four sessions: two upper, two lower."
        case .fullBody: "Three full-body days — best if you train 2–3× a week."
        case .bodyweight: "No gym. Push-ups, rows, squats and core."
        }
    }

    var equipment: String {
        switch self {
        case .gymMachines: "Cables, machines, some free weights"
        case .freeWeights: "Barbell, dumbbells, bench, rack"
        case .upperLower: "Barbell, dumbbells, machines"
        case .fullBody: "Barbell and dumbbells"
        case .bodyweight: "Floor space, a bar if you have one"
        }
    }

    var recommendedDays: Int {
        switch self {
        case .gymMachines: 5
        case .freeWeights: 3
        case .upperLower: 4
        case .fullBody: 3
        case .bodyweight: 3
        }
    }

    var systemImage: String {
        switch self {
        case .gymMachines: "building.2.fill"
        case .freeWeights: "dumbbell.fill"
        case .upperLower: "square.split.2x1.fill"
        case .fullBody: "figure.mixed.cardio"
        case .bodyweight: "house.fill"
        }
    }

    var templateIDs: [WorkoutTemplateID] {
        switch self {
        case .gymMachines: [.pushA, .pullA, .legsA, .upper, .legsB]
        case .freeWeights: [.fwPush, .fwPull, .fwLegs]
        case .upperLower: [.ulUpperA, .ulLowerA, .ulUpperB, .ulLowerB]
        case .fullBody: [.fbA, .fbB, .fbC]
        case .bodyweight: [.bwFullA, .bwFullB, .bwFullC]
        }
    }

    static func recommended(daysPerWeek: Int) -> TrainingProgramID {
        switch daysPerWeek {
        case ...3: .fullBody
        case 4: .upperLower
        default: .gymMachines
        }
    }

    /// Next session in this split after the most recent completed workout that belongs to it.
    func nextTemplate(after sessions: [WorkoutSession]) -> WorkoutTemplateID {
        let rotation = templateIDs
        guard let last = sessions
            .filter({ $0.isCompleted && rotation.contains($0.templateID) })
            .max(by: { $0.startedAt < $1.startedAt }),
              let index = rotation.firstIndex(of: last.templateID) else {
            return rotation[0]
        }
        return rotation[(index + 1) % rotation.count]
    }
}
