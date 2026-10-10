import XCTest

/// Where the Mac's assistant thread stands — the iPhone's rule, held to by measuring: the newest
/// question stands at the top of the column, under the window's top line, and sources unfolding
/// under its answer do not move it.
final class ThreadTests: XCTestCase {
    private var app: XCUIApplication!
    private var folder: URL!
    private let matter = "Care for Mum (Helga) after her fall"

    override func setUp() {
        continueAfterFailure = false
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("causabee-mac-tests-" + UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        app = XCUIApplication()
        app.launchEnvironment["CAUSABEE_STORE"] = folder.appendingPathComponent("matters.store").path
        app.launchEnvironment["CAUSABEE_UI_TEST"] = "1"
        app.launchArguments = ["--demo"]
        app.launch()
        let row = app.staticTexts[matter].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30), "The demo's sidebar did not come up.")
        row.click()
        let more = app.descendants(matching: .any).matching(identifier: "matter.more").firstMatch
        if !more.waitForExistence(timeout: 10) { row.click() }
        XCTAssertTrue(more.waitForExistence(timeout: 20), "The matter's page did not open.")
    }

    override func tearDown() {
        app.terminate()
        try? FileManager.default.removeItem(at: folder)
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

    func testTheNewestStandsAtTheTopAndSourcesLeaveItThere() {
        let asked = app.staticTexts.matching(NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", "What do I need to do before", "What do I need to do before")).firstMatch
        XCTAssertTrue(asked.waitForExistence(timeout: 10), "The demo's question is not in the thread.")
        let window = app.windows.firstMatch.frame
        let place = top(of: asked)
        // Under the window's top line, and not far under it.
        XCTAssertGreaterThan(place - window.minY, 40, "The newest question stands under the window's buttons.")
        XCTAssertLessThan(place - window.minY, 120, "The newest question does not stand at the top of the thread.")
        let sources = app.buttons.matching(NSPredicate(format: "title BEGINSWITH %@ OR label BEGINSWITH %@", "Sources", "Sources")).firstMatch
        XCTAssertTrue(sources.waitForExistence(timeout: 5), "The answer has no sources to unfold.")
        // Asked before the sources unfold: in a low window they run past the thread's end, and the
        // button down to the answer's end is then right to show.
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "thread.toNewest").firstMatch.exists,
                       "The way back shows though the thread is at its newest.")
        sources.click()
        XCTAssertEqual(top(of: asked), place, accuracy: 0.5, "The question moved when its sources unfolded.")
        sources.click()
        XCTAssertEqual(top(of: asked), place, accuracy: 0.5, "The question moved when its sources folded.")
    }
}
