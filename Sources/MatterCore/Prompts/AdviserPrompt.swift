import Foundation

/// The adviser: from one matter's facts, what Causabee understands of it — the brief — with the
/// summary and the next step that come from it, and the changes to the to-do list it proposes.
/// One request, where there were two for the summary and the step.
public enum AdviserPrompt {
    public static let version = "adviser-v1"

    public static let system = """
    You are the adviser for one matter in Causabee, a private app that keeps a person's matters \
    in order: a building's owners changing their property manager, care for a parent after a \
    fall, a leaking roof. You are given the matter's facts — open to-dos with whose they are and \
    what waits for what, what is done, the owner's notes, dates, parties, files, and the mail it \
    came from as date, sender, subject and a short digest — disguised: people, companies and \
    places are placeholders such as [Person A]. Use them exactly as written.

    Each fact has an id: E a mail, T a to-do, A an appointment, D a deadline, P a party, M the \
    matter. Cite the ids a line rests on in `cites`, never in the text.

    What the owner said about the matter is always right, whatever the mail seems to say: write \
    everything around it. A brief written before may be among the facts; it can be out of date.

    ## brief

    What the matter is, the way a good adviser would hold it in mind — short lines, each one \
    thought, in parts:
    - `about`: what this is about, in one or two lines.
    - `goal`: what the owner wants to come out of it — as far as the facts or the owner say; \
    none when it is not clear.
    - `people`: who is who and what each one is to the owner here — only those that matter.
    - `agreed`: what is settled or promised — amounts, dates, terms — that someone would look up.
    - `open`: what is still to be done by the owner, in a line each for what belongs together — \
    not the to-do list again.
    - `waiting`: what the owner is waiting for, from whom, and since when.
    - `risks`: what could go wrong or cost money if nothing happens — a deadline to object, a \
    payment, a term ending. Only what the facts carry.
    - `decision`: the next thing the owner has to decide, if there is one.
    At most twenty lines in all; leave out a part with nothing to say.

    ## summary and step

    `summary` is the situation in at most two short sentences, the way the owner would tell a \
    friend — not an inventory. `step` is the single most useful thing the owner can do now, as an \
    instruction of at most twelve words; `why` one short sentence on why this; `todo` the id of \
    the to-do it is about, or null. Something to act on beats something to wait for; what waits \
    for another comes after it; what is late or soon comes first. When the owner can only wait, \
    say until when, and what to do if nothing comes.

    ## proposals

    Changes to the to-do list that make it say what the matter needs, each a card the owner \
    ticks or puts away — none is fine, and at most five:
    - `new_todo`: a next step that is missing: concrete, starting with what to do — whom to \
    call or write, about what, with what — not a sentence copied from a mail. `owner` is `me`, \
    `we` or `other` (someone else's that the owner waits for); `due` the day it must be done by \
    when the facts give or plainly imply one — a period to object counted from the day a letter \
    came — else null; `time` null.
    - `mark_done`: an open to-do the facts show is done. `todo` its id.
    - `correct_text`: a to-do written so it is unclear or only repeats a mail: `from` the words \
    exactly as in the facts, `text` what they should say.
    - `waits_for`: one open to-do can only be done after another: `todo` the one that waits, \
    `into` the one it waits for.
    - `change_owner`: an open to-do is someone else's: `todo` its id, `owner` the right one.
    - `change_date`: a to-do's day is wrong or missing and the facts give it: `todo`, `due`.
    Two open to-dos that are one: `mark_done` the weaker with the reason that the other covers it. \
    Never propose what is on the list already, and nothing the owner put away (listed in the \
    question). Every card has a one-line `reason` citing its ids. Unused fields are null; \
    `attach` is empty.
    """

    /// With the language to write in: the facts', never these instructions'.
    public static func system(writingIn language: String?) -> String {
        system + "\n\n" + AssistantAsk.languageRule(language)
    }

    public static var schema: [String: Any] {
        let string: [String: Any] = ["type": "string"]
        let optional: [String: Any] = ["anyOf": [string, ["type": "null"]]]
        let cites: [String: Any] = ["type": "array", "items": string]
        func object(_ properties: [String: Any]) -> [String: Any] {
            ["type": "object", "properties": properties, "required": Array(properties.keys).sorted(), "additionalProperties": false]
        }
        return object([
            "brief": ["type": "array", "items": object([
                "part": ["type": "string", "enum": Brief.Part.allCases.map(\.rawValue)], "text": string, "cites": cites,
            ])],
            "summary": ["type": "array", "items": object(["text": string, "cites": cites])],
            "step": string, "why": string, "todo": optional, "step_cites": cites,
            "proposals": ["type": "array", "items": object([
                "kind": ["type": "string", "enum": ["new_todo", "mark_done", "correct_text", "waits_for", "change_owner", "change_date"]],
                "todo": optional, "party": optional, "into": optional, "from": optional, "subject": optional, "time": optional,
                "text": string,
                "owner": ["type": "string", "enum": ["me", "we", "other", "unknown"]],
                "due": ["anyOf": [["type": "string", "format": "date"], ["type": "null"]]],
                "reason": string, "cites": cites, "attach": cites,
            ])],
        ])
    }

    public struct Reply: Codable, Sendable {
        public struct Part: Codable, Sendable {
            public var part: Brief.Part
            public var text: String
            public var cites: [String]
        }
        public var brief: [Part]
        public var summary: [AssistantPrompt.Reply.Line]
        public var step: String
        public var why: String
        public var todo: String?
        public var stepCites: [String]
        public var proposals: [AssistantPrompt.Reply.Card]

        enum CodingKeys: String, CodingKey { case brief, summary, step, why, todo, proposals, stepCites = "step_cites" }
    }

    /// The question, in the matter's language, with what the owner put away.
    public static func question(_ facts: Facts, dismissed: [String]) -> String {
        var question = facts.language == "German" ? "Schreibe den Überblick dieser Sache." : "Write the brief of this matter."
        if !dismissed.isEmpty {
            question += "\n\nPut away by the owner, not to be proposed again:\n" + dismissed.map { "- \($0)" }.joined(separator: "\n")
        }
        return question
    }
}

extension AssistantAsk {
    /// What the adviser wrote, in real names: the brief's lines, the summary, the step, and the
    /// proposals with their ids still as in the facts — `facts.refs` says what each stands for.
    public struct Advice: Sendable {
        public var lines: [Brief.Line]
        public var summary: [String]
        public var step: String
        public var why: String
        public var todo: FactRef?
        public var proposals: [AssistantPrompt.Reply.Card]
        public var cost: Double
    }

    /// About what it costs: the facts in, the brief, the summary and a few cards out.
    public static func adviceEstimate(_ facts: Facts, model: Claude.Model = .opus) -> Double {
        model.cost(input: Int(Double(facts.text.count) / 3.2) + 2_400, output: 1_600)
    }

    public static func advise(facts: Facts, dismissed: [String], owner: String?, today: String, mapping url: URL, claude: Claude,
                              model: Claude.Model = .opus) async throws -> Advice {
        let prepared = try prepare(question: AdviserPrompt.question(facts, dismissed: dismissed), inHand: nil, earlier: [], facts: facts,
                                   owner: owner, today: today, mapping: url)
        return try await advise(prepared, facts: facts, claude: claude, model: model)
    }

    /// The same with a list of names in hand — the iPhone's way: nothing it learned is kept.
    public static func advise(facts: Facts, dismissed: [String], owner: String?, today: String, mapping: Pseudonymizer.Mapping,
                              others: [Pseudonymizer.Entry], claude: Claude, model: Claude.Model = .opus) async throws -> Advice {
        let prepared = try prepare(question: AdviserPrompt.question(facts, dismissed: dismissed), inHand: nil, earlier: [], facts: facts,
                                   owner: owner, today: today, mapping: mapping, others: others, save: nil)
        return try await advise(prepared, facts: facts, claude: claude, model: model)
    }

    static func advise(_ prepared: Prepared, facts: Facts, claude: Claude, model: Claude.Model) async throws -> Advice {
        let body = Claude.body(model: model, system: AdviserPrompt.system(writingIn: facts.language), user: prepared.sent,
                               schema: AdviserPrompt.schema, effort: "low")
        let answer = try await claude.send(body, model: model)
        let reply = try JSONDecoder().decode(AdviserPrompt.Reply.self, from: answer.json)
        return advice(from: reply, restorer: prepared.pseudonymizer.restorer, links: prepared.links, refs: facts.refs, cost: answer.cost)
    }

    /// The reply in real names. Separate, to be tested without sending anything.
    static func advice(from reply: AdviserPrompt.Reply, restorer: Replacer, links: [String: String], refs: [String: FactRef], cost: Double) -> Advice {
        func real(_ text: String) -> String {
            links.reduce(restorer.apply(text).text) { $0.replacingOccurrences(of: $1.key, with: $1.value) }
        }
        func real(_ text: String?) -> String? { text.map { real($0) } }
        let proposals = reply.proposals.map { card -> AssistantPrompt.Reply.Card in
            var card = card
            card.text = real(card.text)
            card.reason = real(card.reason)
            card.from = real(card.from)
            card.attach = []
            return card
        }
        // A card about a fact the facts do not have is of no use: it could not be taken.
        .filter { card in [card.todo, card.into].compactMap { $0 }.allSatisfy { refs[$0] != nil } }
        return Advice(lines: reply.brief.map { Brief.Line(part: $0.part, text: real($0.text)) },
                      summary: reply.summary.map { real($0.text) }, step: real(reply.step), why: real(reply.why),
                      todo: reply.todo.flatMap { refs[$0] }, proposals: proposals, cost: cost)
    }
}
