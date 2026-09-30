import Foundation

/// One line of `decisions.jsonl`: everything the pipeline concluded about one mail, and which
/// layer concluded it.
///
/// The fields the plan fixed are here in the plan's spelling, even the ones no stage fills yet
/// — `parties`, `todos`, `deadlines` stay empty until the API stage exists. Writing the empty
/// shape from the start means the report that reads this file does not have to be rewritten
/// when the shape fills in, and it makes the gap visible in the log instead of only in a
/// promise.
public struct Judgement: Codable, Sendable {
    public enum DecidedBy: String, Codable, Sendable {
        case rule
        case onDevice = "on_device"
        case claude
        /// Nothing decided it yet: the stage that would have is not built.
        case pending
    }

    public var emailID: String
    /// The pointer to the original. Matterbee stores facts and a way back to the source, never
    /// the source itself.
    public var source: String
    public var date: Date?
    public var subject: String
    public var from: String

    public var isBulk: Bool
    public var bulkReason: String?
    public var bulkRule: BulkFilter.Rule?

    public var matter: String?
    /// A new matter's name as the owner would write it. Nil for mail from before the prompt
    /// asked for one, and for mail in a matter that already had a name.
    public var matterTitle: String? = nil
    public var matterConfidence: Double
    public var matterReason: String
    /// Two or three sentences on what this mail says, with its details — what a question about
    /// it months later needs. Nil for mail from before it was asked for.
    public var digest: String? = nil
    /// The Message-ID of the mail this one answers, from its headers; "" when it answers none.
    /// Nil in lines written before it was kept.
    public var replyTo: String? = nil
    public var decidedBy: DecidedBy

    public var parties: [Party]
    public var todos: [Todo]
    public var deadlines: [Deadline]
    public var appointments: [Appointment] = []
    /// The matter's to-dos this mail shows are done, by id.
    public var done: [Done] = []

    /// Not in the plan's schema, because the plan's schema is what comes back *from* the model.
    /// This is what never went to it, and question two cannot be answered without seeing it.
    public var entities: [Entity]
    /// The mail as it would be sent, after step 4. Nil for bulk mail, which is never sent, and
    /// for a run that stopped before the disguise.
    public var disguise: Disguise? = nil
    /// What the detector found and the disguise deliberately left alone. The first place to look
    /// for a leak.
    public var notDisguised: [Pseudonymizer.Skip] = []
    /// Which model answered, for how much, and how long it took — questions 6 and 7 are read
    /// straight off these. Nil until step 5 has run on the mail.
    public var extraction: Extraction? = nil
    public var attachments: [Email.Attachment]
    public var stages: [String]

    public struct Extraction: Codable, Sendable {
        public var model: String
        /// Usually `model`. Another one when Opus declined and the fallback answered.
        public var servedBy: String
        public var mode: String
        public var prompt: String
        /// All input, cached or not; `cacheReadTokens` says how much of it was read from the cache.
        public var inputTokens = 0
        public var outputTokens = 0
        public var cacheReadTokens: Int? = nil
        public var costUSD = 0.0
        public var seconds = 0.0
        /// Answered from the local cache: the tokens and cost are what it cost the first time.
        public var cached = false
        public var error: String? = nil
        /// Set when the mail was not sent at all, and why.
        public var skipped: String? = nil
        /// Characters of quoted history left out of what was sent.
        public var historyOmitted: Int? = nil
        /// The matter the request said this reply's thread belongs to, restored. Nil when none.
        public var thread: String? = nil

        enum CodingKeys: String, CodingKey {
            case model, mode, prompt, seconds, cached, error, skipped, thread
            case historyOmitted = "history_omitted"
            case servedBy = "served_by"
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case costUSD = "cost_usd"
            case cacheReadTokens = "cache_read_tokens"
        }
    }

    public struct Party: Codable, Sendable {
        public var name: String
        public var role: String
        public var isNew: Bool
        enum CodingKeys: String, CodingKey { case name, role, isNew = "is_new" }
    }

    public struct Todo: Codable, Sendable {
        /// Whose it is. `me`: the owner's own. `we`: the owner's together with others — the owners
        /// of a building acting as one. `other`: someone else's, and the owner is waiting on it; a
        /// task of someone else's that the owner is not waiting on is not a to-do at all.
        public enum Owner: String, Codable, Sendable { case me, we, other, unknown }
        public var text: String
        public var owner: Owner
        /// `YYYY-MM-DD`, or nil when the mail gave none.
        public var due: String?
        /// The words this was read out of. Required, so no fact is ever unattributable.
        public var sourceQuote: String
        /// The matter's to-do this one is — `T3` — when the mail asks again for something already
        /// on file. Nil for a to-do the matter did not have yet.
        public var sameAs: String? = nil
        /// Which of the matter's to-dos this became, new or repeated. Given by the pipeline, not
        /// the model.
        public var id: String? = nil
        enum CodingKeys: String, CodingKey { case text, owner, due, id, sourceQuote = "source_quote", sameAs = "same_as" }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(text, forKey: .text)
            try container.encode(owner, forKey: .owner)
            try container.always(due, forKey: .due)
            try container.encode(sourceQuote, forKey: .sourceQuote)
            try container.always(sameAs, forKey: .sameAs)
            try container.always(id, forKey: .id)
        }
    }

    /// A to-do already on file that this mail shows is done.
    public struct Done: Codable, Sendable {
        public var todo: String
        public var sourceQuote: String
        enum CodingKeys: String, CodingKey { case todo, sourceQuote = "source_quote" }
    }

    /// A meeting, call or visit at a set time. Not a to-do — the to-do is what has to be done for
    /// it — and not a deadline, which is a date by which something is done.
    public struct Appointment: Codable, Sendable {
        public var what: String
        public var date: String
        /// `HH:MM`, or nil when the mail gives only the day.
        public var time: String?
        public var place: String?
        public var sourceQuote: String
        enum CodingKeys: String, CodingKey { case what, date, time, place, sourceQuote = "source_quote" }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(what, forKey: .what)
            try container.encode(date, forKey: .date)
            try container.always(time, forKey: .time)
            try container.always(place, forKey: .place)
            try container.encode(sourceQuote, forKey: .sourceQuote)
        }
    }

    public struct Deadline: Codable, Sendable {
        public var what: String
        public var date: String
        public var sourceQuote: String
        enum CodingKeys: String, CodingKey { case what, date, sourceQuote = "source_quote" }
    }

    enum CodingKeys: String, CodingKey {
        case emailID = "email_id"
        case source, date, subject, from
        case isBulk = "is_bulk"
        case bulkReason = "bulk_reason"
        case bulkRule = "bulk_rule"
        case matter
        case matterTitle = "matter_title"
        case matterConfidence = "matter_confidence"
        case matterReason = "matter_reason"
        case digest
        case replyTo = "reply_to"
        case decidedBy = "decided_by"
        case parties, todos, deadlines, appointments, done, entities, disguise, attachments, stages
        case notDisguised = "not_disguised"
        case extraction
    }

    /// Written by hand for one reason: a field that is nil is written as `null` rather than
    /// left out. Swift's own version drops empty optionals, which would make `matter` appear in
    /// some lines and not others, and the report has to count the mails with no matter — a
    /// column that is sometimes missing is a column that has to be guessed at.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(emailID, forKey: .emailID)
        try container.encode(source, forKey: .source)
        try container.always(date, forKey: .date)
        try container.encode(subject, forKey: .subject)
        try container.encode(from, forKey: .from)
        try container.encode(isBulk, forKey: .isBulk)
        try container.always(bulkReason, forKey: .bulkReason)
        try container.always(bulkRule, forKey: .bulkRule)
        try container.always(matter, forKey: .matter)
        try container.encodeIfPresent(matterTitle, forKey: .matterTitle)
        try container.encode(matterConfidence, forKey: .matterConfidence)
        try container.encode(matterReason, forKey: .matterReason)
        try container.encodeIfPresent(digest, forKey: .digest)
        try container.encodeIfPresent(replyTo, forKey: .replyTo)
        try container.encode(decidedBy, forKey: .decidedBy)
        try container.encode(parties, forKey: .parties)
        try container.encode(todos, forKey: .todos)
        try container.encode(deadlines, forKey: .deadlines)
        try container.encode(appointments, forKey: .appointments)
        try container.encode(done, forKey: .done)
        try container.encode(entities, forKey: .entities)
        try container.always(disguise, forKey: .disguise)
        try container.encode(notDisguised, forKey: .notDisguised)
        try container.always(extraction, forKey: .extraction)
        try container.encode(attachments, forKey: .attachments)
        try container.encode(stages, forKey: .stages)
    }
}

extension KeyedEncodingContainer {
    /// `null` rather than nothing at all.
    mutating func always<T: Encodable>(_ value: T?, forKey key: Key) throws {
        if let value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) }
    }
}

/// Appends decisions to a `.jsonl` file as they are made.
///
/// One line per mail, written as the mail is finished rather than at the end of the run: a
/// hundred and fifty mails is long enough that a crash on number ninety should not cost the
/// eighty-nine before it.
public final class JudgementLog {
    public let url: URL
    private let handle: FileHandle
    private let encoder: JSONEncoder

    public init(url: URL) throws {
        self.url = url
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try FileHandle(forWritingTo: url)
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // Deliberately not `.prettyPrinted`: one decision is one line, so the file can be read
        // with `grep` and counted with `wc -l`. Sorted, so two runs of the same folder produce
        // two files that can be diffed — which is how a change to a rule gets looked at.
        encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]
    }

    public func write(_ decision: Judgement) throws {
        var line = try encoder.encode(decision)
        line.append(0x0A)
        try handle.write(contentsOf: line)
    }

    public func close() throws { try handle.close() }
}

extension Judgement {
    /// Read by hand for the same reason it is written by hand: the log is read back by `review`
    /// and `report`, often from a run made before a field existed. A field added later —
    /// `appointments`, `done`, `disguise` — reads as empty rather than making the whole line
    /// unreadable.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        emailID = try c.decode(String.self, forKey: .emailID)
        source = try c.decode(String.self, forKey: .source)
        date = try c.decodeIfPresent(Date.self, forKey: .date)
        subject = try c.decode(String.self, forKey: .subject)
        from = try c.decode(String.self, forKey: .from)
        isBulk = try c.decode(Bool.self, forKey: .isBulk)
        bulkReason = try c.decodeIfPresent(String.self, forKey: .bulkReason)
        bulkRule = try c.decodeIfPresent(BulkFilter.Rule.self, forKey: .bulkRule)
        matter = try c.decodeIfPresent(String.self, forKey: .matter)
        matterTitle = try c.decodeIfPresent(String.self, forKey: .matterTitle)
        matterConfidence = try c.decode(Double.self, forKey: .matterConfidence)
        matterReason = try c.decode(String.self, forKey: .matterReason)
        digest = try c.decodeIfPresent(String.self, forKey: .digest)
        replyTo = try c.decodeIfPresent(String.self, forKey: .replyTo)
        decidedBy = try c.decode(DecidedBy.self, forKey: .decidedBy)
        parties = try c.decode([Party].self, forKey: .parties)
        todos = try c.decode([Todo].self, forKey: .todos)
        deadlines = try c.decode([Deadline].self, forKey: .deadlines)
        appointments = try c.decodeIfPresent([Appointment].self, forKey: .appointments) ?? []
        done = try c.decodeIfPresent([Done].self, forKey: .done) ?? []
        entities = try c.decodeIfPresent([Entity].self, forKey: .entities) ?? []
        disguise = try c.decodeIfPresent(Disguise.self, forKey: .disguise)
        notDisguised = try c.decodeIfPresent([Pseudonymizer.Skip].self, forKey: .notDisguised) ?? []
        extraction = try c.decodeIfPresent(Extraction.self, forKey: .extraction)
        attachments = try c.decodeIfPresent([Email.Attachment].self, forKey: .attachments) ?? []
        stages = try c.decodeIfPresent([String].self, forKey: .stages) ?? []
    }
}
