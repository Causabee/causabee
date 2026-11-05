import XCTest

/// Auto, the whole circle: with Auto on, a matter whose record has changed goes grey at once and is
/// written again when the owner asks for it or leaves. On the demo, where nothing is sent: the step
/// worked out on the device stands in for the AI's.
final class AutoTests: XCTestCase {
    /// The overview opens on its journal; the matters are one filter away.
    private func showMatters(in app: XCUIApplication) {
        let filter = app.buttons["part.Matters"]
        guard filter.waitForExistence(timeout: 40) else { return }
        // The sorted mails' card comes in over the filters just after the start, and a tap then misses.
        let row = app.staticTexts["Bathroom renovation"].firstMatch
        for _ in 0..<5 where !row.exists {
            filter.tap()
            _ = row.waitForExistence(timeout: 3)
        }
    }

    func testAStepDoneBringsTheNextByItself() {
        continueAfterFailure = false
        let app = XCUIApplication()
        // Auto on for this start only, and what it knew of the demo's matters forgotten.
        app.launchArguments = ["--demo", "-demo.filled", "anew", "-mail.auto", "YES", "--auto-anew"]
        app.launch()
        showMatters(in: app)
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
        // Said at once that the step no longer holds; nothing is written while the owner works here.
        let outOfDate = app.staticTexts["OUT OF DATE"]
        XCTAssertTrue(outOfDate.waitForExistence(timeout: 5), "Nothing says the step is out of date.")
        XCTAssertFalse(app.buttons["Done"].firstMatch.exists, "A step out of date can still be acted on.")
        let update = app.buttons["update.now"].firstMatch
        XCTAssertTrue(update.exists, "There is no Update now.")
        update.tap()
        // Written: the step is Causabee's again.
        XCTAssertTrue(outOfDate.waitForNonExistence(timeout: 20), "Update now wrote nothing.")
        XCTAssertTrue(app.staticTexts["NEXT · FROM CAUSABEE"].waitForExistence(timeout: 5), "After Auto wrote it, the step is not Causabee's.")
    }

    func testLeavingAMatterWritesItAgain() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "-demo.filled", "anew", "-mail.auto", "YES", "--auto-anew"]
        app.launch()
        showMatters(in: app)
        let matter = app.staticTexts["Bathroom renovation"].firstMatch
        XCTAssertTrue(matter.waitForExistence(timeout: 20), "The demo's overview did not come up.")
        matter.tap()
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 10), "The matter's next step has no Done.")
        Thread.sleep(forTimeInterval: 6)
        done.tap()
        XCTAssertTrue(app.staticTexts["OUT OF DATE"].waitForExistence(timeout: 5), "Nothing says the step is out of date.")
        // Out of the matter: on the iPhone back, on the iPad to the overview by the sidebar — there
        // the bar has no way back, and its first button is the matter's icon.
        let sidebar = app.buttons["sidebar.toggle"]
        if sidebar.exists {
            if !app.buttons["sidebar.overview"].exists { sidebar.tap() }
            XCTAssertTrue(app.buttons["sidebar.overview"].waitForExistence(timeout: 5), "The sidebar has no Overview.")
            app.buttons["sidebar.overview"].tap()
        } else {
            app.navigationBars.buttons.firstMatch.tap()
        }
        // Back in after it was written: grey no more.
        XCTAssertTrue(matter.waitForExistence(timeout: 10), "The overview did not come back.")
        Thread.sleep(forTimeInterval: 8)
        matter.tap()
        XCTAssertTrue(app.staticTexts["NEXT · FROM CAUSABEE"].waitForExistence(timeout: 10), "Leaving the matter did not write it again.")
    }
}
