import XCTest

/// Where the assistant's thread stands — the one rule, held to by measuring: the newest question
/// stands at the top of the thread, and stays there while the field under it grows and when the
/// next question is asked. What a screen recording showed by eye, these say in points.
final class ThreadTests: XCTestCase {
    private var app: XCUIApplication!
    private let stamp = String(Int(Date().timeIntervalSince1970) % 100_000)

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--demo"]
        app.launch()
        let matter = app.staticTexts["Care for Mum (Helga) after her fall"].firstMatch
        XCTAssertTrue(matter.waitForExistence(timeout: 20), "The demo's overview did not come up.")
        matter.tap()
        XCTAssertTrue(app.buttons["Ask Causabee"].waitForExistence(timeout: 10), "The matter's page did not open.")
        app.buttons["Ask Causabee"].firstMatch.tap()
    }

    private var field: XCUIElement {
        let single = app.textFields["assistant.field"]
        return single.waitForExistence(timeout: 5) ? single : app.textViews["assistant.field"]
    }

    /// "Task", from the plus, typed and sent: in the demo it is in the thread at once, without a key.
    private func addTask(_ words: String) {
        let add = app.buttons["assistant.plus"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 8), "The assistant has no plus.")
        add.tap()
        let entry = app.buttons["plus.task"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "The plus has no task.")
        entry.tap()
        field.tap()
        field.typeText(words)
        app.buttons["Send"].firstMatch.tap()
    }

    private func question(_ words: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", words)).firstMatch
    }

    /// Where a thing stands, once it has stopped moving.
    private func top(of element: XCUIElement) -> CGFloat {
        var last = element.frame.minY
        for _ in 0..<20 {
            Thread.sleep(forTimeInterval: 0.15)
            let now = element.frame.minY
            if abs(now - last) < 0.5 { return now }
            last = now
        }
        return last
    }

    func testTheNewestStandsAtTheTopAndStays() {
        let first = "First of \(stamp)", second = "Second of \(stamp)"
        addTask(first)
        let asked = question("New task: " + first)
        XCTAssertTrue(asked.waitForExistence(timeout: 8), "The question is not in the thread.")
        let header = app.staticTexts["Causabee"].firstMatch.frame.maxY
        let place = top(of: asked)
        // Right under the sheet's header, a little room between them.
        XCTAssertLessThan(place - header, 80, "The newest question does not stand at the top of the thread.")
        XCTAssertGreaterThan(place - header, 10, "The newest question stands under the header.")

        // The field grows by lines: the thread has less room, and the question keeps its place.
        field.tap()
        field.typeText(String(repeating: "more words to make the field grow ", count: 4))
        XCTAssertEqual(top(of: asked), place, accuracy: 1.5, "The question moved when the field grew.")
        // Emptied again, it is where it was.
        let typed = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: typed.count))
        XCTAssertEqual(top(of: asked), place, accuracy: 1.5, "The question did not come back when the field shrank.")

        // The next question takes that place, and the one before it goes up out of it.
        addTask(second)
        let next = question("New task: " + second)
        XCTAssertTrue(next.waitForExistence(timeout: 8), "The second question is not in the thread.")
        XCTAssertEqual(top(of: next), place, accuracy: 1.5, "The next question does not stand where the one before it stood.")
        XCTAssertLessThan(asked.frame.minY, place - 20, "The question before did not make room at the top.")
    }
}
