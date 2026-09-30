import Foundation

/// Step 5's prompt and schema. Versioned, because the spike's exit criteria ask for a chosen
/// prompt, and a number in the log is the only way to know which prompt produced which answer.
///
/// Every rule here mirrors a rule the golden set was labelled by (`docs/golden-set.md`). A
/// prompt that asks for something different from what the labels mean would measure the
/// difference between two definitions, not how good the model is.
public enum ExtractionPrompt {
    public static let version = "extract-v13"

    /// Added for a model that writes a to-do for everything a mail touches — Mistral wrote half
    /// again as many as Opus, most of them "confirm the appointment" and "prepare for it". Opus
    /// is not given it: its answers are kept, and a changed prompt would send every mail again.
    public static let strictVersion = version + "+strict"
    public static let strict = """

    ## Fewer, real to-dos

    A to-do is only what the mail actually asks someone to do, or what plainly has to happen \
    because of it. No to-do to attend, confirm or prepare for a meeting, a call or an invitation \
    unless the mail asks for exactly that. What anyone would do anyway — read the attachment, \
    keep the date free, think about questions for the interview — is not a to-do. When unsure, \
    leave it out: a missing small to-do costs less than a list full of obvious ones.
    """

    public static let system = """
    You read one email from a private person's mailbox and write down what is in it, as JSON \
    matching the schema you are given. Your output becomes suggestions the person checks, so a \
    fact you are not sure of is worse than a fact left out.

    ## Write in the email's language

    Everything you write — to-dos, deadlines, roles, the matter's title, summary and reason, the \
    digest — is in the same language as the email's own words: a German email gets German \
    to-dos, an English email about a job offer gets English ones. Never translate. Only names, \
    and words copied in `source_quote`, stay exactly as the email has them.

    ## The names have been disguised

    Every person, company, place, address, phone number and account number in the email has \
    been replaced before it reached you — either with a tag such as [Person A] or [Company B], \
    or with an invented name of the same kind. Treat the replacements as the real names. Copy \
    them into your answer exactly as they are written, including brackets, so they can be put \
    back afterwards. Never guess at the real name behind one.

    ## Which part of the email

    The newest message is what you are reading. Quoted replies and forwarded history below it \
    are context: use them to understand the newest message, but take to-dos and deadlines from \
    the newest message only, unless it was forwarded precisely to pass on what is below it.

    Sometimes what you are given is not an email but a chat, read from a screenshot: one message \
    a line, with its minute and who said it, under day markers such as "— Heute —". The owner's \
    own messages carry the owner's name, so what the owner promises there is the owner's to-do. \
    Read it as you would an email thread; a line in square brackets says what could not be read. \
    Or it is a document read from a PDF — a letter, an offer, a bill, a notice — page by page \
    under "— Seite n —", sent from "Dokument": read it as a letter to the owner.

    ## matter

    A matter is something that runs over a stretch of time, has people in it, and has steps that \
    are not finished — a change of property manager, a job offer, a hospital discharge, a tax \
    case. A dinner invitation, a newsletter, a receipt or a login code is not a matter. Most \
    email belongs to no matter; then `matter` is null.

    You are given the matters found so far, each with a short summary. When the email belongs to \
    one of them, use its name exactly. The list is not a menu: an email that belongs to none of \
    them but is a matter in its own right starts a new one. Give it a short lowercase name \
    without spaces (for example `hausverwaltung` or `jobwechsel`) that says what the matter is \
    about, not who is in it, set `matter_is_new` to true, and write a one-line `matter_summary`. \
    Give a new matter a `matter_title` too: what the owner would call it on a list, in the \
    language of the email, spelled as it is written, with capitals and umlauts, at most five \
    words — `Sperrmüll` for `sperrmuell`, `Neue Hausverwaltung` for `hausverwaltung`. For a matter \
    that is not new, `matter_title` is null. \
    When you are told the email is a reply in a thread already assigned to a matter, it belongs \
    to that matter unless it plainly changes the subject. `matter_confidence` is how \
    sure you are, from 0 to 1, and `matter_reason` says why in one line.

    ## parties

    Only the people and organisations that are part of the matter — not everyone whose name \
    appears, and nobody at all when `matter` is null. Never the mailbox owner: the matter is \
    theirs, and they are not a party to it. `role` is what they are to the matter, in \
    a word or two: Hausverwaltung, Anbieter, Nachbar, Ärztin — but only \
    as far as the email shows it. A first name with nothing said about the person is not a \
    neighbour or a colleague; write `unklar` rather than guess. `is_new` \
    is true when the party is not named in the matter's summary.

    ## todos

    Something that has to be done, as the email says it — never something the email only \
    implies. Write it short. `owner` says whose it is:

    - `me` — the mailbox owner has to do it.
    - `we` — the mailbox owner does it together with others, as one of a group: the owners of a \
    building who together call on the property manager, a family that together arranges care.
    - `other` — someone else has to do it, and the mailbox owner is waiting for it: something \
    they asked for, need, or have to act on once it is done. "The property manager sends the \
    invitation to the meeting" is one.
    - `unknown` — the email does not make clear whose it is.

    A task of someone else's that the mailbox owner is not waiting for is not a to-do here: \
    "the property manager prepares the annual accounts", said in passing, is left out. \
    `due` is a date only when the email gives one, otherwise null.

    ## To-dos already on file

    You may be given the open to-dos a matter already has, each with an id such as `T3`. A \
    matter keeps one list, so a to-do the email asks for again — a reminder, a "did you manage \
    to…", a reply saying it will be done — is not a new one: put it in `todos` with `same_as` set \
    to its id. A to-do that is not on file has `same_as` null.

    When the email shows that one of them is done — the document was sent, the slot was booked, \
    the question was answered — put its id in `done`, with the words that show it in \
    `source_quote`. Only what the email shows is done; not what is merely promised.

    ## appointments

    A meeting, call or visit at a set time: the site visit on 9 September at 10, the interview \
    on Wednesday, a doctor's appointment. `what` says what it is, `date` is the day, `time` is \
    `HH:MM` or null, `place` is where or null. An appointment is not a to-do: the to-do is only \
    what has to be done for it — confirm it, prepare for it, book a slot. A calendar invitation \
    is an appointment.

    ## deadlines

    A date by which something has to happen, whether or not anyone is named as doing it: \
    "Angebot gebunden bis 31.10." is a deadline with no to-do attached. An invitation is not a \
    matter, but the date to reply by is a deadline. The date of an event is an appointment, not \
    a deadline, unless something has to be done by then.

    ## digest

    `digest` is two or three short sentences, in the same language as the email, on what this email itself says: what it \
    tells or asks, with the details someone would look up months later — amounts, numbers of \
    things, what was agreed, what an attachment is, what someone promised. Not the to-dos again \
    in other words, and not who sent it or when: those are known. Null for an email with nothing \
    worth keeping.

    ## Dates and quotes

    Write every date as YYYY-MM-DD. Resolve relative dates ("nächsten Freitag", "Ende des Monats") \
    against the date the email was sent, which you are given. `source_quote` is the shortest \
    stretch of the email's own words that shows the fact, copied exactly — never paraphrased.
    """

    /// What the mailbox owner is called in disguise, what has been found so far, and the mail.
    /// Only disguised text ever goes into this.
    public struct OpenTodo: Sendable {
        public var id: String
        public var owner: String
        public var text: String
        public init(id: String, owner: String, text: String) { self.id = id; self.owner = owner; self.text = text }
    }

    public static func user(mail: String, sent: Date?, owner: [String], matters: [(name: String, summary: String)],
                            thread: String? = nil, open: [(matter: String, todos: [OpenTodo])] = []) -> String {
        var parts: [String] = []
        if owner.isEmpty {
            parts.append("The mailbox owner is not known.")
        } else {
            parts.append("The mailbox owner (\"me\") appears as: \(owner.joined(separator: ", ")).")
        }
        if let sent {
            let format = DateFormatter()
            format.locale = Locale(identifier: "en_US_POSIX")
            format.dateFormat = "yyyy-MM-dd (EEEE)"
            parts.append("The email was sent on \(format.string(from: sent)).")
        }
        if matters.isEmpty {
            parts.append("No matters have been found yet.")
        } else {
            parts.append("Matters found so far:\n" + matters.map { "- \($0.name): \($0.summary)" }.joined(separator: "\n"))
        }
        if let thread {
            parts.append("This email is a reply in a thread whose earlier emails were assigned to the matter `\(thread)`.")
        }
        let listed = open.filter { !$0.todos.isEmpty }
        if !listed.isEmpty {
            parts.append("Open to-dos already on file:\n" + listed.map { matter in
                "\(matter.matter):\n" + matter.todos.map { "  \($0.id) (\($0.owner)): \($0.text)" }.joined(separator: "\n")
            }.joined(separator: "\n"))
        }
        parts.append("<email>\n\(mail)\n</email>")
        return parts.joined(separator: "\n\n")
    }

    /// Structured outputs guarantee the answer parses. Every object closes with
    /// `additionalProperties: false`, which the API requires.
    public static var schema: [String: Any] {
        let string: [String: Any] = ["type": "string"]
        let date: [String: Any] = ["type": "string", "format": "date"]
        let optionalDate: [String: Any] = ["anyOf": [date, ["type": "null"]]]
        func object(_ properties: [String: Any]) -> [String: Any] {
            ["type": "object", "properties": properties, "required": Array(properties.keys).sorted(),
             "additionalProperties": false]
        }
        return object([
            "matter": ["anyOf": [string, ["type": "null"]]],
            "matter_is_new": ["type": "boolean"],
            "matter_title": ["anyOf": [string, ["type": "null"]]],
            "matter_summary": ["anyOf": [string, ["type": "null"]]],
            "matter_confidence": ["type": "number"],
            "matter_reason": string,
            "digest": ["anyOf": [string, ["type": "null"]]],
            "parties": ["type": "array", "items": object(["name": string, "role": string, "is_new": ["type": "boolean"]])],
            "todos": ["type": "array", "items": object([
                "text": string,
                "owner": ["type": "string", "enum": ["me", "we", "other", "unknown"]],
                "due": optionalDate,
                "source_quote": string,
                "same_as": ["anyOf": [string, ["type": "null"]]],
            ])],
            "done": ["type": "array", "items": object(["todo": string, "source_quote": string])],
            "appointments": ["type": "array", "items": object([
                "what": string, "date": date,
                "time": ["anyOf": [string, ["type": "null"]]],
                "place": ["anyOf": [string, ["type": "null"]]],
                "source_quote": string,
            ])],
            "deadlines": ["type": "array", "items": object(["what": string, "date": date, "source_quote": string])],
        ])
    }
}
