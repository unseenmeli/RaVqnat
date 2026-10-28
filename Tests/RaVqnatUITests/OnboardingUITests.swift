import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testNewUserCompletesOnboardingAndLandsOnExplore() {
        let app = XCUIApplication.launchRaVqnat()
        snapshot(app, "01-welcome")

        app.buttons["welcome.demo"].tap()

        let name = app.textFields["onboarding.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let next = app.buttons["onboarding.continue"]
        XCTAssertFalse(next.isEnabled, "Continue must be disabled until a valid name is entered")
        name.typeText("Nino")
        snapshot(app, "02-name")
        next.tap()

        let age = app.descendants(matching: .any)["onboarding.age"].firstMatch
        XCTAssertTrue(age.waitForExistence(timeout: 3))
        XCTAssertFalse(next.isEnabled, "Adults-only confirmation is required")
        age.tap()
        snapshot(app, "03-age")
        next.tap()

        snapshot(app, "04-photo")
        next.tap() // photo is optional

        let chess = app.buttons["interest.chess"]
        XCTAssertTrue(chess.waitForExistence(timeout: 3))
        chess.tap()
        app.buttons["interest.coffee"].tap()
        snapshot(app, "05-interests")
        next.tap()

        snapshot(app, "06-language")
        next.tap() // language is the last step

        XCTAssertTrue(app.buttons["explore.filters"].waitForExistence(timeout: 5), "Explore should appear after onboarding")
        snapshot(app, "08-explore")
    }
}
