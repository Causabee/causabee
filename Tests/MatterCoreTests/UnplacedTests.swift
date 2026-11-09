import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("Mail read but found no matter")
@MainActor
struct UnplacedTests {
    func line(_ id: String, matter: String?, daysAgo: Double) -> String {
        let date = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-daysAgo * 86_400))
        let json: [String: Any] = [
            "email_id": id, "source": "imap://x;UID=1", "date": date, "subject": "Buchungsbeleg \(id)", "from": "x@example.org",
            "is_bulk": false, "matter": matter as Any? ?? NSNull(), "matter_confidence": 0.5, "matter_reason": "", "decided_by": "claude",
            "parties": [], "todos": [], "deadlines": [], "appointments": [["what": "Mietwagen abholen", "date": "2026-10-20", "time": "10:00", "place": NSNull(), "source_quote": "…"]],
            "done": [], "extraction": ["model": "claude-opus-5", "mode": "placeholder", "prompt": "extract-v13", "served_by": "claude-opus-5", "input_tokens": 0, "output_tokens": 0, "cost_usd": 0.0, "seconds": 0.0, "cached": false],
        ]
        return String(decoding: try! JSONSerialization.data(withJSONObject: json), as: UTF8.self)
    }

    @Test("Offered while in no matter and not set aside; put into one with what it found; then gone from the list")
    func place() throws {
        let log = FileManager.default.temporaryDirectory.appendingPathComponent("log-\(UUID()).jsonl")
        defer { try? FileManager.default.removeItem(at: log) }
        try [line("a", matter: nil, daysAgo: 1), line("b", matter: "reise", daysAgo: 1), line("c", matter: nil, daysAgo: 90), line("d", matter: nil, daysAgo: 2)]
            .joined(separator: "\n").write(to: log, atomically: true, encoding: .utf8)
        let context = ModelContext(try MatterSchema.container(at: nil))
        let trip = Matter(key: "bayonne-reise", name: "Bayonne Reise")
        context.insert(trip)
        try context.save()

        #expect(Unplaced.find(log: log, context: context, setAside: ["d"]).map(\.emailID) == ["a"])
        let mail = try #require(Unplaced.find(log: log, context: context, setAside: []).first { $0.emailID == "a" })
        try Unplaced.place(mail, in: trip, context: context, owner: [])
        #expect((trip.entries ?? []).map(\.messageID) == ["a"])
        #expect((trip.appointments ?? []).first?.what == "Mietwagen abholen")
        #expect(Unplaced.find(log: log, context: context, setAside: []).map(\.emailID) == ["d"])
        #expect(Unplaced.matters(in: context).map(\.key) == ["bayonne-reise"])
    }

    @Test("A mail with no matter starts a new one the owner names, with what it found")
    func start() throws {
        let log = FileManager.default.temporaryDirectory.appendingPathComponent("log-\(UUID()).jsonl")
        defer { try? FileManager.default.removeItem(at: log) }
        try line("a", matter: nil, daysAgo: 1).write(to: log, atomically: true, encoding: .utf8)
        let context = ModelContext(try MatterSchema.container(at: nil))
        let mail = try #require(Unplaced.find(log: log, context: context, setAside: []).first)
        let matter = try Unplaced.start(mail, named: "Neue Reise", context: context, owner: [])
        #expect(matter.name == "Neue Reise")
        #expect((matter.entries ?? []).map(\.messageID) == ["a"])
        #expect((matter.appointments ?? []).first?.what == "Mietwagen abholen")
        #expect(Unplaced.find(log: log, context: context, setAside: []).isEmpty)
    }

    @Test("Closed matters answer by key, name and alias; open ones are not among them")
    func closed() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let done = Matter(key: "alt", name: "Alte Sache")
        done.aliases = ["Frueher"]
        done.closedAt = Date()
        context.insert(done)
        context.insert(Matter(key: "offen", name: "Offen"))
        try context.save()
        #expect(Unplaced.closed(in: context) == ["alt", "alte sache", "frueher"])
    }
}

@Suite("What an item with no matter shows, to decide where it goes")
@MainActor
struct UnplacedLookTests {
    func judgement(_ extra: [String: Any]) throws -> Judgement {
        var json: [String: Any] = [
            "email_id": "a", "source": "imap://x;UID=1", "date": "2026-11-08T09:00:00Z", "subject": "Ihre Buchung", "from": "\"Anna Berg\" <anna@example.org>",
            "is_bulk": false, "matter": NSNull(), "matter_confidence": 0.3, "matter_reason": "Fits none of the open matters", "decided_by": "claude",
            "parties": [["name": "Anna Berg", "role": "agent", "is_new": true]],
            "todos": [["text": "Pay the deposit", "owner": "me", "due": "2026-11-20", "source_quote": "…", "same_as": NSNull(), "id": NSNull()]],
            "deadlines": [["what": "Cancel for free", "date": "2026-11-15", "source_quote": "…"]],
            "appointments": [["what": "Pick up the car", "date": "2026-12-01", "time": "10:00", "place": "Airport", "source_quote": "…"]],
            "done": [], "digest": "A car booked for 1 December.",
            "extraction": ["model": "m", "mode": "x", "prompt": "p", "served_by": "m", "input_tokens": 0, "output_tokens": 0, "cost_usd": 0.0, "seconds": 0.0, "cached": false],
        ]
        json.merge(extra) { _, new in new }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Judgement.self, from: JSONSerialization.data(withJSONObject: json))
    }

    @Test("Sender, what it says, what was found in it — tasks, dates, deadlines, people — and why")
    func everything() throws {
        let look = UnplacedLook(try judgement([:]))
        #expect(look.title == "Ihre Buchung")
        #expect(look.from == "Anna Berg")
        #expect(look.about == "A car booked for 1 December.")
        #expect(look.found.map(\.kind) == [.task, .appointment, .deadline, .person])
        #expect(look.found[0].text.hasPrefix("Pay the deposit · by "))
        #expect(look.found[1].text.contains("10:00") && look.found[1].text.hasSuffix("Airport"))
        #expect(look.found[3].text == "Anna Berg · agent")
        #expect(look.why == "Fits none of the open matters")
    }

    @Test("Nothing found, no summary, an address only, the bee's working notes: nothing made up", arguments: ["", "Yours to place", "Read on this device", "not sent: too long"])
    func bare(reason: String) throws {
        let look = UnplacedLook(try judgement(["subject": "", "from": "<x@example.org>", "digest": "  ", "matter_reason": reason,
                                               "parties": [], "todos": [], "deadlines": [], "appointments": []]))
        #expect(look.title == "(no subject)")
        #expect(look.from == "x@example.org")
        #expect(look.about == nil && look.found.isEmpty && look.why == nil)
    }
}
