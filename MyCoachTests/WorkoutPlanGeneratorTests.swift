import XCTest
@testable import MyCoach

final class WorkoutPlanGeneratorTests: XCTestCase {
    func testMachinesOnlyNeverPicksBarbell() {
        let plan = WorkoutPlanGenerator.generate(
            seed: 7,
            volume: .high,
            goal: .bodybuilding,
            equipment: [.machines, .cables],
            daysPerWeek: 5,
            blockedIDs: []
        )
        XCTAssertFalse(plan.days.flatMap(\.exercises).contains { $0.equipment == .barbell })
        XCTAssertEqual(plan.programID, .gymMachines)
    }

    func testBlockedExerciseIsNotUsed() {
        let blocked = "pec deck"
        let plan = WorkoutPlanGenerator.generate(
            seed: 3,
            volume: .high,
            goal: .bodybuilding,
            equipment: [.machines, .cables],
            daysPerWeek: 5,
            blockedIDs: [blocked]
        )
        XCTAssertFalse(plan.days.flatMap(\.exercises).contains { $0.catalogID == blocked })
    }

    func testHighVolumeHasMoreSetsThanLowVolume() {
        let high = WorkoutPlanGenerator.generate(
            seed: 1,
            volume: .high,
            goal: .bodybuilding,
            equipment: Array(GymEquipment.typicalGym),
            daysPerWeek: 4,
            blockedIDs: []
        )
        let low = WorkoutPlanGenerator.generate(
            seed: 1,
            volume: .low,
            goal: .bodybuilding,
            equipment: Array(GymEquipment.typicalGym),
            daysPerWeek: 4,
            blockedIDs: []
        )
        let highSets = high.days.flatMap(\.exercises).reduce(0) { $0 + $1.defaultSets }
        let lowSets = low.days.flatMap(\.exercises).reduce(0) { $0 + $1.defaultSets }
        XCTAssertGreaterThan(highSets, lowSets)
    }

    func testRegenerateChangesExercises() {
        let first = WorkoutPlanGenerator.generate(
            seed: 1,
            volume: .high,
            goal: .powerbuilding,
            equipment: Array(GymEquipment.typicalGym),
            daysPerWeek: 4,
            blockedIDs: []
        )
        let second = WorkoutPlanGenerator.generate(
            seed: 2,
            volume: .high,
            goal: .powerbuilding,
            equipment: Array(GymEquipment.typicalGym),
            daysPerWeek: 4,
            blockedIDs: []
        )
        XCTAssertNotEqual(
            first.days.flatMap(\.exercises).map(\.catalogID),
            second.days.flatMap(\.exercises).map(\.catalogID)
        )
    }

    func testReplacementsMatchMuscle() {
        let pecDeck = ExerciseCatalog.entry(id: "pec deck")!
        let options = WorkoutPlanGenerator.replacements(
            for: pecDeck,
            equipment: [.machines, .cables, .dumbbells],
            blocked: ["pec deck"],
            excluding: []
        )
        XCTAssertFalse(options.isEmpty)
        XCTAssertTrue(options.allSatisfy { $0.muscle == .chest })
        XCTAssertFalse(options.contains { $0.id == "pec deck" })
    }

    func testBodyweightSplitWhenNoWeights() {
        let plan = WorkoutPlanGenerator.generate(
            seed: 4,
            volume: .low,
            goal: .keepFit,
            equipment: [.bodyweight],
            daysPerWeek: 3,
            blockedIDs: []
        )
        XCTAssertEqual(plan.programID, .bodyweight)
        XCTAssertTrue(plan.days.allSatisfy { !$0.exercises.isEmpty })
    }

    func testSameSeedIsDeterministic() {
        let a = WorkoutPlanGenerator.generate(
            seed: 11,
            volume: .high,
            goal: .strength,
            equipment: [.barbell, .dumbbells],
            daysPerWeek: 4,
            blockedIDs: []
        )
        let b = WorkoutPlanGenerator.generate(
            seed: 11,
            volume: .high,
            goal: .strength,
            equipment: [.barbell, .dumbbells],
            daysPerWeek: 4,
            blockedIDs: []
        )
        XCTAssertEqual(a, b)
    }
}
