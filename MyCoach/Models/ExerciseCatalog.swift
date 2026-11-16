import Foundation

// MARK: - Questionnaire

enum TrainingVolume: String, Codable, CaseIterable, Identifiable, Sendable {
    case high
    case low

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .high: "High volume"
        case .low: "Low volume"
        }
    }

    var subtitle: String {
        switch self {
        case .high: "More exercises and sets. Longer sessions, more pump."
        case .low: "Fewer exercises and sets. Shorter sessions, more recovery."
        }
    }
}

enum TrainingGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case keepFit
    case bodybuilding
    case powerlifting
    case powerbuilding
    case strength

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .keepFit: "Keep fit"
        case .bodybuilding: "Bodybuilding"
        case .powerlifting: "Powerlifting"
        case .powerbuilding: "Powerbuilding"
        case .strength: "Increase strength"
        }
    }

    var subtitle: String {
        switch self {
        case .keepFit: "Stay healthy and athletic without chasing a meet or a show."
        case .bodybuilding: "Build muscle with compounds plus isolation work."
        case .powerlifting: "Squat, bench and deadlift focused, with supporting work."
        case .powerbuilding: "Get stronger and look like you lift — heavy compounds plus hypertrophy."
        case .strength: "Add kilos to the big lifts. Minimal fluff."
        }
    }

    var trainingStyle: TrainingStyle {
        switch self {
        case .keepFit: .athletic
        case .bodybuilding, .powerbuilding: .hypertrophy
        case .powerlifting, .strength: .strength
        }
    }

    var systemImage: String {
        switch self {
        case .keepFit: "heart.fill"
        case .bodybuilding: "figure.strengthtraining.traditional"
        case .powerlifting: "scalemass.fill"
        case .powerbuilding: "dumbbell.fill"
        case .strength: "arrow.up.right"
        }
    }
}

enum GymEquipment: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case machines
    case cables
    case barbell
    case dumbbells
    case bodyweight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .machines: "Gym machines"
        case .cables: "Cable machines"
        case .barbell: "Barbell"
        case .dumbbells: "Dumbbells"
        case .bodyweight: "Bodyweight / home"
        }
    }

    var subtitle: String {
        switch self {
        case .machines: "Leg press, pec deck, assisted pull-up, and similar."
        case .cables: "Pulldowns, pushdowns, flyes, face pulls."
        case .barbell: "Squat rack, bench, and a barbell."
        case .dumbbells: "Adjustable or fixed dumbbells and a bench."
        case .bodyweight: "Floor space, and a bar if you have one."
        }
    }

    static let typicalGym: Set<GymEquipment> = [.machines, .cables, .barbell, .dumbbells]
}

enum MuscleGroup: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case chest, shoulders, triceps, lats, upperBack, biceps, quads, hamstrings, glutes, calves, core

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: "Chest"
        case .shoulders: "Shoulders"
        case .triceps: "Triceps"
        case .lats: "Lats"
        case .upperBack: "Upper back"
        case .biceps: "Biceps"
        case .quads: "Quads"
        case .hamstrings: "Hamstrings"
        case .glutes: "Glutes"
        case .calves: "Calves"
        case .core: "Core"
        }
    }
}

// MARK: - Catalog

struct ExerciseCatalogEntry: Codable, Equatable, Sendable, Identifiable, Hashable {
    var id: String
    var name: String
    var muscle: MuscleGroup
    var equipment: GymEquipment
    var isCompound: Bool
    var isBodyweightMaxReps: Bool
}

enum ExerciseCatalog {
    static func entry(id: String) -> ExerciseCatalogEntry? {
        byID[id]
    }

    static let all: [ExerciseCatalogEntry] = makeCatalog()

    private static let byID: [String: ExerciseCatalogEntry] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    private static func e(
        _ name: String,
        _ muscle: MuscleGroup,
        _ equipment: GymEquipment,
        compound: Bool = false,
        bodyweight: Bool = false
    ) -> ExerciseCatalogEntry {
        ExerciseCatalogEntry(
            id: name.lowercased(),
            name: name,
            muscle: muscle,
            equipment: equipment,
            isCompound: compound,
            isBodyweightMaxReps: bodyweight
        )
    }

    private static func makeCatalog() -> [ExerciseCatalogEntry] {
        [
            e("Barbell bench press", .chest, .barbell, compound: true),
            e("Incline barbell press", .chest, .barbell, compound: true),
            e("Dumbbell bench press", .chest, .dumbbells, compound: true),
            e("Incline dumbbell press", .chest, .dumbbells, compound: true),
            e("Flat chest press", .chest, .machines, compound: true),
            e("Prime incline", .chest, .machines, compound: true),
            e("Chest press machine", .chest, .machines, compound: true),
            e("Pec deck", .chest, .machines),
            e("Cable flye", .chest, .cables),
            e("Upper chest flye", .chest, .cables),
            e("Push-up", .chest, .bodyweight, compound: true, bodyweight: true),
            e("Decline push-up", .chest, .bodyweight, compound: true, bodyweight: true),

            e("Overhead press", .shoulders, .barbell, compound: true),
            e("Seated dumbbell press", .shoulders, .dumbbells, compound: true),
            e("Arnold press", .shoulders, .dumbbells, compound: true),
            e("Shoulder press", .shoulders, .machines, compound: true),
            e("Machine side lateral raise", .shoulders, .machines),
            e("Dumbbell lateral raise", .shoulders, .dumbbells),
            e("Lateral raise", .shoulders, .dumbbells),
            e("Cable lateral raise", .shoulders, .cables),
            e("Rear delt flye", .shoulders, .dumbbells),
            e("Face pull", .shoulders, .cables),
            e("Y raise", .shoulders, .cables),
            e("Pike push-up", .shoulders, .bodyweight, compound: true, bodyweight: true),

            e("Close-grip bench press", .triceps, .barbell, compound: true),
            e("Skull crusher", .triceps, .barbell),
            e("Overhead tricep extension", .triceps, .dumbbells),
            e("Tricep pushdown", .triceps, .cables),
            e("Poliquin tricep extensions", .triceps, .cables),
            e("Tricep dip machine", .triceps, .machines),
            e("Bench dip", .triceps, .bodyweight, bodyweight: true),
            e("Dip", .triceps, .bodyweight, compound: true, bodyweight: true),

            e("Pull-up", .lats, .bodyweight, compound: true, bodyweight: true),
            e("Chin-up", .lats, .bodyweight, compound: true, bodyweight: true),
            e("Lat pulldown", .lats, .cables, compound: true),
            e("Wide grip pulldown", .lats, .cables, compound: true),
            e("Iliac lat pulldown", .lats, .cables),
            e("Assisted Pull up", .lats, .machines, compound: true),
            e("Straight-arm pulldown", .lats, .cables),
            e("One-arm dumbbell row", .lats, .dumbbells, compound: true),

            e("Barbell row", .upperBack, .barbell, compound: true),
            e("Tbar row", .upperBack, .barbell, compound: true),
            e("Seated cable row", .upperBack, .cables, compound: true),
            e("Cybex eagle lat row", .upperBack, .machines, compound: true),
            e("Upper back row", .upperBack, .machines, compound: true),
            e("Chest-supported row", .upperBack, .machines, compound: true),
            e("Inverted row", .upperBack, .bodyweight, compound: true, bodyweight: true),
            e("Superman", .upperBack, .bodyweight, bodyweight: true),

            e("Barbell curl", .biceps, .barbell),
            e("Dumbbell curl", .biceps, .dumbbells),
            e("Hammer curl", .biceps, .dumbbells),
            e("Cable hammer curl", .biceps, .cables),
            e("Dbell preacher curl", .biceps, .dumbbells),
            e("Preacher curl machine", .biceps, .machines),
            e("Incline dumbbell curl", .biceps, .dumbbells),

            e("Back squat", .quads, .barbell, compound: true),
            e("Front squat", .quads, .barbell, compound: true),
            e("Goblet squat", .quads, .dumbbells, compound: true),
            e("Leg press", .quads, .machines, compound: true),
            e("Squat press", .quads, .machines, compound: true),
            e("Hack squat", .quads, .machines, compound: true),
            e("Leg extension", .quads, .machines),
            e("Walking lunge", .quads, .dumbbells),
            e("Bodyweight squat", .quads, .bodyweight, compound: true, bodyweight: true),
            e("Bulgarian split squat", .quads, .bodyweight, compound: true, bodyweight: true),

            e("Conventional deadlift", .hamstrings, .barbell, compound: true),
            e("Romanian deadlift", .hamstrings, .barbell, compound: true),
            e("Dumbbell RDL", .hamstrings, .dumbbells, compound: true),
            e("Seated leg curl", .hamstrings, .machines),
            e("Lying leg curl", .hamstrings, .machines),
            e("Hyperextension", .hamstrings, .bodyweight, bodyweight: true),
            e("Nordic curl", .hamstrings, .bodyweight, bodyweight: true),

            e("Hip thrust", .glutes, .barbell, compound: true),
            e("Glute bridge", .glutes, .bodyweight, bodyweight: true),
            e("Cable kickback", .glutes, .cables),
            e("Hip abduction", .glutes, .machines),
            e("Adductor", .glutes, .machines),
            e("Reverse lunge", .glutes, .bodyweight, bodyweight: true),

            e("Standing calf raise", .calves, .machines),
            e("Seated calf raise", .calves, .machines),
            e("Straight leg calf raise", .calves, .machines),
            e("Calf raise", .calves, .bodyweight, bodyweight: true),

            e("Cable crunch", .core, .cables),
            e("Rope crunch", .core, .cables),
            e("Plank", .core, .bodyweight, bodyweight: true),
            e("Hanging leg raise", .core, .bodyweight, bodyweight: true),
            e("Sit-up", .core, .bodyweight, bodyweight: true),
            e("Hollow hold", .core, .bodyweight, bodyweight: true),
            e("Side plank", .core, .bodyweight, bodyweight: true),
            e("Leg raise (bodyweight max reps)", .core, .bodyweight, bodyweight: true)
        ]
    }
}

// MARK: - Generated plan

struct GeneratedExercise: Codable, Equatable, Sendable, Identifiable, Hashable {
    var catalogID: String
    var name: String
    var muscle: MuscleGroup
    var equipment: GymEquipment
    var defaultSets: Int
    var isBodyweightMaxReps: Bool

    var id: String { catalogID }

    init(entry: ExerciseCatalogEntry, defaultSets: Int) {
        self.catalogID = entry.id
        self.name = entry.name
        self.muscle = entry.muscle
        self.equipment = entry.equipment
        self.defaultSets = defaultSets
        self.isBodyweightMaxReps = entry.isBodyweightMaxReps
    }

    var asBlueprint: WorkoutExerciseBlueprint {
        WorkoutExerciseBlueprint(
            id: catalogID,
            name: name,
            defaultSets: defaultSets,
            isBodyweightMaxReps: isBodyweightMaxReps,
            muscleGroup: muscle,
            equipment: equipment
        )
    }
}

struct GeneratedWorkoutDay: Codable, Equatable, Sendable, Identifiable {
    var templateID: WorkoutTemplateID
    var exercises: [GeneratedExercise]
    var id: WorkoutTemplateID { templateID }
}

struct GeneratedWorkoutPlan: Codable, Equatable, Sendable {
    var seed: Int
    var volume: TrainingVolume
    var goal: TrainingGoal
    var equipment: [GymEquipment]
    var programID: TrainingProgramID
    var blockedExerciseIDs: [String]
    var days: [GeneratedWorkoutDay]

    func day(for id: WorkoutTemplateID) -> GeneratedWorkoutDay? {
        days.first { $0.templateID == id }
    }

    var summaryLine: String {
        "\(goal.displayName) · \(volume.displayName) · \(days.count) sessions"
    }
}

// MARK: - Seeded RNG (must match web/src/engines/exerciseCatalog.ts)

struct SeededRNG: Sendable {
    private var state: UInt32

    init(seed: Int) {
        let raw = UInt32(truncatingIfNeeded: seed)
        state = raw == 0 ? 1 : raw
    }

    mutating func next() -> UInt32 {
        state = state &* 1_664_525 &+ 1_013_904_223
        return state
    }

    mutating func nextInt(_ upper: Int) -> Int {
        guard upper > 0 else { return 0 }
        return Int(next() % UInt32(upper))
    }

    mutating func shuffle<T>(_ items: inout [T]) {
        guard items.count > 1 else { return }
        for i in stride(from: items.count - 1, through: 1, by: -1) {
            items.swapAt(i, nextInt(i + 1))
        }
    }
}

// MARK: - Generator

enum WorkoutPlanGenerator {
    private struct Slot {
        var muscle: MuscleGroup
        var compound: Bool
        var sets: Int
    }

    static func generate(
        seed: Int,
        volume: TrainingVolume,
        goal: TrainingGoal,
        equipment: [GymEquipment],
        daysPerWeek: Int,
        blockedIDs: [String]
    ) -> GeneratedWorkoutPlan {
        let gear: Set<GymEquipment> = equipment.isEmpty ? Set(GymEquipment.allCases) : Set(equipment)
        let program = split(daysPerWeek: daysPerWeek, equipment: gear, goal: goal)
        let blocked = Set(blockedIDs)
        var rng = SeededRNG(seed: seed)
        var used = Set<String>()
        var days: [GeneratedWorkoutDay] = []

        for templateID in program.templateIDs {
            var exercises: [GeneratedExercise] = []
            for slot in slots(for: templateID, goal: goal, volume: volume) {
                if let pick = pick(
                    muscle: slot.muscle,
                    preferCompound: slot.compound,
                    equipment: gear,
                    blocked: blocked,
                    used: used,
                    rng: &rng
                ) {
                    used.insert(pick.id)
                    exercises.append(GeneratedExercise(entry: pick, defaultSets: slot.sets))
                }
            }
            days.append(GeneratedWorkoutDay(templateID: templateID, exercises: exercises))
        }

        return GeneratedWorkoutPlan(
            seed: seed,
            volume: volume,
            goal: goal,
            equipment: GymEquipment.allCases.filter { gear.contains($0) },
            programID: program,
            blockedExerciseIDs: blockedIDs,
            days: days
        )
    }

    static func split(daysPerWeek: Int, equipment: Set<GymEquipment>, goal: TrainingGoal) -> TrainingProgramID {
        let hasMachines = equipment.contains(.machines) || equipment.contains(.cables)
        let hasFree = equipment.contains(.barbell) || equipment.contains(.dumbbells)
        if !hasMachines && !hasFree { return .bodyweight }

        switch goal {
        case .keepFit:
            if daysPerWeek <= 3 { return .fullBody }
            if daysPerWeek == 4 { return .upperLower }
            return hasMachines && !hasFree ? .gymMachines : (hasFree && !hasMachines ? .freeWeights : .upperLower)
        case .bodybuilding:
            if daysPerWeek <= 3 { return .fullBody }
            if daysPerWeek == 4 { return .upperLower }
            return hasMachines ? .gymMachines : .freeWeights
        case .powerlifting, .strength:
            if daysPerWeek <= 3 { return .fullBody }
            return .upperLower
        case .powerbuilding:
            if daysPerWeek <= 3 { return .fullBody }
            if daysPerWeek == 4 { return .upperLower }
            return hasFree ? .freeWeights : .gymMachines
        }
    }

    static func replacements(
        for entry: ExerciseCatalogEntry,
        equipment: Set<GymEquipment>,
        blocked: Set<String>,
        excluding: Set<String>
    ) -> [ExerciseCatalogEntry] {
        let sameMuscle = ExerciseCatalog.all.filter {
            $0.muscle == entry.muscle && $0.id != entry.id && !excluding.contains($0.id)
        }
        let preferred = sameMuscle.filter { equipment.contains($0.equipment) && !blocked.contains($0.id) }
        let fallback = sameMuscle.filter { !blocked.contains($0.id) }
        var seen = Set<String>()
        var out: [ExerciseCatalogEntry] = []
        for item in preferred.sorted(by: { $0.name < $1.name }) + fallback.sorted(by: { $0.name < $1.name }) {
            if seen.insert(item.id).inserted { out.append(item) }
        }
        return out
    }

    static func snapshotLibraryPlan(
        programID: TrainingProgramID,
        volume: TrainingVolume,
        goal: TrainingGoal,
        equipment: [GymEquipment],
        templates: [WorkoutTemplate]
    ) -> GeneratedWorkoutPlan {
        let days = templates.map { template in
            GeneratedWorkoutDay(
                templateID: template.id,
                exercises: template.exercises.map { blueprint in
                    if let entry = ExerciseCatalog.entry(id: blueprint.id) {
                        return GeneratedExercise(entry: entry, defaultSets: blueprint.defaultSets)
                    }
                    return GeneratedExercise(
                        entry: ExerciseCatalogEntry(
                            id: blueprint.id,
                            name: blueprint.name,
                            muscle: blueprint.muscleGroup ?? .chest,
                            equipment: blueprint.equipment ?? .machines,
                            isCompound: true,
                            isBodyweightMaxReps: blueprint.isBodyweightMaxReps
                        ),
                        defaultSets: blueprint.defaultSets
                    )
                }
            )
        }
        return GeneratedWorkoutPlan(
            seed: 0,
            volume: volume,
            goal: goal,
            equipment: equipment.isEmpty ? Array(GymEquipment.typicalGym) : equipment,
            programID: programID,
            blockedExerciseIDs: [],
            days: days
        )
    }

    private static func volumeSets(goal: TrainingGoal, volume: TrainingVolume, compound: Bool) -> Int {
        switch (goal, volume, compound) {
        case (.powerlifting, .high, true), (.strength, .high, true): 5
        case (.powerlifting, .low, true), (.strength, .low, true): 4
        case (.bodybuilding, .high, true), (.powerbuilding, .high, true): 4
        case (.keepFit, .high, true): 3
        case (_, .low, true): 3
        case (.bodybuilding, .high, false): 3
        case (.keepFit, _, false): 2
        case (_, .high, false): 3
        case (_, .low, false): 2
        }
    }

    private static func extraIsolation(_ goal: TrainingGoal, _ volume: TrainingVolume) -> Bool {
        volume == .high && (goal == .bodybuilding || goal == .powerbuilding)
    }

    private static func slot(_ muscle: MuscleGroup, compound: Bool, goal: TrainingGoal, volume: TrainingVolume) -> Slot {
        Slot(muscle: muscle, compound: compound, sets: volumeSets(goal: goal, volume: volume, compound: compound))
    }

    private static func slots(for templateID: WorkoutTemplateID, goal: TrainingGoal, volume: TrainingVolume) -> [Slot] {
        let extra = extraIsolation(goal, volume)
        let heavy = goal == .powerlifting || goal == .strength
        func s(_ muscle: MuscleGroup, _ compound: Bool) -> Slot {
            slot(muscle, compound: compound, goal: goal, volume: volume)
        }

        switch templateID {
        case .pushA, .fwPush:
            if heavy {
                var list = [s(.chest, true), s(.chest, true), s(.shoulders, true), s(.triceps, false)]
                if volume == .high { list.append(s(.shoulders, false)) }
                return list
            }
            if goal == .keepFit {
                var list = [s(.chest, true), s(.shoulders, true), s(.triceps, false)]
                if volume == .high { list.append(s(.chest, false)) }
                return list
            }
            var list = [s(.chest, true), s(.chest, false), s(.shoulders, true), s(.shoulders, false), s(.triceps, false)]
            if extra { list.append(s(.triceps, false)) }
            return list

        case .pullA, .fwPull:
            if heavy {
                var list = [s(.hamstrings, true), s(.upperBack, true), s(.lats, true), s(.biceps, false)]
                if volume == .high { list.append(s(.upperBack, false)) }
                return list
            }
            if goal == .keepFit {
                var list = [s(.lats, true), s(.upperBack, true), s(.biceps, false)]
                if volume == .high { list.append(s(.core, false)) }
                return list
            }
            var list = [s(.lats, true), s(.upperBack, true), s(.lats, false), s(.biceps, false), s(.core, false)]
            if extra { list.append(s(.biceps, false)) }
            return list

        case .legsA, .fwLegs:
            if heavy {
                var list = [s(.quads, true), s(.hamstrings, true), s(.glutes, true), s(.calves, false)]
                if volume == .high { list.append(s(.quads, false)) }
                return list
            }
            var list = [s(.quads, true), s(.hamstrings, true), s(.glutes, true), s(.quads, false), s(.hamstrings, false), s(.calves, false)]
            if extra { list.append(s(.core, false)) }
            return list

        case .legsB:
            var list = [s(.glutes, true), s(.hamstrings, false), s(.quads, true), s(.quads, false), s(.calves, false), s(.core, false)]
            if extra { list.append(s(.glutes, false)) }
            return list

        case .upper, .ulUpperA:
            if heavy {
                return [s(.chest, true), s(.upperBack, true), s(.shoulders, true), s(.lats, true), s(.triceps, false)]
            }
            var list = [s(.chest, true), s(.upperBack, true), s(.shoulders, true), s(.lats, true), s(.biceps, false), s(.triceps, false)]
            if extra { list.append(s(.shoulders, false)) }
            return list

        case .ulUpperB:
            var list = [s(.chest, false), s(.lats, true), s(.shoulders, true), s(.upperBack, true), s(.triceps, false), s(.shoulders, false)]
            if extra { list.append(s(.biceps, false)) }
            return list

        case .ulLowerA:
            if heavy {
                return [s(.quads, true), s(.hamstrings, true), s(.glutes, true), s(.calves, false), s(.core, false)]
            }
            var list = [s(.quads, true), s(.hamstrings, true), s(.quads, false), s(.hamstrings, false), s(.calves, false)]
            if extra { list.append(s(.core, false)) }
            return list

        case .ulLowerB:
            var list = [s(.quads, true), s(.glutes, true), s(.quads, false), s(.calves, false), s(.core, false)]
            if extra { list.append(s(.hamstrings, false)) }
            return list

        case .fbA, .bwFullA:
            var list = [s(.quads, true), s(.chest, true), s(.upperBack, true), s(.hamstrings, true), s(.core, false)]
            if extra { list.append(s(.shoulders, false)) }
            return list

        case .fbB, .bwFullB:
            var list = [s(.hamstrings, true), s(.shoulders, true), s(.lats, true), s(.quads, false), s(.biceps, false)]
            if extra { list.append(s(.core, false)) }
            return list

        case .fbC, .bwFullC:
            var list = [s(.quads, true), s(.chest, true), s(.lats, true), s(.glutes, true), s(.shoulders, false)]
            if extra { list.append(s(.core, false)) }
            return list
        }
    }

    private static func pick(
        muscle: MuscleGroup,
        preferCompound: Bool,
        equipment: Set<GymEquipment>,
        blocked: Set<String>,
        used: Set<String>,
        rng: inout SeededRNG
    ) -> ExerciseCatalogEntry? {
        func pool(muscles: [MuscleGroup], gear: Set<GymEquipment>, compound: Bool?) -> [ExerciseCatalogEntry] {
            ExerciseCatalog.all.filter { entry in
                muscles.contains(entry.muscle)
                    && gear.contains(entry.equipment)
                    && !blocked.contains(entry.id)
                    && !used.contains(entry.id)
                    && (compound == nil || entry.isCompound == compound)
            }
        }

        var options = pool(muscles: [muscle], gear: equipment, compound: preferCompound)
        if options.isEmpty { options = pool(muscles: [muscle], gear: equipment, compound: nil) }
        if options.isEmpty {
            options = pool(muscles: [muscle], gear: equipment.union([.bodyweight]), compound: nil)
        }
        rng.shuffle(&options)
        return options.first
    }
}
