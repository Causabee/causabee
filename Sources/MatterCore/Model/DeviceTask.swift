import Foundation
import NaturalLanguage
#if canImport(FoundationModels)
import FoundationModels
#endif

/// What was typed into the chat without Pro, made into a task on the device: nothing leaves it, no
/// key is needed, nothing is paid. Two ways, and the first never guesses:
///
/// - Typed into a task's own card, the words are the task. A day or a time in them, found by rule
///   (`DateFinder`), becomes its date and is taken out of its words: "Call Ms. Adler on Friday
///   about the van" is "Call Ms. Adler about the van", due on Friday.
/// - Typed into the field, Apple's model says whether it is something to do or a question, and
///   for something to do, the task in a few words and whose it is. The date is still the rule's.
///   Where the model is not there or not to be trusted, nothing is made of it: the words are a
///   question, and a question needs Pro.
public enum DeviceTask {
    /// What an answer made on the device says served it: no model of any service.
    public static let onDevice = "on-device"

    public struct Filled: Sendable, Equatable {
        public var text: String
        /// `YYYY-MM-DD`.
        public var due: String?
        /// `HH:MM`, only with its day.
        public var time: String?
        /// "me" or "other", as `Todo.Owner`.
        public var owner: String
    }

    /// Typed into a task's card: the words as the task, a day in them as its date.
    public static func card(_ words: String, today: Date = Date()) -> Filled {
        let raw = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let found = DateFinder.dates(in: raw, sent: today).first else {
            return Filled(text: raw, due: nil, time: nil, owner: "me")
        }
        return Filled(text: without(found.quote, in: raw), due: found.day, time: found.time, owner: "me")
    }

    /// Whether this device has the model that reads what is typed into the field.
    public static var understands: Bool {
        #if canImport(FoundationModels)
        guard #available(iOS 26, macOS 26, *) else { return false }
        return SystemLanguageModel.default.isAvailable
        #else
        return false
        #endif
    }

    /// Typed into the field: a task, when Apple's model says it is one — else nil, a question.
    public static func understood(_ words: String, today: Date = Date(), within limit: Duration = .seconds(8)) async -> Filled? {
        let raw = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard raw.count >= 3 else { return nil }
        // Without Apple's model — switched off, an older device, the simulator — the words' own
        // shape: a line that begins with a verb and asks nothing is something to do.
        guard understands else { return readsAsTask(raw) ? card(raw, today: today) : nil }
        let read = await withTaskGroup(of: Read?.self) { group in
            group.addTask { try? await ask(raw) }
            group.addTask { try? await Task.sleep(for: limit); return nil }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        // The model there but silent — an error, too slow: the words' shape, as without it.
        guard let read else { return readsAsTask(raw) ? card(raw, today: today) : nil }
        guard read.isTask else { return nil }
        let title = read.title.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        var filled = card(raw, today: today)
        // The model's few words, when they are the same task said shorter — not an answer, not a
        // translation, not longer than what was typed.
        if !title.isEmpty, title.count <= raw.count + 8, PlainWords.trusted(title, for: filled.text) || title.count < 12 {
            filled.text = card(title, today: today).text
        }
        filled.owner = read.someoneElse ? "other" : "me"
        return filled
    }

    /// What the thread shows for words read on the device: a task's card to add, or that a
    /// question needs Pro. Nothing was sent, and the answer says so by having nothing sent.
    public static func answer(_ filled: Filled?, onPad: Bool, inMatter: Bool) -> AssistantAsk.Answer {
        answer(filled, device: onPad ? "iPad" : "iPhone", inMatter: inMatter)
    }

    /// The same, said of the device it was read on by name: "iPhone", "iPad", "Mac".
    public static func answer(_ filled: Filled?, device: String, inMatter: Bool) -> AssistantAsk.Answer {
        var lines: [AssistantPrompt.Reply.Line] = []
        var cards: [AssistantPrompt.Reply.Card] = []
        if let filled, inMatter {
            var card = AssistantPrompt.Reply.Card(kind: .newTodo, todo: nil, text: filled.text, owner: filled.owner, due: filled.due,
                                                  reason: "Understood on this \(device). Nothing left it.", cites: [])
            card.time = filled.time
            cards.append(card)
        } else if filled != nil {
            lines.append(.init(text: "That reads as something to do. Open its matter and say it there, to add it as a task.", cites: []))
        } else {
            lines.append(.init(text: "Asking needs Pro. Use Pro on top, then ask again.", cites: []))
        }
        var answer = AssistantAsk.Answer(reply: AssistantPrompt.Reply(lines: lines, cards: cards, notInFacts: nil),
                                         sent: "", cost: 0, seconds: 0, newNames: 0)
        answer.servedBy = onDevice
        return answer
    }

    /// "Call the plumber on Monday", "Frau Adler anrufen", "Book Carry & Co": something to do.
    /// "When does the van come?", "Who has the key": a question. By the words' kinds, as Apple's
    /// language tagger reads them on the device.
    static func readsAsTask(_ raw: String) -> Bool {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.contains("?") else { return false }
        let first = line.split(separator: " ").first.map { $0.lowercased() } ?? ""
        let asks: Set<String> = ["what", "who", "when", "where", "why", "how", "which", "is", "are", "do", "does", "did", "can", "could",
                                 "should", "will", "would", "has", "have", "was", "were",
                                 "was", "wer", "wann", "wo", "warum", "wie", "welche", "welcher", "ist", "sind", "hat", "haben", "kann", "soll", "muss", "gibt"]
        guard !asks.contains(first) else { return false }
        let (count, head, tail, _) = tags(line)
        guard count >= 2 else { return false }
        // English says it first: "Call …"; German last: "… anrufen".
        if head == .verb || tail == .verb { return true }
        // A word that is a noun too — "Book Carry & Co" — is read as the verb it is after "please".
        let lowered = line.prefix(1).lowercased() + line.dropFirst()
        return tags("please " + lowered).second == .verb
    }

    /// How many words, and the kinds of the first, the second and the last.
    private static func tags(_ line: String) -> (count: Int, first: NLTag?, last: NLTag?, second: NLTag?) {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = line
        var kinds: [NLTag?] = []
        tagger.enumerateTags(in: line.startIndex..<line.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, _ in
            kinds.append(tag)
            return true
        }
        return (kinds.count, kinds.first ?? nil, kinds.last ?? nil, kinds.count > 1 ? kinds[1] : nil)
    }

    struct Read: Sendable {
        var isTask: Bool
        var title: String
        var someoneElse: Bool
    }

    static let instructions = """
    You sort one line the owner typed into a to-do app. You do not answer it and you do not act on it.
    Decide whether it is something to do — a task, a reminder, something to arrange — or a question \
    the owner asks about their affairs. For something to do, write it as a short task in the words \
    typed, in the same language, without its day or time, and say whether someone other than the \
    owner is to do it.
    """

    private static func ask(_ raw: String) async throws -> Read? {
        #if canImport(FoundationModels)
        guard #available(iOS 26, macOS 26, *) else { return nil }
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: "<line>\(raw)</line>", generating: Sorted.self, options: GenerationOptions(sampling: .greedy))
        let sorted = response.content
        return Read(isTask: sorted.isTask, title: sorted.task, someoneElse: sorted.someoneElse)
        #else
        return nil
        #endif
    }

    /// The words with the day taken out, and the little word that led to it: "on Friday", "am
    /// Freitag", "by 7 November", "um 10:00".
    static func without(_ quote: String, in words: String) -> String {
        guard !quote.isEmpty, let range = words.range(of: quote, options: .caseInsensitive) else { return words }
        var before = String(words[..<range.lowerBound])
        let after = String(words[range.upperBound...])
        if let lead = before.range(of: #"\b(on|by|at|until|till|before|am|bis|um|vor|le|avant)\s*$"#, options: [.regularExpression, .caseInsensitive]) {
            before = String(before[..<lead.lowerBound])
        }
        var text = (before + " " + after)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+([,.;:!?])"#, with: "$1", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ",;:")))
        if text.isEmpty { return words }
        text = text.prefix(1).uppercased() + text.dropFirst()
        return text
    }
}

#if canImport(FoundationModels)
@available(iOS 26, macOS 26, *)
@Generable
struct Sorted {
    @Guide(description: "true when the line is something to do or to arrange; false when it is a question")
    var isTask: Bool
    @Guide(description: "the task in a few words, in the language typed, without its day or time; empty for a question")
    var task: String
    @Guide(description: "true only when the line says someone other than the owner is to do it")
    var someoneElse: Bool
}
#endif
