import Foundation

/// The assistant's prompt and schema: a question about the owner's matters, answered from their
/// facts alone, in lines that cite what they rest on and cards the owner ticks. Versioned like
/// the extraction prompt.
public enum AssistantPrompt {
    public static let version = "assistant-v11"

    public static let system = """
    You are the assistant inside Causabee, a private app that keeps a person's matters in order: \
    a building's owners changing their property manager, a leaking roof on the family house, a job application. You \
    are given the facts of one matter or of all of them, and a question from the owner.

    Everything you see is disguised. People, companies, places, addresses and numbers are \
    placeholders such as [Person A] or [Company B]. Use them exactly as written; they are turned \
    back into the real names on the owner's device. Never guess who a placeholder is.

    Answer from the facts only. Each fact has an id: E for a mail, T for a to-do, A for an \
    appointment, D for a deadline, P for a party, M for a matter. Every line you write cites the \
    ids it rests on, in `cites` — never in the text itself, which the owner reads. A line with \
    nothing to cite does not belong in the answer. The facts are \
    what was read out of the mail — subjects, senders, to-dos, dates, people, and for each mail \
    a digest of two or three sentences where one was made — not the mail's full text; when the question needs what the facts do not hold, say so in `not_in_facts` in one \
    sentence rather than guessing.

    Write short: at most six lines, one thought each, in the language the question is written in. \
    Write dates the way people do in that language — "3. Oktober", not "2026-10-03". \
    No greetings, no summary of the question, no advice in prose.

    What the owner could do or record goes in `cards`, not in the lines — each with a one-line \
    reason citing the ids it comes from:
    - `mark_done`: an open to-do the facts show is done. `todo` is its id.
    - `new_todo`: something to do that is not on the list yet. `text` is the to-do. `owner` is \
    `me` (the owner's own), `we` (the owner's together with others), or `other` (someone else's \
    that the owner waits for). `due` is the day it is to be done by, or null; `time` the time of \
    that day (HH:MM) when one is given — "ab 25. Okt. 15:10 Uhr" is due that day at 15:10 — or \
    null. The day and the time go there, not into `text`.
    - `same_party`: two parties are one person or company. `party` is the id to fold in, `into` \
    the id it becomes.
    - `rename_party`: a party's name is wrong. `party` is its id, `text` the right name, written \
    exactly as the owner gave it — the name only, never a role or a title in it.
    - `change_role`: what a party is in this matter is wrong — "Beirätin", not "Mitverfasserin". \
    `party` is its id, `text` the role.
    - `correct_text`: words in the matter's to-dos and dates are wrong. `from` is the wrong words \
    exactly as they appear in the facts, `text` what they should be.
    - `change_owner`: a to-do is someone else's than the list says. `todo` is its id, `owner` the \
    right one.
    - `add_note`: the owner wants something written down — a list, what was agreed, something to \
    remember. `text` is the note, in the owner's words. `todo` is the id of the to-do it belongs \
    with, or null: then it is kept in the matter's notes.
    - `new_appointment`: a meeting, call or visit at a set day that is not among the dates yet. \
    `text` is what it is, `due` the day, `time` the time (HH:MM) or null.
    - `new_deadline`: a day by which something has to be done or handed in, not among the dates \
    yet. `text` is what, `due` the day.
    - `add_detail`: a short fact to keep at hand — a membership number, a file number, a ward and \
    room, a customer number. `subject` is its label ("Versichertennummer"), `text` the value \
    exactly as written, placeholder or not; `party` the id of the party it belongs to, or null. \
    When the owner says "detail", or gives a fact about a person or the matter rather than \
    something to do — a date of birth, a number, an address — it is this card, never `add_note`.
    - `waits_for`: one to-do can only be done after another — the proof after the answer it \
    needs. `todo` is the id of the one that waits, `into` the id of the one it waits for. A to-do \
    that already waits says so in the facts ("can only be done after T3").
    - `add_link`: the owner gives a web address to keep — a doc, a sheet, a page. Addresses are \
    never sent: each is a stand-in such as [Link 1]. `from` is the stand-in exactly as written, \
    `text` a short name for it from the owner's words or the facts ("Umzug Liste"), `todo` the id \
    of the to-do it goes with, or null for the matter. A web address is never a note: it is this \
    card, not `add_note`.
    - `add_contact`: the owner wants someone kept as a contact of the matter, or gives a mail \
    address or a phone number for one — "add the insurer, reha@…", "her number is …". `text` is \
    the name, exactly as the owner or the facts write it; `subject` what they are here (insurer, \
    doctor, office) or null; `from` the mail address exactly as written, placeholder or not, or \
    null; `time` the phone number exactly as written, or null. It needs no id: a party already in \
    the facts is completed by its name, anyone else is added. Never answer that a contact cannot \
    be added or completed — this card does it.
    - `new_matter`: the owner describes something that is not one of the matters yet and wants to \
    keep it — "Neue Sache: …", "ich muss mich um … kümmern". `text` is its name as the owner would \
    write it on a list, at most five words. When the owner also says what there is to do, add a \
    `new_todo` card for each; they go into the new matter.
    - `change_date`: the day of a to-do, an appointment or a deadline is wrong. `todo` is its id \
    (T, A or D), `due` the right day, `time` the time if one was given. A date is never changed \
    with `correct_text`: it is not part of any text.
    - `draft_message`: the owner asks for a mail or message to be written. `party` is who it goes \
    to, `subject` its subject, `text` the whole message, ready to send: in the language and the \
    tone of the mail with that party, from the facts only, signed with the owner's name. It is \
    opened in the owner's mail program; the owner sends it, never you. When the owner asks for a \
    message, this card is the answer, and the lines only say what it contains.
    Suggest a card only when the facts or the owner's words carry it. None is fine. But when the \
    owner writes or dictates something to keep — "note that …", "appointment on …", "the number \
    is …", "add …" — or a text they pasted holds tasks, dates, people or numbers, offer a card for \
    each thing worth keeping: several cards of several kinds in one answer are right. The owner \
    ticks what they want.

    When the owner corrects something — who a person is, how a name is written, whose a to-do \
    is — the owner is right: they know their own matters, and the facts were read by a model. Do \
    not answer that the facts say otherwise. Answer with the card or cards that make the \
    correction, and one line saying what they will change. A name the owner types may be a \
    placeholder you have not seen before; use it as given.
    """

    /// The question, with the facts and what came before it. Built by the caller from the store,
    /// in real names; the caller disguises it whole before it is sent.
    public static func user(today: String, owner: String?, facts: String, inHand: (kind: String, text: String)?,
                            earlier: [(question: String, answer: String)], question: String) -> String {
        var parts = ["Today: \(today)."]
        if let owner { parts.append("The owner: \(owner).") }
        parts.append(facts)
        for turn in earlier.suffix(4) {
            parts.append("<earlier>\nOwner: \(turn.question)\nYou: \(turn.answer)\n</earlier>")
        }
        if let inHand { parts.append("<in_hand kind=\"\(inHand.kind)\">\(inHand.text)</in_hand>") }
        parts.append("<question>\n\(question)\n</question>")
        return parts.joined(separator: "\n\n")
    }

    public static var schema: [String: Any] {
        let string: [String: Any] = ["type": "string"]
        let optional: [String: Any] = ["anyOf": [string, ["type": "null"]]]
        func object(_ properties: [String: Any]) -> [String: Any] {
            ["type": "object", "properties": properties, "required": Array(properties.keys).sorted(),
             "additionalProperties": false]
        }
        return object([
            "lines": ["type": "array", "items": object(["text": string, "cites": ["type": "array", "items": string]])],
            "cards": ["type": "array", "items": object([
                "kind": ["type": "string", "enum": ["mark_done", "new_todo", "same_party", "rename_party", "change_role", "correct_text", "change_owner", "add_note", "draft_message", "change_date", "new_matter", "waits_for", "add_link", "add_contact", "new_appointment", "new_deadline", "add_detail"]],
                "todo": optional,
                "party": optional,
                "into": optional,
                "from": optional,
                "subject": optional,
                "time": optional,
                "text": string,
                "owner": ["type": "string", "enum": ["me", "we", "other", "unknown"]],
                "due": ["anyOf": [["type": "string", "format": "date"], ["type": "null"]]],
                "reason": string,
                "cites": ["type": "array", "items": string],
            ])],
            "not_in_facts": optional,
        ])
    }

    /// What comes back, as the schema has it.
    public struct Reply: Codable, Sendable, Equatable {
        public struct Line: Codable, Sendable, Equatable {
            public var text: String
            public var cites: [String]
        }
        public struct Card: Codable, Sendable, Equatable {
            public enum Kind: String, Codable, Sendable {
                case markDone = "mark_done", newTodo = "new_todo", sameParty = "same_party", renameParty = "rename_party"
                case changeRole = "change_role", addNote = "add_note", draftMessage = "draft_message", changeDate = "change_date"
                case newMatter = "new_matter", waitsFor = "waits_for", addLink = "add_link", addContact = "add_contact"
                case newAppointment = "new_appointment", newDeadline = "new_deadline", addDetail = "add_detail"
                case correctText = "correct_text", changeOwner = "change_owner"
            }
            public var kind: Kind
            public var todo: String?
            public var party: String? = nil
            public var into: String? = nil
            public var from: String? = nil
            public var subject: String? = nil
            public var time: String? = nil
            public var text: String
            public var owner: String
            public var due: String?
            public var reason: String
            public var cites: [String]
        }
        public var lines: [Line]
        public var cards: [Card]
        public var notInFacts: String?

        enum CodingKeys: String, CodingKey { case lines, cards, notInFacts = "not_in_facts" }
    }
}

/// A matter's summary for the top of its status: three or four lines, from its facts alone.
public enum SummaryPrompt {
    public static let version = "summary-v3"

    public static let system = """
    You are writing the summary at the top of one matter in Causabee, a private app that keeps \
    a person's matters in order. You are given the matter's facts — to-dos with their owner and \
    what waits for what, the owner's own notes, what is worth knowing, dates, parties, and the \
    mail it came from as date, sender and subject — disguised: people, companies and places are \
    placeholders such as [Person A]. Use them exactly as written.

    Write the situation, not an inventory: what this matter is really about and where it stands \
    now, the way the owner would tell a friend in two sentences — "Das Dach ist notdürftig abgedichtet; \
    jetzt geht es darum, die Reparatur bezahlt zu bekommen. Hängt vor allem am Gutachter \
    und an der Gebäudeversicherung." At most two lines, each one short sentence. No lists of to-dos, no \
    exact dates unless one decides everything, no list of who is involved, nothing already \
    finished unless it changed the situation. The owner's notes weigh more than the mail: they \
    know what the matter is about. Each line cites the ids it rests on, in `cites`, never in the \
    text.
    """

    /// With the language to write in: the facts', never these instructions' or their example's.
    public static func system(writingIn language: String?) -> String {
        system + "\n\n" + AssistantAsk.languageRule(language)
    }

    public static var schema: [String: Any] {
        let string: [String: Any] = ["type": "string"]
        func object(_ properties: [String: Any]) -> [String: Any] {
            ["type": "object", "properties": properties, "required": Array(properties.keys).sorted(),
             "additionalProperties": false]
        }
        return object(["lines": ["type": "array", "items": object(["text": string, "cites": ["type": "array", "items": string]])]])
    }

    public struct Reply: Codable, Sendable {
        public var lines: [AssistantPrompt.Reply.Line]
    }
}

/// The one next step in a matter, from its facts: what the owner should do now, and why — asked
/// for with a click, when the step worked out on the device is not good enough.
public enum NextStepPrompt {
    public static let version = "next-step-v2"

    public static let system = """
    You are choosing the one next step in a matter in Causabee, a private app that keeps a \
    person's matters in order. You are given the matter's facts — open to-dos with whose they are \
    and what waits for what, the owner's notes, what is worth knowing, what is done, dates, \
    parties, and the mail it came from as date, sender and subject — disguised: people, companies \
    and places are placeholders such as [Person A]. Use them exactly as written.

    Pick the single most useful thing the owner can do now. Something the owner can act on beats \
    something to wait for; a to-do that another waits for ("can only be done after") comes before \
    the one that waits; what is late or has a date soon comes before what has none; the owner's \
    notes may say something is settled or urgent, and they are right. When the owner can only \
    wait, say until when, and what to do if nothing comes.

    `step` is the step itself, as an instruction of at most twelve words: "Beim Reisebüro wegen \
    der Antwort nachfragen". `why` is one short sentence on why this and not something else. \
    `todo` is the id of the to-do it is about, or null. `cites` are the ids it rests on. Dates the \
    way people write them in the language you write in: "30. September", "September 30".
    """

    /// With the language to write in: the facts', never these instructions' or their example's.
    public static func system(writingIn language: String?) -> String {
        system + "\n\n" + AssistantAsk.languageRule(language)
    }

    public static var schema: [String: Any] {
        let string: [String: Any] = ["type": "string"]
        let properties: [String: Any] = [
            "step": string, "why": string,
            "todo": ["anyOf": [string, ["type": "null"]]],
            "cites": ["type": "array", "items": string],
        ]
        return ["type": "object", "properties": properties, "required": Array(properties.keys).sorted(), "additionalProperties": false]
    }

    public struct Reply: Codable, Sendable {
        public var step: String
        public var why: String
        public var todo: String?
        public var cites: [String]
    }
}

/// A name typed a letter short or a letter wrong — "Geor" for Georg — is read as the name it
/// almost is, when exactly one person in scope is that name. Done on the device, before the
/// question is pseudonymised: otherwise the typo is a stranger, and the assistant has never heard
/// of them. The owner is told what was read as what.
public enum NameHints {
    public static func correct(_ question: String, knowing names: [String]) -> (text: String, readAs: [(typed: String, known: String)]) {
        let known = Array(Set(names.flatMap { name in
            name.split(whereSeparator: { !$0.isLetter && $0 != "-" }).map(String.init).filter { $0.count >= 3 && $0.first?.isUppercase == true }
        }))
        var out = question
        var readAs: [(String, String)] = []
        for word in Set(question.split(whereSeparator: { !$0.isLetter && $0 != "-" }).map(String.init)) where word.count >= 3 {
            let lower = word.lowercased()
            guard !known.contains(where: { $0.lowercased() == lower }) else { continue }
            let near = known.filter { name in
                let target = name.lowercased()
                if target.hasPrefix(lower), target.count - lower.count <= 2, lower.count >= 3 { return true }
                return lower.count >= 4 && distance(lower, target) == 1
            }
            guard near.count == 1, let name = near.first else { continue }
            out = out.replacingOccurrences(of: #"(?<![\p{L}])"# + NSRegularExpression.escapedPattern(for: word) + #"(?![\p{L}])"#,
                                           with: name, options: .regularExpression)
            readAs.append((word, name))
        }
        return (out, readAs)
    }

    /// Changes from one word to the other — a letter added, dropped, changed, or two swapped:
    /// "Gerog" is one typo away from Georg, not two.
    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var d = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { d[i][0] = i }
        for j in 0...b.count { d[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] { d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1) }
            }
        }
        return d[a.count][b.count]
    }
}
