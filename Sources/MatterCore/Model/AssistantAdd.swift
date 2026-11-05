import Foundation

/// What the owner picked from the assistant's plus before typing: the assistant is told what is
/// coming, and what is typed or said becomes exactly that — a task, with the day and the time read
/// out of its words, or a note, word for word. Its card is taken in at once: the owner said so.
public enum AssistantAdd: String, CaseIterable, Sendable {
    case task = "New task"
    case note = "New note"
    case link = "New link"
    case detail = "New detail"
    case contact = "New contact"

    /// What the chip over the field says under its name.
    public var hint: String {
        switch self {
        case .task: "Type or say what is to do. A day or a time in it becomes its date."
        case .note: "Type or say it. It is kept in the matter's notes, word for word."
        case .link: "The address, and a name for it if you like. Kept with the matter."
        case .detail: "What it is — a number, a code, an account — and what it says."
        case .contact: "Who it is, and what they are to this matter if you like."
        }
    }

    /// The card that makes it.
    public var cardKind: AssistantPrompt.Reply.Card.Kind {
        switch self {
        case .task: .newTodo
        case .note: .addNote
        case .link: .addLink
        case .detail: .addDetail
        case .contact: .addContact
        }
    }

    /// The card's own name, small, over its fields.
    public var title: String {
        switch self {
        case .task: "Task"
        case .note: "Note"
        case .link: "Link"
        case .detail: "Detail"
        case .contact: "Contact"
        }
    }

    /// What its first field asks for, and its second — nil where there is none.
    public var fields: (first: String, second: String?) {
        switch self {
        case .task: ("What needs doing?", nil)
        case .note: ("What to keep", nil)
        case .link: ("Address", "Name (optional)")
        case .detail: ("What it is, like Insurance number", "What it says")
        case .contact: ("Name", "Role (optional)")
        }
    }

    /// Whether what is typed is enough to add: a detail needs both what it is and what it says.
    public func isComplete(_ first: String, _ second: String) -> Bool {
        let first = first.trimmingCharacters(in: .whitespacesAndNewlines)
        let second = second.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .detail: return !first.isEmpty && !second.isEmpty
        case .link: return WebLink.address(in: first) != nil
        default: return !first.isEmpty
        }
    }

    /// A link, a detail and a contact are kept as they are, on the device. A task goes to the
    /// assistant with Pro, for its day and time; a note too, for the task it belongs with — both
    /// in their words, and as typed without Pro.
    public var asksAssistant: Bool { self == .task || self == .note }

    /// What goes into the thread, and to the assistant: "New task: Online check-in from 25 Oct, 15:10".
    public func question(_ words: String, _ second: String = "") -> String {
        let second = second.trimmingCharacters(in: .whitespacesAndNewlines)
        return rawValue + ": " + words + (second.isEmpty ? "" : " — " + second)
    }

    /// Whether a question in the thread was one of these, and its words.
    public static func of(_ question: String) -> (add: AssistantAdd, words: String)? {
        for add in allCases where question.hasPrefix(add.rawValue + ": ") {
            return (add, String(question.dropFirst(add.rawValue.count + 2)))
        }
        return nil
    }

    /// The card, its fields where the card actions read them: a link's address in `from` and its
    /// name as the text; a detail's label in `subject` and its value as the text; a contact's name
    /// as the text and its role in `subject`.
    private func card(_ words: String, _ second: String = "") -> AssistantPrompt.Reply.Card {
        let words = words.trimmingCharacters(in: .whitespacesAndNewlines)
        let second = second.trimmingCharacters(in: .whitespacesAndNewlines)
        var card = AssistantPrompt.Reply.Card(kind: cardKind, todo: nil, text: words, owner: "me", due: nil, reason: "", cites: [])
        switch self {
        case .link:
            card.from = words
            card.text = second.isEmpty ? (URL(string: WebLink.address(in: words) ?? words)?.host() ?? words) : second
        case .detail:
            card.subject = words
            card.text = second
        case .contact:
            if !second.isEmpty { card.subject = second }
        case .task, .note: break
        }
        return card
    }

    /// The answer with nothing asked: the words as they were typed. For a note, a link, a detail
    /// and a contact, and for a task without Pro or a key to ask with.
    public func asTyped(_ words: String, _ second: String = "") -> AssistantAsk.Answer {
        var answer = AssistantAsk.Answer(reply: AssistantPrompt.Reply(lines: [], cards: [card(words, second)], notInFacts: nil),
                                         sent: "", cost: 0, seconds: 0, newNames: 0)
        answer.servedBy = DeviceTask.onDevice
        return answer
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
