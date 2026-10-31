import XCTest

/// What only an iPad has: the page between its columns, and on its side a column beside the page.
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
        app.launchArguments = ["--demo", "--open", "Care for Mum (Helga) after her fall", "--part", "all", "-mail.auto", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["part.All"].waitForExistence(timeout: 40), "The matter's page did not open.")
    }

    override func tearDown() { XCUIDevice.shared.orientation = .portrait }

    /// On its side: the journal between the sidebar and the column, on every filter, whole.
    func testTheColumnStandsBesideTheJournal() {
        for part in ["All", "Plan", "Mail", "Files", "People", "Notes"] {
            let filter = app.buttons["part.\(part)"]
            XCTAssertTrue(filter.waitForExistence(timeout: 10), "\(part) is not among the filters.")
            filter.tap()
            let column = app.buttons["athand.Summary"]
            XCTAssertTrue(column.waitForExistence(timeout: 10), "The column is not there on \(part).")
            picture(part)
            XCTAssertGreaterThan(app.buttons["part.All"].frame.minX, sidebar, "On \(part) the journal slid under the sidebar.")
            XCTAssertLessThanOrEqual(column.frame.maxX, app.windows.firstMatch.frame.maxX, "On \(part) the column runs off the screen.")
            XCTAssertLessThan(app.buttons["part.All"].frame.maxX, column.frame.minX, "On \(part) the journal and the column overlap.")
        }
    }

    /// The overview on its side: beside the sidebar, its journal and its matters whole.
    func testTheOverviewStandsBesideTheSidebar() {
        app.staticTexts["Overview"].firstMatch.tap()
        let matters = app.buttons["part.Matters"]
        XCTAssertTrue(matters.waitForExistence(timeout: 10), "The overview did not open.")
        picture("Overview")
        XCTAssertGreaterThan(app.buttons["part.All"].frame.minX, sidebar, "The overview slid under the sidebar.")
        matters.tap()
        picture("Overview's matters")
        XCTAssertGreaterThan(app.buttons["part.All"].frame.minX, sidebar, "The overview slid under the sidebar.")
    }

    /// With the assistant beside it there is no room for the column: the journal has the page alone.
    /// On Mail, where what the column holds has no place in the page.
    func testTheAssistantTakesTheColumnsPlace() {
        app.buttons["part.Mail"].tap()
        XCTAssertTrue(app.buttons["athand.Summary"].waitForExistence(timeout: 10), "The column is not there.")
        app.buttons["Ask Causabee"].firstMatch.tap()
        XCTAssertTrue(app.buttons["athand.Summary"].waitForNonExistence(timeout: 10), "The column stayed beside the assistant.")
        picture("Assistant")
        XCTAssertGreaterThan(app.buttons["part.All"].frame.minX, sidebar, "The journal slid under the sidebar.")
    }

    /// Turned upright the sidebar and the column step aside, and the page has the whole window.
    func testUprightThePageIsWhole() {
        app.buttons["part.Mail"].tap()
        XCTAssertTrue(app.buttons["athand.Summary"].waitForExistence(timeout: 10), "The column is not there.")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.buttons["athand.Summary"].waitForNonExistence(timeout: 10), "The column stayed on an upright iPad.")
        picture("Upright")
        XCTAssertGreaterThanOrEqual(app.buttons["part.All"].frame.minX, 0, "The journal is cut off on the left.")
    }

    private func picture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
