import XCTest

/// What others have to do never looks like the owner's own to-do: no box to tick, who first, a
/// dashed line round it instead of a card (manifesto 15). Runs on iPhone and iPad.
final class WaitingUITests: XCTestCase {
    private var app: XCUIApplication!

    func testWaitingForOthersLooksApart() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--demo", "-demo.filled", "anew", "-mail.auto", "NO", "--open", "lisbon-october"]
        app.launch()
        let plan = app.buttons["part.plan"]
        XCTAssertTrue(plan.waitForExistence(timeout: 40), "No Plan tab.")
        plan.tap()
        let section = app.staticTexts["WAITING FOR OTHERS"]
        for _ in 0..<8 where !section.exists || !section.isHittable { app.swipeUp() }
        if let shots = ProcessInfo.processInfo.environment["SHOT_DIR"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shots).appendingPathComponent("waiting-find.png"))
        }
        XCTAssertTrue(section.waitForExistence(timeout: 10), "No Waiting for others.")
        let who = app.staticTexts.matching(NSPredicate(format: "identifier == 'task.waitingFor' AND label BEGINSWITH 'Waiting for '")).firstMatch
        XCTAssertTrue(who.exists, "It does not say whom the owner waits for.")
        XCTAssertTrue(app.buttons["It came — mark as done"].exists, "A box to tick, as for the owner's own.")
        let task = app.staticTexts["Tomás sends the dinner address"]
        XCTAssertTrue(task.exists)
        XCTAssertLessThan(who.frame.minY, task.frame.minY, "Whom it waits for is not said first.")
        if let shots = ProcessInfo.processInfo.environment["SHOT_DIR"] {
            for _ in 0..<2 where section.frame.maxY > app.frame.height * 0.8 { app.swipeUp() }
            Thread.sleep(forTimeInterval: 0.6)
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shots).appendingPathComponent("waiting.png"))
        }
    }
}
