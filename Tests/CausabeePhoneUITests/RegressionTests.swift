import XCTest

/// What must work before a build goes to TestFlight: the things the owner does at the table, on the
/// demo's made-up matters. Run by `scripts/testflight.sh`, which uploads nothing if one of them fails.
///
///   xcodebuild test -project App/Causabee.xcodeproj -scheme CausabeePhoneUITests -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
final class RegressionTests: XCTestCase {
    /// The overview opens on its journal; the matters are one filter away.
    private func showMatters() {
        let filter = app.buttons["overview.matters"]
        if filter.waitForExistence(timeout: 40) { filter.tap() }
    }

    private var app: XCUIApplication!
    /// Different at every run: what an earlier run added is still in the demo's store.
    private let stamp = String(Int(Date().timeIntervalSince1970) % 100_000)

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // The letter test is handed a letter as the camera would bring it.
        // Pro off for the letter, whatever this simulator was left with: it sorts itself in either
        // way, read on the device. On for the rest: the bee opens the chat only with Pro on — grey,
        // it says what Pro adds.
        app.launchArguments = name.contains("Letter") ? ["--demo", "--shot", "letter", "-mail.auto", "NO"] : ["--demo", "-mail.auto", "YES"]
        // Setting a day stays in the demo's store: filled anew, the task is undated again.
        // So is "Seen" on the news: filled anew, the news is new again.
        if name.contains("SetDay") || name.contains("Comment") { app.launchArguments += ["-demo.filled", "anew"] }
        app.launch()
        if !name.contains("Letter") {
            // With Pro on, the demo sorts its new mail in a moment after it opens, and what it sorted
            // stands on top of the overview, pushing the matters down while the test looks for one.
            let receipt = app.buttons["receipt.close"]
            if receipt.waitForExistence(timeout: 8) { receipt.tap() }
        }
        showMatters()
        let matter = app.staticTexts["Care for Mum (Helga) after her fall"].firstMatch
        XCTAssertTrue(matter.waitForExistence(timeout: 20), "The demo's overview did not come up.")
        matter.tap()
        if name.contains("Letter") { return }
        XCTAssertTrue(app.buttons["bee"].waitForExistence(timeout: 10), "The matter's page did not open.")
    }

    /// A photo brought in on a matter opens the assistant and sorts itself into that matter — no
    /// "Sort in", no "Take in" — and one line says what it brought: its task, who wrote, and the
    /// number it is filed under. Undo takes it all back out.
    func testALetterSortsItselfIn() {
        let line = app.otherElements["taken.line"].firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 40), "The letter was not sorted in by itself, or the assistant did not open with it.")
        XCTAssertFalse(app.buttons["Sort in"].exists, "The letter still waits for “Sort in”.")
        shows("Answer", "The line does not say the letter's task.")
        shows("Contact: HKK", "The line does not say who wrote.")
        shows("Versichertennummer: A123456789", "The line does not say the membership number.")
        if let shots = ProcessInfo.processInfo.environment["PANEL_SHOTS"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shots + "/taken-line.png"))
        }
        XCTAssertTrue(app.buttons["taken.change"].exists, "The line has no Change.")
        let undo = app.buttons["taken.undo"]
        XCTAssertTrue(undo.exists, "The line has no Undo.")
        undo.tap()
        XCTAssertTrue(line.waitForNonExistence(timeout: 5), "Undo did not take the letter back out.")
    }

    /// By the part's own name — "plan", "notes" — never by the word on the pill: that word is the
    /// device's language (F009).
    private func tab(_ name: String) {
        let segment = app.buttons["part." + name]
        XCTAssertTrue(segment.waitForExistence(timeout: 5), "No tab \(name).")
        segment.tap()
    }

    /// In the chat: its pill in the panel over the field, and the card that comes for it, typed in and added.
    private func chip(_ item: String, _ first: String, _ second: String) {
        app.buttons["bee"].firstMatch.tap()
        let chip = app.addPill(item)
        XCTAssertTrue(chip.exists, "The chat has no \(item) over its field.")
        chip.tap()
        let one = field("add.text")
        XCTAssertTrue(one.waitForExistence(timeout: 5), "The \(item)'s card has no field.")
        // Return goes on to the second field, as one types it.
        one.typeText(first + "\n")
        let two = field("add.second")
        XCTAssertTrue(two.waitForExistence(timeout: 5), "The \(item)'s card has no second field.")
        for _ in 0..<25 where !(two.value(forKey: "hasKeyboardFocus") as? Bool ?? false) { Thread.sleep(forTimeInterval: 0.2) }
        if !(two.value(forKey: "hasKeyboardFocus") as? Bool ?? false) { two.tap() }
        two.typeText(second)
        let take = app.buttons["add.take"]
        for _ in 0..<50 where !take.isEnabled { Thread.sleep(forTimeInterval: 0.2) }
        take.tap()
    }

    /// A field by its identifier, whichever kind SwiftUI made of it.
    private func field(_ id: String) -> XCUIElement {
        let single = app.textFields[id]
        return single.waitForExistence(timeout: 5) ? single : app.textViews[id]
    }

    private func shows(_ words: String, _ message: String) {
        let found = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", words)).firstMatch
        XCTAssertTrue(found.waitForExistence(timeout: 8), message)
    }

    func testTheFilters() {
        for name in ["all", "mail", "files", "people", "notes", "plan"] { tab(name) }
        shows("WAITING FOR OTHERS", "Back on Plan, the plan is not shown.")
    }

    /// No ⋯ on the iPhone: a task's and a date's menu is their long press, the same four on top.
    func testARowsMenuIsItsLongPress() {
        tab("plan")
        for words in ["Physio", "Agree who is with Mum when"] {
            let row = app.staticTexts[words].firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 8), "“\(words)” is not on the plan.")
            row.press(forDuration: 1.2)
            let chat = app.buttons["Use in Chat"].firstMatch
            XCTAssertTrue(chat.waitForExistence(timeout: 5), "Held, “\(words)” opened no menu.")
            XCTAssertTrue(app.buttons["Connect …"].exists, "“\(words)”'s menu has no Connect.")
            // Away again, as one would: a tap outside the menu.
            let away = app.otherElements["PopoverDismissRegion"].firstMatch
            if away.exists { away.tap() } else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.92)).tap() }
            XCTAssertTrue(chat.waitForNonExistence(timeout: 5), "“\(words)”'s menu did not close.")
        }
    }

    /// No "Comment" line under a yellow card on the iPhone: held, the news offers it, and it opens
    /// the field for the few words.
    func testAYellowCardsCommentIsItsLongPress() {
        tab("all")
        let chip = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "NEW")).firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "The Digest has no news.")
        XCTAssertFalse(app.buttons["tile.comment"].exists, "“Comment” still stands under the card.")
        chip.press(forDuration: 1.2)
        let comment = app.buttons["tile.comment"].firstMatch
        XCTAssertTrue(comment.waitForExistence(timeout: 5), "Held, the news offers no “Comment”.")
        comment.tap()
        XCTAssertTrue(app.descendants(matching: .any)["comment.field"].waitForExistence(timeout: 5), "“Comment” opened no field.")
    }

    /// "Set day" where an undated task's day would stand: a day picked, the task leaves No day yet.
    func testSetDayGivesATaskItsDay() {
        tab("plan")
        let tile = app.buttons["Set a day for Find help with shopping"].firstMatch
        for _ in 0..<4 where !tile.isHittable { app.swipeUp() }
        XCTAssertTrue(tile.waitForExistence(timeout: 8), "The undated task has no “Set day”.")
        tile.tap()
        let set = app.buttons["Set"].firstMatch
        XCTAssertTrue(set.waitForExistence(timeout: 5), "“Set day” opened no calendar.")
        set.tap()
        XCTAssertTrue(tile.waitForNonExistence(timeout: 8), "A day was set and the task still has none.")
    }

    func testAContactAddedByHand() {
        // In letters: a name that differs only in digits is the same contact, and would be found, not made.
        // The same holds for the address: one address is one contact.
        let letters = String(stamp.compactMap { $0.wholeNumberValue.map { Character(UnicodeScalar(UInt8(97 + $0))) } })
        let name = "Kasse " + letters, role = "Insurer " + letters
        // Its card in the chat: the name, and what they are to the matter.
        chip("contact", name, role)
        let kept = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Contact saved")).firstMatch
        XCTAssertTrue(kept.waitForExistence(timeout: 10), "The contact was not saved from its card.")
        app.buttons["Close"].firstMatch.tap()
        tab("people")
        shows(name, "The contact was added and is not under People.")
    }

    func testADetailAdded() {
        let value = "A 123 \(stamp)"
        // Its card in the chat: what it is, and what it says.
        chip("detail", "Versichertennummer", value)
        let kept = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Detail saved")).firstMatch
        XCTAssertTrue(kept.waitForExistence(timeout: 10), "The detail was not saved from its card.")
    }

    func testANoteAdded() {
        let words = "Mum prefers mornings \(stamp)"
        tab("notes")
        let note = field("note.field")
        XCTAssertTrue(note.waitForExistence(timeout: 5), "The notes have no field.")
        note.tap()
        note.typeText(words)
        app.buttons["note.add"].tap()
        shows(words, "The note was added and is not shown.")
    }

    func testTheAssistantOpens() {
        app.buttons["bee"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Speak"].waitForExistence(timeout: 8), "The assistant did not open with its field.")
    }
}
