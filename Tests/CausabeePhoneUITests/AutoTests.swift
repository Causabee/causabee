import XCTest

/// Auto, the whole circle: with Auto on, a matter whose record has changed and come to rest gets
/// its next step written again by itself, and says "Auto" beside it. On the demo, where nothing is
/// sent: the step worked out on the device stands in for the AI's.
final class AutoTests: XCTestCase {
    func testAStepDoneBringsTheNextByItself() {
        continueAfterFailure = false
        let app = XCUIApplication()
        // Auto on for this start only, and what it knew of the demo's matters forgotten.
        app.launchArguments = ["--demo", "-demo.filled", "anew", "-mail.auto", "YES", "--auto-anew"]
        app.launch()
        let matter = app.staticTexts["Bathroom renovation"].firstMatch
        XCTAssertTrue(matter.waitForExistence(timeout: 20), "The demo's overview did not come up.")
        matter.tap()
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 10), "The matter's next step has no Done.")
        XCTAssertFalse(app.staticTexts["Auto"].exists, "The step says Auto before anything changed.")
        // Auto takes note of the matters on its first look, a quarter of a minute in; then the change.
        Thread.sleep(forTimeInterval: 20)
        done.tap()
        // Seen at the next look, at rest at the one after, written a moment later.
        XCTAssertTrue(app.staticTexts["Auto"].waitForExistence(timeout: 60), "The next step was not written again by Auto.")
    }
}
