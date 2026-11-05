import XCTest

/// What must work before a build goes to TestFlight: the things the owner does at the table, on the
/// demo's made-up matters. Run by `scripts/testflight.sh`, which uploads nothing if one of them fails.
///
///   xcodebuild test -project App/Causabee.xcodeproj -scheme CausabeePhoneUITests -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
final class RegressionTests: XCTestCase {
    /// The overview opens on its journal; the matters are one filter away.
    private func showMatters() {
        let filter = app.buttons["part.Matters"]
        if filter.waitForExistence(timeout: 40) { filter.tap() }
    }

    private var app: XCUIApplication!
    /// Different at every run: what an earlier run added is still in the demo's store.
    private let stamp = String(Int(Date().timeIntervalSince1970) % 100_000)

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // The letter test is handed a letter as the camera would bring it.
        // Pro off for the letter, whatever this simulator was left with: with it on, a letter is
        // read at once and nothing waits for "Sort in". On for the rest: the bee opens the chat
        // only with Pro on — grey, it says what Pro adds.
        app.launchArguments = name.contains("Letter") ? ["--demo", "--shot", "letter", "-mail.auto", "NO"] : ["--demo", "-mail.auto", "YES"]
        // Setting a day stays in the demo's store: filled anew, the task is undated again.
        if name.contains("SetDay") { app.launchArguments += ["-demo.filled", "anew"] }
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

    /// A photo brought in on a matter opens the assistant, is read, and offers what it found: its
    /// task, who wrote, and the number it is filed under. Taken in, the contact is in People.
    func testALetterOffersItsTaskContactAndDetail() {
        let sort = app.buttons["Sort in"]
        XCTAssertTrue(sort.waitForExistence(timeout: 30), "The letter was not read, or the assistant did not open with it.")
        sort.tap()
        shows("Contact: HKK", "The letter's sender was not offered as a contact.")
        shows("reha@hkk.de", "The contact was offered without its address.")
        shows("Versichertennummer: A123456789", "The membership number was not offered as a detail.")
        shows("Answer", "The letter's task was not offered.")
        app.buttons["Take in"].tap()
        shows("Taken into", "The letter was not taken into the matter.")
    }

    private func tab(_ name: String) {
        let segment = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(segment.waitForExistence(timeout: 5), "No tab \(name).")
        segment.tap()
    }

    /// The forms, where they still are: held on the bee, its menu offers what can be added, and
    /// each opens its own editor on the page.
    private func held(_ item: String) {
        let bee = app.buttons["bee"].firstMatch
        XCTAssertTrue(bee.waitForExistence(timeout: 8), "The matter's page has no bee.")
        bee.press(forDuration: 1.0)
        let entry = app.buttons["plus." + item]
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "Held, the bee offers no \(item).")
        entry.tap()
    }

    /// In the chat: its chip over the field, and the card that comes for it, typed in and added.
    private func chip(_ item: String, _ first: String, _ second: String) {
        app.buttons["bee"].firstMatch.tap()
        let chip = app.buttons["add." + item]
        XCTAssertTrue(chip.waitForExistence(timeout: 8), "The chat has no \(item) over its field.")
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
        for name in ["Digest", "Mail", "Files", "People", "Notes", "Plan"] { tab(name) }
        shows("WAITING FOR OTHERS", "Back on Plan, the plan is not shown.")
    }

    /// No ⋯ on the iPhone: a task's and a date's menu is their long press, the same four on top.
    func testARowsMenuIsItsLongPress() {
        tab("Plan")
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

    /// "Set day" where an undated task's day would stand: a day picked, the task leaves No day yet.
    func testSetDayGivesATaskItsDay() {
        tab("Plan")
        let tile = app.buttons["Set a day for Find help with shopping"].firstMatch
        for _ in 0..<4 where !tile.isHittable { app.swipeUp() }
        XCTAssertTrue(tile.waitForExistence(timeout: 8), "The undated task has no “Set day”.")
        tile.tap()
        let set = app.buttons["Set"].firstMatch
        XCTAssertTrue(set.waitForExistence(timeout: 5), "“Set day” opened no calendar.")
        set.tap()
        XCTAssertTrue(tile.waitForNonExistence(timeout: 8), "A day was set and the task still has none.")
    }

    func testATaskAddedStays() {
        let words = "Call the pharmacy \(stamp)"
        // "Task" held on the bee opens the task's own editor: added, it is in the list.
        held("task")
        let text = field("task.text")
        XCTAssertTrue(text.waitForExistence(timeout: 5), "“Task” was picked and its editor did not open.")
        text.tap()
        text.typeText(words)
        app.buttons["Add"].firstMatch.tap()
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", words)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), "The task was added and is not in the list.")
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
        tab("People")
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
        tab("Notes")
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
