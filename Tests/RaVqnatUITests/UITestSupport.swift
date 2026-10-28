import XCTest

extension XCUIApplication {
    /// Launches in mock mode with fresh state. `signedIn` skips welcome + onboarding.
    static func launchRaVqnat(signedIn: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"] + (signedIn ? ["-uitest-signed-in"] : [])
        app.launch()
        return app
    }
}

extension XCTestCase {
    /// Saves a screenshot to `RV_SCREENSHOT_DIR` when set (used for design review), and always
    /// attaches it to the test result.
    func snapshot(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["RV_SCREENSHOT_DIR"], !dir.isEmpty {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }
}
