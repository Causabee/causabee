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

    /// Tasks with no day stand on the Digest too, the newest first; a tap opens the task's own
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

    /// ✓ keeps a new task as it is: off the card, and still in the matter's plan.
    func testANewTaskIsKept() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "-demo.filled", "anew", "-mail.auto", "NO", "--open", "Moving to Birch Road 12"]
        app.launch()
        let keep = app.buttons.matching(identifier: "new.keep")
        XCTAssertTrue(keep.firstMatch.waitForExistence(timeout: 40), "A new line has no ✓.")
        if let shots = ProcessInfo.processInfo.environment["PANEL_SHOTS"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shots + "/new-keep.png"))
        }
        let before = keep.count
        keep.firstMatch.tap()
        for _ in 0..<25 where keep.count >= before { Thread.sleep(forTimeInterval: 0.2) }
        XCTAssertEqual(keep.count, before - 1, "Kept, the line is still new.")
        app.buttons["part.Plan"].tap()
        let task = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Ask Ms. Adler'")).firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 8), "Kept, the task is not in the plan.")
    }

    /// A task with no day gets one in a tap — This week, Next week, Later — and leaves "No day yet".
    func testATaskWithNoDayGetsOneInATap() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "-demo.filled", "anew", "-mail.auto", "NO", "--open", "Care for Mum (Helga) after her fall"]
        app.launch()
        let chips = app.buttons.matching(identifier: "when.thisWeek")
        for _ in 0..<5 where !chips.firstMatch.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(chips.firstMatch.exists, "A task with no day has no “This week”.")
        for _ in 0..<4 where !chips.firstMatch.isHittable { app.swipeUp() }
        if let shots = ProcessInfo.processInfo.environment["PANEL_SHOTS"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shots + "/when-chips.png"))
        }
        let before = chips.count
        chips.firstMatch.tap()
        for _ in 0..<25 where chips.count >= before { Thread.sleep(forTimeInterval: 0.2) }
        XCTAssertLessThan(chips.count, before, "Given a day, the task is still under “No day yet”.")
    }

    /// Three tasks added in the chat, then given a day one after the other under "No day yet":
    /// each keeps its day — also after Causabee is opened again.
    func testEachTaskKeepsTheDayItWasGiven() {
        continueAfterFailure = false
        let app = XCUIApplication()
        let matter = "Moving to Birch Road 12"
        app.launchArguments = ["--demo", "-demo.filled", "anew", "-mail.auto", "NO", "--open", matter]
        app.launch()
        let stamp = String(Int(Date().timeIntervalSince1970) % 100_000)
        let words = ["Alpha \(stamp)", "Bravo \(stamp)", "Charlie \(stamp)"]
        let bee = app.buttons["bee"]
        XCTAssertTrue(bee.waitForExistence(timeout: 40), "The matter's page did not open.")
        bee.firstMatch.tap()
        for text in words {
            let pill = app.addPill("task")
            XCTAssertTrue(pill.exists, "No Task over the field.")
            pill.tap()
            let field = app.textFields["add.text"].exists ? app.textFields["add.text"] : app.textViews["add.text"]
            XCTAssertTrue(field.waitForExistence(timeout: 5), "The task's card has no field.")
            field.typeText(text)
            let take = app.buttons["add.take"]
            for _ in 0..<50 where !take.isEnabled { Thread.sleep(forTimeInterval: 0.2) }
            take.tap()
            for _ in 0..<25 where take.exists { Thread.sleep(forTimeInterval: 0.2) }
            if take.exists { take.tap() }
        }
        app.buttons["Close"].firstMatch.tap()
        // Each, by its own row: This week, Next week, Later.
        let whens = ["thisWeek", "nextWeek", "later"]
        for (text, when) in zip(words, whens) {
            let row = app.descendants(matching: .any).matching(identifier: "noDay.row").containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
            for _ in 0..<6 where !(row.exists && row.isHittable) { app.swipeUp() }
            if !row.exists, let shots = ProcessInfo.processInfo.environment["PANEL_SHOTS"] {
                try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shots + "/no-row.png"))
            }
            XCTAssertTrue(row.exists, "“\(text)” is not under “No day yet”.")
            row.buttons["when." + when].tap()
            for _ in 0..<25 where row.exists { Thread.sleep(forTimeInterval: 0.2) }
            XCTAssertFalse(row.exists, "Given a day, “\(text)” is still under “No day yet”.")
        }
        if let shots = ProcessInfo.processInfo.environment["PANEL_SHOTS"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shots + "/kept-days.png"))
        }
        // Opened again: each still has its day.
        app.terminate()
        app.launchArguments = ["--demo", "-mail.auto", "NO", "--open", matter]
        app.launch()
        XCTAssertTrue(app.buttons["bee"].waitForExistence(timeout: 40), "The matter did not open again.")
        Thread.sleep(forTimeInterval: 2)
        for text in words {
            let row = app.descendants(matching: .any).matching(identifier: "noDay.row").containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
            XCTAssertFalse(row.exists, "Opened again, “\(text)” lost its day.")
        }
    }

    /// A tap on the day of a task or a date on the Digest changes it, in its own editor — not Plan.
    func testTheDayOfADateOpensTheCalendar() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "-demo.filled", "anew", "-mail.auto", "NO", "--open", "Care for Mum (Helga) after her fall"]
        app.launch()
        let day = app.buttons["ahead.day"].firstMatch
        for _ in 0..<5 where !day.waitForExistence(timeout: 3) || !day.isHittable { app.swipeUp() }
        XCTAssertTrue(day.exists, "The Digest's days have no tappable day.")
        if let shots = ProcessInfo.processInfo.environment["PANEL_SHOTS"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shots + "/day-tile.png"))
        }
        day.tap()
        let calendar = app.datePickers["day.calendar"]
        XCTAssertTrue(calendar.waitForExistence(timeout: 5), "Tapped, the day did not open the calendar.")
        XCTAssertTrue(app.navigationBars["Change day"].exists, "The calendar is not the day's own.")
        // Another day of the month, then Set.
        let days = calendar.buttons.matching(NSPredicate(format: "label CONTAINS ', '"))
        let other = (0..<days.count).map { days.element(boundBy: $0) }.last { $0.isHittable && !$0.isSelected }
        XCTAssertNotNil(other, "The calendar shows no other day.")
        other?.tap()
        if let shots = ProcessInfo.processInfo.environment["PANEL_SHOTS"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shots + "/day-calendar.png"))
        }
        app.navigationBars["Change day"].buttons.element(boundBy: app.navigationBars["Change day"].buttons.count - 1).tap()
        XCTAssertTrue(calendar.waitForNonExistence(timeout: 5), "Set, the calendar stayed open.")
        XCTAssertFalse(app.buttons["part.Plan"].isSelected, "Tapped, the day went to Plan.")
    }

    func testWaitingForOthersSaysWhom() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "-demo.filled", "anew", "-mail.auto", "NO", "--open", "Care for Mum (Helga) after her fall"]
        app.launch()
        let plan = app.buttons["part.Plan"]
        XCTAssertTrue(plan.waitForExistence(timeout: 10))
        plan.tap()
        let heading = app.staticTexts["WAITING FOR OTHERS"]
        for _ in 0..<8 where !heading.exists || !heading.isHittable { app.swipeUp() }
        app.swipeUp()
        if let shots = ProcessInfo.processInfo.environment["PANEL_SHOTS"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shots + "/waiting-whom.png"))
        }
        XCTAssertTrue(heading.exists, "The plan shows nobody's task to wait for.")
    }
}
