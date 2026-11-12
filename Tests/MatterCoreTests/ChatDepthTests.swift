import Foundation
import SwiftData
import Testing
@testable import MatterCore

/// F005: a quick question is asked with what it needs of the matter — light — and a question
/// that needs the whole matter with all of it — deep. "Not there" only after the whole matter.
@Suite("F005 · The chat in two depths", .serialized)
@MainActor
struct ChatDepthTests {
    static let day: TimeInterval = 86_400
    static let start = Date(timeIntervalSince1970: 1_780_000_000)

    /// A full matter: months of what came in, screenshots with their words, tasks open and done,
    /// dates past and to come, files. `container` must stay alive while the matter is used.
    func fullMatter() throws -> (container: ModelContainer, matter: Matter, words: [String: String]) {
        let container = try MatterSchema.container(at: nil)
        let context = ModelContext(container)
        let matter = Matter(key: "umzug", name: "Umzug in die Lindenstraße")
        context.insert(matter)
        var words: [String: String] = [:]
        for n in 0..<80 {
            let date = Self.start.addingTimeInterval(Double(n) * Self.day)
            let kind: Source.Kind = n % 8 == 0 ? .screenshot : .mail
            let id = "m\(n)@example"
            let source = Source(kind: kind, pointer: "x", messageID: id, date: date, quote: "bitte bis Freitag \(n)")
            let title = n == 2 ? "Kostenvoranschlag vom Dachdecker Brettschneider" : "Nachricht \(n) der Spedition zum Transport am Samstag"
            let entry = Entry(title: title, from: "Spedition Kral <info@kral.example>", date: date, source: source)
            entry.digest = "Die Spedition bestätigt den Termin und fragt nach der Anzahl der Kisten, Liste \(n)."
            context.insert(entry)
            entry.matter = matter
            words[id] = String(repeating: "Wir kommen um acht mit zwei Leuten und dem großen Wagen, Nachricht \(n). ", count: 12)
        }
        for n in 0..<14 {
            let source = Source(kind: .mail, pointer: "x", messageID: "m\(60 + n)@example", date: Self.start.addingTimeInterval(Double(60 + n) * Self.day), quote: "Kisten \(n) bitte beschriften")
            let todo = Todo(text: "Kiste \(n) packen und beschriften", owner: .me, due: n == 0 ? "2026-12-01" : nil, source: source, origin: "t\(n)")
            context.insert(todo)
            todo.matter = matter
        }
        for n in 0..<25 {
            let source = Source(kind: .mail, pointer: "x", messageID: "d\(n)@example", date: Self.start.addingTimeInterval(Double(n) * Self.day))
            let todo = Todo(text: n == 3 ? "Halteverbotszone bei der Stadt beantragen" : "Erledigt \(n): Karton bestellt", owner: .me, due: nil, source: source, origin: "d\(n)")
            todo.isDone = true
            todo.doneAt = Self.start.addingTimeInterval(Double(n) * Self.day)
            context.insert(todo)
            todo.matter = matter
        }
        for (n, day) in ["2026-09-03", "2026-09-10", "2026-12-05"].enumerated() {
            let appointment = Appointment(what: n == 0 ? "Besichtigung mit dem Vermieter Ostrowski" : "Termin \(n)", day: day, time: "10:00", place: nil,
                                          source: Source(kind: .mail, pointer: "x", date: Self.start))
            context.insert(appointment)
            appointment.matter = matter
        }
        try context.save()
        return (container, matter, words)
    }

    func facts(_ matter: Matter, words: [String: String]) -> Facts {
        FactSheet.facts(for: [matter], today: "2026-11-11", keptText: { words[$0.messageID] })
    }

    func line(_ text: String, with words: String) -> String? {
        text.split(separator: "\n").map(String.init).first { $0.contains(words) }
    }

    // MARK: AC-1

    @Test("F005 AC-1 · The light text holds what a quick question needs, with the same ids")
    func lightHoldsWhatItNeeds() throws {
        let (container, matter, words) = try fullMatter()
        _ = container
        let facts = facts(matter, words: words)
        let light = try #require(facts.light, "a full matter has a light text")
        // What is open and what comes, with the same ids as in the whole matter.
        let todo = try #require(line(facts.text, with: "Kiste 0 packen"))
        let id = try #require(todo.split(separator: " ").first.map(String.init))
        #expect(line(light, with: "Kiste 0 packen")?.hasPrefix(id + " ") == true)
        #expect(light.contains("Termin 2"), "a date to come")
        #expect(light.contains("Nachricht 79 der Spedition"), "the newest that came in")
        // Not what only the whole matter needs.
        #expect(!light.contains("Halteverbotszone"), "a done task")
        #expect(!light.contains("Besichtigung mit dem Vermieter"), "a past date")
        #expect(!light.contains("Dachdecker"), "an item that came in long ago")
        #expect(!light.contains("bitte beschriften\""), "where an open task came from")
        #expect(light.contains("Not shown here: older items, done tasks, past dates, older files."))
        #expect(facts.text.contains("Halteverbotszone") && facts.text.contains("Dachdecker"), "the whole matter as today")
        #expect(!facts.text.contains("Not shown here"))
        #expect(facts.lightIDs.contains(id) && !facts.lightIDs.contains("E80"))
    }

    @Test("F005 AC-1 · A full matter's light text is at most half")
    func lightIsAtMostHalf() throws {
        let (container, matter, words) = try fullMatter()
        _ = container
        let facts = facts(matter, words: words)
        let light = try #require(facts.light)
        #expect(light.count * 2 <= facts.text.count, "light \(light.count), whole \(facts.text.count)")
    }

    @Test("F005 AC-1 · No light text where the sheet is short already: several matters, a pinned item, a small matter")
    func noLightText() throws {
        let (container, matter, words) = try fullMatter()
        let context = ModelContext(container)
        let small = Matter(key: "klein", name: "Kleine Sache")
        context.insert(small)
        let todo = Todo(text: "Anrufen", owner: .me, due: nil, source: Source(kind: .mail, pointer: "x", date: Self.start), origin: "a")
        context.insert(todo)
        todo.matter = small
        try context.save()
        #expect(FactSheet.facts(for: [matter, small], today: "2026-11-11").light == nil)
        #expect(FactSheet.facts(for: [matter], today: "2026-11-11", focus: "Kiste 3 packen", keptText: { words[$0.messageID] }).light == nil)
        #expect(FactSheet.facts(for: [small], today: "2026-11-11").light == nil)
    }

    @Test("F005 AC-1 · A quick question goes light")
    func quickGoesLight() throws {
        let (container, matter, words) = try fullMatter()
        _ = container
        let facts = facts(matter, words: words)
        for question in ["Erstelle eine Aufgabe für morgen: Umzugskartons kaufen", "Was steht als Nächstes an?",
                         "Notiz: Schlüssel liegt beim Nachbarn", "Remind me tomorrow to call the movers", "Wann kommt die Spedition?"] {
            #expect(ChatDepth.pick(question: question, facts: facts, after: nil) == .light, "\(question)")
        }
    }

    // MARK: AC-2, AC-4

    @Test("F005 AC-2 · A question that needs the whole matter goes deep")
    func searchGoesDeep() throws {
        let (container, matter, words) = try fullMatter()
        _ = container
        let facts = facts(matter, words: words)
        for question in ["Wo steht die Nummer vom Angebot?", "Find the number in the PDF", "Was hat die Spedition damals geschrieben?",
                         "Fasse alles zusammen, was bisher passiert ist", "Such mir die Rechnung raus", "Was steht im Anhang?"] {
            #expect(ChatDepth.pick(question: question, facts: facts, after: nil) == .deep, "\(question)")
        }
    }

    @Test("F005 AC-4 · An element only the whole matter holds sends the question deep")
    func elementOnlyDeep() throws {
        let (container, matter, words) = try fullMatter()
        _ = container
        let facts = facts(matter, words: words)
        for question in ["Was wollte der Dachdecker?", "Hab ich die Halteverbotszone schon beantragt?", "Verschieb die Besichtigung mit Ostrowski"] {
            #expect(ChatDepth.pick(question: question, facts: facts, after: nil) == .deep, "\(question)")
        }
    }

    // MARK: AC-5, AC-6

    @Test("F005 AC-5 · A follow-up never goes lighter")
    func followUpKeepsDepth() throws {
        let (container, matter, words) = try fullMatter()
        _ = container
        let facts = facts(matter, words: words)
        #expect(ChatDepth.pick(question: "Und für übermorgen auch eine", facts: facts, after: .deep) == .deep)
        #expect(ChatDepth.pick(question: "Und für übermorgen auch eine", facts: facts, after: .light) == .light)
        #expect(ChatDepth.pick(question: "Was hat der Dachdecker geschrieben?", facts: facts, after: .light) == .deep)
    }

    @Test("F005 AC-5 · A follow-up is one within the cache's 30 minutes; later, the depth is picked anew")
    func conversationIsTheCachesLife() throws {
        let now = Date()
        // Within 30 minutes: the depth before it, an answer from a build before F005 as deep.
        #expect(ChatDepth.following(.light, askedAt: now.addingTimeInterval(-10 * 60), now: now) == .light)
        #expect(ChatDepth.following(nil, askedAt: now.addingTimeInterval(-29 * 60), now: now) == .deep)
        // Later — the next hour, the next morning: a first question again.
        #expect(ChatDepth.following(.deep, askedAt: now.addingTimeInterval(-31 * 60), now: now) == nil)
        #expect(ChatDepth.following(nil, askedAt: now.addingTimeInterval(-14 * 3_600), now: now) == nil)
        // The Mac and the iPhone and iPad ask the rule, not a depth of their own.
        for path in ["Sources/Causabee/Conversation.swift", "Sources/CausabeePhone/AssistantSheet.swift"] {
            let source = try String(contentsOf: AIJobTests.root.appendingPathComponent(path), encoding: .utf8)
            #expect(source.contains("ChatDepth.following("), "\(path)")
            #expect(!source.contains("depth ?? .deep"), "\(path)")
        }
    }

    @Test("F005 AC-6 · The depth depends on the question and the matter alone")
    func sameEverywhere() throws {
        let (container, matter, words) = try fullMatter()
        _ = container
        let one = facts(matter, words: words)
        let two = facts(matter, words: words)
        #expect(one.light == two.light && one.text == two.text)
        for question in ["Was steht als Nächstes an?", "Wo steht die Nummer?", "Was wollte der Dachdecker?"] {
            #expect(ChatDepth.pick(question: question, facts: one, after: nil) == ChatDepth.pick(question: question, facts: two, after: nil))
        }
    }

    // MARK: AC-3

    func ask(_ facts: Facts, replies: [String]) async throws -> (answer: AssistantAsk.Answer, steps: [AssistantAsk.Step]) {
        DeeperStub.replies = replies
        DeeperStub.seen = []
        URLProtocol.registerClass(DeeperStub.self)
        defer { URLProtocol.unregisterClass(DeeperStub.self) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("depth-mapping-\(UUID()).json")
        let steps = StepLog()
        let answer = try await AssistantAsk.ask(question: "Was steht als Nächstes an?", inHand: nil, earlier: [], facts: facts, owner: nil,
                                                today: "2026-11-11", mapping: url, claude: Claude(key: "token", relay: URL(string: "https://deeper.test")!),
                                                depth: .light) { steps.add($0) }
        return (answer, steps.all)
    }

    static func reply(_ text: String, cites: [String] = [], notInFacts: String? = nil) -> String {
        let object: [String: Any] = ["lines": [["text": text, "cites": cites]], "cards": [], "not_in_facts": notInFacts ?? NSNull()]
        return String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }

    func sentText(_ request: URLRequest) throws -> String {
        let body = try #require(try JSONSerialization.jsonObject(with: DeeperStub.body(of: request)) as? [String: Any])
        return Claude.sentTexts(body).map(\.text).joined(separator: "\n")
    }

    @Test("F005 AC-3 · A light answer that lacks something is asked again deep, and only that answer is shown")
    func deeperWhenLacking() async throws {
        let (container, matter, words) = try fullMatter()
        _ = container
        let facts = facts(matter, words: words)
        let (answer, steps) = try await ask(facts, replies: [Self.reply("Steht nicht drin.", notInFacts: "Keine Angaben zum Dachdecker."),
                                                             Self.reply("Der Dachdecker schickte einen Kostenvoranschlag.", cites: ["E78"])])
        #expect(DeeperStub.seen.count == 2)
        #expect(DeeperStub.seen.map { $0.value(forHTTPHeaderField: "causabee-job") } == ["chat-light", "chat-deeper"])
        let first = try sentText(DeeperStub.seen[0]), second = try sentText(DeeperStub.seen[1])
        #expect(first.contains("Not shown here") && !first.contains("Dachdecker"))
        #expect(!second.contains("Not shown here") && second.contains("Dachdecker"))
        #expect(answer.reply.lines.map(\.text) == ["Der Dachdecker schickte einen Kostenvoranschlag."])
        #expect(answer.reply.notInFacts == nil)
        #expect(answer.depth == .deep && answer.wentDeeper == true)
        #expect(steps.contains(.lookingDeeper) && steps.last == .restoring)
        #expect(!steps.contains(.restoring) || steps.firstIndex(of: .restoring)! > steps.firstIndex(of: .lookingDeeper)!, "no names put back before it looks deeper")
    }

    @Test("F005 AC-3 · A light answer that cites what it was not shown is asked again deep")
    func deeperWhenCitingUnseen() async throws {
        let (container, matter, words) = try fullMatter()
        _ = container
        let facts = facts(matter, words: words)
        let unseen = try #require(facts.refs.keys.first { !facts.lightIDs.contains($0) })
        let (answer, _) = try await ask(facts, replies: [Self.reply("Siehe dort.", cites: [unseen]), Self.reply("Ganz.", cites: [unseen])])
        #expect(DeeperStub.seen.count == 2)
        #expect(answer.reply.lines.map(\.text) == ["Ganz."])
    }

    @Test("F005 AC-3 · A light answer that has what it needs is shown as it is: one ask")
    func lightWhenEnough() async throws {
        let (container, matter, words) = try fullMatter()
        _ = container
        let facts = facts(matter, words: words)
        let shown = try #require(facts.lightIDs.sorted().first)
        let (answer, steps) = try await ask(facts, replies: [Self.reply("Kiste 0 packen.", cites: [shown])])
        #expect(DeeperStub.seen.count == 1)
        #expect(DeeperStub.seen.first?.value(forHTTPHeaderField: "causabee-job") == "chat-light")
        #expect(answer.depth == .light && answer.wentDeeper != true)
        #expect(!steps.contains(.lookingDeeper))
    }

    // MARK: AC-8

    @Test("F005 AC-8 · The chat's three jobs, the app's and the server's")
    func threeJobs() throws {
        #expect(AIJob.chatLight.rawValue == "chat-light" && AIJob.chatDeeper.rawValue == "chat-deeper")
        for job in [AIJob.chat, .chatLight, .chatDeeper] {
            #expect(!job.flex, "\(job): someone waits")
            #expect(job.effort == AIJob.chat.effort)
        }
        #expect(AIJob.chatDeeper.model == AIJob.chat.model, "the deeper ask is the deep question's")
        let server = try AIJobTests.serverTable()
        #expect(server.jobs["chat-light"] != nil && server.jobs["chat-deeper"] != nil)
    }
}

/// The steps a question went through, from the closure `ask` calls.
final class StepLog: @unchecked Sendable {
    private let lock = NSLock()
    private var steps: [AssistantAsk.Step] = []
    func add(_ step: AssistantAsk.Step) { lock.lock(); steps.append(step); lock.unlock() }
    var all: [AssistantAsk.Step] { lock.lock(); defer { lock.unlock() }; return steps }
}

/// The beeserver, answering each request with the next of `replies`.
final class DeeperStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var seen: [URLRequest] = []
    nonisolated(unsafe) static var replies: [String] = []

    static func body(of request: URLRequest) -> Data { Stub.body(of: request) }

    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "deeper.test" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let n = Self.seen.count
        Self.seen.append(request)
        let text = n < Self.replies.count ? Self.replies[n] : DeeperStubDefault.reply
        let answer: [String: Any] = [
            "model": "gpt-6.1-sol", "status": "completed",
            "output": [["type": "message", "content": [["type": "output_text", "text": text]]]],
            "usage": ["input_tokens": 100, "output_tokens": 10],
        ]
        let data = try! JSONSerialization.data(withJSONObject: answer)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

enum DeeperStubDefault {
    static let reply = #"{"lines":[],"cards":[],"not_in_facts":null}"#
}
