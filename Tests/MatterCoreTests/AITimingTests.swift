import Foundation
import SwiftData
import Testing
@testable import MatterCore

/// How long each part of an AI request takes, with a store and a list of names as large as the
/// owner's: run with CAUSABEE_TIMING=1; with CAUSABEE_LIVE_KEY and CAUSABEE_LIVE_MODEL it also
/// sends real requests. Prints, and asserts nothing.
@MainActor
@Suite(.serialized)
struct AITimingTests {
    nonisolated static let on = ProcessInfo.processInfo.environment["CAUSABEE_TIMING"] != nil

    static func ms(_ d: Duration) -> String { String(format: "%7.1f ms", Double(d.components.attoseconds) / 1e15 + Double(d.components.seconds) * 1000) }

    static let first = ["Anna","Bernd","Carla","Dieter","Eva","Frank","Greta","Hans","Ines","Jens","Karin","Lars","Maria","Nils","Olga","Paul","Rita","Sven","Tina","Uwe","Vera","Wolf","Yvonne","Zora","Georg","Helga","Nina","Tanguy","Patricia","Marcus"]
    static let last = ["Berger","Kramer","Lindner","Schulz","Weber","Fischer","Wagner","Becker","Hoffmann","Koch","Richter","Klein","Wolf","Neumann","Schwarz","Zimmermann","Braun","Krüger","Hartmann","Lange","Werner","Krause","Meier","Lehmann","Schmid","Schulze","Maier","Köhler","Herrmann","König","Walter","Mayer","Huber","Kaiser","Fuchs","Peters","Lang","Scholz","Möller","Weiß","Jung","Hahn","Schubert","Vogel","Friedrich","Keller","Günther","Frank","Berg","Roth","Beck","Lorenz","Baumann","Franke","Albrecht","Schuster","Simon","Ludwig","Böhm","Winter","Kraus","Martin","Schumacher","Krämer","Vogt","Stein","Jäger","Otto","Sommer","Groß","Seidel","Heinrich","Brandt","Haas","Schreiber","Graf","Schulte","Dietrich","Ziegler","Kuhn","Kühn","Pohl","Engel","Horn","Busch","Bergmann","Thomas","Voigt","Sauer","Arnold","Wolff","Pfeiffer","Voss","Kaya","Axmann","Lacroix"]

    /// A matter like the owner's busiest: 60 mails with digests, 15 open tasks, 8 people, notes.
    static func store() throws -> (ModelContext, Matter, [Matter], Pseudonymizer.Mapping) {
        let context = ModelContext(try MatterSchema.container(at: nil))
        var entries: [Pseudonymizer.Entry] = []
        var n = 0
        for f in first { for l in last where entries.count < 2400 {
            n += 1
            entries.append(.init(kind: .person, original: "\(f) \(l)", standIn: "[Person \(n)]"))
        } }
        for i in 0..<500 { entries.append(.init(kind: .organization, original: "\(last[i % last.count]) Service \(i) GmbH", standIn: "[Company \(i)]")) }
        for i in 0..<272 { entries.append(.init(kind: .email, original: "person\(i)@mail\(i).example", standIn: "[Mail \(i)]")) }
        var mapping = Pseudonymizer.Mapping()
        mapping.placeholder = entries
        var matters: [Matter] = []
        for m in 0..<22 {
            let matter = Matter(key: "m\(m)", name: "Matter \(m): Mietwagen, Versicherung und Pflege")
            context.insert(matter)
            matters.append(matter)
            let mails = m == 0 ? 60 : 15
            for e in 0..<mails {
                let who = "\(first[e % first.count]) \(last[(e * 7) % last.count])"
                let source = Source(kind: .mail, pointer: "imap://x/INBOX;UIDVALIDITY=1/;UID=\(m * 100 + e)", messageID: "m\(m)-\(e)@x", date: Date().addingTimeInterval(-Double(e) * 86_400))
                let entry = Entry(title: "Re: Schadensmeldung \(e) zum Mietwagen", from: "\(who) <person\(e)@mail\(e).example>", date: source.date, source: source)
                entry.digest = "\(who) bestätigt den Eingang der Unterlagen und bittet um die Rechnung bis Freitag. Die Kaution von 450 Euro wird nach Prüfung erstattet."
                entry.matter = matter
                context.insert(entry)
            }
            for t in 0..<(m == 0 ? 15 : 5) {
                let todo = Todo(text: "Bei \(first[t % first.count]) \(last[t % last.count]) wegen der Unterlagen \(t) nachfragen", owner: [.me, .we, .other][t % 3], due: nil,
                                source: Source(kind: .mail, pointer: "p", messageID: "m\(m)-\(t)@x", date: Date()), origin: "m\(m)#\(t)")
                todo.matter = matter
                context.insert(todo)
            }
        }
        matters[0].notes = "Termin beim Gutachter steht noch aus. Rückruf von Frau Berger abwarten."
        try context.save()
        return (context, matters[0], matters, mapping)
    }

    @Test(.enabled(if: on))
    func localPartsOfARequest() throws {
        let clock = ContinuousClock()
        let (_, matter, all, mapping) = try Self.store()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("timing-mapping.json")
        try JSONEncoder().encode(mapping).write(to: url)
        let today = MatterStatus.day(Date())
        var report: [String] = ["mapping file \(try Data(contentsOf: url).count / 1024) KB, \(mapping.placeholder.count) names"]
        func time(_ label: String, _ work: () throws -> Void) rethrows {
            _ = try? work() // warm
            let d = try clock.measure(work)
            report.append("\(Self.ms(d))  \(label)")
        }
        try time("read and decode the list of names") { _ = try JSONDecoder().decode(Pseudonymizer.Mapping.self, from: Data(contentsOf: url)) }
        time("make the disguise's names (Pseudonymizer init)") { _ = Pseudonymizer(mode: .placeholder, entries: mapping.placeholder) }
        let p = Pseudonymizer(mode: .placeholder, entries: mapping.placeholder)
        time("build the disguiser (all spellings)") { _ = p.disguiser }
        time("build the restorer") { _ = p.restorer }
        var facts = FactSheet.facts(for: [matter], today: today)
        time("facts · one matter, 120 mails") { facts = FactSheet.facts(for: [matter], today: today) }
        report.append("         facts text \(facts.text.count) characters")
        time("facts · one matter, 40 mails (brief)") { _ = FactSheet.facts(for: [matter], today: today, mails: 40) }
        var allFacts = facts
        time("facts · all 22 matters (overview)") { allFacts = FactSheet.facts(for: all, today: today) }
        report.append("         all-matters facts text \(allFacts.text.count) characters")
        try time("prepare · whole disguise of a question (one matter)") {
            _ = try AssistantAsk.prepare(question: "Was muss ich bis Freitag an Bernd Berger schicken?", inHand: nil, earlier: [], facts: facts, owner: "Mara Voss",
                                         today: today, mapping: url, saves: false)
        }
        try time("prepare · all matters") {
            _ = try AssistantAsk.prepare(question: "Was ist diese Woche wichtig?", inHand: nil, earlier: [], facts: allFacts, owner: "Mara Voss",
                                         today: today, mapping: url, saves: false)
        }
        let user = AssistantPrompt.user(today: today, owner: "Mara", facts: facts.text, inHand: nil, earlier: [], question: "Was nun?")
        time("detector · rules over the request") { _ = EntityDetector(runsTagger: false).entities(in: user, field: .body) }
        time("detector · tagger over a typed question") { _ = EntityDetector().entities(in: "Was muss ich bis Freitag an Bernd Berger schicken?", field: .body) }
        // The iPhone's and the iPad's way: their own list, and the other devices' names learned for each question.
        let own = Array(mapping.placeholder.prefix(1600)), others = Array(mapping.placeholder.dropFirst(1600))
        var mine = Pseudonymizer.Mapping(); mine.placeholder = own
        try time("prepare · iPhone/iPad, 1,572 names from the other devices") {
            _ = try AssistantAsk.prepare(question: "Was muss ich bis Freitag an Bernd Berger schicken?", inHand: nil, earlier: [], facts: facts, owner: "Mara Voss",
                                         today: today, mapping: mine, others: others, save: nil)
        }
        let disguiser = p.disguiser
        time("disguise · apply to the request") { _ = disguiser.apply(user) }
        let restorer = p.restorer
        time("restore · apply to an answer of 1,500 characters") { _ = restorer.apply(String(repeating: "[Person 12] schickt die Rechnung an [Company 3]. ", count: 30)) }
        print("TIMING LOCAL\n" + report.joined(separator: "\n"))
    }

    @Test(.enabled(if: on && ProcessInfo.processInfo.environment["CAUSABEE_LIVE_KEY"] != nil))
    func liveRequests() async throws {
        let env = ProcessInfo.processInfo.environment
        let model = Claude.Model.choices.first { $0.id == env["CAUSABEE_LIVE_MODEL"] } ?? .opus
        let claude = Claude(key: env["CAUSABEE_LIVE_KEY"]!)
        let (_, matter, _, mapping) = try Self.store()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("timing-mapping-live.json")
        try JSONEncoder().encode(mapping).write(to: url)
        let today = MatterStatus.day(Date())
        let clock = ContinuousClock()
        var report: [String] = ["model \(model.id)"]
        let facts = FactSheet.facts(for: [matter], today: today)
        for round in 1...2 {
            let a = try await clock.measure {
                let answer = try await AssistantAsk.ask(question: "Was muss ich als Nächstes tun?", inHand: nil, earlier: [], facts: facts, owner: "Mara Voss",
                                                        today: today, mapping: url, claude: claude, model: model)
                report.append("         assistant answer: \(answer.reply.lines.count) lines, \(answer.reply.cards.count) cards, served in \(String(format: "%.1f", answer.seconds)) s, $\(String(format: "%.4f", answer.cost))")
            }
            report.append("\(Self.ms(a))  assistant question, round \(round)")
        }
        let briefFacts = FactSheet.facts(for: [matter], today: today, mails: 40)
        for round in 1...2 {
            let b = try await clock.measure {
                let advice = try await AssistantAsk.advise(facts: briefFacts, dismissed: [], owner: "Mara Voss", today: today, mapping: url, claude: claude, model: model)
                report.append("         brief: \(advice.lines.count) lines, \(advice.proposals.count) proposals, $\(String(format: "%.4f", advice.cost))")
            }
            report.append("\(Self.ms(b))  brief (adviser), round \(round)")
        }
        let l = try await clock.measure {
            _ = try await WebLookup.ask("Wie lange hat die Pflegekasse in Deutschland Zeit, über einen Pflegegrad zu entscheiden?", language: "German", country: "DE",
                                        claude: claude, model: model)
        }
        report.append("\(Self.ms(l))  web lookup")
        print("TIMING LIVE\n" + report.joined(separator: "\n"))
    }
}
