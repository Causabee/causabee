import Foundation
import Testing
@testable import MatterCore

/// Nothing here touches the network. The client is tested on the requests it would build and
/// the responses it is handed; the one test that runs the whole step does it as a dry run.
@Suite("Asking Claude, and reading the answer")
struct ExtractorTests {
    @Test("Opus gets the refusal fallback and an effort; Haiku gets neither")
    func bodyPerModel() throws {
        let opus = Claude.body(model: .opus, system: "s", user: "u", schema: ExtractionPrompt.schema, effort: "medium")
        #expect(opus["fallbacks"] as? String == "default")
        #expect((opus["output_config"] as? [String: Any])?["effort"] as? String == "medium")

        let haiku = Claude.body(model: .haiku, system: "s", user: "u", schema: ExtractionPrompt.schema, effort: "medium")
        #expect(haiku["fallbacks"] == nil)
        #expect((haiku["output_config"] as? [String: Any])?["effort"] == nil)
        let format = try #require((haiku["output_config"] as? [String: Any])?["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
    }

    @Test("Every object in the schema closes itself, as structured outputs require")
    func schemaIsClosed() {
        func check(_ node: Any) {
            if let object = node as? [String: Any] {
                if object["type"] as? String == "object" {
                    #expect(object["additionalProperties"] as? Bool == false)
                    let properties = (object["properties"] as? [String: Any])?.keys.sorted() ?? []
                    #expect((object["required"] as? [String])?.sorted() == properties)
                }
                object.values.forEach(check)
            } else if let array = node as? [Any] {
                array.forEach(check)
            }
        }
        check(ExtractionPrompt.schema)
    }

    @Test("The answer is the text block, after any thinking")
    func readsTheAnswer() throws {
        let response = #"""
        {"model":"claude-opus-5","stop_reason":"end_turn","usage":{"input_tokens":1200,"output_tokens":90},
         "content":[{"type":"thinking","thinking":""},{"type":"text","text":"{\"matter\":null}"}]}
        """#
        let answer = try Claude.answer(from: Data(response.utf8), seconds: 2)
        #expect(String(decoding: answer.json, as: UTF8.self) == #"{"matter":null}"#)
        #expect(answer.inputTokens == 1200 && answer.outputTokens == 90)
        #expect(answer.servedBy == "claude-opus-5")
    }

    @Test("A dated snapshot is the model that was asked, and is priced as it")
    func datedSnapshot() {
        #expect(Claude.Model.haiku.isServing("claude-haiku-4-5-20251001"))
        #expect(!Claude.Model.opus.isServing("claude-opus-4-8"))
        #expect(Claude.Model.serving("claude-haiku-4-5-20251001") == .haiku)
        let extractor = Extractor(model: .haiku, claude: nil, cache: URL(fileURLWithPath: "/tmp"))
        let answer = Claude.Answer(json: Data(), servedBy: "claude-haiku-4-5-20251001",
                                   inputTokens: 1_000_000, outputTokens: 100_000, seconds: 1)
        #expect(abs(extractor.cost(of: answer) - 1.5) < 0.0001)
    }

    @Test("A refusal and a cut-off answer are errors, not answers")
    func refusalAndTruncation() {
        let refused = #"{"stop_reason":"refusal","stop_details":{"type":"refusal","category":"cyber"},"content":[]}"#
        #expect(throws: Claude.Failure.self) { try Claude.answer(from: Data(refused.utf8), seconds: 0) }
        let cut = #"{"stop_reason":"max_tokens","content":[{"type":"text","text":"{\"mat"}]}"#
        #expect(throws: Claude.Failure.self) { try Claude.answer(from: Data(cut.utf8), seconds: 0) }
    }

    @Test("The key comes from the environment first, then from .env, quotes or not")
    func key() throws {
        let file = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("env-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: file) }
        try "# comment\nOTHER=1\nANTHROPIC_API_KEY=\"sk-ant-test\"\n".write(to: file, atomically: true, encoding: .utf8)
        #expect(Claude.key(environment: [:], dotEnv: file, keychain: false) == "sk-ant-test")
        #expect(Claude.key(environment: ["ANTHROPIC_API_KEY": "sk-ant-env"], dotEnv: file, keychain: false) == "sk-ant-env")
        try "ANTHROPIC_API_KEY=\n".write(to: file, atomically: true, encoding: .utf8)
        #expect(Claude.key(environment: [:], dotEnv: file, keychain: false) == nil)
    }

    @Test("A link goes as [link], never with its tracking code")
    func links() {
        let disguise = Disguise(mode: .placeholder, subject: "s", from: "f", to: [], cc: [],
                                body: "Rechnung ( http://clicks.shop.example/f/a/h4hXjmeQBBgANdSB~~ ) und www.shop.example/x?id=42.",
                                attachmentNames: [], replacements: 0)
        let text = Extractor.text(of: disguise)
        #expect(!text.contains("h4hXjmeQ") && !text.contains("id=42"))
        #expect(text.contains("( [link] )"))
    }

    @Test("A link in the subject or an attachment's name goes as [link] too")
    func linksInHeaders() {
        let disguise = Disguise(mode: .placeholder, subject: "Doc https://docs.example/d/1AbCdSECRET/edit", from: "f", to: [], cc: [],
                                body: "Anbei.", attachmentNames: ["Link www.files.example/x?id=77.pdf"], replacements: 0)
        let text = Extractor.text(of: disguise)
        #expect(!text.contains("SECRET") && !text.contains("id=77"))
        #expect(text.contains("Subject: Doc [link]"))
    }

    @Test("Step 6 puts the real names back into everything the model wrote")
    func restores() throws {
        var pseudonymizer = Pseudonymizer(mode: .placeholder)
        pseudonymizer.learn([Entity(kind: .person, text: "Annegret Berger", field: .body, start: 0, length: 15, source: .rule)])
        let found = Extractor.Found(
            matter: "hausverwaltung", matterIsNew: true, matterSummary: nil, matterConfidence: 0.9,
            matterReason: "[Person A] schreibt als Verwalterin",
            parties: [.init(name: "[Person A]", role: "Hausverwaltung", isNew: true)],
            todos: [.init(text: "[Person A] zurückrufen", owner: .me, due: "2025-10-09", sourceQuote: "Frau [Person A] bittet")],
            deadlines: [])
        var decision = Spike(detector: EntityDetector(runsTagger: false))
            .run(on: EMLParser.parse(source: "From: a@example.net\n\nx", url: URL(fileURLWithPath: "/tmp/x.eml"))).judgement
        Extractor(model: .opus, claude: nil, cache: URL(fileURLWithPath: "/tmp")).apply(found, to: &decision, restorer: pseudonymizer.restorer)

        #expect(decision.parties.first?.name == "Annegret Berger")
        #expect(decision.todos.first?.text == "Annegret Berger zurückrufen")
        #expect(decision.todos.first?.sourceQuote == "Frau Annegret Berger bittet")
        #expect(decision.matterReason == "Annegret Berger schreibt als Verwalterin")
        #expect(decision.decidedBy == .claude)
    }

    @Test("A dry run writes one request per kept mail, and no original name is in any of them")
    func dryRunSendsNothingIdentifiable() async throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("extract-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try """
        From: Hausverwaltung Berger GmbH <post@berger-hv.example>
        To: Jan Kramer <jan@example.net>
        Date: Mon, 22 Sep 2025 09:14:02 +0200
        Subject: Heizung Honigwabenallee 47

        Die Begehung in der Honigwabenallee 47, 10435 Berlin ist am 9. Oktober. Tel. 030 0471 2288
        """.write(to: folder.appendingPathComponent("01.eml"), atomically: true, encoding: .utf8)
        try "From: news@shop.example\nList-Unsubscribe: <https://shop.example/x>\n\nAngebot"
            .write(to: folder.appendingPathComponent("02.eml"), atomically: true, encoding: .utf8)

        var report = try Spike(detector: EntityDetector(runsTagger: false))
            .run(folder: folder, log: nil, pseudonymizer: Pseudonymizer(mode: .placeholder))
        let requests = folder.appendingPathComponent("requests.jsonl")
        let owner = Extractor.owner(named: [], in: report.outcomes)
        #expect(owner.contains("jan@example.net"))

        _ = try await Extractor(model: .opus, claude: nil, cache: folder.appendingPathComponent("cache"))
            .run(&report.outcomes, pseudonymizer: try #require(report.pseudonymizer), owner: owner, dryRun: requests)

        let lines = try String(contentsOf: requests, encoding: .utf8).split(separator: "\n")
        #expect(lines.count == 1)  // the newsletter is bulk and never sent
        for original in ["Berger", "berger-hv", "Honigwabenallee", "10435", "Berlin", "0471", "Kramer", "jan@example.net"] {
            #expect(!lines[0].contains(original), "\(original) would have been sent")
        }
        #expect(lines[0].contains("2025-09-22"))  // dates are not identifying, and the model needs them
    }

    @Test("A mail answered before is not sent again, and the next mail is still told what it found")
    func classifiedOnce() async throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("once-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try "Message-ID: <a@x.example>\nFrom: post@hv.example\nDate: Mon, 1 Sep 2025 09:00:00 +0200\nSubject: Vertrag\n\nBitte den Vertrag schicken."
            .write(to: folder.appendingPathComponent("01.eml"), atomically: true, encoding: .utf8)
        try "Message-ID: <b@x.example>\nFrom: post@hv.example\nDate: Tue, 2 Sep 2025 09:00:00 +0200\nSubject: Re: Vertrag\n\nUnd die Liste."
            .write(to: folder.appendingPathComponent("02.eml"), atomically: true, encoding: .utf8)
        try "Message-ID: <c@x.example>\nFrom: post@hv.example\nDate: Wed, 3 Sep 2025 09:00:00 +0200\nSubject: Noch was\n\nTermin?"
            .write(to: folder.appendingPathComponent("03.eml"), atomically: true, encoding: .utf8)

        var report = try Spike(detector: EntityDetector(runsTagger: false))
            .run(folder: folder, log: nil, pseudonymizer: Pseudonymizer(mode: .placeholder))
        var first = try #require(report.outcomes.first { $0.judgement.emailID == "a@x.example" }).judgement
        first.matter = "hausverwaltung"
        first.decidedBy = .claude
        first.todos = [.init(text: "Vertrag schicken", owner: .me, due: nil, sourceQuote: "", sameAs: nil, id: "T5")]
        first.extraction = .init(model: "claude-opus-5", servedBy: "claude-opus-5", mode: "placeholder", prompt: ExtractionPrompt.version)
        var failed = try #require(report.outcomes.first { $0.judgement.emailID == "c@x.example" }).judgement
        failed.extraction = .init(model: "claude-opus-5", servedBy: "", mode: "placeholder", prompt: ExtractionPrompt.version)
        failed.extraction?.error = "HTTP 529"

        let requests = folder.appendingPathComponent("requests.jsonl")
        let summary = try await Extractor(model: .opus, claude: nil, cache: folder.appendingPathComponent("cache"))
            .run(&report.outcomes, pseudonymizer: try #require(report.pseudonymizer), owner: [], dryRun: requests,
                 known: [first.emailID: first, failed.emailID: failed])

        #expect(summary.kept == 1)
        let lines = try String(contentsOf: requests, encoding: .utf8).split(separator: "\n")
        #expect(lines.count == 2)  // the new reply, and the one that failed before; not the one answered
        #expect(lines[0].contains("Vertrag schicken") && lines[0].contains("T5") && lines[0].contains("hausverwaltung"))
        #expect(report.outcomes.first { $0.judgement.emailID == "a@x.example" }?.judgement.todos.first?.id == "T5")
    }

    @Test("Only today's mail is read, and it is still told what the earlier ones found")
    func onlyTodaysMail() async throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("today-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try "Message-ID: <b@x.example>\nIn-Reply-To: <a@x.example>\nFrom: post@hv.example\nDate: Tue, 2 Sep 2025 09:00:00 +0200\nSubject: Re: Vertrag\n\nUnd die Liste."
            .write(to: folder.appendingPathComponent("02.eml"), atomically: true, encoding: .utf8)
        var report = try Spike(detector: EntityDetector(runsTagger: false))
            .run(folder: folder, log: nil, pseudonymizer: Pseudonymizer(mode: .placeholder))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let json = #"{"email_id":"a@x.example","source":"imap://x","date":"2025-09-01T07:00:00Z","subject":"Vertrag","from":"post@hv.example","is_bulk":false,"matter":"hausverwaltung","matter_confidence":1,"matter_reason":"Vertrag","decided_by":"claude","parties":[],"deadlines":[],"todos":[{"text":"Vertrag schicken","owner":"me","due":null,"source_quote":"","same_as":null,"id":"T5"}],"extraction":{"model":"claude-opus-5","served_by":"claude-opus-5","mode":"placeholder","prompt":"extract-v8","input_tokens":0,"output_tokens":0,"cost_usd":0,"seconds":0,"cached":false}}"#
        let earlier = try decoder.decode(Judgement.self, from: Data(json.utf8))

        let requests = folder.appendingPathComponent("requests.jsonl")
        let summary = try await Extractor(model: .opus, claude: nil, cache: folder.appendingPathComponent("cache"))
            .run(&report.outcomes, pseudonymizer: try #require(report.pseudonymizer), owner: [], dryRun: requests,
                 known: [earlier.emailID: earlier])
        #expect(summary.kept == 1)
        let lines = try String(contentsOf: requests, encoding: .utf8).split(separator: "\n")
        #expect(lines.count == 1)
        #expect(lines[0].contains("T5") && lines[0].contains("Vertrag schicken") && lines[0].contains("hausverwaltung"))
    }

    @Test("The record keeps every earlier answer when today's are written into it")
    func recordMerges() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("record-\(UUID()).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        func judgement(_ id: String, _ day: String) throws -> Judgement {
            try decoder.decode(Judgement.self, from: Data(#"{"email_id":"\#(id)","source":"x","date":"\#(day)T07:00:00Z","subject":"s","from":"f","is_bulk":false,"matter":null,"matter_confidence":0,"matter_reason":"","decided_by":"pending","parties":[],"todos":[],"deadlines":[]}"#.utf8))
        }
        try DailyDoor.write([try judgement("b", "2025-09-02"), try judgement("a", "2025-09-01")], plus: [], to: url)
        try DailyDoor.write(Array(DailyDoor.readLog(url).values), plus: [try judgement("c", "2025-09-03")], to: url)
        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
        #expect(lines.count == 3)
        #expect(lines.map { $0.contains("\"email_id\":\"a\"") } == [true, false, false])
    }

    @Test("A replayed to-do keeps its id, and the next new one comes after it")
    func replayKeepsIDs() {
        var book = TodoBook()
        book.replay(matter: "hv", todos: [("T5", "Vertrag schicken", .me, nil)], done: [])
        let found = book.record(.init(matter: "hv", matterIsNew: false, matterSummary: nil, matterConfidence: 1, matterReason: "",
                                      parties: [], todos: [.init(text: "Liste schicken", owner: .me, due: nil, sourceQuote: "", sameAs: nil)],
                                      deadlines: [], done: [], appointments: []))
        #expect(found.todos.first?.id == "T6")
        #expect(book.open(for: "hv", matters: ["hv"]).first?.todos.map(\.id) == ["T5", "T6"])
    }

    @Test("A matter keeps one list: a repeat joins its entry, a done closes it, a wrong id is a new one")
    func todoBook() {
        var book = TodoBook()
        func found(_ todos: [(String, String?)], done: [String] = []) -> Extractor.Found {
            .init(matter: "hv", matterIsNew: false, matterSummary: nil, matterConfidence: 1, matterReason: "",
                  parties: [], todos: todos.map { .init(text: $0.0, owner: .other, due: nil, sourceQuote: "", sameAs: $0.1) },
                  deadlines: [], done: done.map { .init(todo: $0, sourceQuote: "hier der Vertrag") }, appointments: [])
        }
        let first = book.record(found([("Vertrag schicken", nil)]))
        #expect(first.todos.first?.id == "T1")
        #expect(book.open(for: "hv", matters: ["hv"]).first?.todos.map(\.id) == ["T1"])

        let again = book.record(found([("Vertrag noch schicken", "T1"), ("Liste schicken", "T9")]))
        #expect(again.todos.map(\.id) == ["T1", "T2"])
        #expect(again.todos.map(\.sameAs) == ["T1", nil])  // T9 does not exist: kept as new

        let closed = book.record(found([], done: ["T1", "T7"]))
        #expect(closed.done?.map(\.todo) == ["T1"])
        #expect(book.open(for: "hv", matters: ["hv"]).first?.todos.map(\.id) == ["T2"])
    }

    @Test("The instructions are marked for the prompt cache, and the mark does not change the answer cache's key")
    func promptCache() throws {
        let body = Claude.body(model: .opus, system: "Anweisungen", user: "Mail", schema: ExtractionPrompt.schema, effort: nil)
        let system = try #require(body["system"] as? [[String: Any]])
        #expect((system.first?["cache_control"] as? [String: String])?["type"] == "ephemeral")
        var old = body
        old["system"] = "Anweisungen"
        #expect(try Claude.cacheKey(body) == Claude.cacheKey(old))
    }

    @Test("Cached input costs a tenth to read and a quarter more to write")
    func cachePricing() {
        let opus = Claude.Model.opus
        #expect(abs(opus.cost(input: 0, output: 0, cacheRead: 1_000_000) - 0.5) < 0.0001)
        #expect(abs(opus.cost(input: 0, output: 0, cacheWrite: 1_000_000) - 6.25) < 0.0001)
    }
}
