import XCTest

/// "No matter found" on the overview: a tap shows what the bee read in an item — who sent it,
/// what it says, what she found, why no matter — and the owner decides right there.
final class NoMatterUITests: XCTestCase {
    private var app: XCUIApplication!

    private func launch() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--demo", "-demo.filled", "anew", "-mail.auto", "NO"]
        app.launch()
    }

    private func any(_ words: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", words)).firstMatch
    }

    /// The row of an item, scrolled to.
    private func row(_ title: String) -> XCUIElement {
        let row = app.buttons.matching(NSPredicate(format: "identifier == 'unplaced.row' AND label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(app.buttons["part.Matters"].waitForExistence(timeout: 40), "The overview did not come up.")
        for _ in 0..<8 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 10), "\(title) is not under No matter found.")
        return row
    }

    func testTheRowSaysWhoAndWhat() {
        launch()
        let line = row("Your bike is due for its service")
        XCTAssertTrue(line.label.contains("Velo Nord Workshop"), "The row does not say who sent it: \(line.label)")
        XCTAssertTrue(line.label.contains("yearly service"), "The row does not say what it is about: \(line.label)")
    }

    func testATapShowsWhatIsInIt() {
        launch()
        row("Your bike is due for its service").tap()
        XCTAssertTrue(app.staticTexts["unplaced.title"].waitForExistence(timeout: 10), "No sheet opened.")
        XCTAssertTrue(any("Slots are free next week").exists, "What it says is not shown.")
        XCTAssertTrue(any("Book a service slot").exists, "The task found in it is not shown.")
        XCTAssertTrue(any("Free slot at the workshop").exists, "The date found in it is not shown.")
        XCTAssertTrue(any("bike workshop").exists, "The person found in it is not shown.")
        XCTAssertTrue(any("none of the open matters").exists, "Why no matter is not shown.")
        XCTAssertTrue(app.buttons["unplaced.add"].exists && app.buttons["unplaced.aside"].exists, "The owner cannot decide from here.")
        if let path = ProcessInfo.processInfo.environment["SHOT_DIR"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: path).appendingPathComponent("unplaced-sheet.png"))
        }
    }

    func testOnlyWhatIsThere() {
        launch()
        row("Photos from Saturday").tap()
        XCTAssertTrue(app.staticTexts["unplaced.title"].waitForExistence(timeout: 10), "No sheet opened.")
        XCTAssertTrue(any("twelve photos").exists)
        XCTAssertFalse(any("Found in it").exists, "Found in it, with nothing found.")
    }

    func testNotNeededFromTheSheet() {
        launch()
        row("Photos from Saturday").tap()
        let aside = app.buttons["unplaced.aside"]
        XCTAssertTrue(aside.waitForExistence(timeout: 10))
        aside.tap()
        let gone = app.buttons.matching(NSPredicate(format: "identifier == 'unplaced.row' AND label CONTAINS 'Photos from Saturday'")).firstMatch
        XCTAssertTrue(gone.waitForNonExistence(timeout: 10), "Set aside, it is still in the list.")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == 'unplaced.row'")).firstMatch.exists, "The other item went too.")
    }

    func testAddToAMatterFromTheSheet() {
        launch()
        row("Your bike is due for its service").tap()
        let add = app.buttons["unplaced.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let new = app.buttons["A new matter"]
        XCTAssertTrue(new.waitForExistence(timeout: 5), "Add to … offers no new matter.")
        new.tap()
        let name = app.alerts.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5), "No name asked for the new matter.")
        XCTAssertEqual(name.value as? String, "Your bike is due for its service")
    }
}
