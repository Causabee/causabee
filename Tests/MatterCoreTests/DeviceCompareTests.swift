import Foundation
import Testing
@testable import MatterCore

/// The owner's last mails read by Apple's model on this Mac, beside what the extended model made
/// of them when they were sorted. Nothing is sent: the disguised words in the log are put back to
/// real names first, as the device would read them. Run with CAUSABEE_DEVICE_COMPARE=<how many>;
/// CAUSABEE_COMPARE_OUT names the report.
@Suite(.serialized)
struct DeviceCompareTests {
    nonisolated static let env = ProcessInfo.processInfo.environment

    @Test(.enabled(if: env["CAUSABEE_DEVICE_COMPARE"] != nil))
    func compare() async throws {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Causabee")
        let all = DailyDoor.readLog(folder.appendingPathComponent("decisions-fetch.jsonl")).values
            .filter { $0.disguise != nil && $0.extraction?.error == nil && $0.extraction?.skipped == nil && $0.extraction != nil && !$0.isBulk }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        let chosen = Array(all.suffix(Int(Self.env["CAUSABEE_DEVICE_COMPARE"] ?? "") ?? 50))
        let mapping = try JSONDecoder().decode(Pseudonymizer.Mapping.self, from: Data(contentsOf: folder.appendingPathComponent("mapping.json")))
        let restorer = Pseudonymizer(mode: .placeholder, entries: mapping.placeholder).restorer
        // Each matter with a few words on it — its newest digest — as GPT had each matter's summary.
        var about: [String: String] = [:]
        for j in all where j.matter != nil && j.digest != nil { about[j.matter!] = String(j.digest!.prefix(110)) }
        let matters = about.keys.sorted().map { "\($0): \(restorer.apply(about[$0]!).text)" }
        // The thread decides, by rule, before any model: a reply goes where the mail before it went.
        func topic(_ subject: String) -> String {
            var s = subject.lowercased()
            while let r = s.range(of: #"^\s*(re|aw|wg|fwd|fw|tr)\s*:\s*"#, options: .regularExpression) { s.removeSubrange(r) }
            return s.trimmingCharacters(in: .whitespaces)
        }

        var report: [String] = []
        var sameMatter = 0, seconds: [Double] = [], failed = 0
        var gpt = (todos: 0, dates: 0), device = (todos: 0, dates: 0), datesAgree = 0, datesEither = 0
        for old in chosen {
            guard let disguise = old.disguise else { continue }
            let mail = restorer.apply(Extractor.text(of: disguise, body: Quotes.newest(of: disguise.body, subject: disguise.subject).newest)).text
            let day = old.date.map { String(ISO8601DateFormatter().string(from: $0).prefix(10)) } ?? ""
            report.append("## \(day) · \(old.subject)")
            let read: DeviceReader.Read?
            let thread = all.last { ($0.date ?? .distantPast) < (old.date ?? .distantPast) && topic($0.subject) == topic(old.subject) && $0.matter != nil }?.matter
            do { read = try await DeviceReader.read(mail: mail, sent: old.date, owner: ["Ralf Chille", "ralf@chille.de"], matters: matters, thread: thread) } catch {
                failed += 1
                report.append("**On device:** failed — \(error)\n")
                continue
            }
            guard let read else { report.append("Apple's model is not available here."); break }
            seconds.append(read.seconds)
            let gptMatter = old.matter?.lowercased(), deviceMatter = read.matter?.lowercased()
            let agree = gptMatter == deviceMatter
            if agree { sameMatter += 1 }
            let oldDates = Set(old.appointments.map(\.date) + old.deadlines.map(\.date))
            let newDates = Set(read.appointments.map(\.date) + read.deadlines.map(\.date))
            datesAgree += oldDates.intersection(newDates).count; datesEither += oldDates.union(newDates).count
            gpt.todos += old.todos.filter { $0.sameAs == nil }.count; gpt.dates += oldDates.count
            device.todos += read.todos.count; device.dates += newDates.count

            report.append("Matter — GPT: `\(old.matter ?? "none")` · device: `\(read.matter ?? "none")`\(read.isNew ? " (new)" : "") \(agree ? "✓" : "✗") · \(String(format: "%.1f s", read.seconds))\n")
            report.append("**GPT**\n" + Self.lines(todos: old.todos.map { ($0.text, $0.owner.rawValue, $0.due) },
                                                    dates: old.appointments.map { "📅 \($0.date)\($0.time.map { " \($0)" } ?? "") \($0.what)" } + old.deadlines.map { "⏰ \($0.date) \($0.what)" },
                                                    digest: old.digest))
            report.append("**On device**\n" + Self.lines(todos: read.todos.map { ($0.text, $0.owner, $0.due) },
                                                          dates: read.appointments.map { "📅 \($0.date)\($0.time.map { " \($0)" } ?? "") \($0.what)" } + read.deadlines.map { "⏰ \($0.date) \($0.what)" },
                                                          digest: read.digest))
        }
        let n = max(seconds.count, 1)
        let sorted = seconds.sorted()
        let header = """
        # Apple's model on this Mac against GPT — the last \(chosen.count) mails

        | | |
        |---|---|
        | Same matter as GPT | \(sameMatter) of \(seconds.count) (\(100 * sameMatter / n) %) |
        | New to-dos | GPT \(gpt.todos) · device \(device.todos) |
        | Dates found | GPT \(gpt.dates) · device \(device.dates) · the same day in both: \(datesAgree) of \(datesEither) |
        | Time per mail | median \(String(format: "%.1f", sorted.isEmpty ? 0 : sorted[sorted.count / 2])) s · slowest \(String(format: "%.1f", sorted.last ?? 0)) s |
        | Failed | \(failed) |

        """
        let out = URL(fileURLWithPath: Self.env["CAUSABEE_COMPARE_OUT"] ?? "/tmp/causabee-device-compare.md")
        try ([header] + report).joined(separator: "\n").write(to: out, atomically: true, encoding: .utf8)
        print("DEVICE same matter \(sameMatter)/\(seconds.count) todos gpt \(gpt.todos) device \(device.todos) dates \(datesAgree)/\(datesEither) median \(sorted.isEmpty ? 0 : sorted[sorted.count / 2]) failed \(failed)")
    }

    static func lines(todos: [(String, String, String?)], dates: [String], digest: String?) -> String {
        var lines = dates + todos.map { "☐ [\($0.1)\($0.2.map { ", \($0)" } ?? "")] \($0.0)" }
        if let digest, !digest.isEmpty { lines.append("_\(digest)_") }
        return (lines.isEmpty ? ["—"] : lines.map { "- \($0)" }).joined(separator: "\n") + "\n"
    }
}

@Suite("Dates found by rule, as a mail names them")
struct DateFinderTests {
    @Test("An invitation's day and time, a booking's arrival and departure, a deadline without a year; never 'tomorrow'")
    func found() {
        let sent = ISO8601DateFormatter().date(from: "2026-10-07T09:00:00Z")
        func days(_ text: String) -> [String] { DateFinder.dates(in: text, sent: sent).map { [$0.day, $0.time].compactMap { $0 }.joined(separator: " ") } }
        #expect(days("Einladung: Chat - Fr 9. Okt. 2026 10:30 - 11:00 (MESZ)") == ["2026-10-09 10:30"])
        #expect(days("Anreise ab 17:00 Uhr am 16. Oktober 2026, Abreise bis 10:00 Uhr am 26. Oktober") == ["2026-10-16 17:00", "2026-10-26 10:00"])
        #expect(days("Das Angebot ist gebunden bis 31.10.") == ["2026-10-31"])
        #expect(days("Can we talk tomorrow at 10:00?").isEmpty)
    }
}
