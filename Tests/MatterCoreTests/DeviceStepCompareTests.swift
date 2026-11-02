import Foundation
import SwiftData
import Testing
@testable import MatterCore

/// The owner's open matters written by Apple's model on this Mac, beside what the larger model
/// wrote: on a copy of the store, nothing sent. Run with CAUSABEE_DEVICE_STEPS=<how many matters>;
/// CAUSABEE_COMPARE_OUT names the report.
@MainActor
@Suite(.serialized)
struct DeviceStepCompareTests {
    nonisolated static let env = ProcessInfo.processInfo.environment

    /// Four anyone may ask of a matter, and one its page cannot answer.
    static let questions = ["Was ist der aktuelle Stand?", "Was ist noch offen?", "Worauf warte ich gerade?",
                            "Welche Termine stehen an?", "Wie lautet meine Steuer-Identifikationsnummer?"]

    @Test(.enabled(if: env["CAUSABEE_DEVICE_STEPS"] != nil))
    func compare() async throws {
        let source = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Causabee")
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("causabee-steps-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: copy, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: copy) }
        for name in ["matters.store", "matters.store-wal", "matters.store-shm"] {
            try? FileManager.default.copyItem(at: source.appendingPathComponent(name), to: copy.appendingPathComponent(name))
        }
        let mapping = try JSONDecoder().decode(Pseudonymizer.Mapping.self, from: Data(contentsOf: source.appendingPathComponent("mapping.json")))
        let restorer = Pseudonymizer(mode: .placeholder, entries: mapping.placeholder).restorer
        let container = try MatterSchema.container(at: copy.appendingPathComponent("matters.store"))
        let context = container.mainContext

        let open = try context.fetch(FetchDescriptor<Matter>()).filter { !$0.isClosed && !(($0.entries ?? []).isEmpty && $0.openTodos.isEmpty) }
            .sorted { ($0.entries?.count ?? 0) > ($1.entries?.count ?? 0) }
        let wanted = Int(Self.env["CAUSABEE_DEVICE_STEPS"] ?? "") ?? 20
        // Across the sizes, the largest to the smallest.
        let stride = max(1, open.count / max(wanted, 1))
        let chosen = Array(open.enumerated().filter { $0.offset % stride == 0 }.map(\.element).prefix(wanted))

        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.dateFormat = "yyyy-MM-dd (EEEE)"
        let today = format.string(from: Date())
        let day = String(today.prefix(10))

        var report: [String] = [], seconds: [Double] = [], failures: [String] = [], sizes: [Int] = []
        for matter in chosen {
            let page = DeviceWriter.page(of: matter, today: day, restored: { restorer.apply($0).text })
            sizes.append(page.text.count)
            report.append("## \(matter.name)\n\n\(matter.entries?.count ?? 0) mails · \(matter.openTodos.count) open tasks · \(page.language ?? "language unknown") · page \(page.text.count) characters\n")
            report.append("**Larger model:** \(matter.nextStep.map { restorer.apply($0).text } ?? "none")"
                          + (matter.nextStepWhy.map { "\n\n_\(restorer.apply($0).text)_" } ?? "") + "\n")
            let rule = MatterStatus(matter).nextStep
            report.append("**By rule, no AI:** \(rule.map { restorer.apply($0.text).text + " (\($0.why))" } ?? "nothing")\n\nWould you act on this? ☐ yes ☐ no\n")
            do {
                guard let step = try await DeviceWriter.nextStep(from: page) else { report.append("Apple's model is not available here."); break }
                seconds.append(step.seconds)
                report.append("**On device (\(String(format: "%.1f", step.seconds)) s):** \(step.step)\n\n_\(step.why)_\n\nWould you act on this? ☐ yes ☐ no\n")
            } catch {
                failures.append("\(matter.name): \(error)")
                report.append("**On device:** failed: \(error)\n")
            }
        }

        // Three sizes of matter for the questions.
        var answers: [String] = []
        let few = [chosen.first, chosen.dropFirst(chosen.count / 2).first, chosen.last].compactMap { $0 }
        for matter in few {
            let page = DeviceWriter.page(of: matter, today: day, restored: { restorer.apply($0).text })
            answers.append("### \(matter.name)\n")
            for question in Self.questions {
                do {
                    guard let answer = try await DeviceWriter.answer(question, from: page) else { continue }
                    answers.append("**\(question)** (\(String(format: "%.1f", answer.seconds)) s)\n\n\(answer.text)\n")
                } catch {
                    failures.append("\(matter.name), “\(question)”: \(error)")
                    answers.append("**\(question)** failed: \(error)\n")
                }
            }
        }

        let sorted = seconds.sorted()
        let header = """
        # Apple's model on this Mac, writing next steps

        \(today), \(chosen.count) of \(open.count) open matters.

        | | |
        |---|---|
        | Written | \(seconds.count) of \(chosen.count) |
        | Failed | \(failures.count) (questions counted too) |
        | Time, median | \(sorted.isEmpty ? "–" : String(format: "%.1f s", sorted[sorted.count / 2])) |
        | Time, slowest | \(sorted.last.map { String(format: "%.1f s", $0) } ?? "–") |
        | Longest page | \(sizes.max() ?? 0) characters |

        """
        let text = ([header] + report + ["# Questions\n"] + answers).joined(separator: "\n")
        let out = Self.env["CAUSABEE_COMPARE_OUT"] ?? copy.appendingPathComponent("report.md").path
        try text.write(toFile: out, atomically: true, encoding: .utf8)
        print("REPORT \(out)")
        print("WRITTEN \(seconds.count) of \(chosen.count), failed \(failures.count)")
        for failure in failures.prefix(12) { print("FAILED \(failure.prefix(200))") }
    }
}
