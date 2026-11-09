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

    /// The first words of what was recorded for that turn: the card's text, else the first line.
    static func snippet(results: String, id: String, turn: Int) -> String {
        guard let data = FileManager.default.contents(atPath: results),
              let all = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let item = all.first(where: { ($0["id"] as? String) == id }),
              let turns = item["turns"] as? [[String: Any]], turns.indices.contains(turn) else { return "" }
        let cards = turns[turn]["cards"] as? [[String: String]] ?? []
        let text = cards.first?["text"] ?? (turns[turn]["lines"] as? [String])?.first ?? ""
        // The draft's last long line: greetings repeat from one draft to the next, what is said does not.
        let line = text.split(separator: "\n").last(where: { $0.count > 12 }).map(String.init) ?? text
        return String(line.prefix(20))
    }

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
            // Pro on, as the chat needs it to answer; the demo's own new mail put away first.
            app.launchArguments = ["--demo", "--answers", "-demo.filled", "anew", "-mail.auto", "YES", "-answers.recorded", results,
                                   "-answers.after", "0.3", "--open", key]
            app.launch()
            let receipt = app.buttons["receipt.close"]
            if receipt.waitForExistence(timeout: 6) { receipt.tap() }
            let bee = app.buttons["bee"].firstMatch
            guard bee.waitForExistence(timeout: 30) else { XCTFail("\(id): the matter did not open"); continue }
            bee.tap()
            for (n, question) in turns.enumerated() {
                let single = app.textFields["assistant.field"]
                let field = single.waitForExistence(timeout: 5) ? single : app.textViews["assistant.field"]
                field.tap()
                field.typeText(question)
                app.buttons["Send"].firstMatch.tap()
                // What came back, found by its own first words, and scrolled to stand whole above the field.
                let snippet = Self.snippet(results: results, id: id, turn: n)
                let shown = app.descendants(matching: .any)
                    .matching(NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", snippet, snippet)).firstMatch
                _ = shown.waitForExistence(timeout: 10)
                // The keyboard away: the thread pulled down into it, slowly, as a thumb does.
                for _ in 0..<2 where app.keyboards.count > 0 {
                    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
                        .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)), withVelocity: .slow, thenHoldForDuration: 0.1)
                    Thread.sleep(forTimeInterval: 0.6)
                }
                let bar = app.textFields["assistant.field"].exists ? app.textFields["assistant.field"] : app.textViews["assistant.field"]
                let floor = bar.exists ? bar.frame.minY - 40 : app.frame.maxY * 0.75
                for _ in 0..<20 {
                    guard shown.exists else { break }
                    if shown.frame.minY < 180 {
                        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
                    } else if shown.frame.maxY + 260 > floor {
                        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
                    } else { break }
                    Thread.sleep(forTimeInterval: 0.3)
                }
                Thread.sleep(forTimeInterval: 0.6)
                try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shots).appendingPathComponent("\(id)-\(n + 1).png"))
            }
            app.terminate()
        }
    }
}
