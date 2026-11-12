import Foundation
import SwiftData
import Testing
@testable import MatterCore

enum Thing: String, CaseIterable, Sendable { case task, fact, appointment, deadline }

/// The bee's manifesto (docs/bee-manifesto.md), held to by the code: every source kind × every
/// kind of new thing × how old the date written on it is. Each case is one promise.
@MainActor
struct ManifestoTests {
    /// What can come in. `.conversation` is the owner's own word.
    nonisolated static let kinds: [Source.Kind] = [.mail, .screenshot, .photo, .document]
    /// How long before it reached the bee it was written: today, yesterday, a week, a month, a year.
    nonisolated static let ages: [Double] = [0, 1, 7, 30, 365]

    /// One matter, and a way to make something come in.
    final class World {
        let context: ModelContext
        let matter: Matter
        var count = 0
        init() throws {
            context = ModelContext(try MatterSchema.container(at: nil))
            matter = Matter(key: "m", name: "M")
            context.insert(matter)
        }

        /// Something of `kind`, written `age` days before, reaching the bee at `arrived`, carrying
        /// one `thing` dated ahead.
        @discardableResult
        func comes(_ kind: Source.Kind, _ thing: Thing, written age: Double, arrived: Date = Date(), text: String? = nil) -> Source {
            count += 1
            let id = "<\(kind.rawValue)-\(count)@test>"
            let written = arrived.addingTimeInterval(-age * 86_400)
            let source = Source(kind: kind, pointer: "p\(count)", messageID: id, date: written)
            let entry = Entry(title: "Item \(count)", from: "Someone <s@example.org>", date: written, source: source)
            context.insert(entry)
            entry.matter = matter
            let record = SortedMail(messageID: id, device: "test")
            record.sortedAt = arrived
            context.insert(record)
            let ahead = MatterStatus.day(Date().addingTimeInterval(10 * 86_400))
            switch thing {
            case .task:
                let todo = Todo(text: text ?? "Call about item \(count)", owner: .me, due: nil, source: source, origin: id + "#t")
                context.insert(todo); todo.matter = matter
            case .fact:
                // The bee gives all of them each time: those there, and the new one.
                let there = (matter.todos ?? []).filter { $0.isFact }.map { GoodToKnowFact(text: $0.text, sources: $0.factSources, same: $0.persistentModelID) }
                matter.putFacts(there + [GoodToKnowFact(text: text ?? "Item \(count) holds a fact", sources: [source])], in: context, at: arrived)
            case .appointment:
                let item = Appointment(what: text ?? "Meeting \(count)", day: ahead, time: nil, place: nil, source: source)
                context.insert(item); item.matter = matter
            case .deadline:
                let item = Deadline(what: text ?? "Due \(count)", day: ahead, source: source)
                context.insert(item); item.matter = matter
            }
            try? context.save()
            return source
        }

        var summary: MatterSummary { MatterSummary(matter, today: MatterStatus.day(Date())) }
        var onCard: Int { matter.newItems().count }
        var says: Bool { matter.saysNew() }
    }

    nonisolated static var everything: [(Source.Kind, Thing, Double)] {
        kinds.flatMap { kind in Thing.allCases.flatMap { thing in ages.map { (kind, thing, $0) } } }
    }

    // MARK: Principle 1 and 2 — every source, new by when it reached the bee

    @Test("1·2 Whatever it came as, however old its date: reaching the bee now, it is new", arguments: everything)
    func newWhenItArrives(kind: Source.Kind, thing: Thing, age: Double) throws {
        let world = try World()
        world.matter.sawNew(at: Date().addingTimeInterval(-3600))
        world.comes(kind, thing, written: age)
        #expect(world.onCard == 1, "\(kind) \(thing) written \(age) days ago is not on the card")
        #expect(world.says, "\(kind) \(thing) written \(age) days ago gives no dot")
    }

    @Test("2 Reached the bee before the owner last looked: not new", arguments: everything)
    func notNewWhenArrivedBefore(kind: Source.Kind, thing: Thing, age: Double) throws {
        let world = try World()
        world.comes(kind, thing, written: age, arrived: Date().addingTimeInterval(-7200))
        world.matter.sawNew(at: Date().addingTimeInterval(-3600))
        #expect(world.onCard == 0 && !world.says)
    }

    @Test("1 The chat's footer names no source alone, on the Mac and the iPhone")
    nonisolated func footerNamesNoSourceAlone() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for path in ["Sources/Causabee/Conversation.swift", "Sources/CausabeePhone/AssistantSheet.swift"] {
            let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            let footer = try #require(text.components(separatedBy: "\n").first { $0.contains("Always pseudonymised sent to") })
            #expect(!footer.lowercased().contains("mail"), "\(path)'s footer names mail alone")
        }
    }

    // MARK: Principle 3 — one signal

    @Test("3 The dot and NEW are one signal: on together, off together", arguments: everything)
    func oneSignal(kind: Source.Kind, thing: Thing, age: Double) throws {
        let world = try World()
        world.matter.sawNew(at: Date().addingTimeInterval(-3600))
        world.comes(kind, thing, written: age)
        #expect(world.summary.isNew == world.says && world.says)
        world.matter.openedNew()
        #expect(world.summary.isNew == world.says && !world.says)
    }

    // MARK: Principle 4 — looked at is not handled

    @Test("4 Opened: no dot, still on the card until handled", arguments: everything)
    func lookedIsNotHandled(kind: Source.Kind, thing: Thing, age: Double) throws {
        let world = try World()
        world.matter.sawNew(at: Date().addingTimeInterval(-3600))
        world.comes(kind, thing, written: age)
        #expect(world.matter.openedNew())
        #expect(!world.says && world.onCard == 1)
        #expect(!world.matter.openedNew(), "Opened twice, it said new twice")
    }

    @Test("4 Handled — kept, put away, done, Seen — it leaves the card", arguments: kinds, Thing.allCases)
    func handledLeaves(kind: Source.Kind, thing: Thing) throws {
        for way in ["keep", "away", "done", "seen"] {
            let world = try World()
            world.matter.sawNew(at: Date().addingTimeInterval(-3600))
            world.comes(kind, thing, written: 2)
            world.matter.openedNew()
            let item = try #require(world.matter.newItems().first)
            switch way {
            case "keep": world.matter.keepNew(item)
            case "away":
                switch item {
                case .task(let todo), .fact(let todo): todo.isHidden = true
                case .appointment(let date): date.isHidden = true
                case .deadline(let date): date.isHidden = true
                }
            case "done":
                guard case .task(let todo) = item else { continue }
                todo.isDone = true
            default: world.matter.sawNew()
            }
            #expect(world.onCard == 0, "\(kind) \(thing): \(way) left it on the card")
        }
    }

    @Test("3 Something new after opening brings the dot back", arguments: kinds, Thing.allCases)
    func newAgainAfterOpening(kind: Source.Kind, thing: Thing) throws {
        let world = try World()
        world.matter.sawNew(at: Date().addingTimeInterval(-7200))
        world.comes(kind, thing, written: 1, arrived: Date().addingTimeInterval(-3600))
        world.matter.openedNew(at: Date().addingTimeInterval(-1800))
        #expect(!world.says)
        world.comes(kind, thing, written: 0)
        #expect(world.says && world.matter.unopenedNew().count == 1 && world.onCard == 2)
    }

    // MARK: Principle 5 and the chat — the owner's own word is never new

    @Test("Your own word — a task, a fact, a date you added — is never shown back as new", arguments: Thing.allCases)
    func ownWordNotNew(thing: Thing) throws {
        let world = try World()
        world.matter.sawNew(at: Date().addingTimeInterval(-3600))
        world.comes(.conversation, thing, written: 0)
        #expect(world.onCard == 0 && !world.says)
    }

    // MARK: Principle 8 — good to know is stable

    @Test("8 A fact said again in other words is not new", arguments: kinds, ages)
    func rewordedFact(kind: Source.Kind, age: Double) throws {
        let world = try World()
        let source = world.comes(kind, .fact, written: age, arrived: Date().addingTimeInterval(-86_400), text: "The key is with the neighbour.")
        world.matter.sawNew(at: Date().addingTimeInterval(-3600))
        for words in ["The neighbour has the key.", "Key: with the neighbour next door.", "Spare key — neighbour."] {
            world.matter.putFacts([GoodToKnowFact(text: words, sources: [source])], in: world.context)
            #expect(world.onCard == 0 && !world.says, "\"\(words)\" came back as new")
        }
    }

    @Test("8 A fact resting only on the owner's word is never new")
    func factOnOwnWord() throws {
        let world = try World()
        world.matter.sawNew(at: Date().addingTimeInterval(-3600))
        world.matter.putFacts([GoodToKnowFact(text: "Mum prefers mornings.", sources: [])], in: world.context)
        world.matter.putFacts([GoodToKnowFact(text: "Mornings suit Mum best.", sources: [])], in: world.context)
        #expect(world.onCard == 0 && !world.says)
    }

    // MARK: What is not new at all

    @Test("A closed matter says nothing new", arguments: kinds, Thing.allCases)
    func closedSaysNothing(kind: Source.Kind, thing: Thing) throws {
        let world = try World()
        world.comes(kind, thing, written: 0)
        world.matter.closedAt = Date()
        #expect(world.onCard == 0 && !world.says)
    }

    @Test("A date already past is not new", arguments: kinds)
    func pastDateNotNew(kind: Source.Kind) throws {
        let world = try World()
        world.matter.sawNew(at: Date().addingTimeInterval(-3600))
        let source = Source(kind: kind, pointer: "x", messageID: "<past@x>", date: Date())
        let item = Deadline(what: "Gone", day: MatterStatus.day(Date().addingTimeInterval(-86_400)), source: source)
        world.context.insert(item); item.matter = world.matter
        #expect(world.onCard == 0)
    }

    // MARK: The brief's news — every source, and not after looking

    @Test("What came in since the brief, of every kind, by when it arrived", arguments: kinds, ages)
    func cameSinceBrief(kind: Source.Kind, age: Double) throws {
        let world = try World()
        var brief = Brief(); brief.writtenAt = Date().addingTimeInterval(-3600)
        world.matter.shownBrief = brief
        world.comes(kind, .task, written: age)
        #expect(world.matter.cameSinceBrief.count == 1, "\(kind) written \(age) days ago is not in the news")
    }

    @Test("News about what the owner already looked at is not new", arguments: kinds)
    func newsAfterLooking(kind: Source.Kind) throws {
        let world = try World()
        var brief = Brief(); brief.writtenAt = Date().addingTimeInterval(-7200)
        world.matter.shownBrief = brief
        world.comes(kind, .task, written: 1, arrived: Date().addingTimeInterval(-3600))
        world.matter.openedNew(at: Date().addingTimeInterval(-1800))
        #expect(world.matter.lookedAtAll(world.matter.cameSinceBrief, []))
        world.comes(kind, .task, written: 0)
        #expect(!world.matter.lookedAtAll(world.matter.cameSinceBrief, []))
    }

    // MARK: Days replayed — what says NEW each morning, and only that

    @Test("A week replayed: each morning shows only what came since the day before", arguments: kinds)
    func weekReplayed(kind: Source.Kind) throws {
        let world = try World()
        let start = Date().addingTimeInterval(-7 * 86_400)
        world.matter.sawNew(at: start)
        for day in 0..<7 {
            let morning = start.addingTimeInterval(Double(day) * 86_400 + 8 * 3600)
            // Two things come in during the day before, of every kind of thing.
            for (n, thing) in Thing.allCases.enumerated() where (day + n) % 2 == 0 {
                world.comes(kind, thing, written: Double(n * 5), arrived: morning.addingTimeInterval(-3600 * Double(n + 1)))
            }
            let expected = world.matter.dated().filter { $0.came > (world.matter.shownBrief?.newLookedAt ?? start) }.count
            #expect(world.matter.unopenedNew().count == expected)
            world.matter.openedNew(at: morning)
            #expect(world.matter.unopenedNew().isEmpty, "Day \(day): something stayed new after opening")
            world.matter.sawNew(at: morning.addingTimeInterval(60))
            #expect(world.onCard == 0, "Day \(day): Seen left something on the card")
        }
    }
}
