import XCTest

/// Adding in the chat without Pro: the bee is yellow and opens the chat, Pro is offered on top, and
/// a task is typed in its own card and kept as written — nothing goes to an AI.
final class ChatAddTests: XCTestCase {
    private var app: XCUIApplication!
    /// Different at every run: what an earlier run added is still in the demo's store.
    private let stamp = String(Int(Date().timeIntervalSince1970) % 100_000)

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--demo", "-demo.filled", "anew", "-mail.auto", "NO", "--open", "Moving to Birch Road 12"]
        app.launch()
        let bee = app.buttons["bee"]
        XCTAssertTrue(bee.waitForExistence(timeout: 40), "The matter's page did not open.")
        bee.firstMatch.tap()
    }

    func testATaskTypedInItsCardWithoutPro() {
        XCTAssertTrue(app.buttons["pro.start"].waitForExistence(timeout: 10), "Without Pro, the chat does not offer Pro on top.")
        let chip = app.addPill("task")
        XCTAssertTrue(chip.exists, "Without Pro, there is no Task over the field.")
        chip.tap()
        let words = "Call the movers \(stamp)"
        let field = app.textFields["add.text"].exists ? app.textFields["add.text"] : app.textViews["add.text"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "The task's card has no field to type in.")
        field.typeText(words)
        // Add comes alive once the words are in the card: tapped before, it did nothing.
        let take = app.buttons["add.take"]
        for _ in 0..<50 where !take.isEnabled { Thread.sleep(forTimeInterval: 0.2) }
        take.tap()
        // The kept task's line is a button — a tap opens the task.
        let kept = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Task added")).firstMatch
        // The card rides up with the keyboard: a tap on its way there can miss, and the card stays.
        if !kept.waitForExistence(timeout: 5), take.exists { take.tap() }
        XCTAssertTrue(kept.waitForExistence(timeout: 10), "The task was not kept in the thread.")
        XCTAssertFalse(app.staticTexts["Claude Opus 5"].exists, "A task kept as typed names an AI that never saw it.")
        // In the matter too, as written: in its plan — the matter opens on its digest, which has
        // only the days ahead.
        app.buttons["Close"].firstMatch.tap()
        let plan = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Plan")).firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 10), "The matter has no Plan.")
        plan.tap()
        let task = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", words)).firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 10), "The task is not on the matter's page.")
    }
}

extension XCUIApplication {
    /// A pill of the panel over the chat's field — Task, Note, Link, Detail, Contact — the panel
    /// opened with the plus when it is not open already.
    func addPill(_ item: String) -> XCUIElement {
        let pill = buttons["add." + item]
        if pill.waitForExistence(timeout: 2) { return pill }
        let plus = buttons["assistant.plus"]
        if plus.waitForExistence(timeout: 8) { plus.tap() }
        _ = pill.waitForExistence(timeout: 5)
        return pill
    }
}
