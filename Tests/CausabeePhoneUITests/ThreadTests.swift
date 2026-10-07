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
        // The demo filled anew at every start: what an earlier run asked is not in the thread.
        // `--answers`: a question gets a made-up answer after a moment, with nothing sent.
        app.launchArguments = ["--demo", "--answers", "-demo.filled", "anew"]
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

    /// Sources unfolded under the newest answer, and folded again: the answer grows and shrinks
    /// downwards, and its question does not move by a point.
    func testSourcesUnfoldingLeavesTheQuestionWhereItIs() {
        let asked = question("What do I need to do before")
        XCTAssertTrue(asked.waitForExistence(timeout: 8), "The demo's question is not in the thread.")
        let place = top(of: asked)
        let sources = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Sources")).firstMatch
        XCTAssertTrue(sources.waitForExistence(timeout: 5), "The answer has no sources to unfold.")
        sources.tap()
        XCTAssertEqual(top(of: asked), place, accuracy: 0.5, "The question moved when its sources unfolded.")
        sources.tap()
        XCTAssertEqual(top(of: asked), place, accuracy: 0.5, "The question moved when its sources folded.")
        // Unfolded, the answer may reach under the edge, and the button offers the way down; folded
        // again it is all there, and nothing is offered.
        XCTAssertFalse(app.buttons["thread.toNewest"].waitForExistence(timeout: 1), "The way back shows though the thread is at its newest, all of it in sight.")
    }

    private func ask(_ words: String) {
        field.tap()
        field.typeText(words)
        app.buttons["Send"].firstMatch.tap()
    }

    private var header: CGFloat { app.staticTexts["Causabee"].firstMatch.frame.maxY }

    /// A question goes to the top, and its answer comes in under it: the question does not move
    /// when the answer arrives, and nothing offers a way "back" — the thread is where it should be.
    func testAnAnswerComesInUnderItsQuestion() {
        ask("Who has the spare key?")
        let asked = question("Who has the spare key?")
        XCTAssertTrue(asked.waitForExistence(timeout: 8), "The question is not in the thread.")
        let place = top(of: asked)
        XCTAssertLessThan(place - header, 80, "The question just asked does not stand at the top of the thread.")
        let answer = question("the key is kept at number 4")
        XCTAssertTrue(answer.waitForExistence(timeout: 15), "No answer came.")
        XCTAssertEqual(top(of: asked), place, accuracy: 1, "The question moved when its answer came.")
        XCTAssertGreaterThan(answer.frame.minY, asked.frame.maxY, "The answer is not under its question.")
        XCTAssertFalse(app.buttons["thread.toNewest"].exists, "The way back shows though the thread is at its newest.")
    }

    /// An answer longer than the screen is read from its beginning: its question stays on top.
    func testALongAnswerIsReadFromItsBeginning() {
        ask("Give me the long version")
        let asked = question("Give me the long version")
        XCTAssertTrue(asked.waitForExistence(timeout: 8), "The question is not in the thread.")
        let place = top(of: asked)
        XCTAssertTrue(question("Point 14").waitForExistence(timeout: 15), "No answer came.")
        XCTAssertEqual(top(of: asked), place, accuracy: 1, "The question moved when its long answer came.")
    }

    /// The keyboard coming up over an answer longer than the screen shows its end, right over the
    /// field — that is what is being answered; going, it gives the beginning back.
    func testTheKeyboardShowsTheEndOfALongAnswer() {
        ask("Give me the long version")
        let asked = question("Give me the long version")
        XCTAssertTrue(asked.waitForExistence(timeout: 8), "The question is not in the thread.")
        let last = question("Point 14")
        XCTAssertTrue(last.waitForExistence(timeout: 15), "No answer came.")
        // The keyboard goes with a tap on the thread: the answer from its beginning, under its question.
        question("Point 2").tap()
        let place = top(of: asked)
        XCTAssertLessThan(place - header, 80, "Without the keyboard, the long answer is not shown from its question.")
        // It comes: the answer's end stands over the field.
        field.tap()
        _ = top(of: last)
        XCTAssertLessThan(last.frame.maxY, field.frame.minY, "With the keyboard up, the end of the answer is not over the field.")
        XCTAssertGreaterThan(last.frame.minY, header, "With the keyboard up, the end of the answer is not on the screen.")
        // It goes: the beginning again.
        last.tap()
        XCTAssertEqual(top(of: asked), place, accuracy: 1.5, "The keyboard gone, the answer is not back at its question.")
    }

    /// The thread scrolled by hand while the answer is on its way: it stays where it is being read,
    /// the button says an answer came, and takes the reader to its question.
    func testAThreadBeingReadStaysAndSaysAnAnswerCame() {
        ask("Who has the spare key?")
        let asked = question("Who has the spare key?")
        XCTAssertTrue(asked.waitForExistence(timeout: 8), "The question is not in the thread.")
        let place = top(of: asked)
        // Back into what came before.
        let before = question("What do I need to do before")
        let finger = asked.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        finger.press(forDuration: 0.05, thenDragTo: finger.withOffset(CGVector(dx: 0, dy: 260)))
        XCTAssertTrue(before.waitForExistence(timeout: 5), "The thread did not scroll back.")
        let read = top(of: before)
        let back = app.buttons["thread.toNewest"]
        XCTAssertTrue(back.waitForExistence(timeout: 12), "Scrolled away from the newest, there is no way back.")
        // The answer comes: what is being read stays, and the button says so.
        var said = false
        for _ in 0..<60 where !said { said = back.label == "To the new answer"; if !said { Thread.sleep(forTimeInterval: 0.2) } }
        XCTAssertTrue(said, "An answer came while the thread was being read, and the button does not say so.")
        XCTAssertEqual(top(of: before), read, accuracy: 1, "The thread moved under the reader when the answer came.")
        back.tap()
        XCTAssertEqual(top(of: asked), place, accuracy: 1.5, "The button did not bring the question back to the top.")
        XCTAssertTrue(question("the key is kept at number 4").exists, "The answer is not under its question.")
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
