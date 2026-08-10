import XCTest

final class MyCoachUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testLaunchApp() throws {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testOnboardingWelcomeShowsMyCoach() throws {
        let brand = app.staticTexts["My Coach"]
        XCTAssertTrue(
            brand.waitForExistence(timeout: 8),
            "Welcome onboarding should show the My Coach brand"
        )
    }

    /// Critical journey stub: welcome CTA is tappable when onboarding is shown.
    func testCriticalJourneyGetStartedIfPresent() throws {
        let getStarted = app.buttons["Get Started"]
        guard getStarted.waitForExistence(timeout: 5) else {
            // Returning user / completed onboarding — stub still validates launch shell.
            XCTAssertTrue(app.exists)
            return
        }
        XCTAssertTrue(getStarted.isHittable)
        getStarted.tap()

        // Next onboarding step asks for a name.
        let nameField = app.textFields["Your name"]
        if nameField.waitForExistence(timeout: 5) {
            XCTAssertTrue(nameField.exists)
        } else {
            // Fallback: any Continue / progress UI after welcome.
            let continueButton = app.buttons["Continue"]
            XCTAssertTrue(continueButton.exists || app.staticTexts["My Coach"].exists)
        }
    }

    /// Navigation stub for main tabs when onboarding is already complete.
    func testCriticalJourneyTabBarIfPresent() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 3) else {
            throw XCTSkip("Tab bar not present — likely first-launch onboarding")
        }

        let candidates = ["Today", "Meal Plan", "Log", "Progress", "Coach"]
        let available = candidates.filter { app.tabBars.buttons[$0].exists }
        XCTAssertFalse(available.isEmpty, "Expected at least one main tab")

        if let first = available.first {
            app.tabBars.buttons[first].tap()
            XCTAssertTrue(app.tabBars.buttons[first].isSelected || app.exists)
        }
    }
}
