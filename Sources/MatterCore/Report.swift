import Foundation

/// Step 8 of the spike: what the pipeline said, measured against what the golden set says.
///
/// Built for the manual edition first, so it asks the questions that decide it: does a thread
/// reach its matter from one tap, are the to-dos the right ones and are they given to the right
/// person, are the parties the people in it. Everything is counted per mail and added up, and
/// every to-do it paired is written out — a lexical matcher is a guess about what "the same
/// to-do" means, and the pairs are how that guess gets checked.
public enum Report {
    // MARK: Matching free text

    /// German and English words that carry no to-do: articles, pronouns, the politeness around a
    /// request. What is left is what somebody has to do and to what.
    static let stopwords: Set<String> = [
        "der", "die", "das", "den", "dem", "des", "ein", "eine", "einen", "einem", "einer", "und", "oder",
        "zu", "zur", "zum", "mit", "für", "an", "auf", "in", "im", "am", "um", "von", "vom", "bei", "bis",
        "ich", "du", "er", "sie", "es", "wir", "ihr", "mir", "mich", "dir", "dich", "uns", "euch", "ihnen",
        "ihm", "ihn", "sein", "seine", "ihre", "ihren", "ihrer", "unsere", "meine", "mein", "bitte", "noch",
        "schon", "auch", "nur", "ob", "dass", "wie", "was", "wer", "wenn", "als", "so", "ggf", "evtl",
        "the", "a", "an", "and", "or", "to", "for", "of", "on", "in", "at", "with", "by", "please", "if",
        "me", "you", "we", "they", "it", "my", "your", "our", "their", "be", "is", "are",
    ]

    /// Words cut to their first five letters, which is crude and German enough: `schicken`,
    /// `schickt` and `geschickt` differ, `schicken` and `schickst` do not.
    static func stems(_ text: String) -> Set<String> {
        let words = text.lowercased().precomposedStringWithCanonicalMapping
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 1 && !stopwords.contains($0) }
        return Set(words.map { String($0.prefix(5)) })
    }

    /// Dice's coefficient on the stems: 1 for the same words, 0 for none in common.
    static func similarity(_ a: String, _ b: String) -> Double {
        let (x, y) = (stems(a), stems(b))
        guard !x.isEmpty, !y.isEmpty else { return 0 }
        return 2 * Double(x.intersection(y).count) / Double(x.count + y.count)
    }

    /// How much of the shorter one is in the longer one. Dice punishes a difference in length:
    /// `Feedbackgespräch` is all there in "Bestätigen, ob Mittwoch 10 Uhr für das
    /// Feedbackgespräch passt", and scores 0.2 on Dice.
    static func containment(_ a: String, _ b: String) -> Double {
        let (x, y) = (stems(a), stems(b))
        guard !x.isEmpty, !y.isEmpty else { return 0 }
        return Double(x.intersection(y).count) / Double(min(x.count, y.count))
    }

    /// Two to-dos are the same when their stems overlap enough, or when the shorter one is
    /// nearly all inside the longer. The second bar is higher, because "Angebot prüfen" is half
    /// inside "Angebot annehmen" and is a different thing to do. Chosen by reading the pairs,
    /// not tuned.
    public static let threshold = 0.4
    public static let containedThreshold = 0.66

    static func score(_ a: String, _ b: String) -> Double? {
        let dice = similarity(a, b), contained = containment(a, b)
        guard dice >= threshold || contained >= containedThreshold else { return nil }
        return max(dice, contained)
    }

    /// Greedy pairing, best pair first, each item used once.
    static func pair(_ expected: [String], _ found: [String]) -> [(Int, Int, Double)] {
        var candidates: [(Int, Int, Double)] = []
        for (i, e) in expected.enumerated() {
            for (j, f) in found.enumerated() {
                if let score = score(e, f) { candidates.append((i, j, score)) }
            }
        }
        var usedE = Set<Int>(), usedF = Set<Int>(), pairs: [(Int, Int, Double)] = []
        for candidate in candidates.sorted(by: { $0.2 > $1.2 }) where !usedE.contains(candidate.0) && !usedF.contains(candidate.1) {
            usedE.insert(candidate.0); usedF.insert(candidate.1); pairs.append(candidate)
        }
        return pairs
    }

    // MARK: Counting

    public struct Tally: Sendable {
        public var expected = 0
        public var found = 0
        public var matched = 0
        public var recall: Double { expected == 0 ? 0 : Double(matched) / Double(expected) }
        public var precision: Double { found == 0 ? 0 : Double(matched) / Double(found) }
        public var f1: Double { recall + precision == 0 ? 0 : 2 * recall * precision / (recall + precision) }
    }

    public struct TodoPair: Sendable {
        public var file: String
        public var expected: String?
        public var found: String?
        public var score: Double
        public var ownerExpected: Judgement.Todo.Owner?
        public var ownerFound: Judgement.Todo.Owner?
        public var reason: String? = nil
    }

    public struct Result: Sendable {
        public var mails = 0
        public var todos = Tally()
        public var myTodos = Tally()          // the owner's own, alone or with others: what Causabee is for
        public var waiting = Tally()          // someone else's, that the owner is waiting for
        public var ownerRight = 0             // among matched pairs with an owner on both sides
        public var ownerJudged = 0
        public var dueRight = 0
        public var dueJudged = 0
        public var deadlines = Tally()
        public var parties = Tally()
        public var matterFound = 0            // mails with a matter in the label where the model found one
        public var matterExpected = 0
        public var groups: [(label: String, mails: Int, bestModel: String, share: Double, pieces: Int)] = []
        public var pairs: [TodoPair] = []
        public var reach: Reach?
        public var cost = 0.0
        public var model = ""
        public var duplicates = 0
        /// One list per matter: to-dos the model made new, asked again and closed, and roughly how
        /// many different to-dos the labels hold once the repeats are put together.
        public var modelNew = 0
        public var modelAgain = 0
        public var modelDone = 0
        public var appointments = 0
        public var labelledDistinct = 0
        /// Set when a judge paired the to-dos rather than the word stems.
        public var judge: String? = nil
        public var judgeCost = 0.0
    }

    /// The manual edition, simulated from the labels alone: the tapped mails carry the label,
    /// and every other mail reaches its matter only if thread memory takes it there.
    public struct Reach: Sendable {
        public var taps = 0
        public var followers = 0
        public var reached = 0
        public var reachedWrong = 0
        /// Not reached by thread, but written by or to someone already in the matter — what a
        /// "mail from a known party" rule would add.
        public var byKnownParty = 0
        public var missed: [(subject: String, matter: String)] = []
    }

    /// Pairs decided elsewhere — by a judge — keyed by the label's file name. A mail with no entry
    /// falls back to the word stems.
    public typealias Judged = [String: [(expected: Int, found: Int, reason: String)]]

    public static func measure(decisions: [Judgement], labels: [Label], emails: [Email],
                               judged: Judged? = nil) -> Result {
        var result = Result()
        let byFile = Dictionary(decisions.map { (URL(fileURLWithPath: $0.source).lastPathComponent, $0) },
                                uniquingKeysWith: { first, _ in first })
        // Mail exported twice — the same message in two conversations — counts once, by its
        // Message-ID, as the first copy. Where the copies disagree on `tapped`, the tap wins.
        var seen: [String: Int] = [:]
        var labelled: [Label] = []
        for label in labels where label.isLabelled {
            let id = label.emailID.isEmpty ? label.file : label.emailID
            if let index = seen[id] {
                if label.tapped == true { labelled[index].tapped = true }
                continue
            }
            seen[id] = labelled.count
            labelled.append(label)
        }
        result.duplicates = labels.filter(\.isLabelled).count - labelled.count
        result.model = Set(decisions.compactMap { $0.extraction?.model }).sorted().joined(separator: ", ")
        result.cost = decisions.compactMap { $0.extraction?.costUSD }.reduce(0, +)

        var groupsByLabel: [String: [String?]] = [:]

        for label in labelled {
            guard let decision = byFile[label.file], decision.extraction != nil, decision.extraction?.skipped == nil else { continue }
            result.mails += 1

            // To-dos.
            let expected = label.todos.map(\.text)
            let found = decision.todos.map(\.text)
            let judgedHere = judged?[label.file]
            let pairs: [(Int, Int, Double)] = judgedHere.map { $0.map { ($0.expected, $0.found, 1.0) } } ?? pair(expected, found)
            let reasons = Dictionary(judgedHere?.map { ("\($0.expected)-\($0.found)", $0.reason) } ?? [], uniquingKeysWith: { a, _ in a })
            result.todos.expected += expected.count
            result.todos.found += found.count
            result.todos.matched += pairs.count
            // "Mine" is what the owner has to do, alone or with others: `me` and `we`.
            let mine: (Judgement.Todo.Owner) -> Bool = { $0 == .me || $0 == .we }
            result.myTodos.expected += label.todos.filter { mine($0.owner) }.count
            result.myTodos.found += decision.todos.filter { mine($0.owner) }.count
            result.myTodos.matched += pairs.filter { mine(label.todos[$0.0].owner) && mine(decision.todos[$0.1].owner) }.count
            result.waiting.expected += label.todos.filter { $0.owner == .other }.count
            result.waiting.found += decision.todos.filter { $0.owner == .other }.count
            result.waiting.matched += pairs.filter { label.todos[$0.0].owner == .other && decision.todos[$0.1].owner == .other }.count
            for (i, j, score) in pairs {
                let (e, f) = (label.todos[i], decision.todos[j])
                if e.owner != .unknown, f.owner != .unknown {
                    result.ownerJudged += 1
                    if e.owner == f.owner { result.ownerRight += 1 }
                }
                if e.due != nil || f.due != nil {
                    result.dueJudged += 1
                    if e.due == f.due { result.dueRight += 1 }
                }
                result.pairs.append(.init(file: label.file, expected: e.text, found: f.text, score: score,
                                          ownerExpected: e.owner, ownerFound: f.owner, reason: reasons["\(i)-\(j)"]))
            }
            let pairedE = Set(pairs.map(\.0)), pairedF = Set(pairs.map(\.1))
            for (i, e) in label.todos.enumerated() where !pairedE.contains(i) {
                result.pairs.append(.init(file: label.file, expected: e.text, found: nil, score: 0, ownerExpected: e.owner, ownerFound: nil))
            }
            for (j, f) in decision.todos.enumerated() where !pairedF.contains(j) {
                result.pairs.append(.init(file: label.file, expected: nil, found: f.text, score: 0, ownerExpected: nil, ownerFound: f.owner))
            }

            result.modelNew += decision.todos.filter { $0.sameAs == nil }.count
            result.modelAgain += decision.todos.filter { $0.sameAs != nil }.count
            result.modelDone += decision.done.count
            result.appointments += decision.appointments.count

            // Deadlines: the date has to agree, and the words a little.
            let deadlinePairs = label.deadlines.filter { e in
                decision.deadlines.contains { $0.date == e.date }
            }
            result.deadlines.expected += label.deadlines.count
            result.deadlines.found += decision.deadlines.count
            result.deadlines.matched += min(deadlinePairs.count, decision.deadlines.count)

            // Parties: by name, loosely — a surname in common is the same person.
            let partyPairs = pair(label.parties.map(\.name), decision.parties.map(\.name))
            result.parties.expected += label.parties.count
            result.parties.found += decision.parties.count
            result.parties.matched += partyPairs.count

            // Matters.
            if let matter = label.matter {
                result.matterExpected += 1
                if decision.matter != nil { result.matterFound += 1 }
                groupsByLabel[matter, default: []].append(decision.matter)
            }
        }

        // A label's matter is found when most of its mails land in one of the model's matters.
        // Names never agree — the model makes up its own — so only the grouping is compared.
        for (label, models) in groupsByLabel.sorted(by: { $0.value.count > $1.value.count }) {
            let counts = Dictionary(grouping: models.compactMap { $0 }, by: { $0 }).mapValues(\.count)
            let best = counts.max { $0.value < $1.value }
            result.groups.append((label, models.count, best?.key ?? "—",
                                  Double(best?.value ?? 0) / Double(models.count), counts.count))
        }

        result.labelledDistinct = distinctTodos(labelled.filter { label in byFile[label.file]?.extraction != nil })

        if labelled.contains(where: { $0.tapped != nil }) {
            result.reach = reach(labels: labelled, emails: emails)
        }
        return result
    }

    /// How many different to-dos the labels hold, once a to-do written again in a later mail of
    /// the same matter is counted with the first: nearly all of the shorter inside the longer.
    static func distinctTodos(_ labels: [Label]) -> Int {
        var seen: [(matter: String, stems: Set<String>)] = []
        for label in labels.sorted(by: { $0.date < $1.date }) {
            for todo in label.todos {
                let s = stems(todo.text)
                let matter = label.matter ?? ""
                let repeated = seen.contains { entry in
                    entry.matter == matter && !s.isEmpty && !entry.stems.isEmpty
                        && Double(s.intersection(entry.stems).count) / Double(min(s.count, entry.stems.count)) >= containedThreshold
                }
                if !repeated { seen.append((matter, s)) }
            }
        }
        return seen.count
    }

    static func reach(labels: [Label], emails: [Email]) -> Reach {
        var reach = Reach()
        let byFile = Dictionary(emails.map { ($0.source.lastPathComponent, $0) }, uniquingKeysWith: { first, _ in first })
        var memory = ThreadMemory()
        var people: [String: Set<String>] = [:]  // matter → addresses seen in it

        let ordered = labels.compactMap { label in byFile[label.file].map { (label, $0) } }
            .sorted { ($0.1.date ?? .distantPast) < ($1.1.date ?? .distantPast) }
        for (label, email) in ordered {
            guard let matter = label.matter else { continue }
            let addresses = Set(([email.from] + email.to + email.cc).map(Email.address(in:)))
            if label.tapped == true {
                reach.taps += 1
                memory.remember(email, matter: matter)
                people[matter, default: []].formUnion(addresses)
                continue
            }
            reach.followers += 1
            if let followed = memory.matter(for: email) {
                reach.reached += 1
                if followed != matter { reach.reachedWrong += 1 }
                memory.remember(email, matter: followed)
                people[followed, default: []].formUnion(addresses)
            } else {
                if !(people[matter] ?? []).isDisjoint(with: [Email.address(in: email.from)]) { reach.byKnownParty += 1 }
                reach.missed.append((email.subject, matter))
            }
        }
        return reach
    }

    // MARK: Writing it down

    public static func text(_ result: Result, title: String) -> String {
        func pct(_ value: Double) -> String { String(format: "%.0f%%", value * 100) }
        func tally(_ name: String, _ t: Tally) -> String {
            "| \(name) | \(t.expected) | \(t.found) | \(t.matched) | \(pct(t.recall)) | \(pct(t.precision)) |"
        }
        var out = ["# \(title)", "",
                   "\(result.mails) labelled mails with an answer · \(result.duplicates) duplicates counted once · \(result.model) · \(String(format: "$%.2f", result.cost))", ""]

        if let reach = result.reach {
            out += ["## Reaching the matter from one tap", "",
                    "| | |", "|---|---|",
                    "| taps | \(reach.taps) |",
                    "| mails meant to follow | \(reach.followers) |",
                    "| reached by thread | \(reach.reached) (\(pct(reach.followers == 0 ? 0 : Double(reach.reached) / Double(reach.followers)))) |",
                    "| reached the wrong matter | \(reach.reachedWrong) |",
                    "| missed, but from someone already in the matter | \(reach.byKnownParty) |",
                    "| missed | \(reach.missed.count) |", ""]
            if !reach.missed.isEmpty {
                out += ["Missed, by subject:", ""]
                let counted = Dictionary(grouping: reach.missed, by: { "\($0.matter) · \($0.subject)" }).mapValues(\.count)
                for (line, count) in counted.sorted(by: { $0.key < $1.key }) { out.append("- \(line)\(count > 1 ? " (\(count))" : "")") }
                out.append("")
            }
        }

        out += ["## What was found", "",
                "| | labelled | found | paired | recall | precision |", "|---|---|---|---|---|---|",
                tally("to-dos", result.todos),
                tally("to-dos that are mine (me or we)", result.myTodos),
                tally("to-dos I am waiting for (other)", result.waiting),
                tally("deadlines", result.deadlines),
                tally("parties", result.parties), "",
                "Of the paired to-dos, the owner was right in \(result.ownerRight) of \(result.ownerJudged)" +
                " and the date in \(result.dueRight) of \(result.dueJudged).", "",
                result.judge.map { "To-dos were paired by a judge, \($0), for \(String(format: "$%.2f", result.judgeCost)); the reason for every pair is below." } ?? "",
                "A to-do is paired with one of the labels when their word stems overlap by \(Int(threshold * 100))% or more " +
                "(Dice), or when \(Int(containedThreshold * 100))% of the shorter is inside the longer. That is a guess about " +
                "sameness, and a lexical one: a different verb for the same object pairs whether or not it is the same thing " +
                "to do. The pairs below are how to check it.", ""]

        out += ["## One list per matter", "",
                "| | |", "|---|---|",
                "| your to-dos, one per mail | \(result.todos.expected) |",
                "| your to-dos once repeats are put together (estimated) | \(result.labelledDistinct) |",
                "| the model's new to-dos | \(result.modelNew) |",
                "| the model's \"asked again\" | \(result.modelAgain) |",
                "| the model's \"now done\" | \(result.modelDone) |",
                "| appointments (not measured yet) | \(result.appointments) |", ""]

        out += ["## Matters", "",
                "\(result.matterFound) of \(result.matterExpected) labelled matter mails were given a matter.", "",
                "| your matter | mails | its main matter in the model | share | spread over |", "|---|---|---|---|---|"]
        for group in result.groups {
            out.append("| \(group.label) | \(group.mails) | \(group.bestModel) | \(pct(group.share)) | \(group.pieces) |")
        }
        out.append("")

        out += ["## Every to-do, paired or not", "", "| mail | yours | the model's | score or reason |", "|---|---|---|---|"]
        func owner(_ o: Judgement.Todo.Owner?) -> String { o.map { $0 == .unknown ? "" : " (\($0.rawValue))" } ?? "" }
        func cell(_ s: String) -> String { s.replacingOccurrences(of: "|", with: "/").replacingOccurrences(of: "\n", with: " ") }
        for pair in result.pairs.sorted(by: { ($0.file, $0.expected == nil ? 1 : 0) < ($1.file, $1.expected == nil ? 1 : 0) }) {
            out.append("| \(cell(String(pair.file.prefix(40)))) | \(cell(pair.expected.map { $0 + owner(pair.ownerExpected) } ?? "—")) | "
                       + "\(cell(pair.found.map { $0 + owner(pair.ownerFound) } ?? "—")) | \(pair.reason.map(cell) ?? (pair.expected != nil && pair.found != nil ? String(format: "%.2f", pair.score) : "")) |")
        }
        return out.joined(separator: "\n") + "\n"
    }
}
