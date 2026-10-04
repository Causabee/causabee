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
        app.launchArguments = ["--demo"]
        app.launch()
        let matter = app.staticTexts["Care for Mum (Helga) after her fall"].firstMatch
        XCTAssertTrue(matter.waitForExistence(timeout: 20), "The demo's overview did not come up.")
        matter.tap()
        XCTAssertTrue(app.buttons["matter.plus"].waitForExistence(timeout: 10), "The matter's page did not open.")
    }

    private func tab(_ name: String) {
        let segment = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(segment.waitForExistence(timeout: 5), "No tab \(name).")
        segment.tap()
    }

    private func plus(_ item: String) {
        app.buttons["matter.plus"].tap()
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
        plus("task")
        let text = field("task.text")
        XCTAssertTrue(text.waitForExistence(timeout: 5), "The new task's editor did not open.")
        text.tap()
        text.typeText(words)
        // Long enough for anything that redraws the page under the editor to have done so.
        sleep(6)
        app.buttons["Add"].firstMatch.tap()
        shows(words, "The task was typed and added, and is not in the list.")
    }

    func testAContactAddedByHand() {
        let name = "HKK \(stamp)"
        plus("contact")
        let nameField = field("contact.name")
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "The contact's editor did not open.")
        nameField.tap()
        nameField.typeText(name)
        let mail = field("contact.mail")
        mail.tap()
        mail.typeText("reha@hkk.de")
        app.buttons["Add"].firstMatch.tap()
        shows(name, "The contact was added and is not under People.")
        shows("reha@hkk.de", "The contact's address is not shown.")
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
