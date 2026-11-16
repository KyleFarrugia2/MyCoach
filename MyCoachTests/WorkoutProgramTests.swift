import XCTest
@testable import MyCoach

final class WorkoutProgramTests: XCTestCase {
    func testDefaultProgramIsOriginalGymSplit() {
        XCTAssertEqual(UserPreferences().resolvedProgramID, .gymMachines)
        XCTAssertEqual(UserPreferences().resolvedTrainingStyle, .hypertrophy)
        XCTAssertEqual(TrainingProgramID.gymMachines.templateIDs, [.pushA, .pullA, .legsA, .upper, .legsB])
    }

    func testRecommendedProgramFollowsDaysPerWeek() {
        XCTAssertEqual(TrainingProgramID.recommended(daysPerWeek: 3), .fullBody)
        XCTAssertEqual(TrainingProgramID.recommended(daysPerWeek: 4), .upperLower)
        XCTAssertEqual(TrainingProgramID.recommended(daysPerWeek: 5), .gymMachines)
    }

    func testStrengthStyleAddsCompoundSets() {
        let base = WorkoutLibrary.template(id: .fwPush)
        let styled = WorkoutLibrary.apply(style: .strength, to: base)
        XCTAssertGreaterThanOrEqual(styled.exercises[0].defaultSets, 4)
        XCTAssertGreaterThanOrEqual(styled.exercises[1].defaultSets, 4)
        XCTAssertEqual(WorkoutLibrary.apply(style: .hypertrophy, to: base).exercises.map(\.defaultSets), base.exercises.map(\.defaultSets))
    }

    func testAthleticStyleAddsFinisher() {
        let base = WorkoutLibrary.template(id: .fbA)
        let styled = WorkoutLibrary.apply(style: .athletic, to: base)
        XCTAssertTrue(styled.exercises.contains { $0.id == "conditioning finisher" })
        XCTAssertEqual(WorkoutLibrary.apply(style: .athletic, to: styled).exercises.filter { $0.id == "conditioning finisher" }.count, 1)
    }

    func testNextWorkoutStaysInsideProgram() {
        let push = WorkoutSession(
            templateID: .pushA,
            templateName: "Push A",
            startedAt: Date().addingTimeInterval(-3600),
            completedAt: Date(),
            exercises: []
        )
        XCTAssertEqual(TrainingProgramID.gymMachines.nextTemplate(after: [push]), .pullA)
        XCTAssertEqual(TrainingProgramID.fullBody.nextTemplate(after: [push]), .fbA)

        let last = WorkoutSession(
            templateID: .legsB,
            templateName: "Legs B",
            startedAt: Date(),
            completedAt: Date(),
            exercises: []
        )
        XCTAssertEqual(TrainingProgramID.gymMachines.nextTemplate(after: [push, last]), .pushA)
    }

    func testEveryProgramHasLibraryTemplates() {
        for program in TrainingProgramID.allCases {
            XCTAssertFalse(program.templateIDs.isEmpty)
            for id in program.templateIDs {
                XCTAssertFalse(WorkoutLibrary.template(id: id).exercises.isEmpty)
            }
        }
    }
}
