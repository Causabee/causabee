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

    /// Tasks with no day stand on the Digest too, the oldest first; a tap opens the task's own
    /// editor there — not Plan.
    func testATaskWithNoDayOpensInPlace() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "-demo.filled", "anew", "-mail.auto", "NO", "--open", "Care for Mum (Helga) after her fall"]
        app.launch()
        let noDay = app.descendants(matching: .any)["ahead.noDay"]
        for _ in 0..<4 where !noDay.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(noDay.exists, "The Digest shows no task without a day.")
        // The task's words are its button; its box is the other one.
        let first = noDay.buttons.matching(NSPredicate(format: "label != 'Mark as done'")).firstMatch
        XCTAssertTrue(first.exists, "“No day yet” lists no task.")
        for _ in 0..<6 where !first.isHittable { app.swipeUp() }
        if let shots = ProcessInfo.processInfo.environment["PANEL_SHOTS"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shots + "/no-day.png"))
        }
        first.tap()
        let text = app.textFields["task.text"].exists ? app.textFields["task.text"] : app.textViews["task.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5), "Tapped, the task did not open its editor.")
        XCTAssertFalse(app.buttons["part.Plan"].isSelected, "Tapped, the task went to Plan.")
    }

    /// The overview's latest updates say what happened, and a pinned matter how much is open.
    func testTheOverviewSaysWhatHappened() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "-demo.filled", "anew", "-mail.auto", "NO"]
        app.launch()
        let updates = app.buttons["part.Latest updates"]
        XCTAssertTrue(updates.waitForExistence(timeout: 40), "The overview did not come up.")
        updates.tap()
        let card = app.buttons["overview.day"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Latest updates show no matter.")
        for _ in 0..<3 where !card.isHittable { app.swipeUp() }
        if let shots = ProcessInfo.processInfo.environment["PANEL_SHOTS"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shots + "/overview-latest.png"))
        }
    }

    /// A pinned matter says how much is open and its next day on one line, as every other row does.
    func testAPinnedCardSaysItsNextDayByItsCount() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "-demo.filled", "anew", "-mail.auto", "NO"]
        app.launch()
        let matters = app.buttons["part.Matters"]
        XCTAssertTrue(matters.waitForExistence(timeout: 40), "The overview did not come up.")
        matters.tap()
        // The demo pins none: one is pinned as the owner does it, held.
        let row = app.staticTexts["Moving to Birch Road 12"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The demo's move is not among the matters.")
        row.press(forDuration: 1.0)
        let pin = app.buttons["Pin to Top"].firstMatch
        XCTAssertTrue(pin.waitForExistence(timeout: 5), "Held, a matter cannot be pinned.")
        pin.tap()
        // The card is one button to the test: its words are found in it, whatever they are made of.
        let next = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Next: '")).firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 10), "No matter card says what is next.")
        for _ in 0..<3 where !next.isHittable { app.swipeUp() }
        if let shots = ProcessInfo.processInfo.environment["PANEL_SHOTS"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shots + "/pinned-date.png"))
        }
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label MATCHES '.*[0-9]+ open · [A-Z][a-z]+ [0-9]+.*'")).firstMatch.exists,
                      "The card's count has no day beside it.")
    }
}

