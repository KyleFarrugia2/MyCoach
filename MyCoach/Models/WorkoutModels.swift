import Foundation

// MARK: - Template IDs

enum WorkoutTemplateID: String, Codable, CaseIterable, Identifiable, Sendable {
    case pushA
    case pullA
    case legsA
    case upper
    case legsB
    case fwPush
    case fwPull
    case fwLegs
    case ulUpperA
    case ulLowerA
    case ulUpperB
    case ulLowerB
    case fbA
    case fbB
    case fbC
    case bwFullA
    case bwFullB
    case bwFullC

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pushA: "Push A"
        case .pullA: "Pull A"
        case .legsA: "Legs A"
        case .upper: "Upper"
        case .legsB: "Legs B"
        case .fwPush: "Push"
        case .fwPull: "Pull"
        case .fwLegs: "Legs"
        case .ulUpperA: "Upper A"
        case .ulLowerA: "Lower A"
        case .ulUpperB: "Upper B"
        case .ulLowerB: "Lower B"
        case .fbA: "Full Body A"
        case .fbB: "Full Body B"
        case .fbC: "Full Body C"
        case .bwFullA: "Home A"
        case .bwFullB: "Home B"
        case .bwFullC: "Home C"
        }
    }

    var shortLabel: String {
        switch self {
        case .pushA, .fwPush: "Push"
        case .pullA, .fwPull: "Pull"
        case .legsA, .fwLegs: "Legs"
        case .upper: "Upper"
        case .legsB: "Legs B"
        case .ulUpperA, .ulUpperB: "Upper"
        case .ulLowerA, .ulLowerB: "Lower"
        case .fbA: "FB A"
        case .fbB: "FB B"
        case .fbC: "FB C"
        case .bwFullA: "Home A"
        case .bwFullB: "Home B"
        case .bwFullC: "Home C"
        }
    }

    var focus: String {
        switch self {
        case .pushA, .fwPush: "Chest · shoulders · triceps"
        case .pullA, .fwPull: "Back · biceps · core"
        case .legsA, .legsB, .fwLegs: "Quads · glutes · hamstrings"
        case .upper, .ulUpperA, .ulUpperB: "Chest · back · arms"
        case .ulLowerA, .ulLowerB: "Squat · hinge · calves"
        case .fbA: "Squat · press · row"
        case .fbB: "Hinge · overhead · pull"
        case .fbC: "Front squat · incline · lats"
        case .bwFullA: "Push-up · squat · core"
        case .bwFullB: "Pull · lunge · hips"
        case .bwFullC: "Split squat · push · carry"
        }
    }

    var systemImage: String {
        switch self {
        case .pushA, .fwPush: "arrow.up.circle.fill"
        case .pullA, .fwPull: "arrow.down.circle.fill"
        case .legsA, .legsB, .fwLegs, .ulLowerA, .ulLowerB: "figure.strengthtraining.functional"
        case .upper, .ulUpperA, .ulUpperB: "figure.arms.open"
        case .fbA, .fbB, .fbC: "figure.mixed.cardio"
        case .bwFullA, .bwFullB, .bwFullC: "house.fill"
        }
    }
}

// MARK: - Library

struct WorkoutExerciseBlueprint: Codable, Equatable, Sendable, Identifiable, Hashable {
    var id: String
    var name: String
    var defaultSets: Int
    var isBodyweightMaxReps: Bool
    var muscleGroup: MuscleGroup?
    var equipment: GymEquipment?

    init(
        id: String? = nil,
        name: String,
        defaultSets: Int,
        isBodyweightMaxReps: Bool = false,
        muscleGroup: MuscleGroup? = nil,
        equipment: GymEquipment? = nil
    ) {
        self.id = id ?? name.lowercased()
        self.name = name
        self.defaultSets = defaultSets
        self.isBodyweightMaxReps = isBodyweightMaxReps
        self.muscleGroup = muscleGroup ?? ExerciseCatalog.entry(id: self.id)?.muscle
        self.equipment = equipment ?? ExerciseCatalog.entry(id: self.id)?.equipment
    }

    var resolvedMuscle: MuscleGroup? { muscleGroup ?? ExerciseCatalog.entry(id: id)?.muscle }
    var resolvedEquipment: GymEquipment? { equipment ?? ExerciseCatalog.entry(id: id)?.equipment }
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
        ]),
        WorkoutTemplate(id: .fwPush, exercises: [
            .init(name: "Barbell bench press", defaultSets: 3),
            .init(name: "Overhead press", defaultSets: 3),
            .init(name: "Incline dumbbell press", defaultSets: 2),
            .init(name: "Dumbbell lateral raise", defaultSets: 2),
            .init(name: "Tricep pushdown", defaultSets: 2),
            .init(name: "Dip", defaultSets: 2)
        ]),
        WorkoutTemplate(id: .fwPull, exercises: [
            .init(name: "Conventional deadlift", defaultSets: 3),
            .init(name: "Barbell row", defaultSets: 3),
            .init(name: "Pull-up", defaultSets: 2),
            .init(name: "Face pull", defaultSets: 2),
            .init(name: "Dumbbell curl", defaultSets: 2),
            .init(name: "Hammer curl", defaultSets: 2)
        ]),
        WorkoutTemplate(id: .fwLegs, exercises: [
            .init(name: "Back squat", defaultSets: 3),
            .init(name: "Romanian deadlift", defaultSets: 3),
            .init(name: "Walking lunge", defaultSets: 2),
            .init(name: "Lying leg curl", defaultSets: 2),
            .init(name: "Standing calf raise", defaultSets: 2),
            .init(name: "Plank", defaultSets: 2, isBodyweightMaxReps: true)
        ]),
        WorkoutTemplate(id: .ulUpperA, exercises: [
            .init(name: "Barbell bench press", defaultSets: 3),
            .init(name: "Barbell row", defaultSets: 3),
            .init(name: "Overhead press", defaultSets: 2),
            .init(name: "Pull-up", defaultSets: 2),
            .init(name: "Lateral raise", defaultSets: 2),
            .init(name: "Barbell curl", defaultSets: 2)
        ]),
        WorkoutTemplate(id: .ulLowerA, exercises: [
            .init(name: "Back squat", defaultSets: 3),
            .init(name: "Romanian deadlift", defaultSets: 3),
            .init(name: "Leg press", defaultSets: 2),
            .init(name: "Seated leg curl", defaultSets: 2),
            .init(name: "Standing calf raise", defaultSets: 2),
            .init(name: "Sit-up", defaultSets: 2, isBodyweightMaxReps: true)
        ]),
        WorkoutTemplate(id: .ulUpperB, exercises: [
            .init(name: "Incline dumbbell press", defaultSets: 3),
            .init(name: "Lat pulldown", defaultSets: 3),
            .init(name: "Seated dumbbell press", defaultSets: 2),
            .init(name: "Chest-supported row", defaultSets: 2),
            .init(name: "Overhead tricep extension", defaultSets: 2),
            .init(name: "Rear delt flye", defaultSets: 2)
        ]),
        WorkoutTemplate(id: .ulLowerB, exercises: [
            .init(name: "Front squat", defaultSets: 3),
            .init(name: "Hip thrust", defaultSets: 3),
            .init(name: "Walking lunge", defaultSets: 2),
            .init(name: "Leg extension", defaultSets: 2),
            .init(name: "Seated calf raise", defaultSets: 2),
            .init(name: "Hanging leg raise", defaultSets: 2, isBodyweightMaxReps: true)
        ]),
        WorkoutTemplate(id: .fbA, exercises: [
            .init(name: "Back squat", defaultSets: 3),
            .init(name: "Barbell bench press", defaultSets: 3),
            .init(name: "Barbell row", defaultSets: 3),
            .init(name: "Romanian deadlift", defaultSets: 2),
            .init(name: "Plank", defaultSets: 2, isBodyweightMaxReps: true)
        ]),
        WorkoutTemplate(id: .fbB, exercises: [
            .init(name: "Conventional deadlift", defaultSets: 3),
            .init(name: "Overhead press", defaultSets: 3),
            .init(name: "Pull-up", defaultSets: 3),
            .init(name: "Walking lunge", defaultSets: 2),
            .init(name: "Dumbbell curl", defaultSets: 2)
        ]),
        WorkoutTemplate(id: .fbC, exercises: [
            .init(name: "Front squat", defaultSets: 3),
            .init(name: "Incline dumbbell press", defaultSets: 3),
            .init(name: "Lat pulldown", defaultSets: 3),
            .init(name: "Hip thrust", defaultSets: 2),
            .init(name: "Lateral raise", defaultSets: 2)
        ]),
        WorkoutTemplate(id: .bwFullA, exercises: [
            .init(name: "Push-up", defaultSets: 3, isBodyweightMaxReps: true),
            .init(name: "Inverted row", defaultSets: 3, isBodyweightMaxReps: true),
            .init(name: "Bodyweight squat", defaultSets: 3, isBodyweightMaxReps: true),
            .init(name: "Glute bridge", defaultSets: 2, isBodyweightMaxReps: true),
            .init(name: "Pike push-up", defaultSets: 2, isBodyweightMaxReps: true),
            .init(name: "Hollow hold", defaultSets: 2, isBodyweightMaxReps: true)
        ]),
        WorkoutTemplate(id: .bwFullB, exercises: [
            .init(name: "Decline push-up", defaultSets: 3, isBodyweightMaxReps: true),
            .init(name: "Chin-up", defaultSets: 3, isBodyweightMaxReps: true),
            .init(name: "Reverse lunge", defaultSets: 3, isBodyweightMaxReps: true),
            .init(name: "Hip thrust", defaultSets: 2, isBodyweightMaxReps: true),
            .init(name: "Bench dip", defaultSets: 2, isBodyweightMaxReps: true),
            .init(name: "Hanging leg raise", defaultSets: 2, isBodyweightMaxReps: true)
        ]),
        WorkoutTemplate(id: .bwFullC, exercises: [
            .init(name: "Diamond push-up", defaultSets: 3, isBodyweightMaxReps: true),
            .init(name: "Superman", defaultSets: 3, isBodyweightMaxReps: true),
            .init(name: "Bulgarian split squat", defaultSets: 3, isBodyweightMaxReps: true),
            .init(name: "Calf raise", defaultSets: 2, isBodyweightMaxReps: true),
            .init(name: "Side plank", defaultSets: 2, isBodyweightMaxReps: true),
            .init(name: "Burpee", defaultSets: 2, isBodyweightMaxReps: true)
        ])
    ]

    static func template(id: WorkoutTemplateID) -> WorkoutTemplate {
        templates.first { $0.id == id } ?? templates[0]
    }

    static func templates(for program: TrainingProgramID) -> [WorkoutTemplate] {
        program.templateIDs.map(template(id:))
    }

    /// Applies the user's training style to a library template. User set-count overrides still win later.
    static func apply(style: TrainingStyle, to template: WorkoutTemplate) -> WorkoutTemplate {
        var next = template
        switch style {
        case .hypertrophy:
            break
        case .strength:
            next.exercises = next.exercises.enumerated().map { index, exercise in
                var item = exercise
                if index < 2, !item.isBodyweightMaxReps {
                    item.defaultSets = min(5, max(item.defaultSets, 4))
                } else if index >= 3 {
                    item.defaultSets = max(1, item.defaultSets - 1)
                }
                return item
            }
        case .athletic:
            let finisher = WorkoutExerciseBlueprint(
                name: "Conditioning finisher",
                defaultSets: 2,
                isBodyweightMaxReps: true
            )
            if !next.exercises.contains(where: { $0.id == finisher.id }) {
                next.exercises.append(finisher)
            }
        }
        return next
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
