import Foundation
import SwiftData
import Testing
@testable import MatterCore

/// What sorting in two mails costs on the owner's real store, step by step — on a copy, never the
/// store itself. Run with CAUSABEE_STORE_TIMING=1 on the owner's Mac.
@MainActor
@Suite(.serialized)
struct StoreTimingTests {
    nonisolated static let on = ProcessInfo.processInfo.environment["CAUSABEE_STORE_TIMING"] != nil

    func time<T>(_ label: String, _ work: () throws -> T) rethrows -> T {
        let start = Date()
        let result = try work()
        print(String(format: "TIMING %8.1f ms  %@", Date().timeIntervalSince(start) * 1000, label))
        return result
    }

    @Test(.enabled(if: on))
    func sortingInTwoMails() throws {
        let source = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Causabee")
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("causabee-timing-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: copy, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: copy) }
        for name in ["matters.store", "matters.store-wal", "matters.store-shm", "decisions-fetch.jsonl", "mapping.json"] {
            try? FileManager.default.copyItem(at: source.appendingPathComponent(name), to: copy.appendingPathComponent(name))
        }
        try? FileManager.default.copyItem(at: source.appendingPathComponent("Mail-Text"), to: copy.appendingPathComponent("Mail-Text"))
        let store = copy.appendingPathComponent("matters.store"), log = copy.appendingPathComponent("decisions-fetch.jsonl")

        let container = try time("open the store") { try MatterSchema.container(at: store) }
        let context = container.mainContext
        let matters = try time("fetch matters") { try context.fetch(FetchDescriptor<Matter>()) }
        print("  \(matters.count) matters, \(try context.fetchCount(FetchDescriptor<Entry>())) entries, \(try context.fetchCount(FetchDescriptor<Todo>())) tasks")
        _ = time("overview page, all matters") { OverviewPage(matters) }
        _ = time("overview page again") { OverviewPage(matters) }
        // What one summary is made of, over all matters — on a store opened fresh, as after a change.
        let fresh = ModelContext(container)
        let again = try fresh.fetch(FetchDescriptor<Matter>())
        _ = time("  parts · open tasks") { again.map { $0.openTodos.count } }
        _ = time("  parts · blocked") { again.map { $0.openTodos.filter(\.isBlocked).count } }
        _ = time("  parts · dates") { again.map { ($0.deadlines?.count ?? 0) + ($0.appointments?.count ?? 0) } }
        _ = time("  parts · mail dates") { again.map { MailDates.of($0, entries: $0.entries ?? []).count } }
        _ = time("  parts · the brief's news") { again.map { $0.brief == nil ? nil : $0.shownBrief?.news?.lines.first } }
        _ = time("  parts · the brief's news again") { again.map { $0.brief == nil ? nil : $0.shownBrief?.news?.lines.first } }
        _ = time("  whole page on the fresh context") { OverviewPage(again) }
        print("  briefs: \(again.compactMap(\.brief).map(\.count).reduce(0, +)) characters in \(again.compactMap(\.brief).count)")
        _ = time("Unplaced.matters") { Unplaced.matters(in: context) }
        _ = time("Unplaced.onFile") { Unplaced.onFile(in: context) }
        _ = time("Unplaced.placed") { Unplaced.placed(in: context) }
        _ = time("SortedMails.answered") { SortedMails.answered(in: context) }
        _ = time("SortedMails.answered again") { SortedMails.answered(in: context) }
        _ = time("SortedMails.answeredIDs") { SortedMails.answeredIDs(in: context) }
        _ = time("SortedMails.known") { SortedMails.known(in: context) }
        _ = time("SortedMails.all (log + store)") { SortedMails.all(log: log, in: context) }
        _ = time("Unplaced.find (the list of mail without a matter)") { Unplaced.find(log: log, context: context, setAside: []) }
        _ = time("Unplaced.find again") { Unplaced.find(log: log, context: context, setAside: []) }

        // Two mails into the busiest open matter.
        guard let target = matters.filter({ !$0.isClosed }).max(by: { ($0.entries?.count ?? 0) < ($1.entries?.count ?? 0) }) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let judgements = try (1...2).map { n -> Judgement in
            let json: [String: Any] = [
                "email_id": "timing-\(n)-\(UUID().uuidString)@example.org", "source": "imap://x/;UID=\(n)", "date": ISO8601DateFormatter().string(from: Date()),
                "subject": "Timing \(n)", "from": "A <a@example.org>", "is_bulk": false, "matter": target.key, "matter_confidence": 0.9,
                "matter_reason": "", "decided_by": "claude", "parties": [["name": "Anna Beispiel", "role": "Test", "is_new": true]],
                "todos": [["text": "Send the paper \(n)", "owner": "me", "due": NSNull(), "source_quote": "x", "same_as": NSNull()]],
                "deadlines": [], "appointments": [], "done": [],
            ]
            return try decoder.decode(Judgement.self, from: JSONSerialization.data(withJSONObject: json))
        }
        _ = try time("MatterImport.apply, 2 mails") { try MatterImport.apply(judgements, to: context, owner: ["Ralf Chille"]) }
        _ = try time("SortedMails.record, 2 mails") { try SortedMails.record(judgements, device: "timing", in: context) }
        try time("save") { try context.save() }
        _ = time("KeptTexts.share") { KeptTexts.share(besides: store, in: context) }
        _ = time("overview page after") { OverviewPage(try! context.fetch(FetchDescriptor<Matter>())) }
        _ = time("Unplaced.find after") { Unplaced.find(log: log, context: context, setAside: []) }
    }
}
