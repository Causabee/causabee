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

    /// The name stands after the window's controls and on their line — or in a column of its own,
    /// right of them.
    private func nameIsClear(_ state: String) {
        Thread.sleep(forTimeInterval: 0.8)
        let controls = thing("window.controls").frame, name = thing("matter.title").frame
        XCTAssertGreaterThanOrEqual(name.minX, controls.maxX + 8, "\(state): the matter's name begins under the window's controls.")
        // By its first line: a long name in a narrow column runs on under it.
        XCTAssertEqual(name.minY + 18, controls.midY, accuracy: 6, "\(state): the matter's name is not on the line of the window's controls.")
    }

    private var field: XCUIElement { app.textFields.matching(NSPredicate(format: "placeholderValue BEGINSWITH %@", "Ask about")).firstMatch }

    /// The assistant's column: brought in by the bee in the matter's corner, put away by its own ×.
    private func openAssistant() {
        guard !field.exists else { return }
        let bee = thing("window.bee")
        XCTAssertTrue(bee.waitForExistence(timeout: 5), "The bee is not in the matter's corner.")
        bee.click()
        XCTAssertTrue(field.waitForExistence(timeout: 5), "The assistant did not open.")
    }

    private func closeAssistant() {
        guard field.exists else { return }
        thing("assistant.close").click()
        XCTAssertTrue(thing("window.bee").waitForExistence(timeout: 5), "The assistant did not close: the bee is not back.")
    }

    func testTheNameIsNeverUnderTheControls() {
        let sidebar = thing("window.sidebar")
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5), "The window's controls are not there.")
        XCTAssertTrue(thing("matter.title").waitForExistence(timeout: 5), "The matter's name is not there.")
        openAssistant()
        keep("1-sidebar-open-assistant-open"); nameIsClear("Sidebar open, assistant open")
        // The matter is beside the sidebar, the assistant right of it.
        XCTAssertLessThan(thing("matter.title").frame.minX, field.frame.minX, "The matter is not left of the assistant.")
        closeAssistant()
        keep("2-sidebar-open-assistant-closed"); nameIsClear("Sidebar open, assistant closed")
        // The bee floats in the matter's lower right corner.
        let bee = thing("window.bee").frame, window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(bee.midX, window.midX, "The bee is not on the right.")
        XCTAssertGreaterThan(bee.midY, window.midY, "The bee is not at the bottom.")
        sidebar.click()
        Thread.sleep(forTimeInterval: 0.6)
        keep("4-sidebar-closed-assistant-closed"); nameIsClear("Sidebar closed, assistant closed")
        openAssistant()
        keep("3-sidebar-closed-assistant-open"); nameIsClear("Sidebar closed, assistant open")
    }

    /// The narrowest window: the page's column begins near the window's left edge, and its name
    /// would stand under the controls if it kept the page's margin.
    func testANarrowWindowKeepsTheNameClear() {
        let sidebar = thing("window.sidebar")
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5), "The window's controls are not there.")
        XCTAssertLessThan(app.windows.firstMatch.frame.width, 1000, "The window is not narrow: nothing would be tried.")
        closeAssistant()
        sidebar.click()
        keep("5-narrow-sidebar-closed-assistant-closed"); nameIsClear("Narrow, sidebar closed, assistant closed")
        let bar = thing("window.controls").frame.maxX, name = thing("matter.title").frame.minX
        XCTAssertLessThan(name, bar + 90, "The name is far from the controls: this window did not put it by them.")
        openAssistant()
        keep("6-narrow-sidebar-closed-assistant-open"); nameIsClear("Narrow, sidebar closed, assistant open")
    }
}
