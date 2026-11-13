import XCTest

/// Auto, the whole circle: with Auto on, a matter whose record has changed goes grey at once and is
/// written again when the owner asks for it or leaves. On the demo, where nothing is sent: the step
/// worked out on the device stands in for the AI's.
final class AutoTests: XCTestCase {
    /// The overview opens on its journal; the matters are one filter away.
    private func showMatters(in app: XCUIApplication) {
        let filter = app.buttons["overview.matters"]
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

    /// Principle 12 in the demo (seen 10 November): filled anew on a new day, the demo kept what Auto
    /// knew of yesterday's matters, so each of its matters looked changed — written again after a few
    /// minutes on one device, "Out of date" on another, as it was filled on a third. A brief filled
    /// in holds as it is, on every device, until something in the matter changes.
    func testADemoFilledAnewKeepsItsSteps() {
        continueAfterFailure = false
        let app = XCUIApplication()
        // Auto on, and what it knew of the care matter from a demo filled before: another record.
        app.launchArguments = ["--demo", "-demo.filled", "anew", "-mail.auto", "YES",
                               "-auto.known", "<\(Self.staleCare)>"]
        app.launch()
        showMatters(in: app)
        let matter = app.staticTexts["Care for Mum (Helga) after her fall"].firstMatch
        for _ in 0..<4 where !matter.isHittable { app.swipeUp() }
        XCTAssertTrue(matter.waitForExistence(timeout: 20), "The demo's care matter is not there.")
        matter.tap()
        XCTAssertTrue(app.staticTexts["Read and sign the Sunrise contract"].waitForExistence(timeout: 10), "The care matter's step is not the one the demo was filled with.")
        // Auto's looks, a few seconds apart: the step holds, and nothing says it is out of date.
        Thread.sleep(forTimeInterval: 8)
        XCTAssertFalse(app.staticTexts["OUT OF DATE"].exists, "A demo filled anew calls its step out of date.")
        XCTAssertTrue(app.staticTexts["Read and sign the Sunrise contract"].exists, "The care matter's step changed by itself.")
    }

    /// `auto.known` as a device that ran yesterday's demo keeps it: the care matter with another stamp.
    private static let staleCare = "7b22636172652d666f722d68656c6761223a7b227374616d70223a2230303030303030303030303030303030227d7d"
}
