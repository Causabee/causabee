import Foundation

/// What the owner picked from the assistant's plus before typing: the assistant is told what is
/// coming, and what is typed or said becomes exactly that — a task, with the day and the time read
/// out of its words, or a note, word for word. Its card is taken in at once: the owner said so.
public enum AssistantAdd: String, CaseIterable, Sendable {
    case task = "New task"
    case note = "New note"

    /// What the chip over the field says under its name.
    public var hint: String {
        switch self {
        case .task: "Type or say what is to do. A day or a time in it becomes its date."
        case .note: "Type or say it. It is kept in the matter's notes, word for word."
        }
    }

    /// The card that makes it.
    public var cardKind: AssistantPrompt.Reply.Card.Kind { self == .task ? .newTodo : .addNote }

    /// A note is kept as it is, on the device. A task goes to the assistant, for its day and time.
    public var asksAssistant: Bool { self == .task }

    /// What goes into the thread, and to the assistant: "New task: Online check-in from 25 Oct, 15:10".
    public func question(_ words: String) -> String { rawValue + ": " + words }

    /// Whether a question in the thread was one of these, and its words.
    public static func of(_ question: String) -> (add: AssistantAdd, words: String)? {
        for add in allCases where question.hasPrefix(add.rawValue + ": ") {
            return (add, String(question.dropFirst(add.rawValue.count + 2)))
        }
        return nil
    }

    private func card(_ words: String) -> AssistantPrompt.Reply.Card {
        AssistantPrompt.Reply.Card(kind: cardKind, todo: nil, text: words, owner: "me", due: nil, reason: "", cites: [])
    }

    /// The answer with nothing asked: the words as they were typed. For a note, and for a task when
    /// there is no key to ask with.
    public func asTyped(_ words: String) -> AssistantAsk.Answer {
        AssistantAsk.Answer(reply: AssistantPrompt.Reply(lines: [], cards: [card(words)], notInFacts: nil),
                            sent: "", cost: 0, seconds: 0, newNames: 0)
    }

    /// The assistant's answer, and which of its cards to take in. If it sent none of the kind picked,
    /// one with the words as typed is put in: what the owner wrote is never lost to an answer.
    public func settled(_ answer: AssistantAsk.Answer, words: String) -> (answer: AssistantAsk.Answer, card: Int) {
        if let index = answer.reply.cards.firstIndex(where: { $0.kind == cardKind }) { return (answer, index) }
        var answer = answer
        answer.reply.cards.insert(card(words), at: 0)
        return (answer, 0)
    }
}
