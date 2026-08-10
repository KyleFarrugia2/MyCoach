import Foundation

// MARK: - Template IDs

enum WorkoutTemplateID: String, Codable, CaseIterable, Identifiable, Sendable {
    case pushA
    case pullA
    case legsA
    case upper
    case legsB

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pushA: "Push A"
        case .pullA: "Pull A"
        case .legsA: "Legs A"
        case .upper: "Upper"
        case .legsB: "Legs B"
        }
    }

    var shortLabel: String {
        switch self {
        case .pushA: "Push"
        case .pullA: "Pull"
        case .legsA: "Legs A"
        case .upper: "Upper"
        case .legsB: "Legs B"
        }
    }
}

// MARK: - Library

struct WorkoutExerciseBlueprint: Codable, Equatable, Sendable, Identifiable, Hashable {
    var id: String
    var name: String
    var defaultSets: Int
    var isBodyweightMaxReps: Bool

    init(name: String, defaultSets: Int, isBodyweightMaxReps: Bool = false) {
        self.id = name.lowercased()
        self.name = name
        self.defaultSets = defaultSets
        self.isBodyweightMaxReps = isBodyweightMaxReps
    }
}

struct WorkoutTemplate: Identifiable, Equatable, Sendable {
    var id: WorkoutTemplateID
    var exercises: [WorkoutExerciseBlueprint]

    var name: String { id.displayName }
}

enum WorkoutLibrary {
    static let templates: [WorkoutTemplate] = [
        WorkoutTemplate(id: .pushA, exercises: [
            .init(name: "Y raise", defaultSets: 2),
            .init(name: "Upper chest flye", defaultSets: 2),
            .init(name: "Flat chest press", defaultSets: 2),
            .init(name: "Shoulder press", defaultSets: 1),
            .init(name: "Poliquin tricep extensions", defaultSets: 3),
            .init(name: "Cable crunch", defaultSets: 2)
        ]),
        WorkoutTemplate(id: .pullA, exercises: [
            .init(name: "Wide grip pulldown", defaultSets: 2),
            .init(name: "Iliac lat pulldown", defaultSets: 1),
            .init(name: "Upper back row", defaultSets: 2),
            .init(name: "Cable hammer curl", defaultSets: 2),
            .init(name: "Dbell preacher curl", defaultSets: 2),
            .init(name: "Leg raise (bodyweight max reps)", defaultSets: 2, isBodyweightMaxReps: true)
        ]),
        WorkoutTemplate(id: .legsA, exercises: [
            .init(name: "Glute bridge", defaultSets: 2),
            .init(name: "Seated leg curl", defaultSets: 3),
            .init(name: "Hyperextension", defaultSets: 2),
            .init(name: "Leg extension", defaultSets: 2),
            .init(name: "Straight leg calf raise", defaultSets: 2),
            .init(name: "Leg press", defaultSets: 2),
            .init(name: "Adductor", defaultSets: 1)
        ]),
        WorkoutTemplate(id: .upper, exercises: [
            .init(name: "Machine side lateral raise", defaultSets: 2),
            .init(name: "Prime incline", defaultSets: 2),
            .init(name: "Pec deck", defaultSets: 2),
            .init(name: "Assisted Pull up", defaultSets: 2),
            .init(name: "Cybex eagle lat row", defaultSets: 1),
            .init(name: "Tbar row", defaultSets: 2),
            .init(name: "Poliquin tricep extensions", defaultSets: 2),
            .init(name: "Cable hammer curl", defaultSets: 1),
            .init(name: "Dbell preacher curl", defaultSets: 2)
        ]),
        WorkoutTemplate(id: .legsB, exercises: [
            .init(name: "Glute bridge", defaultSets: 2),
            .init(name: "Seated leg curl", defaultSets: 3),
            .init(name: "Hyperextension", defaultSets: 2),
            .init(name: "Leg extension", defaultSets: 2),
            .init(name: "Straight leg calf raise", defaultSets: 2),
            .init(name: "Squat press", defaultSets: 2),
            .init(name: "Adductor", defaultSets: 1),
            .init(name: "Rope crunch", defaultSets: 2)
        ])
    ]

    static func template(id: WorkoutTemplateID) -> WorkoutTemplate {
        templates.first { $0.id == id } ?? templates[0]
    }
}

// MARK: - Logged performance

struct LoggedSet: Codable, Equatable, Sendable, Identifiable, Hashable {
    var id: UUID
    var setNumber: Int
    var weightKg: Double?
    var reps: Int
    var completedAt: Date

    init(
        id: UUID = UUID(),
        setNumber: Int,
        weightKg: Double? = nil,
        reps: Int,
        completedAt: Date = Date()
    ) {
        self.id = id
        self.setNumber = setNumber
        self.weightKg = weightKg
        self.reps = max(0, reps)
        self.completedAt = completedAt
    }

    var volume: Double {
        (weightKg ?? 0) * Double(reps)
    }

    var summaryLabel: String {
        if let weightKg, weightKg > 0 {
            let rounded = (weightKg * 10).rounded() / 10
            return "\(rounded.formatted(.number.precision(.fractionLength(0...1)))) kg × \(reps)"
        }
        return "\(reps) reps"
    }
}

struct WorkoutExerciseLog: Codable, Equatable, Sendable, Identifiable, Hashable {
    var id: String
    var name: String
    var plannedSets: Int
    var isBodyweightMaxReps: Bool
    var sets: [LoggedSet]

    init(
        id: String,
        name: String,
        plannedSets: Int,
        isBodyweightMaxReps: Bool = false,
        sets: [LoggedSet] = []
    ) {
        self.id = id
        self.name = name
        self.plannedSets = max(1, plannedSets)
        self.isBodyweightMaxReps = isBodyweightMaxReps
        self.sets = sets
    }

    var completedSetCount: Int { sets.count }
    var isComplete: Bool { completedSetCount >= plannedSets }

    var bestWeightKg: Double {
        sets.compactMap(\.weightKg).max() ?? 0
    }

    var bestReps: Int {
        sets.map(\.reps).max() ?? 0
    }

    var totalVolume: Double {
        sets.reduce(0) { $0 + $1.volume }
    }

    var lastSetSummary: String {
        guard let last = sets.sorted(by: { $0.setNumber < $1.setNumber }).last else {
            return "Not logged"
        }
        return last.summaryLabel
    }
}

struct WorkoutSession: Codable, Equatable, Sendable, Identifiable, Hashable {
    var id: UUID
    var templateID: WorkoutTemplateID
    var templateName: String
    var localDate: Date
    var startedAt: Date
    var completedAt: Date?
    var exercises: [WorkoutExerciseLog]
    var notes: String

    init(
        id: UUID = UUID(),
        templateID: WorkoutTemplateID,
        templateName: String,
        localDate: Date = Calendar.current.startOfDay(for: Date()),
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        exercises: [WorkoutExerciseLog],
        notes: String = ""
    ) {
        self.id = id
        self.templateID = templateID
        self.templateName = templateName
        self.localDate = Calendar.current.startOfDay(for: localDate)
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.exercises = exercises
        self.notes = notes
    }

    var isCompleted: Bool { completedAt != nil }

    var durationSeconds: Int {
        let end = completedAt ?? Date()
        return max(0, Int(end.timeIntervalSince(startedAt)))
    }

    var completedSets: Int {
        exercises.reduce(0) { $0 + $1.completedSetCount }
    }
}

struct WorkoutTemplateOverride: Codable, Equatable, Sendable {
    var templateID: WorkoutTemplateID
    /// exercise id → planned set count
    var setCounts: [String: Int]

    init(templateID: WorkoutTemplateID, setCounts: [String: Int] = [:]) {
        self.templateID = templateID
        self.setCounts = setCounts
    }
}

// MARK: - Progress / stagnation

enum WorkoutProgressAnalyzer {
    /// True if `current` improved vs `previous` (weight, then reps, then volume).
    static func didProgress(previous: WorkoutExerciseLog?, current: WorkoutExerciseLog) -> Bool {
        guard let previous, !previous.sets.isEmpty, !current.sets.isEmpty else { return true }
        if current.bestWeightKg > previous.bestWeightKg + 0.05 { return true }
        if abs(current.bestWeightKg - previous.bestWeightKg) <= 0.05, current.bestReps > previous.bestReps {
            return true
        }
        if current.isBodyweightMaxReps, current.bestReps > previous.bestReps { return true }
        if current.totalVolume > previous.totalVolume + 0.5 { return true }
        return false
    }

    /// Exercises with no progress across the last `streak` consecutive completed sessions of this template.
    static func stagnantExercises(
        templateID: WorkoutTemplateID,
        sessions: [WorkoutSession],
        streak: Int = 3
    ) -> [String] {
        let completed = sessions
            .filter { $0.templateID == templateID && $0.isCompleted }
            .sorted { $0.startedAt < $1.startedAt }

        // Need streak comparisons → streak + 1 sessions.
        guard completed.count >= streak + 1 else { return [] }
        let window = Array(completed.suffix(streak + 1))
        let latest = window.last!
        var stagnant: [String] = []

        for exercise in latest.exercises {
            var failedStreak = 0
            for index in 1..<window.count {
                let prior = window[index - 1].exercises.first { $0.id == exercise.id }
                let current = window[index].exercises.first { $0.id == exercise.id }
                guard let current, !current.sets.isEmpty else { continue }
                if didProgress(previous: prior, current: current) {
                    failedStreak = 0
                } else {
                    failedStreak += 1
                }
            }
            if failedStreak >= streak {
                stagnant.append(exercise.name)
            }
        }
        return stagnant
    }
}
