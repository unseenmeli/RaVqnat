import XCTest

/// Smoke test: every main screen renders for a signed-in user, and the core navigation works.
final class ScreensUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testMainScreensRender() {
        let app = XCUIApplication.launchRaVqnat(signedIn: true)

        XCTAssertTrue(app.buttons["explore.location"].waitForExistence(timeout: 5))
        snapshot(app, "10-explore")

        let card = app.staticTexts["Pick-up basketball in Vake Park"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.buttons["detail.join"].waitForExistence(timeout: 5), "Detail should offer a join action")
        XCTAssertFalse(app.buttons["tab.explore"].exists, "Tab bar is hidden on pushed screens")
        snapshot(app, "11-detail")
        app.buttons["detail.back"].tap()

        app.buttons["tab.map"].tap()
        snapshot(app, "12-map")

        app.buttons["tab.host"].tap()
        XCTAssertTrue(app.buttons["host.verify"].waitForExistence(timeout: 5), "Unverified users are asked to verify before hosting")
        snapshot(app, "13-host")

        app.buttons["tab.chats"].tap()
        snapshot(app, "14-chats")

        app.buttons["tab.profile"].tap()
        XCTAssertTrue(app.buttons["profile.edit"].waitForExistence(timeout: 5))
        snapshot(app, "15-profile")

        app.buttons["profile.settings"].tap()
        snapshot(app, "16-settings")
    }
}
