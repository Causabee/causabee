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
}
