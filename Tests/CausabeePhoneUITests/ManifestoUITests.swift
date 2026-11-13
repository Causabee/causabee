import XCTest

/// The bee's manifesto (docs/bee-manifesto.md), on the screen, on the demo as people really have
/// it: every source, the dot and NEW as one signal, looked-at not handled. Runs on iPhone and iPad.
final class ManifestoUITests: XCTestCase {
    private var app: XCUIApplication!

    private func launch(open matter: String? = nil) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--demo", "-demo.filled", "anew", "-mail.auto", "NO"] + (matter.map { ["--open", $0] } ?? [])
        app.launch()
    }

    /// The overview's list of matters.
    private func showMatters() {
        let matters = app.buttons["overview.matters"]
        XCTAssertTrue(matters.waitForExistence(timeout: 40), "The overview did not come up.")
        matters.tap()
    }

    /// A matter's row in the list.
    private func row(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
    }

    private func hasDot(_ name: String) -> Bool {
        let line = row(name)
        XCTAssertTrue(line.waitForExistence(timeout: 20), "\(name) is not in the list.")
        return line.label.contains(", New,") || line.label.hasSuffix(", New")
    }

    /// Back to the overview, from a matter, on either device.
    private func back() {
        let sidebar = app.buttons["sidebar.toggle"]
        if sidebar.exists {
            if !app.buttons["sidebar.overview"].exists { sidebar.tap() }
            app.buttons["sidebar.overview"].tap()
        } else {
            app.navigationBars.buttons.firstMatch.tap()
        }
    }

    private func open(_ name: String) {
        let line = row(name)
        XCTAssertTrue(line.waitForExistence(timeout: 20), "\(name) is not in the list.")
        for _ in 0..<6 where !line.isHittable { app.swipeUp() }
        line.tap()
    }

    private func text(_ words: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", words)).firstMatch
    }

    private func any(_ words: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", words)).firstMatch
    }

    /// By the part's own name — "plan", "files" — never by the word on the pill: that word is the
    /// device's language (F009).
    private func tab(_ name: String) {
        let part = app.buttons["part." + name]
        XCTAssertTrue(part.waitForExistence(timeout: 20), "No \(name) tab.")
        part.tap()
    }

    private var newLabel: XCUIElement { app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'NEW'")).firstMatch }

    // MARK: 1·2 — new by when it reached the bee, from every source

    func testOnlyWhatCameInTodayHasTheDot() {
        launch(); showMatters()
        for name in ["New property manager for Elm Court 51", "Garden planner app (side project)"] {
            XCTAssertTrue(hasDot(name), "\(name): came in today, no dot.")
        }
        for name in ["Mortgage refinancing 2027", "Application: Head of Design, Brightwave", "Cancel Mum's gym membership", "Volvo or VW — next car"] {
            XCTAssertFalse(hasDot(name), "\(name): nothing came in since last night, yet a dot.")
        }
    }

    func testAScreenshotWrittenLastWeekSharedTodayIsNew() {
        launch(open: "New property manager for Elm Court 51")
        XCTAssertTrue(newLabel.waitForExistence(timeout: 40), "The owners' group screenshot, shared today, is not NEW.")
        XCTAssertTrue(any("Ask Hartmann for the 2025 statement").exists, "What the screenshot asks for is not on the card.")
    }

    func testAnOldScreenshotSharedTodayIsNew() {
        launch(open: "Garden planner app (side project)")
        XCTAssertTrue(newLabel.waitForExistence(timeout: 40), "A screenshot from three weeks ago, shared today, is not NEW.")
        XCTAssertTrue(any("Add the weather to the watering week").exists)
    }

    // MARK: 3 — one signal: opening takes it away, on any tab

    func testOpeningTakesTheDotAway() {
        launch(); showMatters()
        let name = "New property manager for Elm Court 51"
        XCTAssertTrue(hasDot(name))
        open(name)
        XCTAssertTrue(newLabel.waitForExistence(timeout: 20))
        back(); showMatters()
        XCTAssertFalse(hasDot(name), "Opened, the dot is still there.")
    }

    func testOpeningOnPlanTakesTheDotAwayToo() {
        launch(); showMatters()
        let name = "Garden planner app (side project)"
        XCTAssertTrue(hasDot(name))
        open(name)
        tab("plan")
        sleep(1)
        back(); showMatters()
        XCTAssertFalse(hasDot(name), "Opened on Plan, the dot is still there.")
    }

    func testTheDotStaysOnMattersNotOpened() {
        launch(); showMatters()
        open("New property manager for Elm Court 51")
        XCTAssertTrue(newLabel.waitForExistence(timeout: 20))
        back(); showMatters()
        XCTAssertTrue(hasDot("Garden planner app (side project)"), "Opening one matter took another's dot.")
    }

    // MARK: 4 — looked at is not handled

    func testNewOnceThenTheCardStays() {
        launch(); showMatters()
        let name = "New property manager for Elm Court 51"
        open(name)
        XCTAssertTrue(newLabel.waitForExistence(timeout: 20))
        let lines = app.buttons.matching(identifier: "new.putAway").count
        back(); showMatters(); open(name)
        XCTAssertTrue(app.buttons["brief.seen"].firstMatch.waitForExistence(timeout: 20), "Back again, the card is gone.")
        XCTAssertFalse(newLabel.exists, "Back again, it still says NEW.")
        XCTAssertEqual(app.buttons.matching(identifier: "new.putAway").count, lines, "Lines left the card without being handled.")
    }

    func testKeptLeavesTheCard() {
        launch(open: "New property manager for Elm Court 51")
        let keep = app.buttons.matching(identifier: "new.keep")
        XCTAssertTrue(keep.firstMatch.waitForExistence(timeout: 40))
        let before = keep.count
        keep.firstMatch.tap()
        for _ in 0..<25 where keep.count >= before { Thread.sleep(forTimeInterval: 0.2) }
        XCTAssertEqual(keep.count, before - 1, "Kept, the line is still on the card.")
    }

    func testPutAwayLeavesTheCard() {
        launch(open: "Garden planner app (side project)")
        let away = app.buttons.matching(identifier: "new.putAway")
        XCTAssertTrue(away.firstMatch.waitForExistence(timeout: 40))
        let before = away.count
        away.firstMatch.tap()
        for _ in 0..<25 where away.count >= before { Thread.sleep(forTimeInterval: 0.2) }
        XCTAssertEqual(away.count, before - 1, "Put away, the line is still on the card.")
    }

    func testSeenClearsTheCard() {
        launch(open: "New property manager for Elm Court 51")
        let seen = app.buttons["brief.seen"].firstMatch
        XCTAssertTrue(seen.waitForExistence(timeout: 40))
        seen.tap()
        for _ in 0..<25 where seen.exists { Thread.sleep(forTimeInterval: 0.2) }
        XCTAssertFalse(seen.exists, "Seen, the card is still there.")
        XCTAssertEqual(app.buttons.matching(identifier: "new.keep").count, 0)
    }

    // MARK: 1 — every source is read: files, photos, screenshots, notes

    func testAMatterOfFilesOnlyHasItsTasks() {
        launch(open: "Mortgage refinancing 2027")
        tab("plan")
        XCTAssertTrue(any("Compare Nordbank and Sparkasse").waitForExistence(timeout: 20), "Tasks from the bank's files are not in Plan.")
    }

    func testAMatterOfFilesOnlyShowsItsFiles() {
        launch(open: "Mortgage refinancing 2027")
        tab("files")
        XCTAssertTrue(any("Nordbank offer").waitForExistence(timeout: 20), "The bank's offer is not in Files.")
        XCTAssertTrue(any("Sparkasse offer").exists)
    }

    func testAPhotographedLetterGivesItsTask() {
        launch(open: "mums-gym")
        tab("plan")
        XCTAssertTrue(any("Send the cancellation to FitPark").waitForExistence(timeout: 20), "The photographed letter's task is not in Plan.")
    }

    func testAPhotographedLetterGivesItsDeadline() {
        launch(open: "mums-gym")
        tab("plan")
        XCTAssertTrue(any("Last day to cancel").waitForExistence(timeout: 20), "The letter's deadline is not in Plan.")
    }

    func testAChatScreenshotGivesItsTask() {
        launch(open: "Application: Head of Design, Brightwave")
        tab("plan")
        XCTAssertTrue(any("Decide the salary expectation").waitForExistence(timeout: 20), "The LinkedIn screenshot's task is not in Plan.")
    }

    func testOwnNotesAreInNotes() {
        launch(open: "Garden planner app (side project)")
        tab("notes")
        XCTAssertTrue(any("Keep it to one screen").waitForExistence(timeout: 20), "The owner's note is not in Notes.")
    }

    func testOwnNotesAreInNotesWithMail() {
        launch(open: "New property manager for Elm Court 51")
        tab("notes")
        XCTAssertTrue(any("Boiler room keys").waitForExistence(timeout: 20), "The owner's note is not in Notes.")
    }

    func testGoodToKnowFromAScreenshot() {
        launch(open: "Christmas dinner with friends")
        XCTAssertTrue(any("Good to know").waitForExistence(timeout: 30), "No Good to know.")
    }

    func testDatesFromEverySourceAreInPlan() {
        launch(open: "Volvo or VW — next car")
        tab("plan")
        XCTAssertTrue(any("Test drive VW ID.3").waitForExistence(timeout: 20), "The dealer's date is not in Plan.")
    }

    // MARK: Every matter opens, at its next step

    private func opensAtItsNextStep(_ name: String, _ step: String) {
        launch(open: name)
        XCTAssertTrue(any(step).waitForExistence(timeout: 40), "\(name) does not show its next step: \(step)")
    }

    func testEveryMatterOpensAtItsNextStep_ElmCourt() { opensAtItsNextStep("New property manager for Elm Court 51", "Send the signed power of attorney to Kessler") }
    func testEveryMatterOpensAtItsNextStep_Application() { opensAtItsNextStep("Application: Head of Design, Brightwave", "Prepare the 20-minute design-system case study") }
    func testEveryMatterOpensAtItsNextStep_MumsGym() { opensAtItsNextStep("mums-gym", "Have Mum sign the cancellation") }
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
