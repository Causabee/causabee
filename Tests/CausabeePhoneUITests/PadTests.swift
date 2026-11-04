import XCTest

/// What only an iPad has: the page between the sidebar and the assistant, one column, whole.
/// What a picture of a page cut off on both sides showed by eye, these say in points. On an iPhone
/// they are skipped; `scripts/testflight.sh` runs them on an iPad too.
///
///   xcodebuild test -project App/Causabee.xcodeproj -scheme CausabeePhoneUITests -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' -only-testing:CausabeePhoneUITests/PadTests
final class PadTests: XCTestCase {
    private var app: XCUIApplication!
    /// The sidebar's width, `PadMetrics.sidebar`.
    private let sidebar: CGFloat = 300

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "Only an iPad has columns.")
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["--demo", "--open", "Care for Mum (Helga) after her fall", "--part", "all", "-mail.auto", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["part.Digest"].waitForExistence(timeout: 40), "The matter's page did not open.")
    }

    override func tearDown() { XCUIDevice.shared.orientation = .portrait }

    /// On its side with the chat closed: one page beside the sidebar, on every filter, whole —
    /// what is ahead is in it, not in a column of its own.
    func testOnItsSideThePageIsOneColumn() {
        let window = app.windows.firstMatch.frame
        for part in ["Digest", "Plan", "Mail", "Files", "People", "Notes"] {
            let filter = app.buttons["part.\(part)"]
            XCTAssertTrue(filter.waitForExistence(timeout: 10), "\(part) is not among the filters.")
            filter.tap()
            picture(part)
            let digest = app.buttons["part.Digest"].frame
            XCTAssertGreaterThan(digest.minX, sidebar, "On \(part) the journal slid under the sidebar.")
            let summary = app.buttons["athand.Summary"]
            if summary.exists {
                XCTAssertGreaterThanOrEqual(summary.frame.minX, digest.minX - 30, "On \(part) the summary stands in a column beside the page.")
                XCTAssertLessThanOrEqual(summary.frame.maxX, window.maxX, "On \(part) the summary runs off the screen.")
            }
        }
    }

    /// The overview on its side: beside the sidebar, its journal and its matters whole.
    func testTheOverviewStandsBesideTheSidebar() {
        app.staticTexts["Overview"].firstMatch.tap()
        let matters = app.buttons["part.Matters"]
        XCTAssertTrue(matters.waitForExistence(timeout: 10), "The overview did not open.")
        picture("Overview")
        XCTAssertGreaterThan(app.buttons["part.Latest updates"].frame.minX, sidebar, "The overview slid under the sidebar.")
        matters.tap()
        picture("Overview's matters")
        XCTAssertGreaterThan(app.buttons["part.Latest updates"].frame.minX, sidebar, "The overview slid under the sidebar.")
    }

    /// What is ahead reads as the plan does: a task has its box, a date its block, and the box
    /// ticks. The demo is filled anew after it, for the runs that count on that task.
    func testATaskAheadIsTickedThere() {
        let ahead = app.descendants(matching: .any)["ahead"]
        XCTAssertTrue(ahead.waitForExistence(timeout: 10), "What is ahead is not there.")
        picture("Ahead")
        let box = ahead.buttons["Mark as done"].firstMatch
        // In the page, under the next step: its tasks are drawn once they come into sight.
        for _ in 0..<4 where !box.exists { app.swipeUp() }
        XCTAssertTrue(box.waitForExistence(timeout: 5), "No task ahead has its box.")
        let left = ahead.staticTexts.matching(NSPredicate(format: "label CONTAINS ' open'")).firstMatch
        let before = left.label
        box.tap()
        let end = Date().addingTimeInterval(5)
        while left.label == before, Date() < end { RunLoop.current.run(until: Date().addingTimeInterval(0.2)) }
        picture("Ahead, ticked")
        XCTAssertNotEqual(left.label, before, "The box was tapped and the task still counts as open.")
        app.terminate()
        app.launchArguments += ["-demo.filled", "anew"]
        app.launch()
        XCTAssertTrue(app.buttons["part.Digest"].waitForExistence(timeout: 40), "The demo did not come back.")
    }

    /// With the assistant beside it the journal keeps its room between the sidebar and the chat.
    func testTheAssistantStandsBesideThePage() {
        app.buttons["part.Mail"].tap()
        app.buttons["bee"].firstMatch.tap()
        XCTAssertTrue(app.buttons["part.Digest"].waitForExistence(timeout: 10), "The page went when the assistant came.")
        picture("Assistant")
        XCTAssertGreaterThan(app.buttons["part.Digest"].frame.minX, sidebar, "The journal slid under the sidebar.")
    }

    /// Turned upright the sidebar steps aside, and the page has the whole window.
    func testUprightThePageIsWhole() {
        app.buttons["part.Mail"].tap()
        XCUIDevice.shared.orientation = .portrait
        let end = Date().addingTimeInterval(10)
        while app.buttons["part.Digest"].frame.minX > sidebar, Date() < end { RunLoop.current.run(until: Date().addingTimeInterval(0.2)) }
        picture("Upright")
        XCTAssertGreaterThanOrEqual(app.buttons["part.Digest"].frame.minX, 0, "The journal is cut off on the left.")
    }

    private func picture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
