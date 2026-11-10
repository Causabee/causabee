import XCTest

/// The bee's manifesto (docs/bee-manifesto.md) on the Mac, on the demo as people really have it:
/// every source, the dot and NEW as one signal, looked-at not handled.
final class ManifestoMacTests: XCTestCase {
    private var app: XCUIApplication!
    private var folder: URL!

    override func setUp() {
        continueAfterFailure = false
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("causabee-mac-tests-" + UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        app = XCUIApplication()
        app.launchEnvironment["CAUSABEE_STORE"] = folder.appendingPathComponent("matters.store").path
        app.launchEnvironment["CAUSABEE_UI_TEST"] = "1"
        app.launchArguments = ["--demo"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Care for Mum (Helga) after her fall"].firstMatch.waitForExistence(timeout: 30), "The demo's sidebar did not come up.")
    }

    override func tearDown() {
        app.terminate()
        try? FileManager.default.removeItem(at: folder)
    }

    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func any(_ words: String) -> XCUIElement { app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", words, words)).firstMatch }

    /// The sidebar's line of a matter: its cell.
    private func line(_ name: String) -> XCUIElement {
        app.cells.containing(.staticText, identifier: name).firstMatch
    }

    private func hasDot(_ name: String) -> Bool {
        let cell = line(name)
        XCTAssertTrue(cell.waitForExistence(timeout: 20), "\(name) is not in the sidebar.")
        return cell.descendants(matching: .any).matching(NSPredicate(format: "label == 'New'")).count > 0
    }

    private func open(_ name: String) {
        let row = app.staticTexts[name].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20), "\(name) is not in the sidebar.")
        // Below the list's edge in a small window: scrolled to first.
        // The list's edge is where "No matter found" begins (10 November: what has no matter yet
        // took the sidebar's foot, and three matters were below it, clicked unseen).
        let top = app.staticTexts["Care for Mum (Helga) after her fall"].firstMatch
        let edge = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'No matter found' OR value BEGINSWITH 'No matter found'")).firstMatch
        for _ in 0..<12 where edge.exists && row.frame.maxY > edge.frame.minY - 4 { top.scroll(byDeltaX: 0, deltaY: -80) }
        row.click()
        if !element("matter.more").waitForExistence(timeout: 10) { row.click() }
        XCTAssertTrue(element("matter.more").waitForExistence(timeout: 20), "\(name) did not open.")
    }

    private func tab(_ name: String) {
        let segment = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ OR title BEGINSWITH %@", name, name)).firstMatch
        XCTAssertTrue(segment.waitForExistence(timeout: 5), "No tab \(name).")
        segment.click()
    }

    private var newLabel: XCUIElement { app.staticTexts.matching(NSPredicate(format: "value BEGINSWITH 'NEW' OR label BEGINSWITH 'NEW'")).firstMatch }

    func testOnlyWhatCameInTodayHasTheDot() {
        XCTAssertTrue(hasDot("New property manager for Elm Court 51"), "A screenshot shared today gives no dot.")
        XCTAssertTrue(hasDot("Garden planner app (side project)"), "An old screenshot shared today gives no dot.")
        XCTAssertFalse(hasDot("Mortgage refinancing 2027"), "Nothing came in, yet a dot.")
        XCTAssertFalse(hasDot("Volvo or VW — next car"), "Nothing came in, yet a dot.")
    }

    func testOpeningTakesTheDotAway() {
        let name = "New property manager for Elm Court 51"
        XCTAssertTrue(hasDot(name))
        open(name)
        open("Mortgage refinancing 2027")
        XCTAssertFalse(hasDot(name), "Opened, the dot is still there.")
        XCTAssertTrue(hasDot("Garden planner app (side project)"), "Opening one matter took another's dot.")
    }

    func testNewOnceThenTheCardStays() {
        let name = "New property manager for Elm Court 51"
        open(name)
        XCTAssertTrue(newLabel.waitForExistence(timeout: 20), "The first visit does not say NEW.")
        open("Mortgage refinancing 2027")
        open(name)
        XCTAssertTrue(element("brief.seen").waitForExistence(timeout: 20), "Back again, the card is gone.")
        XCTAssertFalse(newLabel.exists, "Back again, it still says NEW.")
    }

    func testAMatterOfFilesOnlyHasItsTasks() {
        open("Mortgage refinancing 2027")
        tab("Plan")
        XCTAssertTrue(any("Compare Nordbank and Sparkasse").waitForExistence(timeout: 20), "Tasks from the bank's files are not in Plan.")
    }

    func testAPhotographedLetterGivesItsTask() {
        open("Cancel Mum's gym membership")
        tab("Plan")
        XCTAssertTrue(any("Send the cancellation to FitPark").waitForExistence(timeout: 20))
    }

    func testOwnNotesAreInNotes() {
        open("Garden planner app (side project)")
        tab("Notes")
        XCTAssertTrue(any("Keep it to one screen").waitForExistence(timeout: 20), "The owner's note is not in Notes.")
    }

    private func opensAtItsNextStep(_ name: String, _ step: String) {
        open(name)
        XCTAssertTrue(any(step).waitForExistence(timeout: 30), "\(name) does not show its next step: \(step)")
    }

    func testEveryMatterOpensAtItsNextStep_ElmCourt() { opensAtItsNextStep("New property manager for Elm Court 51", "Send the signed power of attorney to Kessler") }
    func testEveryMatterOpensAtItsNextStep_Application() { opensAtItsNextStep("Application: Head of Design, Brightwave", "Prepare the 20-minute design-system case study") }
    func testEveryMatterOpensAtItsNextStep_MumsGym() { opensAtItsNextStep("Cancel Mum's gym membership", "Have Mum sign the cancellation") }
    func testEveryMatterOpensAtItsNextStep_Mortgage() { opensAtItsNextStep("Mortgage refinancing 2027", "Ask Sparkasse whether a special repayment is possible") }
    func testEveryMatterOpensAtItsNextStep_GardenApp() { opensAtItsNextStep("Garden planner app (side project)", "Add the weather to the watering week") }
    func testEveryMatterOpensAtItsNextStep_Dinner() { opensAtItsNextStep("Christmas dinner with friends", "Ask Chiara if her sister comes") }
    func testEveryMatterOpensAtItsNextStep_NextCar() { opensAtItsNextStep("Volvo or VW — next car", "Confirm the ID.3 test drive for Saturday") }
    func testEveryMatterOpensAtItsNextStep_ScienceFair() { opensAtItsNextStep("Science fair: rainwater filter (Noa, 9b)", "Send the summary to Ms. Okafor") }
    func testEveryMatterOpensAtItsNextStep_Lisbon() { opensAtItsNextStep("Lisbon, 17–24 October (family trip)", "Tell Marta when we arrive") }
    func testEveryMatterOpensAtItsNextStep_Care() { opensAtItsNextStep("Care for Mum (Helga) after her fall", "Read and sign the Sunrise contract") }
    func testEveryMatterOpensAtItsNextStep_Flat() { opensAtItsNextStep("Buying the flat at Linden Street 8", "Send the salary slip to Northbank") }
    func testEveryMatterOpensAtItsNextStep_Wedding() { opensAtItsNextStep("Wedding, 12 June 2027 (Mara and Sam)", "Pay the deposit for Gut Birkenhof") }
    func testEveryMatterOpensAtItsNextStep_Moving() { opensAtItsNextStep("Moving to Birch Road 12", "Ask FiberNest to move the internet") }
    func testEveryMatterOpensAtItsNextStep_Tax() { opensAtItsNextStep("Tax return 2025", "Find the desk receipt") }
    func testEveryMatterOpensAtItsNextStep_Accident() { opensAtItsNextStep("Parking-lot accident, 14 September", "Send the repair estimate") }
    func testEveryMatterOpensAtItsNextStep_Bathroom() { opensAtItsNextStep("Bathroom renovation", "Order the tiles at Tile Hall") }
}
