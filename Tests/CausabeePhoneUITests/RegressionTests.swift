import XCTest

/// What must work before a build goes to TestFlight: the things the owner does at the table, on the
/// demo's made-up matters. Run by `scripts/testflight.sh`, which uploads nothing if one of them fails.
///
///   xcodebuild test -project App/Causabee.xcodeproj -scheme CausabeePhoneUITests -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
final class RegressionTests: XCTestCase {
    private var app: XCUIApplication!
    /// Different at every run: what an earlier run added is still in the demo's store.
    private let stamp = String(Int(Date().timeIntervalSince1970) % 100_000)

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // The letter test is handed a letter as the camera would bring it.
        // Auto off, whatever this simulator was left with: with it on, a letter is read at once
        // and nothing waits for "Sort in".
        app.launchArguments = (name.contains("Letter") ? ["--demo", "--shot", "letter"] : ["--demo"]) + ["-mail.auto", "NO"]
        app.launch()
        let matter = app.staticTexts["Care for Mum (Helga) after her fall"].firstMatch
        XCTAssertTrue(matter.waitForExistence(timeout: 20), "The demo's overview did not come up.")
        matter.tap()
        if name.contains("Letter") { return }
        XCTAssertTrue(app.buttons["Ask Causabee"].waitForExistence(timeout: 10), "The matter's page did not open.")
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

    /// What is added goes in by the assistant: its bee, then the plus beside its field.
    private func plus(_ item: String) {
        app.buttons["Ask Causabee"].firstMatch.tap()
        let add = app.buttons["assistant.plus"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 8), "The assistant has no plus.")
        add.tap()
        let entry = app.buttons["plus." + item]
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "The plus has no \(item).")
        entry.tap()
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

    func testTheFourTabs() {
        for name in ["Record", "People", "Notes", "To do"] { tab(name) }
        shows("Tasks", "Back on To do, the tasks are not shown.")
    }

    func testATaskAddedStays() {
        let words = "Call the pharmacy \(stamp)"
        // "Task", said to the assistant before it is typed: sent, it is a task at once.
        plus("task")
        let text = field("assistant.field")
        XCTAssertTrue(text.waitForExistence(timeout: 5), "The assistant's field is not there.")
        text.tap()
        text.typeText(words)
        app.buttons["Send"].firstMatch.tap()
        // Its card in the thread is one thing to the screen reader: the words and "Task added".
        let card = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Task added")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 8), "“Task” was picked and sent, and the thread does not say it was added.")
        // And it is in the matter's list, under the assistant's sheet.
        app.buttons["Close"].firstMatch.tap()
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", words)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), "The task was added and is not in the list.")
    }

    func testAContactAddedByHand() {
        // In letters: a name that differs only in digits is the same contact, and would be found, not made.
        // The same holds for the address: one address is one contact.
        let letters = String(stamp.compactMap { $0.wholeNumberValue.map { Character(UnicodeScalar(UInt8(97 + $0))) } })
        let name = "Kasse " + letters, address = letters + "@hkk.de"
        plus("contact")
        let nameField = field("contact.name")
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "The contact's editor did not open.")
        nameField.tap()
        nameField.typeText(name)
        let mail = field("contact.mail")
        mail.tap()
        mail.typeText(address)
        app.buttons["Add"].firstMatch.tap()
        shows(name, "The contact was added and is not under People.")
        shows(address, "The contact's address is not shown.")
    }

    func testADetailAdded() {
        let value = "A 123 \(stamp)"
        plus("detail")
        let label = field("detail.label")
        XCTAssertTrue(label.waitForExistence(timeout: 5), "The detail's editor did not open.")
        label.tap()
        label.typeText("Versichertennummer")
        let valueField = field("detail.value")
        valueField.tap()
        valueField.typeText(value)
        app.buttons["Add"].firstMatch.tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), "The detail was added and is not in the record.")
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
        app.buttons["Ask Causabee"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Speak"].waitForExistence(timeout: 8), "The assistant did not open with its field.")
    }
}
