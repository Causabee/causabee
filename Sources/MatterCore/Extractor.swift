import Foundation
import CryptoKit

/// Steps 5 and 6 of the spike: send each disguised mail to Claude, read back what it found, and
/// put the real names into the answer.
///
/// Mails go in date order, one at a time, because each call is told the matters found so far —
/// in disguise, never restored, and never taken from the golden set. That is how the model can
/// say "this belongs to the Hausverwaltung matter" without being told the answer by the labels
/// it will be measured against.
public struct Extractor: Sendable {
    public var model: Claude.Model
    public var effort: String?
    public var claude: Claude?
    /// Answers already paid for, by the exact request that produced them. A re-run of the same
    /// folder with the same prompt costs nothing, and a run that stopped halfway picks up where
    /// it stopped.
    public var cache: URL
    /// Send only the newest message of a reply, not the thread quoted below it. On by default:
    /// the first full run spent 45% of its text on history the model had already read.
    public var newestOnly: Bool
    /// After this many answers in a row with nothing in them — no matter, no to-do, no deadline —
    /// a sender's mail is no longer sent. Zero turns it off. Learned during the run, in date
    /// order, the way it would be learned from a live inbox; every rule it makes is reported.
    public var quietAfter: Int
    /// `ExtractionPrompt.strict` added to the instructions: fewer, real to-dos.
    public var strict = false
    /// The owner's matters as the store has them — also those made in the app, which no mail
    /// named yet: by the key a mail is filed under, and a line on what each is about.
    public var storeMatters: [(key: String, about: String)] = []

    var system: String { strict ? ExtractionPrompt.system + ExtractionPrompt.strict : ExtractionPrompt.system }
    var promptVersion: String { strict ? ExtractionPrompt.strictVersion : ExtractionPrompt.version }

    public init(model: Claude.Model, effort: String? = nil, claude: Claude?, cache: URL,
                newestOnly: Bool = true, quietAfter: Int = 3) {
        self.model = model
        self.effort = effort
        self.claude = claude
        self.cache = cache
        self.newestOnly = newestOnly
        self.quietAfter = quietAfter
    }

    /// What the model returns, in the schema's spelling. Names in here are still disguised.
    public struct Found: Codable, Sendable {
        public var matter: String?
        public var matterIsNew: Bool
        /// A new matter's name as the owner would write it: `Sperrmüll`, not `sperrmuell`.
        public var matterTitle: String? = nil
        public var matterSummary: String?
        public var matterConfidence: Double
        public var matterReason: String
        public var digest: String? = nil
        public var parties: [Judgement.Party]
        public var todos: [Judgement.Todo]
        public var deadlines: [Judgement.Deadline]
        public var done: [Judgement.Done]? = nil
        public var appointments: [Judgement.Appointment]? = nil

        enum CodingKeys: String, CodingKey {
            case matter, parties, todos, deadlines, done, appointments, digest
            case matterIsNew = "matter_is_new"
            case matterTitle = "matter_title"
            case matterSummary = "matter_summary"
            case matterConfidence = "matter_confidence"
            case matterReason = "matter_reason"
        }
    }

    public struct Summary: Sendable {
        public var sent = 0
        public var cached = 0
        /// Mails classified in an earlier run and kept as they were: not sent, not paid for.
        public var kept = 0
        public var failed: [(subject: String, error: String)] = []
        public var inputTokens = 0
        public var outputTokens = 0
        public var cacheReadTokens = 0
        public var cost = 0.0
        public var seconds = 0.0
        public var fallbacks = 0
        public var matters: [String] = []
        /// Mails not sent because their sender had gone quiet, and the senders that went quiet.
        public var skipped = 0
        public var quietSenders: [(sender: String, from: String)] = []
        public var historyLeftOut = 0
        /// The matters' to-do lists as the run built them: new ones, ones asked for again, ones
        /// shown to be done, and appointments.
        public var todosNew = 0
        public var todosAgain = 0
        public var todosDone = 0
        public var appointments = 0
    }

    // MARK: Who "me" is

    /// The mailbox owner, as the model will see them. Given with `--me`, or else read off the
    /// mail: the address that most often receives it, and the names it goes by there.
    public static func owner(named names: [String], in outcomes: [Spike.Outcome]) -> [String] {
        if !names.isEmpty { return names }
        var counts: [String: Int] = [:]
        var display: [String: Set<String>] = [:]
        for outcome in outcomes where !outcome.judgement.isBulk {
            for field in outcome.email.to + outcome.email.cc {
                let address = Email.address(in: field)
                guard address.contains("@") else { continue }
                counts[address, default: 0] += 1
                if let name = Email.displayName(in: field) { display[address, default: []].insert(name) }
            }
        }
        guard let top = counts.max(by: { $0.value < $1.value })?.key else { return [] }
        return [top] + (display[top] ?? []).sorted()
    }

    // MARK: A folder

    /// Mail already classified is not classified again. `known` is the record of earlier runs, by
    /// Message-ID: a mail in it keeps the answer it got — even when the disguise or the prompt has
    /// changed since — and only goes back into the run's memory, so that a new mail is still told
    /// the matters, threads and open to-dos. Only mail with no answer yet is sent. A mail whose
    /// earlier try failed is tried again.
    public static func isSettled(_ judgement: Judgement) -> Bool {
        guard let extraction = judgement.extraction else { return false }
        return extraction.error == nil
    }

    public func run(_ outcomes: inout [Spike.Outcome], pseudonymizer: Pseudonymizer, owner: [String],
                    limit: Int? = nil, dryRun: URL? = nil, known: [String: Judgement] = [:],
                    progress: (Int, Int, Spike.Outcome) -> Void = { _, _, _ in }) async throws -> Summary {
        var summary = Summary()
        let disguiser = pseudonymizer.disguiser
        let restorer = pseudonymizer.restorer
        let disguisedOwner = Array(Set(owner.map { disguiser.apply($0).text })).sorted()

        let order = outcomes.indices
            .filter { outcomes[$0].judgement.disguise != nil }
            .sorted { (outcomes[$0].email.date ?? .distantPast) < (outcomes[$1].email.date ?? .distantPast) }
        let chosen = limit.map { Array(order.prefix($0)) } ?? order

        var matters: [(name: String, summary: String)] = []
        var requests: [Data] = []

        var emptyInARow: [String: Int] = [:]
        var threads = ThreadMemory()
        var book = TodoBook()
        let ownDomains = Set(owner.compactMap { $0.contains("@") ? Email.address(in: $0).split(separator: "@").last.map(String.init) : nil })

        // What earlier runs found, back into memory. The one mail of today is told about the
        // hundred and eighty before it without any of them being read again.
        func replay(_ earlier: Judgement, email: Email) {
            let sender = Self.senderKey(email.fromAddress, own: ownDomains)
            let nothing = earlier.matter == nil && earlier.todos.isEmpty && earlier.deadlines.isEmpty
            if earlier.extraction?.skipped == nil { emptyInARow[sender] = nothing ? emptyInARow[sender, default: 0] + 1 : 0 }
            let matter = earlier.matter.map { disguiser.apply($0).text }
            threads.remember(email, matter: matter)
            book.replay(matter: matter, todos: earlier.todos.map { ($0.id, disguiser.apply($0.text).text, $0.owner, $0.sameAs) },
                        done: earlier.done.map(\.todo))
            if let name = matter, !matters.contains(where: { $0.name == name }) {
                matters.append((name, disguiser.apply(earlier.matterReason).text))
            }
        }
        for matter in storeMatters {
            let name = disguiser.apply(matter.key).text
            if !matters.contains(where: { $0.name == name }) { matters.append((name, disguiser.apply(matter.about).text)) }
        }
        let present = Set(outcomes.map(\.judgement.emailID))
        for earlier in known.values.filter({ !present.contains($0.emailID) && Self.isSettled($0) })
            .sorted(by: { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }) {
            replay(earlier, email: Email(standingIn: earlier))
            summary.kept += 1
        }

        for (step, index) in chosen.enumerated() {
            if let earlier = known[outcomes[index].judgement.emailID], Self.isSettled(earlier) {
                // Kept, and remembered: what it found is part of what the next mail is told.
                outcomes[index].judgement = earlier
                replay(earlier, email: outcomes[index].email)
                summary.kept += 1
                continue
            }
            progress(step + 1, chosen.count, outcomes[index])
            guard let disguise = outcomes[index].judgement.disguise else { continue }

            let sender = Self.senderKey(outcomes[index].email.fromAddress, own: ownDomains)
            if quietAfter > 0, emptyInARow[sender, default: 0] >= quietAfter, dryRun == nil {
                var record = Judgement.Extraction(model: model.id, servedBy: "", mode: disguise.mode.rawValue,
                                                 prompt: promptVersion)
                record.skipped = "\(sender) sent nothing to act on the last \(quietAfter) times"
                outcomes[index].judgement.extraction = record
                outcomes[index].judgement.decidedBy = .rule
                outcomes[index].judgement.matterReason = "not sent: " + (record.skipped ?? "")
                outcomes[index].judgement.stages = Spike.stages + ["quiet_sender"]
                summary.skipped += 1
                continue
            }

            let history = newestOnly ? Quotes.newest(of: disguise.body, subject: disguise.subject)
                                     : Quotes.Split(newest: disguise.body, omitted: 0, reason: "whole thread sent")
            if history.omitted > 0 { summary.historyLeftOut += 1 }
            let thread = threads.matter(for: outcomes[index].email)
            let user = ExtractionPrompt.user(mail: Self.text(of: disguise, body: history.newest, omitted: history.omitted),
                                             sent: outcomes[index].email.date, owner: disguisedOwner, matters: matters,
                                             thread: thread, open: book.open(for: thread, matters: matters.map(\.name)))
            let body = Claude.body(model: model, system: system, user: user,
                                   schema: ExtractionPrompt.schema, effort: effort)

            if dryRun != nil {
                requests.append(try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .withoutEscapingSlashes]))
                continue
            }

            var record = Judgement.Extraction(model: model.id, servedBy: model.id, mode: disguise.mode.rawValue,
                                             prompt: promptVersion)
            do {
                let (answer, wasCached) = try await answer(for: body)
                var found = try JSONDecoder().decode(Found.self, from: answer.json)
                record.servedBy = answer.servedBy
                record.inputTokens = answer.inputTokens + answer.cacheWriteTokens + answer.cacheReadTokens
                record.cacheReadTokens = answer.cacheReadTokens
                record.outputTokens = answer.outputTokens
                record.costUSD = cost(of: answer)
                record.seconds = answer.seconds
                record.cached = wasCached

                record.historyOmitted = history.omitted
                let nothing = found.matter == nil && found.todos.isEmpty && found.deadlines.isEmpty
                emptyInARow[sender] = nothing ? emptyInARow[sender, default: 0] + 1 : 0
                if nothing, emptyInARow[sender] == quietAfter, quietAfter > 0 {
                    summary.quietSenders.append((sender, outcomes[index].judgement.from))
                }

                threads.remember(outcomes[index].email, matter: found.matter)
                found = book.record(found)
                summary.todosNew += found.todos.filter { $0.sameAs == nil }.count
                summary.todosAgain += found.todos.filter { $0.sameAs != nil }.count
                summary.todosDone += found.done?.count ?? 0
                summary.appointments += found.appointments?.count ?? 0
                record.thread = thread.map { restorer.apply($0).text }

                if let name = found.matter, !matters.contains(where: { $0.name == name }) {
                    matters.append((name, found.matterSummary ?? found.matterReason))
                }
                apply(found, to: &outcomes[index].judgement, restorer: restorer)

                if wasCached { summary.cached += 1 } else { summary.sent += 1 }
                summary.inputTokens += answer.inputTokens + answer.cacheWriteTokens + answer.cacheReadTokens
                summary.cacheReadTokens += answer.cacheReadTokens
                summary.outputTokens += answer.outputTokens
                summary.cost += record.costUSD
                summary.seconds += answer.seconds
                if !answer.servedBy.isEmpty, !model.isServing(answer.servedBy) { summary.fallbacks += 1 }
            } catch {
                record.error = "\(error)"
                summary.failed.append((outcomes[index].judgement.subject, "\(error)"))
            }
            outcomes[index].judgement.extraction = record
        }

        if let dryRun {
            var out = Data()
            for line in requests { out.append(line); out.append(0x0A) }
            try out.write(to: dryRun, options: .atomic)
        }
        summary.matters = matters.map { restorer.apply($0.name).text }
        return summary
    }

    /// Who a sender is, for learning that they have gone quiet. A company's mass mailer writes
    /// from a new random address every time — CHECK24 does — so a company is its domain. A person
    /// at Gmail or web.de is their address, because the domain there is millions of people; so is
    /// anyone at the owner's own domain.
    static func senderKey(_ address: String, own: Set<String>) -> String {
        let domain = String(address.split(separator: "@").last ?? "")
        if Pseudonymizer.freeMail.contains(domain) || own.contains(domain) || domain.isEmpty { return address }
        return domain.split(separator: ".").suffix(2).joined(separator: ".")
    }

    /// The mail as the model reads it: the headers a person would look at, then the body, with
    /// every link reduced to `[link]`. A tracking link's long code can identify the person it was
    /// sent to as surely as a name, and it tells the model nothing a person reading would use.
    public static func text(of disguise: Disguise, body: String? = nil, omitted: Int = 0) -> String {
        // In the subject and the attachments' names too: a shared document's address is as
        // telling there as in the text.
        func unlinked(_ text: String) -> String { text.replacing(/(?:https?:\/\/|www\.)[^\s)>\]]+/, with: "[link]") }
        var body = unlinked(body ?? disguise.body)
        if omitted > 0 {
            body += "\n\n[Earlier messages quoted below this one were left out; they were read when they arrived.]"
        }
        var lines = ["From: \(disguise.from)"]
        if !disguise.to.isEmpty { lines.append("To: \(disguise.to.joined(separator: ", "))") }
        if !disguise.cc.isEmpty { lines.append("Cc: \(disguise.cc.joined(separator: ", "))") }
        lines.append("Subject: \(unlinked(disguise.subject))")
        if !disguise.attachmentNames.isEmpty { lines.append("Attachments: \(disguise.attachmentNames.map(unlinked).joined(separator: ", "))") }
        return lines.joined(separator: "\n") + "\n\n" + body
    }

    /// Step 6. Everything the model wrote goes back through the mapping before it is logged,
    /// so the log reads in real names and the report can compare it with the labels.
    func apply(_ found: Found, to decision: inout Judgement, restorer: Replacer) {
        func real(_ text: String) -> String { restorer.apply(text).text }
        decision.matter = found.matter.map(real)
        decision.matterTitle = found.matterTitle.map(real)
        decision.digest = found.digest.map(real)
        decision.matterConfidence = found.matterConfidence
        decision.matterReason = real(found.matterReason)
        decision.decidedBy = .claude
        decision.parties = found.parties.map { .init(name: real($0.name), role: real($0.role), isNew: $0.isNew) }
        decision.todos = found.todos.map {
            .init(text: real($0.text), owner: $0.owner, due: $0.due, sourceQuote: real($0.sourceQuote),
                  sameAs: $0.sameAs, id: $0.id)
        }
        decision.done = (found.done ?? []).map { .init(todo: $0.todo, sourceQuote: real($0.sourceQuote)) }
        decision.appointments = (found.appointments ?? []).map {
            .init(what: real($0.what), date: $0.date, time: $0.time, place: $0.place.map(real), sourceQuote: real($0.sourceQuote))
        }
        decision.deadlines = found.deadlines.map {
            .init(what: real($0.what), date: $0.date, sourceQuote: real($0.sourceQuote))
        }
        decision.stages = Spike.stages + ["classify", "restore"]
    }

    /// Priced at the rates of the model that actually answered. One the table does not know is
    /// priced as the model that was asked, rather than guessed at.
    func cost(of answer: Claude.Answer) -> Double {
        let served = Claude.Model.serving(answer.servedBy) ?? model
        return served.cost(input: answer.inputTokens, output: answer.outputTokens,
                           cacheWrite: answer.cacheWriteTokens, cacheRead: answer.cacheReadTokens)
    }

    // MARK: The cache

    struct Stored: Codable {
        var json: String
        var servedBy: String
        var inputTokens: Int
        var outputTokens: Int
        var seconds: Double
        /// Optional so answers stored before caching still read back.
        var cacheWriteTokens: Int?
        var cacheReadTokens: Int?
    }

    func answer(for body: [String: Any]) async throws -> (Claude.Answer, cached: Bool) {
        let name = try Claude.cacheKey(body)
        let file = cache.appendingPathComponent(model.id).appendingPathComponent(name + ".json")

        if let data = try? Data(contentsOf: file), let stored = try? JSONDecoder().decode(Stored.self, from: data) {
            return (Claude.Answer(json: Data(stored.json.utf8), servedBy: stored.servedBy,
                                  inputTokens: stored.inputTokens, outputTokens: stored.outputTokens,
                                  seconds: stored.seconds, cacheWriteTokens: stored.cacheWriteTokens ?? 0,
                                  cacheReadTokens: stored.cacheReadTokens ?? 0), true)
        }
        guard let claude else { throw Claude.Failure.noKey }
        let answer = try await claude.send(body, model: model)
        let stored = Stored(json: String(decoding: answer.json, as: UTF8.self), servedBy: answer.servedBy,
                            inputTokens: answer.inputTokens, outputTokens: answer.outputTokens, seconds: answer.seconds,
                            cacheWriteTokens: answer.cacheWriteTokens, cacheReadTokens: answer.cacheReadTokens)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(stored).write(to: file, options: .atomic)
        return (answer, false)
    }
}

/// Which matter each thread was assigned to, so a reply can be told without being sent the
/// thread quoted below it. The matter names are the model's own, still in disguise.
///
/// A thread is found by the headers mail clients set for exactly this — `In-Reply-To` and
/// `References` — and, when a client left them out, by the subject with its `Re:` and `AW:`
/// taken off. A short subject is not trusted: `Re: Telefonat` could be any of three threads.
struct ThreadMemory: Sendable {
    private var byMessage: [String: String] = [:]
    private var bySubject: [String: String] = [:]

    func matter(for email: Email) -> String? {
        for id in Self.parents(of: email).reversed() { if let matter = byMessage[id] { return matter } }
        guard let key = Self.subjectKey(email.subject), Self.isReply(email.subject) else { return nil }
        return bySubject[key]
    }

    mutating func remember(_ email: Email, matter: String?) {
        guard let matter else { return }
        byMessage[email.id] = matter
        if let key = Self.subjectKey(email.subject) { bySubject[key] = matter }
    }

    /// Message-IDs of the mails this one answers, oldest first.
    static func parents(of email: Email) -> [String] {
        let text = (email.allHeaders("references") + email.allHeaders("in-reply-to")).joined(separator: " ")
        return text.matches(of: /<([^<>\s]+)>/).map { String($0.output.1) }
    }

    static func isReply(_ subject: String) -> Bool {
        subject.trimmed.lowercased().firstMatch(of: /^(re|aw|antw|wg|fwd?)\s*:/) != nil
    }

    static func subjectKey(_ subject: String) -> String? {
        var key = subject.trimmed.lowercased()
        while let prefix = key.firstMatch(of: /^(re|aw|antw|wg|fwd?|\[[^\]]*\])\s*:?\s*/) , !prefix.output.0.isEmpty {
            key = String(key[prefix.range.upperBound...])
        }
        return key.count >= 12 ? key : nil
    }
}

/// Each matter's to-do list, kept across the run the way the app will keep it: one entry per
/// thing to do, however many mails ask for it, closed when a mail shows it done.
///
/// The model is shown the open entries and says, for each to-do it finds, whether it is one of
/// them. Everything here is in disguise, like the rest of what the model sees.
struct TodoBook: Sendable {
    struct Entry: Sendable {
        var id: String
        var matter: String
        var text: String
        var owner: Judgement.Todo.Owner
        var done = false
        var mentions = 1
    }
    private(set) var entries: [Entry] = []
    /// The number the next new to-do gets. Past every id seen, so a to-do replayed from an earlier
    /// run keeps its id and a new one never takes it.
    private var next = 1

    /// A to-do found in an earlier run, with the id it got then. Nothing is sent; the list is
    /// only put back the way it was.
    mutating func replay(matter: String?, todos: [(id: String?, text: String, owner: Judgement.Todo.Owner, sameAs: String?)], done: [String]) {
        for todo in todos {
            guard let id = todo.id else { continue }
            if let at = entries.firstIndex(where: { $0.id == id }) {
                entries[at].mentions += 1
            } else {
                entries.append(Entry(id: id, matter: matter ?? "", text: todo.text, owner: todo.owner))
            }
            if let number = Int(id.dropFirst()), number >= next { next = number + 1 }
        }
        for id in done {
            if let at = entries.firstIndex(where: { $0.id == id }) { entries[at].done = true }
        }
    }

    /// The open to-dos to show with a mail: the thread's matter when the thread is known, since
    /// that is where a repeat will be; otherwise every matter's, the latest few of each.
    func open(for thread: String?, matters: [String], perMatter: Int = 12) -> [(matter: String, todos: [ExtractionPrompt.OpenTodo])] {
        let shown = thread.map { [$0] } ?? matters
        return shown.map { matter in
            let open = entries.filter { $0.matter == matter && !$0.done }.suffix(perMatter)
            return (matter, open.map { .init(id: $0.id, owner: $0.owner.rawValue, text: $0.text) })
        }
    }

    /// Gives every to-do its entry, new or repeated, and closes the ones shown done. A `same_as`
    /// that names no open entry is taken as new — the model misremembering an id must not lose
    /// the to-do.
    mutating func record(_ found: Extractor.Found) -> Extractor.Found {
        var found = found
        let matter = found.matter ?? ""
        for index in found.todos.indices {
            if let same = found.todos[index].sameAs, let entry = entries.firstIndex(where: { $0.id == same && !$0.done }) {
                entries[entry].mentions += 1
                found.todos[index].id = same
            } else {
                let id = "T\(next)"
                next += 1
                entries.append(Entry(id: id, matter: matter, text: found.todos[index].text, owner: found.todos[index].owner))
                found.todos[index].sameAs = nil
                found.todos[index].id = id
            }
        }
        found.done = (found.done ?? []).filter { done in
            guard let entry = entries.firstIndex(where: { $0.id == done.todo && !$0.done }) else { return false }
            entries[entry].done = true
            return true
        }
        return found
    }
}
