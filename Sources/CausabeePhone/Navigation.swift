import Foundation
import MatterCore
import SwiftData

/// Where the iPhone is — the overview, a matter pushed on it, the assistant over both — and the
/// assistant's thread as the Mac writes it into the store, one record a turn.
@MainActor
@Observable
final class Navigation {
    /// The matters pushed on the overview, the last one on top.
    var path: [PersistentIdentifier] = []
    /// Reading: the small actions and the AI's explanations put away, as on the Mac; remembered.
    var reading = UserDefaults.standard.bool(forKey: "ui.reading") {
        didSet { UserDefaults.standard.set(reading, forKey: "ui.reading") }
    }
    var showsAssistant = false
    /// A task to scroll to when its matter opens: the one an overdue line pointed at.
    var showing: PersistentIdentifier?
    /// The item "Talk about it" put into the assistant: shown above the field, taken off with ×.
    var pinned: Pinned?
    /// Words to put in the assistant's field, for the owner to send or change.
    var prefill: String?
    /// Picked from the assistant's plus, and with an editor of its own on the matter's page: the
    /// assistant steps aside and the page opens it.
    enum Adding { case contact, detail, link, scan }
    var adding: Adding?
    /// What the plus adds to a matter — beside the assistant's field, or held on the yellow button.
    enum Plus: String, Identifiable {
        case scan, contact, detail, link, note, task
        var id: String { rawValue }
    }
    /// Picked where no matter is open, and none of the matters offered with it was the one: every
    /// matter is offered, to find it. Over the overview — or over the assistant, when that is open:
    /// the assistant stays where it is.
    var choosing: Plus?
    var choosingInAssistant: Plus?

    /// A task or a note is said to the assistant, over the matter; the others have an editor of
    /// their own on the matter's page, and the assistant steps aside for it.
    func add(_ plus: Plus, to matter: Matter) {
        switch plus {
        case .note, .task:
            let add: AssistantAdd = plus == .note ? .note : .task
            pinned = Pinned(matter: matter.persistentModelID, matterName: matter.name, kind: add.rawValue, text: add.hint)
            showsAssistant = true
        case .scan, .contact, .detail, .link:
            adding = switch plus { case .scan: .scan; case .contact: .contact; case .detail: .detail; default: .link }
            showsAssistant = false
        }
    }

    /// Every matter is offered, over what is open now.
    func choose(for plus: Plus) {
        if showsAssistant { choosingInAssistant = plus } else { choosing = plus }
    }

    /// The matter it is for. A task or a note: the matter comes under the assistant, which stays —
    /// or comes — and is about that matter from then on; nothing goes down to come up again. What
    /// has an editor of its own: the matter's page opens, and the editor on it.
    func chosen(_ matter: Matter, for plus: Plus) {
        choosing = nil
        choosingInAssistant = nil
        RecentMatters.note(matter)
        showing = nil
        if path.last != matter.persistentModelID { path.append(matter.persistentModelID) }
        switch plus {
        case .note, .task:
            add(plus, to: matter)
        case .scan, .contact, .detail, .link:
            showsAssistant = false
            // Once its page is there, and the assistant has gone.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.add(plus, to: matter) }
        }
    }

    /// Puts an item in hand and opens the assistant over its matter, as the Mac's pin does.
    func talk(_ text: String, kind: String, in matter: Matter, prefill: String? = nil) {
        pinned = Pinned(matter: matter.persistentModelID, matterName: matter.name, kind: kind, text: text)
        self.prefill = prefill
        showsAssistant = true
    }

    /// Asked from a matter's menu, wherever it is: a new name, or merging one into another.
    var renaming: Matter?
    var merging: (from: Matter, into: Matter)?
    /// A matter to pin while as many as fit are pinned already: which one it replaces is asked.
    var pinning: Matter?

    func open(_ matter: Matter, showing todo: PersistentIdentifier? = nil) {
        showing = todo
        showsAssistant = false
        RecentMatters.note(matter)
        if path.last != matter.persistentModelID { path.append(matter.persistentModelID) }
    }

    /// The item the owner had in hand when asking on the Mac. Only its words are read here: the
    /// matter's id is the Mac store's own.
    struct Pinned: Equatable, Codable {
        var matter: PersistentIdentifier?
        var matterName: String
        var kind: String
        var text: String

        enum CodingKeys: String, CodingKey { case matter, matterName, kind, text }

        init(matter: PersistentIdentifier?, matterName: String, kind: String, text: String) {
            (self.matter, self.matterName, self.kind, self.text) = (matter, matterName, kind, text)
        }

        /// The whole matter in hand, not one thing in it. Old saved threads still say "Sache".
        static func isMatter(_ kind: String) -> Bool { kind == "Matter" || kind == "Sache" }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            matter = try? c.decodeIfPresent(PersistentIdentifier.self, forKey: .matter)
            matterName = try c.decodeIfPresent(String.self, forKey: .matterName) ?? ""
            kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? ""
            text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        }

        func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encodeIfPresent(matter, forKey: .matter)
            try c.encode(matterName, forKey: .matterName)
            try c.encode(kind, forKey: .kind)
            try c.encode(text, forKey: .text)
        }
    }

    /// One turn of the thread, read from the payload the Mac writes (`Navigation.Turn` there),
    /// with the same keys. What only the Mac can act on — a screenshot's file, how to undo — is
    /// left in the payload and not read here.
    struct Turn: Identifiable {
        enum State {
            case answered(AssistantAsk.Answer)
            case failed(String)
        }
        var id = UUID()
        var date = Date()
        var question: String
        var scope: String
        var inHand: Pinned?
        var seen: String
        var refs: [String: FactRef]
        /// The same facts in words every device has: the ids in `refs` are the asking store's own.
        var keys: [String: String] = [:]
        var matter: PersistentIdentifier?
        var state: State = .failed("")
        var applied: Set<Int> = []
        var dismissedCards: Set<Int> = []
        /// A line Causabee wrote itself — what came in with "Get new mail" — not a question.
        var note: String?
        var readAs: [String] = []
        /// A screenshot brought in on the Mac: its file stays there.
        var hasShot = false

        init(question: String, scope: String, inHand: Pinned?, seen: String, refs: [String: FactRef], matter: PersistentIdentifier?) {
            self.question = question
            self.scope = scope
            self.inHand = inHand
            self.seen = seen
            self.refs = refs
            self.matter = matter
        }

        var answer: AssistantAsk.Answer? {
            if case .answered(let answer) = state { return answer }
            return nil
        }
    }

    /// Turns read once per payload: a thread is read again on every drawing.
    @ObservationIgnored private var read: [UUID: (payload: Data, turn: Turn?)] = [:]

    func turn(_ record: ThreadTurn) -> Turn? {
        if let known = read[record.id], known.payload == record.payload { return known.turn }
        var turn = try? JSONDecoder().decode(Turn.self, from: record.payload)
        // Asked on the Mac, its facts have the Mac's ids: found here by their keys.
        if let asked = turn, let context = record.modelContext {
            turn?.refs = CardActions.local(asked.refs, keys: asked.keys, matter: record.matter, in: context)
        }
        read[record.id] = (record.payload, turn)
        return turn
    }

    /// How to take back a card taken in here, as long as the app is open — as on the Mac.
    @ObservationIgnored var undos: [UUID: [Int: CardActions.Undo]] = [:]
    /// The matter a "new matter" card of a turn made: the cards beside it put their to-dos there.
    @ObservationIgnored var madeMatter: [UUID: PersistentIdentifier] = [:]

    /// A card's state, written into the turn's own record, keeping every key the Mac put there,
    /// so the Mac shows it the same: taken in or not, dismissed or not, and the draft as it was
    /// opened in Mail.
    func mark(_ record: ThreadTurn, card index: Int, applied: Bool? = nil, dismissed: Bool? = nil,
              text: String? = nil, subject: String? = nil, context: ModelContext) {
        guard var json = (try? JSONSerialization.jsonObject(with: record.payload)) as? [String: Any] else { return }
        func set(_ key: String, _ on: Bool?) {
            guard let on else { return }
            var list = Set((json[key] as? [Int]) ?? [])
            if on { list.insert(index) } else { list.remove(index) }
            json[key] = list.sorted()
        }
        set("applied", applied)
        set("dismissedCards", dismissed)
        if text != nil || subject != nil, var answer = json["answer"] as? [String: Any], var reply = answer["reply"] as? [String: Any],
           var cards = reply["cards"] as? [[String: Any]], cards.indices.contains(index) {
            if let text { cards[index]["text"] = text }
            if let subject { cards[index]["subject"] = subject }
            reply["cards"] = cards
            answer["reply"] = reply
            json["answer"] = answer
        }
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]) else { return }
        record.payload = data
        try? context.save()
    }
}

extension Navigation.Turn: Codable {
    enum CodingKeys: String, CodingKey {
        case id, date, question, scope, inHand, seen, refs, keys, matter, answer, failed, applied, readAs, dismissedCards, note, shotFile
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Ids of the Mac's store may not read here; the words do.
        self.init(question: try c.decode(String.self, forKey: .question), scope: try c.decode(String.self, forKey: .scope),
                  inHand: try? c.decodeIfPresent(Navigation.Pinned.self, forKey: .inHand), seen: try c.decode(String.self, forKey: .seen),
                  refs: ((try? c.decodeIfPresent([String: FactRef].self, forKey: .refs)) ?? nil) ?? [:],
                  matter: (try? c.decodeIfPresent(PersistentIdentifier.self, forKey: .matter)) ?? nil)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        keys = ((try? c.decodeIfPresent([String: String].self, forKey: .keys)) ?? nil) ?? [:]
        applied = try c.decodeIfPresent(Set<Int>.self, forKey: .applied) ?? []
        readAs = try c.decodeIfPresent([String].self, forKey: .readAs) ?? []
        dismissedCards = try c.decodeIfPresent(Set<Int>.self, forKey: .dismissedCards) ?? []
        note = try c.decodeIfPresent(String.self, forKey: .note)
        hasShot = c.contains(.shotFile)
        if let answer = try? c.decodeIfPresent(AssistantAsk.Answer.self, forKey: .answer) {
            state = .answered(answer)
        } else {
            state = .failed(try c.decodeIfPresent(String.self, forKey: .failed) ?? "Stopped: the app was closed before the answer came.")
        }
    }

    /// As the Mac writes it — for the demo's own thread, made on the iPhone.
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(date, forKey: .date)
        try c.encode(question, forKey: .question)
        try c.encode(scope, forKey: .scope)
        try c.encodeIfPresent(inHand, forKey: .inHand)
        try c.encode(seen, forKey: .seen)
        try c.encode(refs, forKey: .refs)
        if !keys.isEmpty { try c.encode(keys, forKey: .keys) }
        if !dismissedCards.isEmpty { try c.encode(dismissedCards, forKey: .dismissedCards) }
        try c.encodeIfPresent(note, forKey: .note)
        try c.encodeIfPresent(matter, forKey: .matter)
        try c.encode(applied, forKey: .applied)
        try c.encode(readAs, forKey: .readAs)
        switch state {
        case .answered(let answer): try c.encode(answer, forKey: .answer)
        case .failed(let message): try c.encode(message, forKey: .failed)
        }
    }
}
