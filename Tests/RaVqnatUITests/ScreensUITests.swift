import XCTest

/// Smoke test: every main screen renders for a signed-in user, and the core navigation works.
final class ScreensUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testMainScreensRender() {
        let app = XCUIApplication.launchRaVqnat(signedIn: true)

        XCTAssertTrue(app.buttons["explore.filters"].waitForExistence(timeout: 5))
        snapshot(app, "10-explore")

        // Seeded "Pick-up basketball in Vake Park" (see MockSeed).
        let card = app.descendants(matching: .any)["activity.card.10000000-0000-4000-8000-000000000002"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        // Tap the cover, not the centre (which can land on the card's Join button).
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
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

    @MainActor
    func testHoldAndDragAcrossTabBarSwitchesPages() {
        let app = XCUIApplication.launchRaVqnat(signedIn: true)
        let explore = app.buttons["tab.explore"]
        XCTAssertTrue(explore.waitForExistence(timeout: 5))
        snapshot(app, "17-tabbar")

        // A one-step drag (the case that used to snap back to the starting tab).
        explore.press(forDuration: 0.5, thenDragTo: app.buttons["tab.map"])
        XCTAssertTrue(app.buttons["tab.map"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["tab.map"].isSelected, "Dragging one step lands on Map")

        // Hold the current tab, then slide to the right end of the capsule.
        app.buttons["tab.map"].press(forDuration: 0.5, thenDragTo: app.buttons["tab.profile"])
        XCTAssertTrue(app.buttons["profile.edit"].waitForExistence(timeout: 3), "Dragging to the end lands on Profile")

        // Dragging from a tab you are NOT on does nothing; tapping still works.
        app.buttons["tab.map"].tap()
        XCTAssertTrue(app.buttons["tab.map"].isSelected)
        app.buttons["tab.host"].tap()
        XCTAssertTrue(app.buttons["tab.host"].isSelected, "The separate + button opens hosting")
    }
}
