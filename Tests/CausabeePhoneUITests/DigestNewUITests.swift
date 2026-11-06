import XCTest

/// What is new on top of the Digest: put away one by one, or all seen at once.
final class DigestNewUITests: XCTestCase {
    func testNewIsPutAwayAndSeen() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "-demo.filled", "anew", "-mail.auto", "NO", "--open", "Moving to Birch Road 12"]
        app.launch()
        let away = app.buttons.matching(identifier: "new.putAway")
        XCTAssertTrue(away.firstMatch.waitForExistence(timeout: 40), "The Digest shows nothing new from the demo's last mails.")
        if let shots = ProcessInfo.processInfo.environment["PANEL_SHOTS"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shots + "/digest-new.png"))
        }
        let before = away.count
        away.firstMatch.tap()
        for _ in 0..<25 where away.count >= before { Thread.sleep(forTimeInterval: 0.2) }
        XCTAssertEqual(away.count, before - 1, "Put away, the line is still there.")
        // The last one put away takes the card with it; with more left, Seen clears them all.
        if away.count > 0 {
            app.buttons["brief.seen"].firstMatch.tap()
            for _ in 0..<25 where away.count > 0 { Thread.sleep(forTimeInterval: 0.2) }
            XCTAssertEqual(away.count, 0, "Seen, what was new is still there.")
        }
        XCTAssertFalse(app.buttons["brief.seen"].exists, "Nothing new left, the card is still there.")
    }
}
