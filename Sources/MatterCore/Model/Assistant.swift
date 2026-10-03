import Foundation
import NaturalLanguage
import SwiftData

/// A fact the assistant was shown, by the id it was shown under — so a line that cites `T4` can
/// be a door to that to-do.
public enum FactRef: Hashable, Sendable, Codable {
    case matter(PersistentIdentifier)
    case entry(PersistentIdentifier)
    case todo(PersistentIdentifier)
    case appointment(PersistentIdentifier)
    case deadline(PersistentIdentifier)
    case party(PersistentIdentifier)
}

/// What the assistant is shown about the matters in scope, in real names, and what each id is.
public struct Facts: Sendable {
    public var text: String
    public var refs: [String: FactRef]
    /// For the screen: what it can see, in words. "75 Mails, 46 offene Aufgaben, 8 Termine".
    public var seen: String
    /// What the owner wrote in their own words — a matter's notes, a to-do's note. Read on the
    /// device for names like a typed question, because nothing has disguised it before.
    public var ownerText: String = ""
    /// The language the matter is written in — its mails, tasks and notes — in English words:
    /// "German", "English". What a summary or a next step is written in. Nil when it cannot be told.
    public var language: String? = nil
}

@MainActor
public enum FactSheet {
    /// One matter in full — every to-do, date, party and mail subject — or, for several, each one
    /// in brief: what is open and what comes next. The store holds facts, not mail, so a mail is
    /// its date, sender and subject.
    /// With something in hand — a person, a to-do — a matter is shown without its whole history:
    /// its people, its open to-dos and dates, and only the mail that mentions what is in hand.
    /// Changing a person's role does not need seventy-five mail subjects.
    /// `keptText`: the words kept on this device of a screenshot or a PDF the owner brought in —
    /// a chat, a portal page — given with it, since its summary line alone is too little.
    public static func facts(for matters: [Matter], today: String, focus: String? = nil, mails: Int = 120,
                             keptText: ((Entry) -> String?)? = nil) -> Facts {
        let focusWords = (focus ?? "").lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init).filter { $0.count >= 4 }
        func mentions(_ text: String) -> Bool {
            let lower = text.lowercased()
            return focusWords.contains { lower.contains($0) }
        }
        let focused = !focusWords.isEmpty
        var refs: [String: FactRef] = [:]
        var counters: [String: Int] = [:]
        func id(_ prefix: String, _ ref: FactRef) -> String {
            counters[prefix, default: 0] += 1
            let id = "\(prefix)\(counters[prefix]!)"
            refs[id] = ref
            return id
        }
        let detailed = matters.count == 1
        var blocks: [String] = []
        var ownerText: [String] = []
        var mailCount = 0, todos = 0, dates = 0
        for matter in matters {
            let status = MatterStatus(matter)
            var lines: [String] = []
            let names = ([matter.key] + matter.aliases).filter { $0 != matter.name }
            lines.append("<matter id=\"\(id("M", .matter(matter.persistentModelID)))\" name=\"\(matter.name)\"\(names.isEmpty ? "" : " also=\"\(names.joined(separator: ", "))\"")>")
            if let notes = matter.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("The owner's notes on this matter:\n\(notes)")
                ownerText.append(notes)
            }
            ownerText += (matter.todos ?? []).compactMap(\.note)
            ownerText += (matter.links ?? []).filter(\.isKept).map(\.title).filter { !$0.isEmpty }
            let open = [Todo.Owner.me, .we, .other, .unknown].flatMap(status.open)
            lines.append(open.isEmpty ? "No open to-dos." : "Open to-dos:")
            // Ids first, so a to-do can say which one it waits for, wherever that one is listed.
            let openIDs = Dictionary(uniqueKeysWithValues: open.map { ($0.persistentModelID, id("T", .todo($0.persistentModelID))) })
            for todo in open {
                var line = "\(openIDs[todo.persistentModelID]!) [\(todo.owner.rawValue)] \(todo.text)"
                if let due = todo.due { line += " (due \(due)\(todo.dueTime.map { " \($0)" } ?? ""))" }
                if let blocker = todo.waitsFor {
                    if let blockerID = openIDs[blocker.persistentModelID] { line += " — can only be done after \(blockerID)" }
                    else if blocker.isDone { line += " — what it waited for is done: \(blocker.text)" }
                }
                if todo.sources.count > 1 { line += " — asked \(todo.sources.count)×" }
                if let note = todo.note, !note.isEmpty { line += " — owner's note: \(note.replacingOccurrences(of: "\n", with: "; "))" }
                // The name of a link only: its address may open a shared doc.
                for link in todo.links ?? [] { line += " — linked: \(link.forFacts)" }
                if detailed, !focused || mentions(todo.text), let quote = todo.sources.first?.quote { line += " — \"\(quote.prefix(160))\"" }
                if let day = todo.sources.first?.date { line += " — since \(MatterStatus.day(day))" }
                lines.append(line)
            }
            todos += open.count
            let links = (matter.links ?? []).filter { $0.todo == nil && $0.isKept }.sorted { $0.createdAt < $1.createdAt }
            if detailed, !links.isEmpty {
                lines.append("The owner's links (names only; the owner opens them):")
                for link in links { lines.append("- \(link.forFacts)") }
            }
            if detailed, !matter.infos.isEmpty {
                // Worth knowing, and not to do: the owner said so.
                lines.append("Worth knowing (not to-dos):")
                for info in matter.infos.prefix(focused ? 10 : 30) {
                    lines.append("\(id("T", .todo(info.persistentModelID))) \(info.text)")
                }
            }
            if detailed {
                let done = focused ? Array(status.done.filter { mentions($0.text) }.prefix(10)) : Array(status.done.prefix(30))
                if !done.isEmpty { lines.append("Done:") }
                for todo in done {
                    lines.append("\(id("T", .todo(todo.persistentModelID))) [\(todo.owner.rawValue)] \(todo.text) — done \(todo.doneAt.map(MatterStatus.day) ?? "")")
                }
            }
            let upcoming = status.upcomingAppointments
            let appointments = detailed ? upcoming + status.pastAppointments.prefix(10) : upcoming
            if !appointments.isEmpty { lines.append("Appointments:") }
            for item in appointments {
                lines.append("\(id("A", .appointment(item.persistentModelID))) \(item.day)\(item.time.map { " \($0)" } ?? "") \(item.what)\(item.place.map { " at \($0)" } ?? "")")
            }
            let deadlines = detailed ? status.deadlines : status.deadlines.filter { $0.day >= status.today }
            if !deadlines.isEmpty { lines.append("Deadlines:") }
            for item in deadlines {
                lines.append("\(id("D", .deadline(item.persistentModelID))) \(item.day) \(item.what)")
            }
            dates += appointments.count + deadlines.count
            if detailed {
                let memberships = status.memberships
                if !memberships.isEmpty { lines.append("Parties:") }
                for membership in memberships {
                    guard let party = membership.party else { continue }
                    lines.append("\(id("P", .party(party.persistentModelID))) \(party.name)\(membership.role.map { " — \($0)" } ?? "") (in \(membership.mentions) mails)")
                }
                // A file in hand: what is known of it, and the mail it came with — always listed,
                // whatever its subject says. Its text is not kept; a scanned file's facts are above.
                let files = focused ? (matter.documents ?? []).filter { $0.shownName == focus || $0.name == focus } : []
                for file in files {
                    var line = "The file in hand: \(file.shownName)"
                    if file.title != nil { line += " (file name: \(file.name))" }
                    if let came = status.entries.first(where: { !file.messageID.isEmpty && $0.messageID == file.messageID }) {
                        line += " — came with the mail of \(came.date.map(MatterStatus.day) ?? "?") from \(Email.displayName(in: came.from) ?? Email.address(in: came.from)): \(came.title)"
                    }
                    line += file.readAt.map { " — scanned \(MatterStatus.day($0)): what it said is in the to-dos, dates and notes above, with their sources" }
                        ?? " — not scanned yet: only its name and its mail are known; scanning it would tell more"
                    lines.append(line)
                }
                let fileMails = Set(files.map(\.messageID).filter { !$0.isEmpty })
                let entries = focused
                    ? Array(status.entries.filter { fileMails.contains($0.messageID) || mentions($0.title) || mentions($0.from) }.prefix(15))
                    : Array(status.entries.prefix(mails))
                if !entries.isEmpty { lines.append("Mails, newest first:") }
                for entry in entries {
                    let from = Email.displayName(in: entry.from) ?? Email.address(in: entry.from)
                    var line = "\(id("E", .entry(entry.persistentModelID))) \(entry.date.map(MatterStatus.day) ?? "?") from \(from): \(entry.title)"
                    // What the mail said, so a question about its details has something to go on.
                    if let digest = entry.digest, !digest.isEmpty { line += " — " + digest.replacingOccurrences(of: "\n", with: " ") }
                    if [.screenshot, .document].contains(entry.source.kind), let text = keptText?(entry), !text.isEmpty {
                        line += " — its words: \"" + String(text.prefix(1500)).replacingOccurrences(of: "\n", with: " / ") + "\""
                    }
                    lines.append(line)
                }
                mailCount += entries.count
            } else if let last = status.lastDate {
                lines.append("Last mail: \(MatterStatus.day(last)), \(matter.entries?.count ?? 0) mails in all.")
            }
            lines.append("</matter>")
            blocks.append(lines.joined(separator: "\n"))
        }
        var seen: [String] = []
        if detailed { seen.append("\(mailCount) \(mailCount == 1 ? "mail" : "mails")") } else { seen.append("\(matters.count) \(matters.count == 1 ? "matter" : "matters")") }
        seen.append("\(todos) open \(todos == 1 ? "task" : "tasks")")
        if dates > 0 { seen.append("\(dates) appointments and deadlines") }
        // What the matter is written in: its own words, not the labels above them.
        let words = matters.flatMap { matter in
            [matter.notes ?? ""] + (matter.todos ?? []).map(\.text) + (matter.entries ?? []).prefix(40).flatMap { [$0.title, $0.digest ?? ""] }
        }
        return Facts(text: blocks.joined(separator: "\n\n"), refs: refs, seen: seen.joined(separator: ", "),
                     ownerText: ownerText.joined(separator: "\n"), language: AssistantAsk.language(of: words))
    }
}

/// Asks. Everything that leaves goes through the same disguise as the mail: the mapping is read
/// from disk, the question and the facts are searched for names on the device and any new one is
/// learned before the whole request is disguised, and the answer is turned back into real names
/// here. The mapping never leaves; what was sent is returned, so the screen can show it.
public enum AssistantAsk {
    public struct Answer: Sendable, Codable {
        /// In real names.
        public var reply: AssistantPrompt.Reply
        /// Exactly what went to the API, disguised.
        public var sent: String
        public var cost: Double
        public var seconds: Double
        /// Names found in the question or the facts that the mapping did not know yet.
        public var newNames: Int
        /// The web addresses typed in the question, by the stand-in sent instead: `[Link 1]`.
        public var links: [String: String]?
        /// Which model wrote it, as the API named it. Nil in answers from before there was a choice.
        public var servedBy: String?

        /// The name a person reads: "Mistral Large 3".
        public var modelLabel: String {
            guard let servedBy else { return Claude.Model.opus.label }
            return Claude.Model.serving(servedBy)?.label ?? servedBy
        }

        /// The answer as words to copy: its lines, and what the facts do not say.
        public var plainText: String {
            (reply.lines.map(\.text) + [reply.notInFacts].compactMap { $0 }).joined(separator: "\n")
        }
    }

    /// What asking is doing, in the order it does it: the thread says each step while the answer
    /// is on its way.
    public enum Step: Int, Sendable, Comparable, CaseIterable {
        /// On the device: the names swapped for their stand-ins.
        case disguising
        /// Sent, and the model is writing.
        case waiting
        /// On the device again: the stand-ins swapped back for the names.
        case restoring

        public static func < (a: Step, b: Step) -> Bool { a.rawValue < b.rawValue }
    }

    /// What a turn says when the owner stopped it before the answer came. A turn the app was
    /// closed on says "Stopped: …" too: both are quiet, not a failure.
    public static let stopped = "Stopped."
    public static func wasStopped(_ message: String) -> Bool { message.hasPrefix("Stopped") }

    /// The request, disguised, and the disguise that made it — everything but the sending.
    public struct Prepared: Sendable {
        public var sent: String
        public var pseudonymizer: Pseudonymizer
        public var newNames: Int
        /// Web addresses kept on the device, by the stand-in sent instead.
        public var links: [String: String] = [:]

        /// Originals from the mapping that are still in what would be sent. Should be none.
        public func leaks(_ entries: [Pseudonymizer.Entry]) -> [String] {
            // The tags themselves are not leaks: `[Person A]` has "Person" in it.
            let lower = sent.replacingOccurrences(of: #"\[[A-Za-z]+ [A-Z]+\]"#, with: " ", options: .regularExpression).lowercased()
            return entries.filter { [.person, .organization, .email, .phone, .iban, .street].contains($0.kind) && $0.original.count >= 4 }
                .flatMap { [$0.original] + Pseudonymizer.spellings(of: $0.original) }
                .filter { original in
                    let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: original.lowercased()) + "(?![\\p{L}\\p{N}])"
                    return lower.range(of: pattern, options: .regularExpression) != nil
                }
        }
    }

    public static func prepare(question: String, inHand: (kind: String, text: String)?, earlier: [(question: String, answer: String)],
                               facts: Facts, owner: String?, today: String, mapping url: URL, saves: Bool = true) throws -> Prepared {
        // No list of names yet is a new Mac; a list that is there and cannot be read is not: the facts
        // would then go out with none of the names learned from the mail disguised.
        var mapping = Pseudonymizer.Mapping()
        if FileManager.default.fileExists(atPath: url.path) {
            let data: Data
            do { data = try Data(contentsOf: url) } catch { throw MappingUnreadable(url: url) }
            mapping = try JSONDecoder().decode(Pseudonymizer.Mapping.self, from: data)
        }
        mapping.upgrade()
        let file = url
        return try prepare(question: question, inHand: inHand, earlier: earlier, facts: facts, owner: owner, today: today,
                           mapping: mapping, others: []) { learned in
            guard saves else { return }
            var mapping = mapping
            mapping.placeholder = learned
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(mapping).write(to: file, options: .atomic)
        }
    }

    /// The same, with a list of names in hand instead of on the disk — the copy a Mac put into the
    /// store — and `others`: names only another Mac's list knows, learned for this question too.
    /// `save` gets the list with what was learned, when anything was; nil keeps nothing.
    public static func prepare(question: String, inHand: (kind: String, text: String)?, earlier: [(question: String, answer: String)],
                               facts: Facts, owner: String?, today: String, mapping: Pseudonymizer.Mapping,
                               others: [Pseudonymizer.Entry], save: (([Pseudonymizer.Entry]) throws -> Void)?) throws -> Prepared {
        var pseudonymizer = Pseudonymizer(mode: .placeholder, entries: mapping.placeholder)
        // Another Mac's names: every one of them gets a stand-in too, so none leaves as it is.
        for entry in others { _ = pseudonymizer.learn(entry.kind, entry.original) }

        // A web address never leaves: the id in a doc's address may open it for anyone. It goes
        // as `[Link 1]`, and a card that keeps it is given the address back here.
        var links = LinkStandIns()
        let question = links.replace(in: question)
        let inHand = inHand.map { (kind: $0.kind, text: links.replace(in: $0.text)) }
        let earlier = earlier.map { (question: links.replace(in: $0.question), answer: links.replace(in: $0.answer)) }
        // The facts too: a note or a to-do's note can hold a shared document's address.
        let factsText = links.replace(in: facts.text)
        let user = AssistantPrompt.user(today: today, owner: owner, facts: factsText, inHand: inHand, earlier: earlier, question: question)
        let before = pseudonymizer.entries.count
        // Only what the owner typed can hold a name the mapping has not seen: every name in the
        // facts came back from the mail's disguise, so the mapping knows it already. The tagger
        // is not run over the facts — on a list of to-dos it reads "Hausverwaltung" and "Fragen"
        // as names — but the facts are the vocabulary, so a word that is everywhere in them is
        // known for the ordinary word it is.
        let typed = ([question, inHand?.text, facts.ownerText].compactMap { $0 } + earlier.map(\.question)).joined(separator: "\n")
        // The rules alone — shapes, not guesses — can read the whole of it: a policy number in a
        // note, "Frau Behrend" in a to-do. They do not take "Fragen" for a name.
        // The tagger takes the word before a name for part of it — "Schreibe Georg" as one person. When
        // the end of what it found is a name the mapping knows and the whole is not, the name is the end.
        let people = Set(pseudonymizer.entries.filter { $0.kind == .person }.map { $0.original.lowercased() })
        let tagged = EntityDetector().entities(in: typed, field: .body).map { entity -> Entity in
            guard entity.kind == .person, !people.contains(entity.text.lowercased()) else { return entity }
            var words = entity.text.split(separator: " ")
            while words.count > 1 {
                words.removeFirst()
                let rest = words.joined(separator: " ")
                guard people.contains(rest.lowercased()) else { continue }
                let cut = entity.text.utf16.count - rest.utf16.count
                return Entity(kind: entity.kind, text: rest, field: entity.field, start: entity.start + cut,
                              length: entity.length - cut, source: entity.source)
            }
            return entity
        }
        let entities = tagged + EntityDetector(runsTagger: false).entities(in: user, field: .body)
        pseudonymizer.learn(entities, vocabulary: Vocabulary([user]))
        let newNames = pseudonymizer.entries.count - before
        if newNames > 0 { try save?(pseudonymizer.entries) }

        return Prepared(sent: pseudonymizer.disguiser.apply(user).text, pseudonymizer: pseudonymizer, newNames: newNames,
                        links: links.byStandIn)
    }

    public static func ask(question: String, inHand: (kind: String, text: String)?, earlier: [(question: String, answer: String)],
                           facts: Facts, owner: String?, today: String, mapping url: URL, claude: Claude,
                           model: Claude.Model = .opus, step: (@Sendable (Step) -> Void)? = nil) async throws -> Answer {
        step?(.disguising)
        let prepared = try prepare(question: question, inHand: inHand, earlier: earlier, facts: facts, owner: owner, today: today, mapping: url)
        return try await send(prepared, claude: claude, model: model, step: step)
    }

    /// Asks with a list of names in hand — the iPhone's way: it uses the Mac's list and keeps
    /// nothing it learned for the question.
    public static func ask(question: String, inHand: (kind: String, text: String)?, earlier: [(question: String, answer: String)],
                           facts: Facts, owner: String?, today: String, mapping: Pseudonymizer.Mapping, others: [Pseudonymizer.Entry],
                           claude: Claude, model: Claude.Model = .opus, step: (@Sendable (Step) -> Void)? = nil) async throws -> Answer {
        step?(.disguising)
        let prepared = try prepare(question: question, inHand: inHand, earlier: earlier, facts: facts, owner: owner, today: today,
                                   mapping: mapping, others: others, save: nil)
        return try await send(prepared, claude: claude, model: model, step: step)
    }

    static func send(_ prepared: Prepared, claude: Claude, model: Claude.Model, step: (@Sendable (Step) -> Void)? = nil) async throws -> Answer {
        let (sent, pseudonymizer, newNames) = (prepared.sent, prepared.pseudonymizer, prepared.newNames)
        let body = Claude.body(model: model, system: AssistantPrompt.system, user: sent, schema: AssistantPrompt.schema, effort: "medium")
        // Stopped while the names were being disguised: nothing goes out.
        try Task.checkCancellation()
        step?(.waiting)
        let answer = try await claude.send(body, model: model)
        step?(.restoring)
        var reply = try JSONDecoder().decode(AssistantPrompt.Reply.self, from: answer.json)

        let restorer = pseudonymizer.restorer
        func real(_ text: String) -> String { restorer.apply(text).text }
        reply.lines = reply.lines.map { .init(text: prepared.links.reduce(real($0.text)) { $0.replacingOccurrences(of: $1.key, with: $1.value) }, cites: $0.cites) }
        reply.cards = reply.cards.map { card in
            var card = card
            card.text = real(card.text)
            card.from = card.from.map(real)
            card.subject = card.subject.map(real)
            card.reason = real(card.reason)
            return card
        }
        reply.notInFacts = reply.notInFacts.map(real)
        return Answer(reply: reply, sent: sent, cost: answer.cost, seconds: answer.seconds, newNames: newNames,
                      links: prepared.links.isEmpty ? nil : prepared.links, servedBy: answer.servedBy)
    }
}

/// Web addresses swapped for `[Link 1]`, `[Link 2]` — the same address the same stand-in.
/// The list of names is on the disk but cannot be read — not yet downloaded from iCloud, locked,
/// damaged. Nothing is sent then.
public struct MappingUnreadable: Error, LocalizedError {
    public let url: URL
    public var errorDescription: String? { "The list of names at \(url.path) cannot be read, so nothing was sent." }
}

public struct LinkStandIns: Sendable {
    public private(set) var byStandIn: [String: String] = [:]

    public init() {}

    static let pattern = try! NSRegularExpression(pattern: #"(?i)\bhttps?://[^\s<>"]+|\b(?:docs|drive)\.google\.com/[^\s<>"]+"#)

    public mutating func replace(in text: String) -> String {
        var out = text
        let range = NSRange(text.startIndex..., in: text)
        for match in Self.pattern.matches(in: text, range: range).reversed() {
            guard let found = Range(match.range, in: text) else { continue }
            var address = String(text[found])
            // A full stop or a bracket after an address ends the sentence, not the address.
            var tail = ""
            while let last = address.last, ".,;:!?)»“\"'".contains(last) { tail = String(last) + tail; address.removeLast() }
            let standIn = byStandIn.first { $0.value == address }?.key ?? "[Link \(byStandIn.count + 1)]"
            byStandIn[standIn] = address
            out.replaceSubrange(Range(match.range, in: out)!, with: standIn + tail)
        }
        return out
    }

    /// The addresses in a text, in order.
    public static func addresses(in text: String) -> [String] {
        var standIns = LinkStandIns()
        _ = standIns.replace(in: text)
        return standIns.byStandIn.sorted { $0.key < $1.key }.map(\.value)
    }
}

extension AssistantAsk {
    /// About what writing a summary costs: the facts in, a few lines out, with Opus 5.
    public static func summaryEstimate(_ facts: Facts, model: Claude.Model = .opus) -> Double {
        model.cost(input: Int(Double(facts.text.count) / 3.2) + 1_500, output: 600)
    }

    /// About what asking for the next step costs: the facts in, two sentences out.
    public static func nextStepEstimate(_ facts: Facts, model: Claude.Model = .opus) -> Double {
        model.cost(input: Int(Double(facts.text.count) / 3.2) + 1_200, output: 400)
    }

    /// The one next step and why, from the matter's facts, pseudonymised like every question.
    public static func nextStep(facts: Facts, owner: String?, today: String, mapping url: URL, claude: Claude,
                                model: Claude.Model = .opus) async throws -> (step: String, why: String, todo: FactRef?, cost: Double) {
        let prepared = try prepare(question: nextStepQuestion(facts), inHand: nil, earlier: [], facts: facts,
                                   owner: owner, today: today, mapping: url)
        return try await nextStep(prepared, facts: facts, claude: claude, model: model)
    }

    /// The same with a list of names in hand — the iPhone's way: nothing it learned is kept.
    public static func nextStep(facts: Facts, owner: String?, today: String, mapping: Pseudonymizer.Mapping, others: [Pseudonymizer.Entry],
                                claude: Claude, model: Claude.Model = .opus) async throws -> (step: String, why: String, todo: FactRef?, cost: Double) {
        let prepared = try prepare(question: nextStepQuestion(facts), inHand: nil, earlier: [], facts: facts, owner: owner, today: today,
                                   mapping: mapping, others: others, save: nil)
        return try await nextStep(prepared, facts: facts, claude: claude, model: model)
    }

    /// The question in the matter's own language, so it does not pull the answer into another.
    static func nextStepQuestion(_ facts: Facts) -> String {
        facts.language == "German" ? "Was ist jetzt der beste nächste Schritt?" : "What is the best next step now?"
    }
    static func summaryQuestion(_ facts: Facts) -> String {
        facts.language == "German" ? "Schreibe die Zusammenfassung dieser Sache." : "Write the summary of this matter."
    }

    /// Content keeps its language: an English matter gets an English summary, a German one a German one.
    public static func languageRule(_ language: String?) -> String {
        guard let language else { return "Write in the language the facts are written in — their to-dos, notes and mail — not in the language of these instructions or their examples." }
        return "Write in \(language): the language the facts are written in — not the language of these instructions or their examples."
    }

    /// The language most of `texts` is written in, as its English name.
    public static func language(of texts: [String]) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(texts.joined(separator: "\n"))
        guard let language = recognizer.dominantLanguage, language != .undetermined else { return nil }
        return Locale(identifier: "en_US").localizedString(forLanguageCode: language.rawValue)
    }

    static func nextStep(_ prepared: Prepared, facts: Facts, claude: Claude, model: Claude.Model) async throws -> (step: String, why: String, todo: FactRef?, cost: Double) {
        let body = Claude.body(model: model, system: NextStepPrompt.system(writingIn: facts.language), user: prepared.sent, schema: NextStepPrompt.schema, effort: "low")
        let answer = try await claude.send(body, model: model)
        let reply = try JSONDecoder().decode(NextStepPrompt.Reply.self, from: answer.json)
        let restorer = prepared.pseudonymizer.restorer
        return (restorer.apply(reply.step).text, restorer.apply(reply.why).text, reply.todo.flatMap { facts.refs[$0] }, answer.cost)
    }

    /// Three or four lines on the matter, from its facts, pseudonymised like every question.
    public static func summarize(facts: Facts, owner: String?, today: String, mapping url: URL, claude: Claude,
                                 model: Claude.Model = .opus) async throws -> (lines: [String], cost: Double) {
        let prepared = try prepare(question: summaryQuestion(facts), inHand: nil, earlier: [], facts: facts,
                                   owner: owner, today: today, mapping: url)
        return try await summarize(prepared, facts: facts, claude: claude, model: model)
    }

    /// The same with a list of names in hand — the iPhone's way: nothing it learned is kept.
    public static func summarize(facts: Facts, owner: String?, today: String, mapping: Pseudonymizer.Mapping, others: [Pseudonymizer.Entry],
                                 claude: Claude, model: Claude.Model = .opus) async throws -> (lines: [String], cost: Double) {
        let prepared = try prepare(question: summaryQuestion(facts), inHand: nil, earlier: [], facts: facts, owner: owner, today: today,
                                   mapping: mapping, others: others, save: nil)
        return try await summarize(prepared, facts: facts, claude: claude, model: model)
    }

    static func summarize(_ prepared: Prepared, facts: Facts, claude: Claude, model: Claude.Model) async throws -> (lines: [String], cost: Double) {
        let body = Claude.body(model: model, system: SummaryPrompt.system(writingIn: facts.language), user: prepared.sent, schema: SummaryPrompt.schema, effort: "low")
        let answer = try await claude.send(body, model: model)
        let reply = try JSONDecoder().decode(SummaryPrompt.Reply.self, from: answer.json)
        let restorer = prepared.pseudonymizer.restorer
        return (reply.lines.map { restorer.apply($0.text).text }, answer.cost)
    }
}
