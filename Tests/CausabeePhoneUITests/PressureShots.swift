import XCTest

/// The bee's real answers on the screen: `matter-spike pressure` records them on the demo, and this
/// asks the same questions in the app with `-answers.recorded`, so each draft and card is drawn as
/// the owner would see it — a picture of each, for the report. Runs only when told where they are
/// (PRESSURE_CASES, PRESSURE_RESULTS, SHOT_DIR); nothing is sent.
final class PressureShots: XCTestCase {
    private static let keys = [
        "Cancel Mum's gym membership": "mums-gym", "Science fair: rainwater filter (Noa, 9b)": "science-fair-9b",
        "Application: Head of Design, Brightwave": "brightwave-application", "Buying the flat at Linden Street 8": "flat-linden-street",
        "Lisbon, 17–24 October (family trip)": "lisbon-october", "Garden planner app (side project)": "garden-planner",
        "Mortgage refinancing 2027": "mortgage-2027", "Bathroom renovation": "bathroom-renovation", "Tax return 2025": "tax-return-2025",
        "New property manager for Elm Court 51": "elm-court-manager", "Moving to Birch Road 12": "move-birch-road",
        "Christmas dinner with friends": "christmas-dinner", "Care for Mum (Helga) after her fall": "care-for-helga",
        "Parking-lot accident, 14 September": "parking-accident", "Volvo or VW — next car": "next-car",
        "Wedding, 12 June 2027 (Mara and Sam)": "wedding-june",
    ]

    func testEveryRecordedAnswerOnTheScreen() throws {
        let env = ProcessInfo.processInfo.environment
        guard let casesPath = env["PRESSURE_CASES"], let results = env["PRESSURE_RESULTS"], let shots = env["SHOT_DIR"] else {
            throw XCTSkip("Only with PRESSURE_CASES, PRESSURE_RESULTS and SHOT_DIR.")
        }
        let cases = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: casesPath))) as? [[String: Any]] ?? []
        continueAfterFailure = true
        for item in cases {
            guard let id = item["id"] as? String, let matter = item["matter"] as? String, let key = Self.keys[matter],
                  let turns = item["turns"] as? [String] else { continue }
            let app = XCUIApplication()
            app.launchArguments = ["--demo", "--answers", "-demo.filled", "anew", "-mail.auto", "NO", "-answers.recorded", results,
                                   "-answers.after", "0.3", "--open", key]
            app.launch()
            let bee = app.buttons["bee"].firstMatch
            guard bee.waitForExistence(timeout: 30) else { XCTFail("\(id): the matter did not open"); continue }
            bee.tap()
            for (n, question) in turns.enumerated() {
                let single = app.textFields["assistant.field"]
                let field = single.waitForExistence(timeout: 5) ? single : app.textViews["assistant.field"]
                field.tap()
                field.typeText(question)
                app.buttons["Send"].firstMatch.tap()
                Thread.sleep(forTimeInterval: 2.5)
                // The answer and its card, scrolled into view.
                app.swipeUp()
                Thread.sleep(forTimeInterval: 0.8)
                try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shots).appendingPathComponent("\(id)-\(n + 1).png"))
            }
            app.terminate()
        }
    }
}
