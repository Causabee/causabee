import XCTest

/// Auto, the whole circle: with Auto on, a matter whose record has changed and come to rest gets
/// its next step written again by itself; a line under it says "Auto mode". On the demo, where nothing is
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
        // With Auto on there is nothing to ask with: no link, no price.
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "ask again")).firstMatch.exists, "The link to ask again is there though Auto asks.")
        // Auto takes note of the matters on its first look, a few seconds in; then the change.
        Thread.sleep(forTimeInterval: 6)
        done.tap()
        // Said at once that it will be written, and written within a few seconds.
        let soon = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Auto updates this in a moment")).firstMatch
        XCTAssertTrue(soon.waitForExistence(timeout: 8), "Nothing says the record changed and will be written.")
        // Written: the line says "Auto mode" again, and the step is Causabee's.
        XCTAssertTrue(soon.waitForNonExistence(timeout: 20), "The next step was not written again by Auto.")
        XCTAssertTrue(app.staticTexts["NEXT · FROM CAUSABEE"].waitForExistence(timeout: 5), "After Auto wrote it, the step is not Causabee's.")
    }
}
