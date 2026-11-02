import Foundation
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

/// What Apple's model on this device can say about a whole matter. It holds too little to read a
/// matter, so it reads a packed page: what is open, what is ahead, and what was saved of the newest
/// mails. Nothing leaves the device.
public enum DeviceWriter {
    /// What the model reads of a matter, at most this many characters: its limit, less its
    /// instructions and its answer.
    static let mostCharacters = 9_000
    static let newestMails = 8

    public struct Page: Sendable {
        public var text: String
        public var language: String?
    }

    public struct Step: Sendable {
        public var step: String
        public var why: String
        public var todo: String?
        public var seconds: Double
    }

    /// `restored`: puts real names back where the store holds disguised words.
    @MainActor
    public static func page(of matter: Matter, today: String, restored: (String) -> String = { $0 }) -> Page {
        func one(_ text: String, _ most: Int) -> String {
            String(text.replacingOccurrences(of: "\n", with: " ").prefix(most))
        }
        var lines = ["Matter: \(matter.name)", "Today: \(today)"]
        if let notes = matter.notesText, !notes.isEmpty { lines.append("The owner's notes: \(one(notes, 500))") }

        let open = matter.openTodos.sorted { ($0.due ?? "9999") < ($1.due ?? "9999") }
        var ids: [PersistentIdentifier: String] = [:]
        for (index, todo) in open.enumerated() { ids[todo.persistentModelID] = "T\(index + 1)" }
        func rows(_ todos: [Todo]) -> [String] {
            todos.prefix(20).map { todo in
                var line = "\(ids[todo.persistentModelID] ?? "") \(one(todo.text, 150))"
                if let due = todo.due { line += " (due \(due))" }
                if let blocker = todo.waitsFor, let id = ids[blocker.persistentModelID] { line += " (only after \(id))" }
                if let note = todo.note, !note.isEmpty { line += " — note: \(one(note, 120))" }
                return line
            }
        }
        let mine = rows(open.filter { $0.owner != .other }), others = rows(open.filter { $0.owner == .other })
        lines.append(mine.isEmpty ? "The owner's open tasks: none." : "The owner's open tasks:\n" + mine.joined(separator: "\n"))
        if !others.isEmpty { lines.append("Waiting for others:\n" + others.joined(separator: "\n")) }

        let ahead = (matter.appointments ?? []).filter { $0.day >= today }.map { ($0.day, "\($0.day)\($0.time.map { " " + $0 } ?? ""): \(one($0.what, 100))") }
            + (matter.deadlines ?? []).filter { $0.day >= today }.map { ($0.day, "\($0.day): \(one($0.what, 100)) (deadline)") }
        if !ahead.isEmpty { lines.append("Dates ahead:\n" + ahead.sorted { $0.0 < $1.0 }.prefix(10).map(\.1).joined(separator: "\n")) }

        var used = lines.joined(separator: "\n\n").count
        var mails: [String] = []
        let newest = (matter.entries ?? []).sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        for entry in newest.prefix(newestMails) {
            let from = Email.displayName(in: entry.from) ?? Email.address(in: entry.from)
            var line = "\(entry.date.map(MatterStatus.day) ?? "?") from \(from): \(one(entry.title, 90))"
            if let digest = entry.digest, !digest.isEmpty { line += " — " + one(digest, 260) }
            guard used + line.count < mostCharacters else { break }
            used += line.count
            mails.append(line)
        }
        if !mails.isEmpty { lines.append("Newest mails, newest first:\n" + mails.joined(separator: "\n")) }
        lines.append("\(matter.entries?.count ?? 0) mails in all.")
        let language = FactSheet.facts(for: [matter], today: today, mails: 0).language
        return Page(text: restored(lines.joined(separator: "\n\n")), language: language)
    }

    static func stepInstructions(_ language: String?) -> String {
        """
        You choose the one next step in a person's matter, from the page you are given. Pick the \
        single most useful thing the owner can do now. Something the owner can do beats something \
        to wait for. A task another waits for comes first. What is late or has a date soon comes \
        before what has none. The owner's notes are right. If the owner can only wait, say until \
        when, and what to do if nothing comes.

        Use only what is on the page. Never add a fact, a name or a date.

        step: the step as an instruction of at most twelve words. why: one short sentence on why \
        this one now. todo: the task's id, such as T3, or empty. Write in \(language ?? "the language of the page").
        """
    }

    static func answerInstructions(_ language: String?) -> String {
        """
        You answer a person's question about their matter, from the page you are given, in at \
        most three sentences. Use only what is on the page. Never add a fact, a name, a number or \
        a date. If the page does not hold the answer, say plainly that you cannot see it here. \
        Write in \(language ?? "the language of the page").
        """
    }

    public static func nextStep(from page: Page) async throws -> Step? {
        #if canImport(FoundationModels)
        guard #available(iOS 26, macOS 26, *), DeviceReader.isAvailable else { return nil }
        let start = Date()
        let session = LanguageModelSession(instructions: stepInstructions(page.language))
        let answer = try await session.respond(to: page.text, generating: DeviceStep.self,
                                               options: GenerationOptions(sampling: .greedy)).content
        let todo = answer.todo.trimmingCharacters(in: .whitespacesAndNewlines)
        return Step(step: answer.step, why: answer.why, todo: todo.isEmpty ? nil : todo, seconds: Date().timeIntervalSince(start))
        #else
        return nil
        #endif
    }

    public static func answer(_ question: String, from page: Page) async throws -> (text: String, seconds: Double)? {
        #if canImport(FoundationModels)
        guard #available(iOS 26, macOS 26, *), DeviceReader.isAvailable else { return nil }
        let start = Date()
        let session = LanguageModelSession(instructions: answerInstructions(page.language))
        let answer = try await session.respond(to: page.text + "\n\nQuestion: " + question,
                                               options: GenerationOptions(sampling: .greedy)).content
        return (answer, Date().timeIntervalSince(start))
        #else
        return nil
        #endif
    }
}

#if canImport(FoundationModels)
@available(iOS 26, macOS 26, *)
@Generable
struct DeviceStep {
    @Guide(description: "The step, at most twelve words")
    var step: String
    @Guide(description: "One short sentence on why this one now")
    var why: String
    @Guide(description: "The id of the task it is about, or empty")
    var todo: String
}
#endif
