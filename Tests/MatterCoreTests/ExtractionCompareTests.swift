import Foundation
import Testing
@testable import MatterCore

/// The owner's last mails read again with today's prompt, beside what they brought when they were
/// sorted: how many to-dos and dates each brings now. Only the disguised words in the Mac's log
/// are sent. Run with CAUSABEE_COMPARE=<how many>, CAUSABEE_LIVE_KEY and CAUSABEE_LIVE_MODEL;
/// CAUSABEE_COMPARE_OUT names the report.
@Suite(.serialized)
struct ExtractionCompareTests {
    nonisolated static let env = ProcessInfo.processInfo.environment

    @Test(.enabled(if: env["CAUSABEE_COMPARE"] != nil && env["CAUSABEE_LIVE_KEY"] != nil))
    func compare() async throws {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Causabee")
        let all = DailyDoor.readLog(folder.appendingPathComponent("decisions-fetch.jsonl")).values
            .filter { $0.disguise != nil && $0.extraction?.error == nil && $0.extraction?.skipped == nil && $0.extraction != nil && !$0.isBulk }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        let count = Int(Self.env["CAUSABEE_COMPARE"] ?? "") ?? 30
        let chosen = Array(all.suffix(count))
        let first = chosen.first?.date ?? .distantPast
        let earlier = all.filter { ($0.date ?? .distantPast) < first }

        let mapping = try JSONDecoder().decode(Pseudonymizer.Mapping.self, from: Data(contentsOf: folder.appendingPathComponent("mapping.json")))
        let pseudonymizer = Pseudonymizer(mode: .placeholder, entries: mapping.placeholder)
        // On file before the first mail: the appointments the earlier mails brought, by matter.
        var onFile: [String: Extractor.OnFile] = [:]
        for judgement in earlier {
            guard let key = judgement.matter else { continue }
            var file = onFile[key] ?? .init(appointments: [], unwanted: [])
            file.appointments += judgement.appointments.map { Extractor.line(day: $0.date, time: $0.time, what: $0.what) }
            onFile[key] = file
        }

        let model = Claude.Model.choices.first { $0.id == Self.env["CAUSABEE_LIVE_MODEL"] } ?? .gptSol
        var extractor = Extractor(model: model, claude: Claude(key: Self.env["CAUSABEE_LIVE_KEY"]!),
                                  cache: FileManager.default.temporaryDirectory.appendingPathComponent("causabee-compare-\(UUID().uuidString)"), quietAfter: 0)
        extractor.strict = model.isOpenAI || model.isMistral
        extractor.onFile = onFile
        var outcomes = chosen.map { old -> Spike.Outcome in
            var fresh = old
            fresh.extraction = nil
            return Spike.Outcome(judgement: fresh, email: Email(standingIn: old))
        }
        let known = Dictionary(earlier.map { ($0.emailID, $0) }, uniquingKeysWith: { a, _ in a })
        let summary = try await extractor.run(&outcomes, pseudonymizer: pseudonymizer, owner: ["Ralf Chille", "ralf@chille.de"], known: known)

        func lines(_ j: Judgement) -> [String] {
            j.appointments.map { "📅 \($0.date)\($0.time.map { " \($0)" } ?? "") \($0.what)\($0.replaces.map { " (moves \($0))" } ?? "")" }
                + j.deadlines.map { "⏰ \($0.date) \($0.what)" }
                + j.todos.map { "☐ [\($0.owner.rawValue)\($0.due.map { ", \($0)" } ?? "")\($0.sameAs != nil ? ", again" : "")] \($0.text)" }
        }
        // Before, the days showed everyone's dated to-dos; now only the owner's.
        func onDay(_ j: Judgement, others: Bool) -> Int {
            j.appointments.filter { $0.replaces == nil }.count + j.deadlines.count
                + j.todos.filter { $0.sameAs == nil && (others || $0.owner != .other) && $0.due != nil }.count
        }
        var report = ["# The last \(chosen.count) mails, read again\n", "Model: \(model.label) · cost $\(String(format: "%.2f", summary.cost))\n"]
        var before = (todos: 0, dates: 0, day: 0), after = (todos: 0, dates: 0, day: 0)
        for (old, outcome) in zip(chosen, outcomes) {
            let new = outcome.judgement
            before.todos += old.todos.filter { $0.sameAs == nil }.count; after.todos += new.todos.filter { $0.sameAs == nil }.count
            before.dates += old.appointments.count + old.deadlines.count; after.dates += new.appointments.filter { $0.replaces == nil }.count + new.deadlines.count
            before.day += onDay(old, others: true); after.day += onDay(new, others: false)
            let day = old.date.map { ISO8601DateFormatter().string(from: $0).prefix(10) } ?? ""
            report.append("## \(day) · \(old.subject)\n_\(old.matter ?? "no matter")_\n")
            report.append("**Before**\n" + (lines(old).isEmpty ? "—" : lines(old).map { "- \($0)" }.joined(separator: "\n")) + "\n")
            report.append("**Now**\n" + (lines(new).isEmpty ? "—" : lines(new).map { "- \($0)" }.joined(separator: "\n")) + "\n")
        }
        report.insert("| | Before | Now |\n|---|---|---|\n| New to-dos | \(before.todos) | \(after.todos) |\n| New dates | \(before.dates) | \(after.dates) |\n| On your days | \(before.day) | \(after.day) |\n", at: 2)
        let out = URL(fileURLWithPath: Self.env["CAUSABEE_COMPARE_OUT"] ?? "/tmp/causabee-compare.md")
        try report.joined(separator: "\n").write(to: out, atomically: true, encoding: .utf8)
        print("COMPARE before \(before) after \(after) cost \(summary.cost) failed \(summary.failed.count)")
    }
}
