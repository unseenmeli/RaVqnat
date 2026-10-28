import XCTest

final class NotificationsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testBellOpensInboxAndNotificationsNavigate() {
        let app = XCUIApplication.launchRaVqnat(signedIn: true)
        let bell = app.buttons["explore.notifications"]
        XCTAssertTrue(bell.waitForExistence(timeout: 5))
        bell.tap()

        // Every new account starts with a welcome / safety notice.
        let welcome = app.cells.firstMatch
        XCTAssertTrue(welcome.waitForExistence(timeout: 3))
        snapshot(app, "30-inbox")
        welcome.tap()
        XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 3))
        snapshot(app, "31-inbox-destination")
    }
}
