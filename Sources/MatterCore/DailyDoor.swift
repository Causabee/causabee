import Foundation

/// The manual edition's daily door, from start to end: read what is new under the label, say
/// what sending it would cost, and only on a yes send it, answer it and keep the answer.
///
/// Two steps, because the owner decides between them. `look` reads the mail and disguises it on
/// the device; nothing goes to the API. `classify` sends only what `look` found new, keeps every
/// earlier answer as it was, and writes both back to the log — the record of what the label has
/// answered, so each mail is classified once.
public struct DailyDoor: Sendable {
    public var account: MailAccount
    public var label: String
    /// The record: `decisions-fetch.jsonl`.
    public var log: URL
    public var mapping: URL
    public var cache: URL
    public var model: Claude.Model
    /// Fewer, real to-dos: the rule a model that writes too many is given.
    public var strict = false
    /// What the other devices sorted, from the store (`SortedMails`): known as if in the log, so
    /// no mail is sent twice. The log's own answer wins where both have one.
    public var earlier: [String: Judgement] = [:]
    /// Mail already in a matter — the store's entries — whose answer this device may not have:
    /// neither downloaded nor sent again.
    public var alsoKnown: Set<String> = []
    /// New mail the owner unticked once: read, but not offered again until put back.
    public var setAside: Set<String> = []

    public init(account: MailAccount, label: String = "Matterbee", log: URL, mapping: URL, cache: URL, model: Claude.Model = .opus) {
        self.account = account
        self.label = label
        self.log = log
        self.mapping = mapping
        self.cache = cache
        self.model = model
    }

    /// Next to the store: the record, the disguise and the answer cache live where the store does.
    public init(account: MailAccount, besides store: URL) {
        let folder = store.deletingLastPathComponent()
        self.init(account: account, log: folder.appendingPathComponent("decisions-fetch.jsonl"),
                  mapping: folder.appendingPathComponent("mapping.json"), cache: folder.appendingPathComponent(".matter-cache"))
    }

    /// What is new, read and disguised, and not sent yet.
    public struct Look: Sendable {
        public var report: Spike.Report
        public var answered: [String: Judgement]
        public var intake: LabelIntake.Result
        /// Mails that would be sent.
        public var pending: Int
        public var estimate: Double
        /// The new mails, in their order: what the owner ticks or unticks before Sort in.
        public var newIDs: [String] = []

        public var newMails: [Spike.Outcome] {
            let ids = Set(newIDs)
            return report.outcomes.filter { ids.contains($0.judgement.emailID) }
        }

        /// Only these of the new mails, to be sent: the others stay out of this run. What was
        /// answered before stays in, as it is never sent again anyway.
        public func only(_ chosen: Set<String>) -> Look {
            var kept = self
            let new = Set(newIDs)
            kept.report.outcomes = report.outcomes.filter { !new.contains($0.judgement.emailID) || chosen.contains($0.judgement.emailID) }
            kept.newIDs = newIDs.filter(chosen.contains)
            kept.estimate = pending == 0 ? 0 : estimate * Double(kept.newIDs.count) / Double(pending)
            kept.pending = kept.newIDs.count
            return kept
        }
    }

    public static func costPerMail(_ model: Claude.Model) -> Double {
        // Opus 5 came to $0.031–$0.033 a mail on the label; a little over, to be safe.
        model.perMail
    }

    public static func readLog(_ url: URL) -> [String: Judgement] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var out: [String: Judgement] = [:]
        for line in data.split(separator: 0x0A) {
            if let judgement = try? decoder.decode(Judgement.self, from: Data(line)) { out[judgement.emailID] = judgement }
        }
        return out
    }

    /// Mail with nothing left to do: answered, or bulk the filter stopped — neither is read again.
    public static func done(in answered: [String: Judgement]) -> Set<String> {
        Set(answered.values.filter { Extractor.isSettled($0) || $0.isBulk }.map(\.emailID))
    }

    public func look(password: String, progress: @Sendable (String) -> Void = { _ in }) async throws -> Look {
        let answered = earlier.merging(Self.readLog(log)) { _, own in own }
        let settled = Self.done(in: answered).union(alsoKnown)

        let client = try await IMAPClient.connect(to: account, password: password)
        let intake: LabelIntake.Result
        do {
            var reading = LabelIntake(label: label, host: account.host, known: settled)
            // A scan mailed to yourself with the label's name in the subject counts as labelled.
            reading.keyword = label
            reading.ownAddresses = [account.user]
            intake = try await reading.run(client, progress: progress)
        } catch {
            await client.logout()
            throw error
        }
        await client.logout()

        var mapping = Pseudonymizer.Mapping()
        if let data = try? Data(contentsOf: self.mapping) { mapping = try JSONDecoder().decode(Pseudonymizer.Mapping.self, from: data) }
        mapping.upgrade()
        let report = Spike(detector: EntityDetector())
            .run(emails: intake.emails, labelled: intake.labelled,
                 pseudonymizer: Pseudonymizer(mode: .placeholder, entries: mapping.placeholder))
        let new = report.outcomes.filter {
            $0.judgement.disguise != nil && !settled.contains($0.judgement.emailID) && !setAside.contains($0.judgement.emailID)
        }.map(\.judgement.emailID)
        // Set aside: not sent in this run, whatever is ticked.
        var offered = report
        offered.outcomes.removeAll { setAside.contains($0.judgement.emailID) && !settled.contains($0.judgement.emailID) }
        return Look(report: offered, answered: answered, intake: intake, pending: new.count,
                    estimate: Double(new.count) * Self.costPerMail(model), newIDs: new)
    }

    /// Sends what `look` found new, and returns the new answers. Every earlier answer is kept and
    /// written back with them.
    public func classify(_ look: Look, claude: Claude, owner: [String], matters: [(key: String, about: String)] = [],
                         progress: @Sendable (Int, Int, String) -> Void = { _, _, _ in }) async throws -> (judgements: [Judgement], summary: Extractor.Summary) {
        var outcomes = look.report.outcomes
        var summary = Extractor.Summary()
        if let pseudonymizer = look.report.pseudonymizer {
            var extractor = Extractor(model: model, claude: claude, cache: cache)
            extractor.strict = strict
            extractor.storeMatters = matters
            summary = try await extractor
                .run(&outcomes, pseudonymizer: pseudonymizer, owner: owner, known: look.answered) { step, total, outcome in
                    progress(step, total, outcome.judgement.subject)
                }
            var mapping = Pseudonymizer.Mapping()
            if let data = try? Data(contentsOf: self.mapping) { mapping = try JSONDecoder().decode(Pseudonymizer.Mapping.self, from: data) }
            mapping.upgrade()
            mapping.placeholder = pseudonymizer.entries
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(mapping).write(to: self.mapping, options: .atomic)
        }
        let new = outcomes.map(\.judgement)
        try Self.write(Array(look.answered.values), plus: new, to: log)
        return (new, summary)
    }

    /// The whole record, earlier answers and new, in date order. Written beside the log and moved
    /// over it, so a run that stops halfway leaves the old record whole.
    public static func write(_ earlier: [Judgement], plus new: [Judgement], to url: URL) throws {
        var byID = Dictionary(earlier.map { ($0.emailID, $0) }, uniquingKeysWith: { a, _ in a })
        for judgement in new { byID[judgement.emailID] = judgement }
        let all = byID.values.sorted { ($0.date ?? .distantPast, $0.emailID) < ($1.date ?? .distantPast, $1.emailID) }
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).writing")
        let log = try JudgementLog(url: temporary)
        for judgement in all { try log.write(judgement) }
        try log.close()
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
        } else {
            try FileManager.default.moveItem(at: temporary, to: url)
        }
    }
}
