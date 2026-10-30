import XCTest

/// How smoothly the app scrolls, screen by screen, on the big demo — forty more matters with a
/// hundred mails each, and a care matter with some three hundred mails and seventy tasks done.
/// Each screen is swiped up and down, and the app's own frame meter (`--frame-meter`) says how
/// many frames came late and how much time was lost. Not part of the TestFlight run: run it to compare.
/// (The app's own `--scroll-tour` measures without the test's reading of the screen between swipes.)
///
///   TEST_RUNNER_CAUSABEE_SCROLL_TESTS=1 xcodebuild test -project App/Causabee.xcodeproj -scheme CausabeePhoneUITests -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:CausabeePhoneUITests/ScrollTests
final class ScrollTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CAUSABEE_SCROLL_TESTS"] != nil, "Only when asked for: TEST_RUNNER_CAUSABEE_SCROLL_TESTS=1")
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["--demo", "--big", "--frame-meter", "-mail.auto", "NO", "-demo.filled", "anew"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Care for Mum (Helga) after her fall"].firstMatch.waitForExistence(timeout: 90), "The demo's overview did not come up.")
        // Settled: the store read, the first pages prepared.
        sleep(3)
    }

    /// (late frames, lost milliseconds) so far.
    private func meter() -> (late: Int, lost: Int) {
        let words = app.staticTexts["frame-meter"].firstMatch.label
        let numbers = words.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        return numbers.count >= 3 ? (numbers[1], numbers[2]) : (0, 0)
    }

    /// Scrolls the screen's first scroll view down and up again, twice, and says what it lost.
    @discardableResult
    private func scroll(_ name: String) -> (late: Int, lost: Int) {
        let page = app.scrollViews.firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 10), "\(name): nothing to scroll.")
        let before = meter()
        for _ in 0..<2 {
            page.swipeUp(velocity: .fast); page.swipeUp(velocity: .fast)
            page.swipeDown(velocity: .fast); page.swipeDown(velocity: .fast)
        }
        let after = meter()
        let result = (after.late - before.late, after.lost - before.lost)
        let line = "SCROLL \(name): \(result.0) late frames, \(result.1) ms lost"
        print(line)
        XCTContext.runActivity(named: line) { _ in }
        return result
    }

    func testScrollingEveryScreen() {
        scroll("overview")
        app.staticTexts["Care for Mum (Helga) after her fall"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Ask Causabee"].waitForExistence(timeout: 20), "The matter's page did not open.")
        sleep(2)
        scroll("matter · plan")
        for (part, name) in [("Record", "matter · record"), ("People", "matter · people"), ("Notes", "matter · notes")] {
            let button = app.buttons[part].firstMatch
            guard button.exists else { continue }
            button.tap()
            sleep(1)
            scroll(name)
        }
    }
}
