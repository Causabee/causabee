import XCTest

/// Pictures and the screen's tree of the demo, for reading — not a check.
final class DemoLookTests: XCTestCase {
    func testLook() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "-demo.filled", "anew", "-mail.auto", "NO"]
        app.launch()
        let matters = app.buttons["part.Matters"]
        XCTAssertTrue(matters.waitForExistence(timeout: 40))
        guard let shots = ProcessInfo.processInfo.environment["PANEL_SHOTS"] else { return }
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shots + "/look-overview.png"))
        try? app.debugDescription.write(toFile: shots + "/look-overview.txt", atomically: true, encoding: .utf8)
        matters.tap()
        sleep(2)
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shots + "/look-matters.png"))
        try? app.debugDescription.write(toFile: shots + "/look-matters.txt", atomically: true, encoding: .utf8)
    }
}
