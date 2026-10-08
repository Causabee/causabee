import XCTest

/// The window's top line is one row: the window's buttons, Causabee's controls by them, and then
/// what the first column begins with. With the sidebar and the assistant put away that is the
/// matter's name — after the bee, on its line, never under it. A picture of each of the four
/// combinations is kept with the test's result.
final class ToolbarTests: XCTestCase {
    private var app: XCUIApplication!
    private var folder: URL!
    private let matter = "Care for Mum (Helga) after her fall"

    override func setUp() {
        continueAfterFailure = true
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("causabee-mac-tests-" + UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        app = XCUIApplication()
        app.launchEnvironment["CAUSABEE_STORE"] = folder.appendingPathComponent("matters.store").path
        app.launchEnvironment["CAUSABEE_UI_TEST"] = "1"
        app.launchArguments = ["--demo"]
        // The window keeps its size from one start to the next: each test says its own.
        app.launchEnvironment["CAUSABEE_WINDOW_WIDTH"] = name.contains("Narrow") ? "960" : "1440"
        app.launch()
        let row = app.staticTexts[matter].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30), "The demo's sidebar did not come up.")
        row.click()
        let more = thing("matter.more")
        if !more.waitForExistence(timeout: 10) { row.click() }
        XCTAssertTrue(more.waitForExistence(timeout: 20), "The matter's page did not open.")
    }

    override func tearDown() {
        app.terminate()
        try? FileManager.default.removeItem(at: folder)
    }

    private func thing(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    private func keep(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        // In the test's result, to be taken out of it: `xcrun xcresulttool export attachments`.
        let picture = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        picture.name = name
        picture.lifetime = .keepAlways
        add(picture)
    }

    /// The name stands after the bee and on its line — or in a column of its own, right of both.
    /// The bee by its own 30 points: a moment after a click its label hangs under it and counts
    /// into its frame.
    private func nameIsClear(_ state: String) {
        Thread.sleep(forTimeInterval: 0.8)
        let bee = thing("window.bee").frame, name = thing("matter.title").frame
        XCTAssertGreaterThanOrEqual(name.minX, bee.minX + 30 + 8, "\(state): the matter's name begins under the window's controls.")
        // By its first line: a long name in a narrow column runs on under it.
        XCTAssertEqual(name.minY + 18, bee.minY + 15, accuracy: 6, "\(state): the matter's name is not on the line of the window's controls.")
    }

    func testTheNameIsNeverUnderTheControls() {
        let bee = thing("window.bee"), sidebar = thing("window.sidebar")
        XCTAssertTrue(bee.waitForExistence(timeout: 5) && sidebar.exists, "The window's controls are not there.")
        XCTAssertTrue(thing("matter.title").waitForExistence(timeout: 5), "The matter's name is not there.")
        // The assistant's column is open beside a matter, or not: the bee brings it to a known state.
        let field = app.textFields.matching(NSPredicate(format: "placeholderValue BEGINSWITH %@", "Ask about")).firstMatch
        if !field.exists { bee.click(); XCTAssertTrue(field.waitForExistence(timeout: 5), "The assistant did not open.") }
        keep("1-sidebar-open-assistant-open"); nameIsClear("Sidebar open, assistant open")
        bee.click()
        keep("2-sidebar-open-assistant-closed"); nameIsClear("Sidebar open, assistant closed")
        sidebar.click()
        Thread.sleep(forTimeInterval: 0.6)
        keep("4-sidebar-closed-assistant-closed"); nameIsClear("Sidebar closed, assistant closed")
        bee.click()
        XCTAssertTrue(field.waitForExistence(timeout: 5), "The assistant did not open.")
        keep("3-sidebar-closed-assistant-open"); nameIsClear("Sidebar closed, assistant open")
    }

    /// The narrowest window: the page's column begins near the window's left edge, and its name
    /// would stand under the controls if it kept the page's margin.
    func testANarrowWindowKeepsTheNameClear() {
        let bee = thing("window.bee"), sidebar = thing("window.sidebar")
        XCTAssertTrue(bee.waitForExistence(timeout: 5) && sidebar.exists, "The window's controls are not there.")
        XCTAssertLessThan(app.windows.firstMatch.frame.width, 1000, "The window is not narrow: nothing would be tried.")
        let field = app.textFields.matching(NSPredicate(format: "placeholderValue BEGINSWITH %@", "Ask about")).firstMatch
        if field.exists { bee.click() }
        sidebar.click()
        keep("5-narrow-sidebar-closed-assistant-closed"); nameIsClear("Narrow, sidebar closed, assistant closed")
        let bar = bee.frame.minX + 30, name = thing("matter.title").frame.minX
        XCTAssertLessThan(name, bar + 90, "The name is far from the controls: this window did not put it by them.")
        bee.click()
        keep("6-narrow-sidebar-closed-assistant-open"); nameIsClear("Narrow, sidebar closed, assistant open")
    }
}
