import Foundation
import SwiftData
import Testing
@testable import MatterCore

/// The owner's rule of 11 November: a brief, once written, is true on every device. It is written
/// again only when the owner changes something or something new comes in — never because another
/// device opens and finds a record it had not seen (14 briefs written again at the Mac's start).
@Suite("A brief holds on every device")
@MainActor
struct BriefHoldsTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func source() -> Source { Source(kind: .mail, pointer: "imap://x/;UID=1") }

    /// A matter with one task, and a brief written for it — as the device that wrote it leaves it.
    private func written(in context: ModelContext) throws -> Matter {
        let matter = try Matter.make(named: "Lisbon", in: context)
        let todo = Todo(text: "Choose the Sintra day", owner: .me, due: "2026-11-16", source: source(), origin: "T1")
        todo.matter = matter
        context.insert(todo)
        matter.shownBrief = Brief().rewritten(lines: [Brief.Line(part: .about, text: "A week in Lisbon.")], proposals: [], at: now.addingTimeInterval(-3600))
        matter.sealBrief()
        try context.save()
        return matter
    }

    @Test("Written on another device an hour ago, for the record as it stands: not written again")
    func writtenElsewhereLongAgo() throws {
        let container = try MatterSchema.container(at: nil)
        let context = container.mainContext
        let matter = try written(in: context)
        #expect(AutoPace.holds(brief: matter.shownBrief, stamp: matter.recordStamp, writtenElsewhere: now.addingTimeInterval(-3600), now: now))
        // This device never saw it written — a store come whole from iCloud: it holds all the same.
        #expect(AutoPace.holds(brief: matter.shownBrief, stamp: matter.recordStamp, writtenElsewhere: nil, now: now))
    }

    @Test("Something new came in, or the owner changed something: it no longer holds, however fresh it is")
    func changedSince() throws {
        let container = try MatterSchema.container(at: nil)
        let context = container.mainContext
        let matter = try written(in: context)
        let todo = Todo(text: "Book the Sintra train", owner: .me, due: nil, source: source(), origin: "T2")
        todo.matter = matter
        context.insert(todo)
        try context.save()
        #expect(!AutoPace.holds(brief: matter.shownBrief, stamp: matter.recordStamp, writtenElsewhere: now.addingTimeInterval(-60), now: now))
        (matter.todos ?? []).first { $0.origin == "T2" }?.isHidden = true
        #expect(AutoPace.holds(brief: matter.shownBrief, stamp: matter.recordStamp, writtenElsewhere: nil, now: now))
        (matter.todos ?? []).first { $0.origin == "T1" }?.isDone = true
        #expect(!AutoPace.holds(brief: matter.shownBrief, stamp: matter.recordStamp, writtenElsewhere: nil, now: now))
    }

    @Test("What the owner says of the matter is a change; looking at it is none")
    func saidAndSeen() throws {
        let container = try MatterSchema.container(at: nil)
        let context = container.mainContext
        let matter = try written(in: context)
        var brief = try #require(matter.shownBrief)
        brief.newSeenAt = now
        brief.newLookedAt = now
        matter.shownBrief = brief
        #expect(AutoPace.holds(brief: matter.shownBrief, stamp: matter.recordStamp, writtenElsewhere: nil, now: now))
        matter.say("We fly on the 14th, not the 15th.")
        #expect(!AutoPace.holds(brief: matter.shownBrief, stamp: matter.recordStamp, writtenElsewhere: nil, now: now))
    }

    @Test("What it was written for is kept in the brief's JSON, which every device shares")
    func keptInTheBrief() throws {
        let container = try MatterSchema.container(at: nil)
        let context = container.mainContext
        let matter = try written(in: context)
        let json = try #require(matter.brief)
        let read = try JSONDecoder().decode(Brief.self, from: Data(json.utf8))
        #expect(read.writtenFor == matter.recordStamp)
        // Written anew, it is for no record until it is sealed again.
        #expect(read.rewritten(lines: [], proposals: [], at: now).writtenFor == nil)
    }

    @Test("A brief from a build before says nothing of its record: taken only when just written elsewhere, as before")
    func fromABuildBefore() throws {
        let old = try JSONDecoder().decode(Brief.self, from: Data(#"{"lines":[{"part":"about","text":"A week in Lisbon."}]}"#.utf8))
        #expect(old.writtenFor == nil)
        #expect(AutoPace.holds(brief: old, stamp: "aa", writtenElsewhere: now.addingTimeInterval(-60), now: now))
        #expect(!AutoPace.holds(brief: old, stamp: "aa", writtenElsewhere: now.addingTimeInterval(-3600), now: now))
        #expect(!AutoPace.holds(brief: old, stamp: "aa", writtenElsewhere: nil, now: now))
        #expect(!AutoPace.holds(brief: nil, stamp: "aa", writtenElsewhere: nil, now: now))
    }
}
