import Foundation
import SwiftData
import Testing
@testable import MatterCore

/// "Friday at 14:30" offered in one mail, settled in the next: the time reaches the appointment,
/// the chat finds it, and the card says when and how long.
@Suite("A time offered, then settled")
@MainActor
struct OfferedTimeTests {
    let reply = """
    Hallo Herr Chille,

    prima, dann sehen wir uns am Freitag. Bringen Sie bitte Ihren Führerschein mit, die Probefahrt dauert etwa eine Stunde.

    Viele Grüße
    Jens Koch

    Am 9. Nov. 2026 um 10:12 schrieb Ralf Chille:
    > Freitag passt mir gut.
    >
    > Am 8. Nov. 2026 schrieb Jens Koch:
    >> Wir können Ihnen für die Probefahrt mit dem EX40 Freitag um 14:30 oder Samstag um 10:00 anbieten.
    """

    @Test("The reply is read with the start of what it answers, where the time was offered")
    func readerSeesTheOffer() {
        let split = Quotes.newest(of: reply, subject: "AW: VOLVO EX40")
        #expect(split.omitted > 0 && !split.newest.contains("14:30"))
        #expect(split.quoted.contains("Freitag um 14:30"))
        let disguise = Disguise(mode: .placeholder, subject: "AW: VOLVO EX40", from: "x", to: [], cc: [], body: reply, attachmentNames: [], replacements: 0)
        let text = Extractor.text(of: disguise, body: split.newest, omitted: split.omitted, answered: split.quoted)
        #expect(text.contains("The start of what it answers"))
        #expect(text.contains("Freitag um 14:30"))
    }

    @Test("Nothing left out: nothing added")
    func nothingQuoted() {
        let disguise = Disguise(mode: .placeholder, subject: "s", from: "x", to: [], cc: [], body: "Hallo,\nbis Freitag.\nGruß", attachmentNames: [], replacements: 0)
        #expect(!Extractor.text(of: disguise).contains("what it answers"))
    }

    @Test("The reader is told a settled offer keeps its time")
    func rule() {
        #expect(ExtractionPrompt.system.contains("Its time is never left null when the offer gave one"))
    }

    @Test("The chat gets the mail's own words, not only its summary")
    func chatSeesTheWords() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "car", name: "Volvo or VW")
        context.insert(matter)
        let source = Source(kind: .mail, pointer: "imap://x", messageID: "offer@example", date: Date())
        let entry = Entry(title: "AW: VOLVO EX40", from: "Jens Koch <jk@autohaus.example>", date: Date(), source: source)
        entry.digest = "Das Autohaus bietet eine Probefahrt an."
        entry.matter = matter
        context.insert(entry)
        try context.save()
        let body = "Hallo Herr Chille,\n\nwir können Ihnen Freitag um 14:30 oder Samstag um 10:00 anbieten.\n\nViele Grüße\nJens Koch"
        let facts = FactSheet.facts(for: [matter], today: MatterStatus.day(Date()), keptText: { _ in body })
        #expect(facts.text.contains("its words: \"Hallo Herr Chille, / wir können Ihnen Freitag um 14:30"), "\(facts.text)")
        #expect(AssistantPrompt.system.contains("Look in those words before you say something is not there"))
    }

    @Test("The card says when and how long", arguments: [
        ("14:30", nil as String?, nil as String?, "14:30"),
        ("14:30", "16:00", nil, "14:30–16:00 · 1 h 30 min"),
        ("09:00", "09:45", nil, "09:00–09:45 · 45 min"),
        (nil, nil, nil, "No time yet"),
    ])
    func hours(time: String?, end: String?, endDay: String?, line: String) {
        #expect(Calendars.hoursLine(what: "Probefahrt", day: "2026-11-13", time: time, endDay: endDay, endTime: end) == line)
    }

    @Test("A length in its words is a length known")
    func lengthInWords() {
        #expect(Calendars.hoursLine(what: "Probefahrt, 14:30–15:30", day: "2026-11-13", time: "14:30") == "14:30–15:30 · 1 h")
    }

    @Test("Over several days without a time: its days say it")
    func severalDays() {
        #expect(Calendars.hoursLine(what: "Urlaub", day: "2026-11-13", time: nil, endDay: "2026-11-15") == nil)
    }
}
