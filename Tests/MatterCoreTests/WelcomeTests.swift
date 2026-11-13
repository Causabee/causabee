import Foundation
import SwiftData
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
        // The iPhone as simple as the Mac: no title, no search over nothing (the owner, 13 November).
        #expect(try Self.source(Self.phoneOverview).contains("if !matters.isEmpty { searchField }"))
    }

    @Test("F008 AC-4 · Typed, it becomes the first matter")
    func typed() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("welcome-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = try Welcome.typedFile("Mum fell. The care service visits on Thursday.\nAsk about the stairs.", in: folder)
        #expect(file.pathExtension == "txt")
        // Shown as the owner's words, never by its file name.
        #expect(Welcome.isTyped(file) && Welcome.isTyped(URL(fileURLWithPath: "/x/B8EC6F27-\(file.lastPathComponent)")))
        #expect(!Welcome.isTyped(URL(fileURLWithPath: "/x/notes.txt")))
        // The Mac's chat card shows them as words: no file block, nothing "would be sent".
        let card = try Self.source("Sources/Causabee/ShotView.swift")
        #expect(card.contains("if !Welcome.isTyped(shot.file) {") && card.components(separatedBy: "if !Welcome.isTyped(look.file) { sentDisclosure(look) }").count == 3)
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
        // With no name from the reader, the line before its date — without the words that lead to it
        // (the owner's try on the Mac, 13 November).
        #expect(Welcome.matterName(proposed: nil, typed: "Muttis Reha started am 2.12.2026") == "Muttis Reha")
        #expect(Welcome.matterName(proposed: nil, typed: "Muttis Reha startet am 23.11.") == "Muttis Reha")
        #expect(Welcome.matterName(proposed: nil, typed: "Science fair project with Lena, due 20 November") == "Science fair project with Lena")
        #expect(Welcome.matterName(proposed: nil, typed: "12.3. Umzug") == "12.3. Umzug", "nothing before the date: the line")
        // A date the reader gave only as itself takes the matter's name.
        var judgement = try #require(look.report.outcomes.first?.judgement)
        judgement.deadlines = [Judgement.Deadline(what: "2.12.2026", date: "2026-12-02", sourceQuote: "")]
        Welcome.nameDates(&judgement, name: "Muttis Reha", line: "Muttis Reha started am 2.12.2026")
        #expect(judgement.deadlines.first?.what == "Muttis Reha")
        // A long line is cut at a word, never in one (the pressure test, 12 November).
        #expect(Welcome.matterName(proposed: nil, typed: "Car insurance claim after the parking-lot accident, the assessor calls next week")
                == "Car insurance claim after the parking-lot accident, the")
    }

    @Test("F008 AC-4 · Typed words show once: as the owner's note, never as a mail")
    @MainActor
    func typedOnce() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "reha")
        context.insert(matter)
        let typed = Source(kind: .conversation, pointer: Source.ownWords, messageID: "typed:726fc2c7af880022", date: Date())
        let words = Entry(title: "Mum's rehab starts on 23 November", from: "Notiz", date: typed.date, source: typed)
        words.matter = matter
        context.insert(words)
        let mail = Source(kind: .mail, pointer: "imap://x;UID=1", messageID: "<1@x>", date: Date())
        let letter = Entry(title: "Rehab clinic: your arrival", from: "clinic@example.com", date: mail.date, source: mail)
        letter.matter = matter
        context.insert(letter)
        try context.save()
        let picked = RecordBrowse.pick(threads: MailThreads.build([words, letter]), documents: [], links: [], kind: .everything, show: .all, made: RecordLinks(matter))
        #expect(picked.items.map(\.id) == ["thread-<1@x>"], "the typed words are the note already")
    }

    @Test("F008 AC-4 · The first matter read by the best reader, told it is the first")
    func firstMatterPrompts() throws {
        // Both readers are told, and only for what is brought in at the first start.
        #expect(ExtractionPrompt.version == "extract-v18" && DeviceReader.version == "device-2")
        let first = ExtractionPrompt.user(mail: "Der umzug ist für dne 1.2.2027 geplant", sent: nil, owner: [], matters: [], first: true)
        #expect(first.contains(ExtractionPrompt.firstMatter))
        #expect(!ExtractionPrompt.user(mail: "x", sent: nil, owner: [], matters: []).contains(ExtractionPrompt.firstMatter), "a first mail is no first step")
        #expect(!ExtractionPrompt.user(mail: "x", sent: nil, owner: [], matters: [("Umzug", "")], first: true).contains(ExtractionPrompt.firstMatter))
        // No shortcut past the best reader any more; both apps say what is first.
        for path in ["Sources/Causabee/Conversation.swift", "Sources/CausabeePhone/PhoneShots.swift"] {
            let text = try Self.source(path)
            #expect(!text.contains("readsOnDevice") && text.contains("first: matters.isEmpty"), "\(path)")
        }
    }

    @Test("F008 AC-4 · Nothing made up: a name and dates only from the line's own words")
    func grounded() throws {
        let line = "Der umzug ist für dne 1.2.2027 geplant"
        #expect(!Welcome.grounded("move", in: line) && !Welcome.grounded("die Verteilung", in: line) && !Welcome.grounded("den Tag", in: line))
        #expect(Welcome.grounded("Umzug", in: line))
        #expect(Welcome.grounded("Steuererklärung", in: "Steuererklrung bis 31. Juli"), "a typo fixed is the line's word")
        #expect(Welcome.grounded("Care for Mum", in: "Mum fell. The care service visits on Thursday."))
        #expect(Welcome.matterName(proposed: "move", typed: line) != "move")
        #expect(Welcome.matterName(proposed: "Umzug", typed: line) == "Umzug")
        // A made-up date label takes the matter's name; two dates on one day from one line are one.
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("grounded-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let look = try ScreenshotDoor(besides: folder.appendingPathComponent("store.sqlite")).look(at: Welcome.typedFile(line, in: folder), owner: "Alex")
        var judgement = try #require(look.report.outcomes.first?.judgement)
        judgement.appointments = [Judgement.Appointment(what: "die Verteilung", date: "2027-02-01", time: nil, place: nil, sourceQuote: "")]
        judgement.deadlines = [Judgement.Deadline(what: "den Tag", date: "2027-02-01", sourceQuote: "")]
        Welcome.nameDates(&judgement, name: "Umzug", line: line)
        #expect(judgement.appointments.map(\.what) == ["Umzug"] && judgement.deadlines.isEmpty)
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

    @Test("F008 AC-13 · Notifications asked later, not at the door")
    func notificationsLater() throws {
        #expect(!Welcome.mayAskNotifications(starts: 0) && !Welcome.mayAskNotifications(starts: 1))
        #expect(Welcome.mayAskNotifications(starts: 2) && Welcome.mayAskNotifications(starts: 5))
        // Every system question waits for it; both apps count their starts.
        let actions = try Self.source("Sources/Causabee/CardActions.swift")
        let asks = actions.components(separatedBy: "requestAuthorization(").count - 1
        let guarded = actions.components(separatedBy: "NewsNotice.mayAsk, ").count - 1
        #expect(asks > 0 && asks == guarded, "\(asks) questions, \(guarded) waiting for the second start")
        #expect(try Self.source("Sources/CausabeePhone/PhoneApp.swift").contains("Welcome.countStart()"))
        #expect(try Self.source(Self.macApp).contains("Welcome.countStart()"))
    }

    @Test("F008 AC-14 · The start credit, asked for at the first start on every device")
    func startAsked() throws {
        for path in [Self.macApp, "Sources/CausabeePhone/PhoneApp.swift"] {
            #expect(try Self.source(path).contains("BeeServer.shared.askStart()"), "\(path)")
        }
        let bee = try Self.source("Sources/Causabee/BeeServer.swift")
        #expect(bee.contains("AppTransaction.shared") && bee.contains("v1/start") && bee.contains("!DemoData.isRequested"))
        // Once per install, whatever token is kept: the beeserver decides (13 November, for the owner's tries).
        #expect(!bee.contains("token == nil || fresh"))
    }

    @Test("F008 AC-15 · Said once, plainly, and named in Pro's use")
    func startSaid() {
        #expect(Welcome.startLine == "A start credit is yours: Pro reads your first things, names disguised.")
        #expect(Welcome.showsStartLine(startCredit: true, extraShare: 0.333))
        #expect(!Welcome.showsStartLine(startCredit: true, extraShare: 0.2), "partly used: no longer said")
        #expect(!Welcome.showsStartLine(startCredit: false, extraShare: 0.333), "a bought top-up is no start credit")
        let meter = ProMeter(monthUsed: nil, extraShare: 0.333, kind: "credit", renewsOn: nil, pro: false, startCredit: true)
        #expect(meter.bars.first?.words == "of a Pro month in your start credit")
        #expect(meter.bars.first?.spoken == "Start credit: 33 percent of a Pro month left")
        #expect(meter.line == "Kept until it is used.")
        let bought = ProMeter(monthUsed: nil, extraShare: 0.333, kind: "credit", renewsOn: nil, pro: false)
        #expect(bought.bars.first?.words == "of a Pro month in top-ups")
    }

    @Test("F008 AC-16 · It works as a top-up does, on every plan")
    func startWorks() {
        // Pro's reader is on with credit alone, whatever the plan: the start credit is credit.
        #expect(Plan.proIsOn(switched: true, plan: .free, credit: true))
        #expect(Plan.proIsOn(switched: true, plan: .matters, credit: true))
    }

    @Test("F008 AC-17 · Used: back to the device, and a top-up offered once")
    func startUsed() throws {
        #expect(Welcome.offersTopUp(matters: 1, startCredit: true, extraShare: 0, pro: false, counted: true, later: false))
        #expect(!Welcome.offersTopUp(matters: 1, startCredit: true, extraShare: 0.1, pro: false, counted: true, later: false), "still some left")
        #expect(!Welcome.offersTopUp(matters: 1, startCredit: true, extraShare: 0, pro: true, counted: true, later: false), "Pro has its own words")
        #expect(!Welcome.offersTopUp(matters: 1, startCredit: true, extraShare: 0, pro: false, counted: true, later: true), "Not now is for good")
        #expect(!Welcome.offersTopUp(matters: 1, startCredit: false, extraShare: 0, pro: false, counted: true, later: false), "a bought top-up used: as today")
        #expect(!Welcome.offersTopUp(matters: 0, startCredit: true, extraShare: 0, pro: false, counted: true, later: false))
        #expect(Welcome.startUsedTitle == "Your start credit is used.")
        // On both overviews, before the mail card; Top up opens "Pro, now and then".
        for path in ["Sources/Causabee/AssistantView.swift", Self.phoneOverview] {
            let text = try Self.source(path)
            let card = try #require(text.range(of: "StartCreditUsed(matters:"))
            let mail = try #require(text.range(of: "MailOffer(matters:"))
            #expect(card.lowerBound < mail.lowerBound, "\(path)")
        }
        #expect(try Self.source(Self.firstStep).contains("Store.shared.asks = .topUp"))
    }
}
