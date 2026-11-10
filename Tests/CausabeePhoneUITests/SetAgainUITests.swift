import XCTest

/// A date set in the chat and changed back since: its receipt says so and offers "Set again" — and
/// a tap sets it again, with the app still there (10 November: a tap closed the app).
@MainActor
final class SetAgainUITests: XCTestCase {
    func testSetAgainSetsTheDateAgain() throws { try setAgain(relaunch: false) }
    func testSetAgainAfterTheAppOpenedAgain() throws { try setAgain(relaunch: true) }

    private func setAgain(relaunch: Bool) throws {
        let day = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.dateFormat = "yyyy-MM-dd"
        let due = format.string(from: day)
        func turn(_ question: String, time: String, end: String?) -> [String: Any] {
            var card = ["kind": "change_date", "text": "Test drive VW ID.3", "todo": "A1", "due": due, "time": time,
                        "reason": "Said in the chat.", "cites": "A1"]
            card["end_time"] = end
            return ["question": question, "lines": ["The test drive is set.  [A1]"], "cards": [card]]
        }
        let answers = [["id": "set-again", "turns": [turn("Probefahrt 14:30 bis 17:30", time: "14:30", end: "17:30"),
                                                     turn("Probefahrt doch um 10", time: "10:00", end: nil)]]]
        let path = NSTemporaryDirectory() + "set-again-\(UUID().uuidString).json"
        try JSONSerialization.data(withJSONObject: answers).write(to: URL(fileURLWithPath: path))

        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--answers", "-demo.filled", "anew", "-mail.auto", "YES", "-answers.recorded", path,
                               "-answers.after", "0.3", "--open", "next-car"]
        app.launch()
        let receipt = app.buttons["receipt.close"]
        if receipt.waitForExistence(timeout: 6) { receipt.tap() }
        let bee = app.buttons["bee"].firstMatch
        XCTAssertTrue(bee.waitForExistence(timeout: 30), "The matter did not open.")
        bee.tap()

        func ask(_ question: String) {
            let single = app.textFields["assistant.field"]
            let field = single.waitForExistence(timeout: 5) ? single : app.textViews["assistant.field"]
            field.tap()
            field.typeText(question)
            app.buttons["Send"].firstMatch.tap()
            let change = app.buttons["Change date"].firstMatch
            XCTAssertTrue(change.waitForExistence(timeout: 15), "No card for “\(question)”.")
            change.tap()
        }
        ask("Probefahrt 14:30 bis 17:30")
        ask("Probefahrt doch um 10")

        // As on the owner's iPhone: the app opened again later, the thread read back from the store.
        if relaunch {
            app.terminate()
            app.launchArguments = ["--demo", "--answers", "-mail.auto", "YES", "-answers.recorded", path, "--open", "next-car"]
            app.launch()
            if receipt.waitForExistence(timeout: 6) { receipt.tap() }
            XCTAssertTrue(bee.waitForExistence(timeout: 30), "The matter did not open again.")
            bee.tap()
        }

        let again = app.buttons["receipt.again"].firstMatch
        XCTAssertTrue(again.waitForExistence(timeout: 10), "The first card does not say it was changed back.")
        again.tap()
        Thread.sleep(forTimeInterval: 2)
        XCTAssertEqual(app.state, .runningForeground, "Set again closed the app.")
        let kinds = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "Date changed", "Changed back"))
            .allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(kinds.contains { $0.contains("Date changed") && $0.contains("14:30–17:30") },
                      "After Set again: \(kinds)")
    }
}
