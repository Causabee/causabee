import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("The record browsed: kind, show and sort, and everyone a mail names")
@MainActor
struct RecordBrowseTests {
    private func matter() throws -> (ModelContext, Matter, [Entry], Document) {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "mama")
        context.insert(matter)
        for name in ["Helga Voss", "Nina Voss", "Healthbridge Care Fund"] {
            let party = Party(name: name)
            context.insert(party)
            let membership = Membership()
            membership.party = party
            membership.matter = matter
            context.insert(membership)
        }
        var entries: [Entry] = []
        for (index, (title, from, digest)) in [("Visit on 6 October", "Healthbridge Care Fund <care@healthbridge.example>", "The assessment visit for Helga Voss is on 6 October."),
                                               ("Who does what", "Nina Voss <nina@example.com>", "Nina takes Wednesdays."),
                                               ("Newsletter", "news@example.com", "Nothing for anyone.")].enumerated() {
            let source = Source(kind: .mail, pointer: "imap://x;UID=\(index)", messageID: "<\(index)@x>", date: Date(timeIntervalSince1970: Double(index) * 86_400 * 40))
            let entry = Entry(title: title, from: from, date: source.date, source: source)
            entry.digest = digest
            entry.replyTo = ""
            entry.matter = matter
            context.insert(entry)
            entries.append(entry)
        }
        let file = Document(name: "Form.pdf", contentType: "application/pdf", byteCount: 9000, source: entries[0].source)
        file.matter = matter
        context.insert(file)
        let visit = Appointment(what: "Assessment", day: "2026-10-06", time: nil, place: nil, source: entries[0].source)
        visit.matter = matter
        context.insert(visit)
        try context.save()
        return (context, matter, entries, file)
    }

    @Test("Show cuts to what brought tasks or dates, to information only, or to the mails with kept files; a mail's files stand under it")
    func show() throws {
        let (_, matter, entries, file) = try matter()
        let threads = MailThreads.build(entries)
        let made = RecordLinks(matter)
        let all = RecordBrowse.pick(threads: threads, documents: [file], links: [], kind: .everything, show: .all, made: made)
        #expect(all.items.count == 3)
        #expect(all.attached.values.flatMap { $0 }.count == 1)
        #expect(RecordBrowse.pick(threads: threads, documents: [file], links: [], kind: .everything, show: .withFacts, made: made).items.count == 1)
        #expect(RecordBrowse.pick(threads: threads, documents: [file], links: [], kind: .everything, show: .info, made: made).items.count == 2)
        let kept = RecordBrowse.pick(threads: threads, documents: [file], links: [], kind: .everything, show: .kept, made: made)
        #expect(kept.items.map(\.id) == ["thread-<0@x>"])
        let files = RecordBrowse.pick(threads: threads, documents: [file], links: [], kind: .files, show: .all, made: made)
        #expect(files.items.count == 1 && files.attached.isEmpty)
    }

    @Test("By person, a mail stands under everyone it names, marked as also under the others; oldest and newest go by month")
    func byPerson() throws {
        let (_, matter, entries, _) = try matter()
        let threads = MailThreads.build(entries)
        let picked = RecordBrowse.pick(threads: threads, documents: [], links: [], kind: .mail, show: .all, made: RecordLinks(matter))
        let groups = RecordBrowse.groups(picked.items, sort: .byPerson) { item in
            guard case .thread(let thread) = item else { return [] }
            return thread.rows.flatMap { RecordBrowse.people(in: $0.entry, of: matter, text: { _ in nil }) }.map(\.name)
        }
        #expect(groups.map(\.title).contains("Helga Voss"))
        #expect(groups.map(\.title).contains("Healthbridge Care Fund"))
        #expect(groups.last?.title == "Nobody named")
        let helga = try #require(groups.first { $0.title == "Helga Voss" })
        #expect(helga.also["thread-<0@x>"] == ["Healthbridge Care Fund"])
        #expect(RecordBrowse.groups(picked.items, sort: .oldest).first?.items.first?.id == "thread-<0@x>")
        #expect(RecordBrowse.groups(picked.items, sort: .newest).first?.items.first?.id == "thread-<2@x>")
    }

    @Test("A name is found as a whole word, in any case and accent, never inside another word or when too short")
    func names() {
        #expect(RecordBrowse.names("Visit for helga voss tomorrow", "Helga Voss"))
        #expect(RecordBrowse.names("Bitte an sebastian süss", "Sebastian Süss"))
        #expect(RecordBrowse.names("Grüße an Rene", "René"))
        #expect(!RecordBrowse.names("Helgasstraße 4", "Helga"))
        #expect(!RecordBrowse.names("Max and Tom", "Tom"))
    }
}
