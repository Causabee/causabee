import Foundation
import Testing
@testable import MatterCore

@Suite("The Phase 0 pipeline and its log")
struct SpikeTests {
    let spike = Spike(detector: EntityDetector(runsTagger: false))

    func email(_ source: String, name: String = "x.eml") -> Email {
        EMLParser.parse(source: source, url: URL(fileURLWithPath: "/tmp/\(name)"))
    }

    @Test("Bulk mail stops at the filter: no tagger, no entities, nothing to disguise")
    func bulkStopsThere() {
        let decision = spike.run(on: email("""
        From: Baumarkt <newsletter@example.com>
        To: Annegret Berger <post@berger-hv.example>
        List-Unsubscribe: <https://example.com/abmelden>

        Herbstaktion in der Wabenhöfer Allee 12, 10435 Berlin. IBAN DE89 3704 0044 0532 0130 00
        """)).judgement

        #expect(decision.isBulk)
        #expect(decision.decidedBy == .rule)
        #expect(decision.entities.isEmpty)
    }

    @Test("With the filter off, a labelled mail from a noreply sender is kept")
    func filterOff() {
        let decision = Spike(detector: EntityDetector(runsTagger: false), filtersBulk: false)
            .run(on: email("From: no-reply@tomorro.example\nAuto-Submitted: auto-generated\n\nBitte unterschreiben")).judgement
        #expect(!decision.isBulk)
        #expect(decision.bulkRule == nil)
    }

    @Test("A mail that gets past it is not classified, and says so rather than guessing")
    func nothingIsClassifiedYet() {
        let decision = spike.run(on: email("""
        From: Annegret Berger <post@berger-hv.example>

        Die Sonderumlage ist bis zum 30.11.2025 fällig.
        """)).judgement

        #expect(!decision.isBulk)
        #expect(decision.matter == nil)
        #expect(decision.matterConfidence == 0)
        #expect(decision.decidedBy == .pending)
        #expect(decision.parties.isEmpty)
        #expect(decision.todos.isEmpty)
        #expect(decision.deadlines.isEmpty)
        #expect(decision.stages == ["parse", "bulk_filter", "entity_detection"])
    }

    @Test("A decision points back at its original rather than carrying a copy of it")
    func pointsAtTheOriginal() {
        let outcome = spike.run(on: email("Message-ID: <abc@example.net>\n\nHallo", name: "01.eml"))
        #expect(outcome.judgement.emailID == "abc@example.net")
        #expect(outcome.judgement.source == "/tmp/01.eml")
    }

    @Test("The log writes the field names the plan fixed")
    func logKeysMatchThePlan() throws {
        var decision = spike.run(on: email("From: a@example.net\n\nHallo")).judgement
        decision.parties = [.init(name: "Annegret Berger", role: "Hausverwaltung", isNew: true)]
        decision.todos = [.init(text: "Angebote vergleichen", owner: .me, due: "2025-10-15",
                                sourceQuote: "bis zum 15. Oktober")]
        decision.deadlines = [.init(what: "Sonderumlage", date: "2025-11-30", sourceQuote: "bis zum 30.11.2025")]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let object = try JSONSerialization.jsonObject(with: encoder.encode(decision)) as? [String: Any]
        let json = try #require(object)

        for key in ["email_id", "is_bulk", "bulk_reason", "matter", "matter_confidence",
                    "matter_reason", "decided_by", "parties", "todos", "deadlines"] {
            #expect(json.keys.contains(key), "the plan's schema is missing \(key)")
        }
        #expect((json["parties"] as? [[String: Any]])?.first?["is_new"] as? Bool == true)
        #expect((json["todos"] as? [[String: Any]])?.first?["source_quote"] as? String == "bis zum 15. Oktober")
        #expect((json["deadlines"] as? [[String: Any]])?.first?["source_quote"] as? String == "bis zum 30.11.2025")
        // A field with nothing in it is written as null, not left out.
        #expect(json["matter"] is NSNull)
        #expect(json["bulk_reason"] is NSNull)
    }

    @Test("One mail, one line, appended as it goes")
    func oneLinePerMail() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("spike-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        for index in 1...3 {
            try "Message-ID: <\(index)@example.net>\nFrom: a@example.net\n\nHallo \(index)"
                .write(to: folder.appendingPathComponent("0\(index).eml"), atomically: true, encoding: .utf8)
        }
        // Not a mail, and not the pipeline's business.
        try "ignore me".write(to: folder.appendingPathComponent("notes.md"), atomically: true, encoding: .utf8)

        let log = try JudgementLog(url: folder.appendingPathComponent("decisions.jsonl"))
        let report = try spike.run(folder: folder, log: log)
        try log.close()

        #expect(report.outcomes.count == 3)
        #expect(report.failures.isEmpty)

        let lines = try String(contentsOf: log.url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines.count == 3)
        for line in lines {
            #expect((try? JSONSerialization.jsonObject(with: Data(line.utf8))) != nil)
        }
    }

    @Test("The report counts what the first four questions ask about")
    func reportCounts() throws {
        let kept = spike.run(on: email("From: post@berger-hv.example\n\nIBAN DE89 3704 0044 0532 0130 00"))
        let bulk = spike.run(on: email("From: x@example.com\nPrecedence: bulk\n\nHallo"))
        var report = Spike.Report()
        report.outcomes = [kept, bulk]

        #expect(report.bulk.count == 1)
        #expect(report.kept.count == 1)
        #expect(report.byRule[.precedenceBulk] == 1)
        #expect(report.byKind[.iban] == 1)
        // The IBAN in the body and the sender's own address: rules find both.
        #expect(report.bySource[.rule] == 2)
    }
}
