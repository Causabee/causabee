import Foundation
import MatterCore
import SwiftData

/// What a model on the Mac says about one mail — the same questions the extraction asks Claude,
/// in a shape small enough for a small model.
struct LocalAnswer: Codable {
    struct Todo: Codable { var text: String; var owner: String; var due: String }
    struct Day: Codable { var day: String; var time: String; var what: String; var kind: String }
    struct Party: Codable { var name: String; var role: String }
    /// A matter's key from the list, "neu" for a new one, "keine" for none.
    var matter: String
    var newMatterTitle: String
    var todos: [Todo]
    var dates: [Day]
    var parties: [Party]
}

protocol LocalEngine {
    var name: String { get }
    func read(instructions: String, prompt: String) async throws -> LocalAnswer
}

/// One mail to read: the text Opus was sent, with the real names put back on the Mac, and what
/// the store says is true about it after the owner's corrections.
struct BenchCase {
    var id: String
    var subject: String
    var date: Date?
    var text: String
    var opus: Judgement
    /// The matter the mail is in now; nil when it is in none.
    var matter: Matter?
    /// The mail is the first in its matter: "neu" was the right answer then.
    var startsMatter: Bool
    var todos: [(text: String, owner: String, due: String?)]
    var days: [String]
}

@MainActor
enum Bench {
    static func cases(store: ModelContext, log: URL, mapping: URL, limit: Int?) throws -> [BenchCase] {
        var map = Pseudonymizer.Mapping()
        if let data = try? Data(contentsOf: mapping) { map = try JSONDecoder().decode(Pseudonymizer.Mapping.self, from: data) }
        _ = map.upgrade()
        let restorer = Pseudonymizer(mode: .placeholder, entries: map.placeholder).restorer
        let entries = try store.fetch(FetchDescriptor<Entry>())
        let todos = try store.fetch(FetchDescriptor<MatterCore.Todo>())
        let appointments = try store.fetch(FetchDescriptor<Appointment>())
        let deadlines = try store.fetch(FetchDescriptor<Deadline>())

        let judgements = DailyDoor.readLog(log).values
            .filter { !$0.isBulk && $0.disguise != nil && $0.extraction != nil && $0.extraction?.skipped == nil && !$0.emailID.hasPrefix("screenshot:") }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        var out: [BenchCase] = []
        for judgement in judgements {
            guard let disguise = judgement.disguise else { continue }
            let newest = Quotes.newest(of: disguise.body, subject: disguise.subject)
            let sent = Extractor.text(of: disguise, body: newest.newest, omitted: newest.omitted)
            let id = judgement.emailID
            let matter = entries.first { $0.messageID == id }?.matter
            let first = matter.flatMap { m in (m.entries ?? []).min { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) } }
            out.append(BenchCase(
                id: id, subject: judgement.subject, date: judgement.date, text: restorer.apply(sent).text, opus: judgement,
                matter: matter, startsMatter: first?.messageID == id,
                todos: todos.filter { !$0.isInfo && $0.sources.contains { $0.messageID == id } }.map { ($0.text, $0.owner.rawValue, $0.due) },
                days: appointments.filter { $0.sources.contains { $0.messageID == id } }.map(\.day)
                    + deadlines.filter { $0.sources.contains { $0.messageID == id } }.map(\.day)))
        }
        if let limit { return Array(out.suffix(limit)) }
        return out
    }

    static func instructions(owner: String) -> String {
        """
        You sort the owner's mail into matters and read out what there is to do. The owner is \(owner). \
        Answer in German, from the mail only.
        matter: the key of the matter from the list the mail belongs to; "neu" if it starts a new matter \
        worth keeping; "keine" if it belongs to none (advertising, a notice with nothing to keep).
        newMatterTitle: for "neu", a short name as the owner would write it; otherwise empty.
        todos: what someone must do because of this mail. owner is "me" (the owner), "we" (the owner \
        together with others), or "other" (someone else, the owner waits for it). due is YYYY-MM-DD or empty.
        dates: appointments (kind "appointment") and deadlines (kind "deadline"), day YYYY-MM-DD, time HH:MM or empty.
        parties: the people and companies involved, with their role in a few words.
        """
    }

    /// The subject without "Re:", "AW:", "Fwd:" in front, to find the mail's thread by.
    static func thread(_ subject: String) -> String {
        subject.replacing(/^(?i)((re|aw|wg|fw|fwd)\s*:\s*)+/, with: "").trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// What Opus was told too: each matter with a few of its open to-dos, and the matter the
    /// earlier mail of the same thread is in.
    static func prompt(for item: BenchCase, matters: [Matter], maxCharacters: Int) -> String {
        let list = matters.map { matter in
            let open = matter.openTodos.prefix(3).map(\.text).map { String($0.prefix(70)) }
            return "- \(matter.key): \(matter.name)" + (open.isEmpty ? "" : " — open: " + open.joined(separator: "; "))
        }.joined(separator: "\n")
        let sent = item.date.map { MatterStatus.day($0) } ?? "?"
        var mail = item.text
        if mail.count > maxCharacters { mail = String(mail.prefix(maxCharacters)) + "\n[…gekürzt]" }
        let subject = thread(item.subject)
        let earlier = matters.first { matter in
            (matter.entries ?? []).contains { $0.messageID != item.id && ($0.date ?? .distantFuture) < (item.date ?? .distantPast) && thread($0.title) == subject }
        }
        let hint = earlier.map { "\nEarlier mail in this thread is in the matter \($0.key).\n" } ?? ""
        return "Matters:\n\(list)\n\(hint)\nMail sent on \(sent):\n\(mail)"
    }

    // MARK: Scoring

    static func words(_ text: String) -> Set<String> {
        let stop: Set<String> = ["eine", "einen", "einer", "dass", "oder", "sowie", "bitte", "wegen", "über", "nach", "damit", "noch", "auch", "diese", "dieser"]
        return Set(text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count >= 4 && !stop.contains($0) })
    }

    /// Two to-dos are the same thing when half the words of the shorter one are in the other.
    static func same(_ a: String, _ b: String) -> Bool {
        let x = words(a), y = words(b)
        guard !x.isEmpty, !y.isEmpty else { return false }
        return Double(x.intersection(y).count) / Double(min(x.count, y.count)) >= 0.5
    }

    struct Score {
        var matterRight = false
        var truthTodos = 0, foundTodos = 0, saidTodos = 0, rightTodos = 0, ownerRight = 0, dueRight = 0
        var truthDays = 0, foundDays = 0
    }

    static func matterRight(_ said: String?, title: String?, item: BenchCase, matters: [Matter]) -> Bool {
        let said = (said ?? "keine").trimmingCharacters(in: .whitespaces)
        switch said.lowercased() {
        case "keine", "none", "": return item.matter == nil
        case "neu", "new": return item.startsMatter
        default:
            let chosen = matters.first { $0.answers(to: said) || $0.name.lowercased() == said.lowercased() }
            // A key the list does not have is a new matter by another name.
            guard let chosen else { return item.startsMatter }
            return chosen === item.matter
        }
    }

    static func score(todos said: [(text: String, owner: String, due: String?)], days: [String], matterRight: Bool, item: BenchCase) -> Score {
        var score = Score(matterRight: matterRight, truthTodos: item.todos.count, saidTodos: said.count, truthDays: item.days.count)
        for truth in item.todos {
            guard let match = said.first(where: { same($0.text, truth.text) }) else { continue }
            score.foundTodos += 1
            if match.owner == truth.owner { score.ownerRight += 1 }
            if (match.due ?? "").isEmpty == (truth.due ?? "").isEmpty, (match.due ?? "") == (truth.due ?? "") { score.dueRight += 1 }
        }
        score.rightTodos = said.filter { s in item.todos.contains { same(s.text, $0.text) } }.count
        score.foundDays = Set(item.days).intersection(days).count
        return score
    }
}
