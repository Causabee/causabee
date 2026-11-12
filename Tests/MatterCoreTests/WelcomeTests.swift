import Foundation
import Testing
@testable import MatterCore

/// F008: the first start without the expert's load — a few calm pages, then the first matter,
/// typed or added; the demo second; nothing asked at the door.
@Suite("F008 · The welcome page")
struct WelcomeTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static func source(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
    static let phoneWelcome = "Sources/CausabeePhone/Welcome.swift", macIntro = "Sources/Causabee/IntroView.swift"
    static let macApp = "Sources/Causabee/CausabeeApp.swift", phoneOverview = "Sources/CausabeePhone/OverviewScreen.swift"
    static let firstStep = "Sources/Causabee/FirstStep.swift"

    @Test("F008 AC-1 · A few calm pages, then in")
    func fewPages() throws {
        #expect(Welcome.pages.count == 3)
        for page in Welcome.pages {
            #expect(page.line.count <= 90, "\(page.title): one short line")
            #expect(!page.line.contains("?"), "\(page.title) asks nothing")
        }
        // The last page is no checklist: no ticks for iCloud, the plan or mail.
        let phone = try Self.source(Self.phoneWelcome)
        #expect(!phone.contains("Ready when you are") && !phone.contains("check(\"Mail\""))
    }

    @Test("F008 AC-2 · Private, said once")
    func privateOnce() throws {
        #expect(Welcome.privacy == "Names are disguised before anything is sent.")
        for path in [Self.phoneWelcome, Self.macIntro] {
            let text = try Self.source(path)
            #expect(text.components(separatedBy: "Welcome.privacy").count == 2, "\(path) says it once")
            #expect(!text.contains("names, addresses and numbers are replaced"), "\(path) has a privacy paragraph of its own")
        }
    }

    @Test("F008 AC-3 · The welcome ends at the first step, in the person's own Causabee")
    func endsAtFirstStep() throws {
        #expect(try Self.source(Self.phoneOverview).contains("FirstStep("))
        #expect(try Self.source(Self.macApp).contains("FirstStep("))
        #expect(Welcome.firstTitle == "What’s on your mind?")
    }

    @Test("F008 AC-4 · Typed, it becomes the first matter")
    func typed() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("welcome-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = try Welcome.typedFile("Mum fell. The care service visits on Thursday.\nAsk about the stairs.", in: folder)
        #expect(file.pathExtension == "txt")
        let look = try ScreenshotDoor(besides: folder.appendingPathComponent("store.sqlite")).look(at: file, owner: "Alex")
        let id = try #require(look.report.outcomes.first?.judgement.emailID)
        #expect(id.hasPrefix("typed:"))
        #expect(look.heading == "Mum fell. The care service visits on Thursday.")
        // The owner's own word, a kind every build knows.
        #expect(Source.Kind.of(emailID: id) == .conversation)
        #expect(Source.Kind.of(emailID: "screenshot:ab") == .screenshot && Source.Kind.of(emailID: "document:ab") == .document)
        #expect(Source.Kind.of(emailID: "<x@y>") == .mail)
        // The bee's name, or the typed line when it gives none.
        #expect(Welcome.matterName(proposed: "Care for Mum", typed: "Mum fell.") == "Care for Mum")
        #expect(Welcome.matterName(proposed: nil, typed: "Mum fell. The care service visits on Thursday.\nMore") == "Mum fell. The care service visits on Thursday.")
        #expect(Welcome.matterName(proposed: " ", typed: String(repeating: "a", count: 80)).count == 60)
    }

    @Test("F008 AC-5 · Added, it becomes the first matter")
    func added() throws {
        #expect(Welcome.takesAtOnce(matters: 0) && !Welcome.takesAtOnce(matters: 1))
        #expect(try Self.source("Sources/CausabeePhone/PhoneShots.swift").contains("Welcome.takesAtOnce("))
        #expect(try Self.source("Sources/Causabee/Conversation.swift").contains("Welcome.takesAtOnce("))
    }

    @Test("F008 AC-6 · The demo is the second way, never the first")
    func demoSecond() throws {
        #expect(Welcome.demo == "Look around in an example.")
        let step = try Self.source(Self.firstStep)
        let demo = try #require(step.range(of: "Welcome.demo"))
        let field = try #require(step.range(of: "Welcome.firstTitle"))
        #expect(field.lowerBound < demo.lowerBound)
        #expect(step.contains(".buttonStyle(.gold)"))
        // The iPhone's welcome no longer offers the demo as a filled button.
        #expect(!(try Self.source(Self.phoneWelcome)).contains("Button(\"Try the demo\") { finish(); store.switchDemo(true) }.buttonStyle(.phone(filled: true"))
    }

    @Test("F008 AC-7 · Nothing asked at the door")
    func nothingAtTheDoor() throws {
        let mac = try Self.source(Self.macApp)
        #expect(!mac.contains("SetupAssistant.isMissingSomething { showsSetup = true }"))
        #expect(!mac.contains("if SetupState.isFresh || (!setupLater && !DemoData.isRequested && SetupAssistant.isMissingSomething) { showsSetup = true }"))
        // Still there, opened by hand.
        #expect(mac.contains("Set Up Causabee"))
    }

    @Test("F008 AC-8 · Mail is offered once there is a matter")
    func mailOffer() {
        #expect(Welcome.offersMail(matters: 1, hasMailbox: false, later: false))
        #expect(!Welcome.offersMail(matters: 0, hasMailbox: false, later: false))
        #expect(!Welcome.offersMail(matters: 2, hasMailbox: true, later: false))
        #expect(!Welcome.offersMail(matters: 2, hasMailbox: false, later: true))
        #expect(Welcome.mailTitle == "Also what comes by mail?")
    }

    @Test("F008 AC-9 · Empty is the first step, everywhere")
    func emptyIsFirstStep() throws {
        #expect(!(try Self.source(Self.macApp)).contains("to bring in your mail"))
        #expect(!(try Self.source(Self.phoneOverview)).contains("Pull down to get new mail"))
    }

    @Test("F008 AC-10 · Already in use elsewhere: straight to the matters")
    func cloud() {
        let start = Date()
        #expect(Welcome.waitsForCloud(signedIn: true, imported: false, since: start, now: start.addingTimeInterval(10)))
        #expect(!Welcome.waitsForCloud(signedIn: true, imported: false, since: start, now: start.addingTimeInterval(31)))
        #expect(!Welcome.waitsForCloud(signedIn: true, imported: true, since: start, now: start))
        #expect(!Welcome.waitsForCloud(signedIn: false, imported: false, since: start, now: start))
        #expect(Welcome.cloudLine == "Looking in iCloud for your matters …")
    }

    @Test("F008 AC-11 · The same welcome on every device")
    func sameEverywhere() throws {
        for path in [Self.phoneWelcome, Self.macIntro] {
            let text = try Self.source(path)
            #expect(text.contains("Welcome.pages") && text.contains("Welcome.promise"), "\(path) has pages of its own")
        }
    }

    @Test("F008 AC-12 · Your name, asked once, after the first matter")
    func name() throws {
        #expect(Welcome.asksName(names: []) && Welcome.asksName(names: ["", " "]))
        #expect(!Welcome.asksName(names: ["Alex"]))
        let line = try Self.source("Sources/Causabee/NameLine.swift")
        #expect(line.contains("NSFullUserName()") && line.contains("Welcome.asksName("))
    }
}
