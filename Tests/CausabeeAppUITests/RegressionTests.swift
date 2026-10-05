import XCTest

/// What must work before a Mac release goes out: the things the owner does at the desk, on the
/// demo's made-up matters. Run by `scripts/mac-tests.sh`, which `scripts/release.sh` runs first —
/// nothing is built or published if one of them fails.
///
/// The app under test is started as the demo on a store made for each test, so the owner's matters
/// are never opened. It runs under Causabee's own identifier: the owner's Causabee is quit first.
final class RegressionTests: XCTestCase {
    private var app: XCUIApplication!
    private var folder: URL!
    private let stamp = String(Int(Date().timeIntervalSince1970) % 100_000)
    private let matter = "Care for Mum (Helga) after her fall"

    override func setUp() {
        continueAfterFailure = false
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("causabee-mac-tests-" + UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        app = XCUIApplication()
        // Everything by the environment, nothing among the arguments but `--demo`: a word there that is
        // no option — a path, a "NO" — is a file to open, to the Mac, and an app started to open a file
        // opens no window of its own.
        app.launchEnvironment["CAUSABEE_STORE"] = folder.appendingPathComponent("matters.store").path
        // The assistant's column shown and reading off, whatever the owner left; neither is kept.
        app.launchEnvironment["CAUSABEE_UI_TEST"] = "1"
        app.launchArguments = ["--demo"]
        app.launch()
        let row = app.staticTexts[matter].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30), "The demo's sidebar did not come up.")
        row.click()
        // The first start fills the demo's store while the window is already up: a click may come too early.
        if !element("matter.more").waitForExistence(timeout: 10) { row.click() }
        XCTAssertTrue(element("matter.more").waitForExistence(timeout: 20), "The matter's page did not open.")
    }

    override func tearDown() {
        app.terminate()
        try? FileManager.default.removeItem(at: folder)
    }

    /// Whatever kind SwiftUI made of it: a menu's button is one kind on one system, another on the next.
    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func tab(_ name: String) {
        let segment = app.radioButtons.matching(NSPredicate(format: "label BEGINSWITH %@ OR title BEGINSWITH %@", name, name)).firstMatch
        XCTAssertTrue(segment.waitForExistence(timeout: 5), "No tab \(name).")
        segment.click()
    }

    /// One of a menu's entries, by its words — the entry under that button, not the one of the same
    /// name in the menu bar's Matter menu.
    private func choose(_ words: String, from menu: String) {
        let button = element(menu)
        button.click()
        let entry = button.descendants(matching: .menuItem)[words].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "The menu has no “\(words)”.")
        entry.click()
    }

    private func field(_ id: String) -> XCUIElement {
        let single = app.textFields[id].firstMatch
        return single.waitForExistence(timeout: 5) ? single : app.textViews[id].firstMatch
    }

    private func type(_ words: String, into id: String, _ message: String) {
        let target = field(id)
        XCTAssertTrue(target.waitForExistence(timeout: 5), message)
        target.click()
        target.typeText(words)
    }

    private func shows(_ words: String, _ message: String) {
        let found = app.staticTexts.matching(NSPredicate(format: "value CONTAINS[c] %@ OR label CONTAINS[c] %@", words, words)).firstMatch
        XCTAssertTrue(found.waitForExistence(timeout: 8), message)
    }

    /// A button of what is open over the page — a popover, a sheet, a question — before one of the
    /// same name on the page: the assistant's cards have an "Add" too.
    private func press(_ title: String) {
        let over = [app.popovers, app.sheets, app.dialogs].map { $0.buttons[title].firstMatch }.first { $0.exists }
        let button = over ?? app.buttons[title].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "No button “\(title)”.")
        button.click()
    }

    func testTheFourTabs() {
        for name in ["Record", "People", "Notes", "To do"] { tab(name) }
        shows("Tasks", "Back on To do, the tasks are not shown.")
    }

    /// "Task", said to the assistant before it is typed: sent, it is a task at once, and in the list.
    func testATaskAddedStays() {
        let words = "Call the pharmacy \(stamp)"
        choose("Task", from: "assistant.plus")
        type(words, into: "assistant.field", "The assistant's field is not there.")
        app.typeKey(.return, modifierFlags: [])
        shows("Task added", "“Task” was picked and sent, and the thread does not say it was added.")
        let row = app.staticTexts.matching(NSPredicate(format: "value == %@ OR label == %@", words, words)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), "The task was added and is not in the list.")
    }

    /// The same for a note: kept word for word, with nothing asked.
    func testANoteAdded() {
        let words = "Mum prefers mornings \(stamp)"
        choose("Note", from: "assistant.plus")
        type(words, into: "assistant.field", "The assistant's field is not there.")
        app.typeKey(.return, modifierFlags: [])
        shows("Note added", "“Note” was picked and sent, and the thread does not say it was added.")
        tab("Notes")
        let note = app.staticTexts.matching(NSPredicate(format: "value == %@ OR label == %@", words, words)).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 8), "The note was added and is not among the notes.")
    }

    func testADetailAdded() {
        let value = "A 123 \(stamp)"
        choose("Add Detail …", from: "assistant.plus")
        type("Versichertennummer", into: "detail.label", "The detail's editor did not open.")
        type(value, into: "detail.value", "The detail's editor has no value field.")
        press("Add")
        // A detail's row is a button — a click copies it — that says its label and its value.
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), "The detail was added and is not in the record.")
    }

    func testAContactAddedByHand() {
        // In letters: a name that differs only in digits is the same contact, and would be found, not made.
        let letters = String(stamp.compactMap { $0.wholeNumberValue.map { Character(UnicodeScalar(UInt8(97 + $0))) } })
        let name = "Kasse " + letters
        choose("Add Contact …", from: "assistant.plus")
        type(name, into: "contact.name", "The contact's editor did not open.")
        type(letters + "@hkk.de", into: "contact.mail", "The contact's editor has no address field.")
        press("Add")
        shows(name, "The contact was added and is not under People.")
    }

    func testFindFindsAWord() {
        app.typeKey("f", modifierFlags: .command)
        app.typeText("physio")
        shows(" of ", "⌘F and a word of a task found nothing.")
    }

    /// Close sits behind ⋯, asks first, and the same menu opens the matter again.
    func testClosedAndOpenedAgain() {
        choose("Close Matter…", from: "matter.more")
        press("Leave them open and close")
        element("matter.more").click()
        let again = app.menuItems["Open Again"].firstMatch
        XCTAssertTrue(again.waitForExistence(timeout: 8), "A closed matter's ⋯ does not offer to open it again.")
        again.click()
        element("matter.more").click()
        XCTAssertTrue(app.menuItems["Close Matter…"].firstMatch.waitForExistence(timeout: 8), "Opened again, the matter cannot be closed.")
        app.typeKey(.escape, modifierFlags: [])
    }

    /// Merging asks before it merges; "Cancel" leaves both matters as they were.
    func testMergeAsksFirst() {
        let question = app.staticTexts.matching(NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", "into “Tax return 2025”", "into “Tax return 2025”")).firstMatch
        // A click into a submenu that is still opening can miss: asked for a second time, then.
        for _ in 1...2 where !question.exists {
            element("matter.more").click()
            let merge = app.menuItems["Merge with …"].firstMatch
            XCTAssertTrue(merge.waitForExistence(timeout: 5), "⋯ has no “Merge with …”.")
            merge.hover()
            let other = app.menuItems["Tax return 2025"].firstMatch
            XCTAssertTrue(other.waitForExistence(timeout: 5), "“Merge with …” does not list the other matters.")
            sleep(1)
            other.click()
            if !question.waitForExistence(timeout: 6) { app.typeKey(.escape, modifierFlags: []) }
        }
        XCTAssertTrue(question.exists, "Merging did not ask first.")
        press("Cancel")
        XCTAssertTrue(app.staticTexts[matter].firstMatch.exists, "After “Cancel”, the matter is gone.")
    }

    /// A click on "Find or start a matter" offers the matters opened last, before anything is typed —
    /// and the first letters typed put what is found in their place.
    func testTheFieldOffersTheLastMatters() {
        // The matter is open, so it is the last one opened: back on the overview, the field offers it.
        app.staticTexts["Overview"].firstMatch.click()
        let search = element("overview.search")
        XCTAssertTrue(search.waitForExistence(timeout: 8), "The overview has no field to find a matter.")
        search.click()
        shows("RECENT", "A click on the field did not bring the matters opened last.")
        let offered = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Care for Mum")).firstMatch
        XCTAssertTrue(offered.waitForExistence(timeout: 5), "The matter just opened is not among the last ones.")
        app.typeText("tax")
        let found = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Tax return 2025")).firstMatch
        XCTAssertTrue(found.waitForExistence(timeout: 5), "Typing did not put what is found in their place.")
    }
}
