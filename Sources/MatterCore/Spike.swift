import Foundation
import NaturalLanguage

/// The Phase 0 pipeline, as far as it is built: parse, filter, detect, disguise, log.
///
/// Steps 5 to 8 of the plan — ask the model, restore, cluster, report — are not here yet, and
/// the decision each mail carries says so in `decided_by: pending` rather than pretending the
/// run is finished.
public struct Spike: Sendable {
    public var detector: EntityDetector
    /// What ran, named in the log so a record from an older run is never mistaken for a newer one.
    public static let stages = ["parse", "bulk_filter", "entity_detection", "pseudonymize"]
    static let detectionStages = Array(stages.prefix(3))

    /// Off for the manual edition, where every mail was chosen by the owner: a label is a
    /// decision, and a `noreply@` sender or an `Auto-Submitted` header does not overrule it.
    public var filtersBulk: Bool

    public init(detector: EntityDetector = EntityDetector(), filtersBulk: Bool = true) {
        self.detector = detector
        self.filtersBulk = filtersBulk
    }

    public struct Outcome: Sendable {
        public var judgement: Judgement
        public var email: Email
    }

    /// `filtersBulk` overrides the pipeline's own setting for this one mail.
    public func run(on email: Email, filtersBulk: Bool? = nil) -> Outcome {
        let filters = filtersBulk ?? self.filtersBulk
        let verdict = filters ? BulkFilter.verdict(for: email) : BulkFilter.Verdict(isBulk: false, rule: nil, reason: nil)
        // Bulk mail is settled here and goes no further: no tagger, no disguise, no model. That
        // is most of the saving the filter exists for, so the pipeline has to actually stop.
        let entities = verdict.isBulk ? [] : detector.entities(in: email)

        let decision = Judgement(
            emailID: email.id,
            source: email.source.isFileURL ? email.source.path : email.source.absoluteString,
            date: email.date,
            subject: email.subject,
            from: email.from,
            isBulk: verdict.isBulk,
            bulkReason: verdict.reason,
            bulkRule: verdict.rule,
            matter: nil,
            matterConfidence: 0,
            matterReason: verdict.isBulk
                ? "bulk mail is not classified"
                : "not classified: the model stage is not built yet",
            replyTo: ThreadMemory.parents(of: email).last ?? "",
            decidedBy: verdict.isBulk ? .rule : .pending,
            parties: [],
            todos: [],
            deadlines: [],
            entities: entities,
            attachments: email.attachments,
            stages: Self.detectionStages)
        return Outcome(judgement: decision, email: email)
    }

    // MARK: A folder of them

    public struct Report: Sendable {
        public var outcomes: [Outcome] = []
        public var failures: [(file: String, error: String)] = []
        /// With everything the run learned in it, ready to be written back to `mapping.json`.
        public var pseudonymizer: Pseudonymizer?
        public var disguised: [Outcome] { outcomes.filter { $0.judgement.disguise != nil } }

        public var bulk: [Outcome] { outcomes.filter(\.judgement.isBulk) }
        public var kept: [Outcome] { outcomes.filter { !$0.judgement.isBulk } }

        public var byRule: [BulkFilter.Rule: Int] {
            outcomes.reduce(into: [:]) { counts, outcome in
                guard let rule = outcome.judgement.bulkRule else { return }
                counts[rule, default: 0] += 1
            }
        }

        public var byKind: [Entity.Kind: Int] {
            outcomes.flatMap(\.judgement.entities).reduce(into: [:]) { counts, entity in
                counts[entity.kind, default: 0] += 1
            }
        }

        public var bySource: [Entity.Source: Int] {
            outcomes.flatMap(\.judgement.entities).reduce(into: [:]) { counts, entity in
                counts[entity.source, default: 0] += 1
            }
        }

        /// Mail that came through with nothing readable in it. Worth its own count: an empty
        /// body is not a mail without entities, it is a mail the detector never saw.
        public var empty: [Outcome] { outcomes.filter { $0.email.body.trimmed.isEmpty } }
    }

    public static func files(in folder: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { ["eml", "emlx", "txt"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Two passes when there is a disguise to make. The whole folder is learned before any mail
    /// is disguised, so a name the tagger only recognised in the ninetieth mail is still replaced
    /// in the third.
    public func run(folder: URL, log: JudgementLog?, pseudonymizer: Pseudonymizer? = nil) throws -> Report {
        var emails: [Email] = []
        var failures: [(file: String, error: String)] = []
        for file in try Self.files(in: folder) {
            do { emails.append(try EMLParser.parse(contentsOf: file)) }
            catch { failures.append((file.lastPathComponent, "\(error)")) }
        }
        var report = run(emails: emails, pseudonymizer: pseudonymizer)
        report.failures = failures
        for outcome in report.outcomes { try log?.write(outcome.judgement) }
        return report
    }

    /// The same, for mail that did not come from a folder. `labelled` names the mail the owner
    /// chose, by Message-ID: the filter does not overrule a label, but it still decides for a
    /// reply that came in by thread alone.
    public func run(emails: [Email], labelled: Set<String> = [], pseudonymizer: Pseudonymizer? = nil) -> Report {
        var report = Report()
        report.outcomes = emails.map { run(on: $0, filtersBulk: labelled.contains($0.id) ? false : nil) }

        if var pseudonymizer {
            let kept = report.outcomes.filter { !$0.judgement.isBulk }
            let vocabulary = Vocabulary(kept.flatMap { outcome -> [String] in
                let email = outcome.email
                return [email.subject, email.from, email.body] + email.to + email.cc
            })
            let skipped = pseudonymizer.learn(kept.flatMap(\.judgement.entities), vocabulary: vocabulary)
            let disguiser = pseudonymizer.disguiser
            for index in report.outcomes.indices where !report.outcomes[index].judgement.isBulk {
                let outcome = report.outcomes[index]
                let texts = outcome.judgement.entities.map(\.text)
                report.outcomes[index].judgement.disguise = pseudonymizer.disguise(outcome.email, with: disguiser)
                report.outcomes[index].judgement.notDisguised = skipped.filter { skip in texts.contains { $0.contains(skip.text) } }
                report.outcomes[index].judgement.stages = Self.stages
            }
            report.pseudonymizer = pseudonymizer
        }
        return report
    }
}
