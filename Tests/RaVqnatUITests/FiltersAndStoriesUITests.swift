import XCTest

final class FiltersAndStoriesUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testFiltersLiveInTheSheetAndCanBeCleared() {
        let app = XCUIApplication.launchRaVqnat(signedIn: true)
        let filters = app.buttons["explore.filters"]
        XCTAssertTrue(filters.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["explore.greeting"].exists || app.staticTexts["What shall we do, Meli?"].exists)
        XCTAssertFalse(app.buttons["explore.clear_filters"].exists, "No filter summary when nothing is filtered")

        filters.tap()
        app.buttons["filter.date.custom"].tap()
        XCTAssertTrue(app.staticTexts["filter.days_hint"].waitForExistence(timeout: 3), "Pick dates shows a calendar")
        snapshot(app, "20-filters-dates")
        app.buttons["filter.date.today"].tap()
        app.buttons["filter.category.sports"].tap()
        snapshot(app, "21-filters")
        app.buttons["filter.apply"].tap()

        let clear = app.buttons["explore.clear_filters"]
        XCTAssertTrue(clear.waitForExistence(timeout: 3), "Active filters are summarised on the home screen")
        snapshot(app, "22-explore-filtered")
        clear.tap()
        XCTAssertFalse(clear.waitForExistence(timeout: 1))
    }

    @MainActor
    func testStoriesCanBeViewedAndAdvanced() {
        let app = XCUIApplication.launchRaVqnat(signedIn: true)
        let bubble = app.buttons["stories.group.0"]
        XCTAssertTrue(bubble.waitForExistence(timeout: 5), "Seeded stories appear in the row")
        snapshot(app, "23-stories-row")
        bubble.tap()

        let close = app.buttons["stories.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 3))
        snapshot(app, "24-story-viewer")
        app.buttons["stories.next"].tap()
        XCTAssertTrue(app.buttons["stories.view_activity"].exists)
        close.tap()
        XCTAssertTrue(app.buttons["explore.filters"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testComposerExplainsEligibilityForNewUsers() {
        let app = XCUIApplication.launchRaVqnat(signedIn: true)
        let add = app.buttons["stories.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        // The demo user has not joined or hosted anything yet, so posting is not possible.
        XCTAssertFalse(app.buttons["stories.share"].isEnabled)
        snapshot(app, "25-story-composer")
    }
}
