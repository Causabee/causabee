import XCTest

/// Good to know under the summary: each line has Hide, and a hidden one is gone from the page.
final class GoodToKnowUITests: XCTestCase {
    func testALineHiddenIsGone() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "-demo.filled", "anew", "-mail.auto", "NO", "--open", "Care for Mum (Helga) after her fall"]
        app.launch()
        let fold = app.buttons["athand.Good to know"]
        XCTAssertTrue(fold.waitForExistence(timeout: 40), "The demo's matter shows no Good to know.")
        if fold.value as? String == "folded" { fold.tap() }
        let hide = app.buttons.matching(identifier: "info.hide")
        XCTAssertTrue(hide.firstMatch.waitForExistence(timeout: 5), "A line worth knowing has no Hide.")
        let before = hide.count
        if let shots = ProcessInfo.processInfo.environment["PANEL_SHOTS"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shots + "/good-to-know.png"))
        }
        hide.firstMatch.tap()
        for _ in 0..<25 where hide.count >= before { Thread.sleep(forTimeInterval: 0.2) }
        XCTAssertEqual(hide.count, before - 1, "Hidden, the line is still on the page.")
    }
}
