import Foundation
import SwiftData
import Testing
@testable import MatterCore

/// Every way a date is set and every way it could be changed afterwards — under the manifesto
/// (5, 6, 14, 17, and the chat: what you tell her to change changes as you said it, and stays) and
/// the owner's rule of 9 November: "When I say in the chat I want to change it, it has to change.
/// There is nobody in the game that can override this."
@Suite("Dates and times: the whole matrix")
@MainActor
struct DateMatrixTests {
    // MARK: Reading the owner's words

    @Test("Times as people write them", arguments: [
        ("Die Probefahrt am 13. November wird auf 14:30 bis 17:30 Uhr gesetzt.", "14:30", "17:30" as String?),
        ("Probefahrt auf 14 bis 17 Uhr", "14:00", "17:00"),
        ("von 14 bis 17 Uhr bitte", "14:00", "17:00"),
        ("14–17 Uhr", "14:00", "17:00"),
        ("change it to 2 p.m. to 5 p.m.", "14:00", "17:00"),
        ("2-5 pm", "14:00", "17:00"),
        ("2:30 pm until 5:30 pm", "14:30", "17:30"),
        ("um 14.30 Uhr", "14:30", nil),
        ("um 9 Uhr", "09:00", nil),
        ("at 9:15", "09:15", nil),
        ("12 am", "00:00", nil),
        ("12 pm", "12:00", nil),
        ("Probefahrt am 13.11. um 14:30", "14:30", nil),
        ("vom 13.11. bis 15.11., ab 10 Uhr", "10:00", nil),
        ("14.30 bis 17.30 Uhr", "14:30", "17:30"),
        ("14h30", "14:30", nil),
        ("Freitag 13.11 - 14 Uhr", "14:00", nil),
        ("11-1 pm", "11:00", "13:00"),
        ("von 14:30 auf 16:00", "16:00", nil),
        ("verschieb sie auf 16 Uhr", "16:00", nil),
        ("9 am to 5 pm", "09:00", "17:00"),
        ("zwischen 14 und 17 Uhr", "14:00", "17:00"),
        ("Meeting at 10 am tomorrow", "10:00", nil),
        ("10 am Friday", "10:00", nil),
        ("nicht um 14 Uhr, sondern um 16 Uhr", "16:00", nil),
        ("statt 14 lieber 16 Uhr", "16:00", nil),
        ("16:00 instead of 14:00", "16:00", nil),
        ("um 14 Uhr 30", "14:30", nil),
        ("um 14.30", "14:30", nil),
        ("von 9.30 bis 10 Uhr", "09:30", "10:00"),
        ("14h30 à 17h30", "14:30", "17:30"),
        ("de 14h à 17h", "14:00", "17:00"),
        ("à 14h", "14:00", nil),
    ])
    func words(_ text: String, start: String, end: String?) {
        let span = TimeWords.span(in: text)
        #expect(span?.start == start, "\(text): start \(span?.start ?? "nil")")
        #expect(span?.end == end, "\(text): end \(span?.end ?? "nil")")
    }

    @Test("No time in it: none made up", arguments: ["Verschieb sie auf den 14.11.", "move it to Friday", "13.11. bis 15.11.", "Zimmer 14", "", "2026-11-13",
                                                     "mach sie 2 h lang", "um 1 h verschieben", "Zimmer 14 am Freitag", "von 2 bis 5 am Freitag", "13.11 - 15.11",
                                                     "vom 13.11 bis 15.11, am Abend", "13.11 - 15.11 Uhr"])
    func noTime(_ text: String) {
        #expect(TimeWords.span(in: text) == nil, "\(text) gave a time")
    }

    // MARK: Setting

    func world() throws -> (ModelContext, Matter, Appointment) {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "car", name: "Volvo or VW")
        context.insert(matter)
        let source = Source(kind: .mail, pointer: "imap://x", messageID: "first@dealer", date: Date())
        let appointment = Appointment(what: "Probefahrt mit dem VOLVO EX40", day: "2026-11-13", time: nil, place: nil, source: source)
        context.insert(appointment)
        appointment.matter = matter
        try context.save()
        return (context, matter, appointment)
    }

    @Test("Start and end said: both set, theirs, and it holds")
    func setBoth() throws {
        let (_, _, a) = try world()
        a.set(day: "2026-11-13", time: "14:30", endTime: "17:30")
        #expect(a.time == "14:30" && a.endTime == "17:30")
        #expect(a.sources.first?.kind == .conversation)
        #expect(a.holds(day: "2026-11-13", time: "14:30", endTime: "17:30"))
        #expect(Calendars.hoursLine(what: a.what, day: a.day, time: a.time, endTime: a.endTime) == "14:30–17:30 · 3 h")
    }

    @Test("A new start alone keeps the length, as Calendar does")
    func newStartKeepsLength() throws {
        let (_, _, a) = try world()
        a.set(day: "2026-11-13", time: "14:00", endTime: "17:00")
        a.set(day: "2026-11-13", time: "14:30", endTime: nil)
        #expect(a.time == "14:30" && a.endTime == "17:30")
    }

    @Test("Only the end said: the start stays")
    func onlyEnd() throws {
        let (_, _, a) = try world()
        a.set(day: "2026-11-13", time: "14:00", endTime: "17:00")
        a.set(day: "2026-11-13", time: nil, endTime: "18:00")
        #expect(a.time == "14:00" && a.endTime == "18:00")
    }

    @Test("Only the day said: the hours go with it")
    func onlyDay() throws {
        let (_, _, a) = try world()
        a.set(day: "2026-11-13", time: "14:30", endTime: "17:30")
        a.set(day: "2026-11-14", time: nil, endTime: nil)
        #expect(a.day == "2026-11-14" && a.time == "14:30" && a.endTime == "17:30")
    }

    @Test("Words that are no time are not stored as one")
    func noTimeStored() throws {
        let (_, _, a) = try world()
        a.set(day: "2026-11-13", time: "14:30 Uhr", endTime: "später")
        #expect(a.time == nil && a.endTime == nil)
    }

    @Test("A chat card that left the time out takes it from the owner's words")
    func cardFromWords() throws {
        let json: [String: Any] = ["kind": "change_date", "text": "", "owner": "me", "todo": "A1", "due": "2026-11-13", "reason": "", "cites": []]
        let card = try JSONDecoder().decode(AssistantPrompt.Reply.Card.self, from: JSONSerialization.data(withJSONObject: json))
        for (words, start, end) in [("auf 14 bis 17 Uhr", "14:00", "17:00"), ("to 2 p.m. to 5 p.m.", "14:00", "17:00"), ("14:30–17:30", "14:30", "17:30")] {
            let filled = AssistantAsk.withTimes(card, from: words)
            #expect(filled.time == start && filled.endTime == end, "\(words)")
        }
        // Unreadable times from the answer are replaced by the owner's.
        var odd = card
        odd.time = "14.30h"
        #expect(AssistantAsk.withTimes(odd, from: "14:30 bis 17:30").time == "14:30")
    }

    // MARK: What comes in afterwards — every kind, never over the owner's word

    func comesIn(_ context: ModelContext, kind: String = "imap://x/INBOX;UIDVALIDITY=1/;UID=9", id: String, date: String, time: String?, end: String? = nil, replaces: String?) throws {
        var item: [String: Any] = ["what": "Probefahrt mit dem VOLVO EX40", "date": date, "time": time as Any? ?? NSNull(), "place": NSNull(), "source_quote": "…"]
        if let end { item["end_time"] = end }
        if let replaces { item["replaces"] = replaces }
        let json: [String: Any] = [
            "email_id": id, "source": kind, "date": "2026-11-09T18:00:00Z", "subject": "AW: VOLVO EX40", "from": "Hannes <h@dealer.example>",
            "is_bulk": false, "matter": "car", "matter_confidence": 0.9, "matter_reason": "", "decided_by": "claude",
            "parties": [], "todos": [], "deadlines": [], "appointments": [item], "done": [],
        ]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let judgement = try decoder.decode(Judgement.self, from: JSONSerialization.data(withJSONObject: json))
        // It reaches the bee now.
        let record = SortedMail(messageID: id, device: "test")
        record.sortedAt = Date()
        context.insert(record)
        try MatterImport.apply([judgement], to: context)
    }

    @Test("Set by the owner, then whatever comes in: it stays", arguments: [
        ("2026-11-13", nil as String?, "2026-11-13 14:30" as String?),   // "dann bis Freitag"
        ("2026-11-13", "10:00", "2026-11-13 14:30"),                       // another hour
        ("2026-11-14", "14:30", "2026-11-13 14:30"),                       // another day
        ("2026-11-13", nil, nil),                                          // the same visit, said again
        ("2026-11-13", "14:30", nil),
    ])
    func ownersStays(date: String, time: String?, replaces: String?) throws {
        let (context, matter, a) = try world()
        a.set(day: "2026-11-13", time: "14:30", endTime: "17:30")
        try comesIn(context, id: "reply-\(UUID())", date: date, time: time, replaces: replaces)
        #expect(a.day == "2026-11-13" && a.time == "14:30" && a.endTime == "17:30", "moved by \(date) \(time ?? "-")")
        #expect(a.holds(day: "2026-11-13", time: "14:30", endTime: "17:30"))
        // What came in is not lost: kept among its sources, or, for another hour without `replaces`, its own date.
        #expect((matter.appointments ?? []).count <= 2)
    }

    @Test("From a screenshot or a file just the same — not only mail", arguments: ["shot://Screenshot 1.png", "file:///Users/x/Termin.pdf"])
    func otherSources(pointer: String) throws {
        let (context, _, a) = try world()
        a.set(day: "2026-11-13", time: "14:30", endTime: "17:30")
        try comesIn(context, kind: pointer, id: "other-\(UUID())", date: "2026-11-13", time: nil, replaces: "2026-11-13 14:30")
        #expect(a.time == "14:30" && a.endTime == "17:30")
    }

    @Test("Not the owner's: the same day without an hour keeps the hour; a new hour moves it, with its end")
    func notOwners() throws {
        let (context, _, a) = try world()
        a.time = "14:00"; a.endTime = "17:00"
        try comesIn(context, id: "r1", date: "2026-11-13", time: nil, replaces: "2026-11-13 14:00")
        #expect(a.time == "14:00" && a.endTime == "17:00")
        try comesIn(context, id: "r2", date: "2026-11-13", time: "15:00", end: "16:00", replaces: "2026-11-13 14:00")
        #expect(a.time == "15:00" && a.endTime == "16:00")
        try comesIn(context, id: "r3", date: "2026-11-20", time: nil, replaces: "2026-11-13 15:00")
        #expect(a.day == "2026-11-20" && a.time == nil && a.endTime == nil, "Another day, no hour: the old hour is not carried over")
    }

    @Test("The owner's own date is never shown back as new")
    func ownersNotNew() throws {
        let (context, matter, a) = try world()
        // It came two days ago, and was looked at since.
        let record = SortedMail(messageID: "first@dealer", device: "test")
        record.sortedAt = Date().addingTimeInterval(-2 * 86_400)
        context.insert(record)
        try context.save()
        matter.sawNew(at: Date().addingTimeInterval(-3600))
        #expect(!matter.newItems().contains { if case .appointment(let x) = $0 { x === a } else { false } })
        a.set(day: "2026-11-13", time: "14:30", endTime: "17:30")
        #expect(!matter.newItems().contains { if case .appointment(let x) = $0 { x === a } else { false } })
    }

    // MARK: Calendar — in step, and never over the owner's word

    func synced(_ a: Appointment, _ context: ModelContext, calendar: PretendCalendar, stamps: Mirror.Stamps) async -> Mirror.Result {
        await Mirror.reconcile(context, worker: calendar, calendars: Calendars(), reads: (true, true), stamps: stamps)
    }

    func event(_ day: String, _ from: String?, _ to: String?) -> CalendarWorker.Seen {
        guard let from, let to else {
            let start = MatterStatus.date(of: day)!
            return CalendarWorker.Seen(fields: ["Probefahrt mit dem VOLVO EX40", day, "", ""], start: start, end: start.addingTimeInterval(86_400), isAllDay: true)
        }
        return CalendarWorker.Seen(fields: ["Probefahrt mit dem VOLVO EX40", day, from, ""],
                                   start: Calendars.start(day: day, time: from), end: Calendars.start(day: day, time: to))
    }

    @Test("Linked, every state of the event, every pass: the owner's 14:30–17:30 stays and Calendar is never made worse", arguments: [
        ("all-day, then takes it", true),
        ("all-day, puts it back", false),
    ])
    func linked(_ name: String, accepts: Bool) async throws {
        let (context, _, a) = try world()
        let calendar = PretendCalendar(), stamps = Mirror.Stamps(defaults: nil)
        a.calendarID = "e"
        await calendar.put(event: "e", event("2026-11-13", nil, nil))
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        a.set(day: "2026-11-13", time: "14:30", endTime: "17:30")
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        await calendar.put(event: "e", accepts ? event("2026-11-13", "14:30", "17:30") : event("2026-11-13", nil, nil))
        for pass in 0..<4 {
            await calendar.forget()
            _ = await synced(a, context, calendar: calendar, stamps: stamps)
            #expect(a.time == "14:30" && a.endTime == "17:30", "\(name), pass \(pass): \(a.time ?? "nil")–\(a.endTime ?? "nil")")
            #expect(await calendar.written.isEmpty, "\(name), pass \(pass): wrote again")
        }
    }

    @Test("The owner moves it in Calendar: that is the owner's word too, and comes here — day, time and end")
    func ownerInCalendar() async throws {
        let (context, _, a) = try world()
        let calendar = PretendCalendar(), stamps = Mirror.Stamps(defaults: nil)
        a.calendarID = "e"
        a.set(day: "2026-11-13", time: "14:30", endTime: "17:30")
        await calendar.put(event: "e", event("2026-11-13", "14:30", "17:30"))
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        await calendar.put(event: "e", event("2026-11-14", "10:00", "11:30"))
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        #expect(a.day == "2026-11-14" && a.time == "10:00" && a.endTime == "11:30")
    }

    @Test("The event deleted in Calendar: nothing here changes")
    func eventGone() async throws {
        let (context, _, a) = try world()
        let calendar = PretendCalendar(), stamps = Mirror.Stamps(defaults: nil)
        a.calendarID = "gone"
        a.set(day: "2026-11-13", time: "14:30", endTime: "17:30")
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        #expect(a.time == "14:30" && a.endTime == "17:30" && a.day == "2026-11-13")
    }

    @Test("Linked to an event with the time, never set here: the time and the end come from it")
    func gapFromCalendar() async throws {
        let (context, _, a) = try world()
        let calendar = PretendCalendar(), stamps = Mirror.Stamps(defaults: nil)
        a.calendarID = "e"
        await calendar.put(event: "e", event("2026-11-13", "14:00", "17:00"))
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        #expect(a.time == "14:00" && a.endTime == "17:00")
        #expect(Calendars.hoursLine(what: a.what, day: a.day, time: a.time, endTime: a.endTime) == "14:00–17:00 · 3 h")
    }

    // MARK: The whole chain, as on 9 November

    @Test("Said in the chat, then a reply of the dealer's, then the sync, again and again: 14:30–17:30 throughout")
    func chain() async throws {
        let (context, _, a) = try world()
        let calendar = PretendCalendar(), stamps = Mirror.Stamps(defaults: nil)
        a.calendarID = "e"
        await calendar.put(event: "e", event("2026-11-13", nil, nil))
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        // The chat: the answer's card without a time, filled from the words.
        let json: [String: Any] = ["kind": "change_date", "text": "", "owner": "me", "todo": "A1", "due": "2026-11-13", "reason": "", "cites": []]
        let card = AssistantAsk.withTimes(try JSONDecoder().decode(AssistantPrompt.Reply.Card.self, from: JSONSerialization.data(withJSONObject: json)),
                                          from: "Die Probefahrt am 13. November wird auf 14:30 bis 17:30 Uhr gesetzt.")
        a.set(day: card.due!, time: card.time, endTime: card.endTime, endDay: card.endDay)
        for round in 0..<3 {
            try comesIn(context, id: "reply-\(round)", date: "2026-11-13", time: nil, replaces: "2026-11-13")
            _ = await synced(a, context, calendar: calendar, stamps: stamps)
            if round == 0 { await calendar.put(event: "e", event("2026-11-13", "14:30", "17:30")) }
            #expect(a.holds(day: card.due, time: card.time, endTime: card.endTime), "round \(round): \(a.time ?? "nil")–\(a.endTime ?? "nil")")
            #expect(Calendars.hoursLine(what: a.what, day: a.day, time: a.time, endTime: a.endTime) == "14:30–17:30 · 3 h")
        }
    }

    // MARK: Showing

    @Test("When and how long, as the card says it", arguments: [
        ("14:30" as String?, "17:30" as String?, nil as String?, "14:30–17:30 · 3 h" as String?),
        ("09:00", "09:45", nil, "09:00–09:45 · 45 min"),
        ("22:00", "01:00", nil, "22:00–01:00 · 3 h"),
        ("14:30", nil, nil, "14:30"),
        (nil, nil, nil, "No time yet"),
        (nil, nil, "2026-11-15", nil),
        ("10:00", nil, "2026-11-15", "10:00"),
    ])
    func shown(time: String?, end: String?, endDay: String?, line: String?) {
        #expect(Calendars.hoursLine(what: "Probefahrt", day: "2026-11-13", time: time, endDay: endDay, endTime: end) == line)
    }

    @Test("On the day the clocks go back, an hour is an hour")
    func clocksChange() {
        #expect(Calendars.hoursLine(what: "Termin", day: "2026-10-25", time: "01:30", endTime: "03:30")?.hasPrefix("01:30–03:30") == true)
    }

    // MARK: The reviewers' findings, each held to

    func linkedWorld(_ seen: CalendarWorker.Seen) async throws -> (ModelContext, Appointment, PretendCalendar, Mirror.Stamps) {
        let (context, _, a) = try world()
        let calendar = PretendCalendar(), stamps = Mirror.Stamps(defaults: nil)
        a.calendarID = "e"
        await calendar.put(event: "e", seen)
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        return (context, a, calendar, stamps)
    }

    @Test("A new length set here reaches Calendar; Calendar's old end does not come back over it")
    func lengthGoesThere() async throws {
        let (context, a, calendar, stamps) = try await linkedWorld(event("2026-11-13", "14:30", "17:30"))
        #expect(a.time == "14:30" && a.endTime == "17:30")
        a.set(day: "2026-11-13", time: nil, endTime: "18:00")
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        #expect(a.endTime == "18:00")
        let wrote = await calendar.written
        #expect(wrote.contains { if case .end = $0 { true } else { false } }, "The new end was not sent: \(wrote)")
        await calendar.forget()
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        #expect(a.endTime == "18:00")
    }

    @Test("The owner changes the length in Calendar: it comes here")
    func lengthFromThere() async throws {
        let (context, a, calendar, stamps) = try await linkedWorld(event("2026-11-13", "14:30", "17:30"))
        await calendar.put(event: "e", event("2026-11-13", "14:30", "16:00"))
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        #expect(a.time == "14:30" && a.endTime == "16:00")
    }

    @Test("Causabee's own hour is no length: 10:00 stays 10:00")
    func guessedHour() async throws {
        let start = Calendars.start(day: "2026-11-13", time: "10:00")!
        let made = CalendarWorker.Seen(fields: ["Probefahrt mit dem VOLVO EX40", "2026-11-13", "10:00", ""], start: start,
                                       end: start.addingTimeInterval(3_600), madeByCausabee: true)
        let (context, a, calendar, stamps) = try await linkedWorld(made)
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        #expect(a.time == "10:00" && a.endTime == nil)
        #expect(Calendars.hoursLine(what: a.what, day: a.day, time: a.time, endTime: a.endTime) == "10:00")
    }

    @Test("Put back by Calendar's server later — after it was in step once — the owner's word stays")
    func lateRevert() async throws {
        let (context, a, calendar, stamps) = try await linkedWorld(event("2026-11-13", nil, nil))
        a.set(day: "2026-11-13", time: "14:30", endTime: "17:30")
        _ = await synced(a, context, calendar: calendar, stamps: stamps)          // written
        await calendar.put(event: "e", event("2026-11-13", "14:30", "17:30"))
        _ = await synced(a, context, calendar: calendar, stamps: stamps)          // in step
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        await calendar.put(event: "e", event("2026-11-13", nil, nil))            // the server, minutes later
        for _ in 0..<3 { _ = await synced(a, context, calendar: calendar, stamps: stamps) }
        #expect(a.time == "14:30" && a.endTime == "17:30")
    }

    @Test("A write that failed is no revert: it is tried again, and the owner's word stays")
    func failedWrite() async throws {
        let (context, a, calendar, stamps) = try await linkedWorld(event("2026-11-13", nil, nil))
        await calendar.refuse(true)
        a.set(day: "2026-11-13", time: "14:30", endTime: "17:30")
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        await calendar.refuse(false)
        await calendar.forget()
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        #expect(a.time == "14:30" && a.endTime == "17:30")
        #expect(await calendar.written.contains(.event(id: "e", fields: ["Probefahrt mit dem VOLVO EX40", "2026-11-13", "14:30", ""])), "Not tried again")
    }

    @Test("An invitation of the dealer's: nothing written to it, what it knows fills a gap, the owner's word stays")
    func invitation() async throws {
        var invite = event("2026-11-13", "14:00", "17:00")
        invite.editable = false
        let (context, a, calendar, stamps) = try await linkedWorld(invite)
        #expect(a.time == "14:00" && a.endTime == "17:00")
        a.set(day: "2026-11-13", time: "14:30", endTime: "17:30")
        await calendar.forget()
        for _ in 0..<3 { _ = await synced(a, context, calendar: calendar, stamps: stamps) }
        #expect(a.time == "14:30" && a.endTime == "17:30")
        #expect(await calendar.written.isEmpty)
    }

    @Test("The owner takes the time away on purpose: Calendar gets the whole day, and it is not filled again")
    func ownerClears() async throws {
        let (context, a, calendar, stamps) = try await linkedWorld(event("2026-11-13", "14:00", "17:00"))
        a.set(day: "2026-11-13", time: nil, endTime: nil)
        a.time = nil; a.endTime = nil
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        #expect(a.time == nil)
        #expect(await calendar.written.contains(.event(id: "e", fields: ["Probefahrt mit dem VOLVO EX40", "2026-11-13", "", ""])))
    }

    @Test("Undone, the date is given back: what comes in may move it again")
    func undoGivesBack() throws {
        let (_, _, a) = try world()
        let owned = a.isOwners
        a.set(day: "2026-11-13", time: "14:30", endTime: "17:30")
        #expect(a.isOwners)
        if !owned { a.unclaim() }
        #expect(!a.isOwners)
    }

    @Test("A stay moved: its last day moves with it")
    func stayMoves() throws {
        let (_, _, a) = try world()
        a.set(day: "2026-11-13", time: nil, endTime: nil, endDay: "2026-11-15")
        a.set(day: "2026-11-20", time: nil, endTime: nil)
        #expect(a.day == "2026-11-20" && a.endDay == "2026-11-22")
    }

    @Test("Durations as the owner sets them", arguments: [(0, "Not set"), (45, "45 min"), (60, "1 h"), (90, "1 h 30 min"), (180, "3 h")])
    func durations(minutes: Int, label: String) {
        #expect(Durations.label(minutes) == label)
        if minutes > 0 {
            let end = Durations.end(from: "14:30", minutes: minutes)
            #expect(Durations.minutes(from: "14:30", to: end) == minutes)
        }
    }

    // MARK: What comes in finds the right date

    @Test("`replaces` as listed, with its words after it, finds the date by day and hour")
    func replacesAsListed() throws {
        let (context, matter, a) = try world()
        a.time = "14:30"
        try comesIn(context, id: "m1", date: "2026-11-20", time: "10:00", replaces: "2026-11-13 14:30 — Probefahrt mit dem VOLVO EX40")
        #expect(a.day == "2026-11-20" && a.time == "10:00")
        #expect((matter.appointments ?? []).count == 1, "A second one was made")
    }

    @Test("Two dates on one day: `replaces` with the day only moves the one its words match")
    func twoOnADay() throws {
        let (context, matter, a) = try world()
        a.time = "14:30"
        let other = Appointment(what: "Reifenwechsel", day: "2026-11-13", time: "09:00", place: nil,
                                source: Source(kind: .mail, pointer: "x", messageID: "tyres@garage", date: Date()))
        context.insert(other); other.matter = matter
        try comesIn(context, id: "m2", date: "2026-11-14", time: "15:00", replaces: "2026-11-13")
        #expect(a.day == "2026-11-14" && other.day == "2026-11-13")
    }

    @Test("The other side moves the owner's date: it comes as a date of its own, NEW, the owner's stays")
    func proposalNotLost() throws {
        let (context, matter, a) = try world()
        matter.sawNew(at: Date().addingTimeInterval(-60))
        a.set(day: "2026-11-13", time: "14:30", endTime: "17:30")
        try comesIn(context, id: "move", date: "2026-11-14", time: "10:00", replaces: "2026-11-13 14:30")
        #expect(a.day == "2026-11-13" && a.time == "14:30")
        let proposed = (matter.appointments ?? []).first { $0 !== a }
        #expect(proposed?.day == "2026-11-14" && proposed?.time == "10:00")
        #expect(matter.newItems().contains { if case .appointment(let x) = $0 { x === proposed } else { false } }, "Not shown as NEW")
        // Said again: no third one.
        try comesIn(context, id: "move-again", date: "2026-11-14", time: "10:00", replaces: "2026-11-13 14:30")
        #expect((matter.appointments ?? []).count == 2)
    }

    @Test("The owner's date without a time is not given one by what comes in")
    func ownersGapNotFilled() throws {
        let (context, _, a) = try world()
        a.set(day: "2026-11-13", time: nil, endTime: nil)
        try comesIn(context, id: "fill", date: "2026-11-13", time: "16:00", replaces: nil)
        #expect(a.time == nil)
    }

    @Test("Only an end said: only the end")
    func endOnly() throws {
        #expect(TimeWords.span(in: "bis 17 Uhr") == TimeWords.Span(start: nil, end: "17:00"))
        let json: [String: Any] = ["kind": "change_date", "text": "", "owner": "me", "todo": "A1", "due": "2026-11-13", "time": "17:00", "reason": "", "cites": []]
        let card = AssistantAsk.withTimes(try JSONDecoder().decode(AssistantPrompt.Reply.Card.self, from: JSONSerialization.data(withJSONObject: json)), from: "bis 17 Uhr")
        #expect(card.time == nil && card.endTime == "17:00")
        let (_, _, a) = try world()
        a.set(day: "2026-11-13", time: "14:00", endTime: "16:00")
        a.set(day: card.due!, time: card.time, endTime: card.endTime)
        #expect(a.time == "14:00" && a.endTime == "17:00")
    }

    @Test("An end before its start is no 23 hours")
    func endBeforeStart() {
        #expect(Calendars.hoursLine(what: "Termin", day: "2026-11-13", time: "14:00", endTime: "13:00") == "14:00")
        #expect(Calendars.hoursLine(what: "Termin", day: "2026-11-13", time: "22:00", endTime: "01:00") == "22:00–01:00 · 3 h")
    }

    // MARK: Pass 3 — the fixes' own traps

    @Test("Put back once by the server; a week later the owner moves it: the move goes to Calendar")
    func revertThenNewEdit() async throws {
        let (context, a, calendar, stamps) = try await linkedWorld(event("2026-11-13", "14:30", "17:30"))
        a.set(day: "2026-11-13", time: "16:00", endTime: nil)
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        await calendar.put(event: "e", event("2026-11-13", "14:30", "17:30"))   // the server
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        #expect(a.time == "16:00")
        a.set(day: "2026-11-20", time: "10:00", endTime: "11:00")
        await calendar.forget()
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        #expect(await calendar.written.contains(.event(id: "e", fields: ["Probefahrt mit dem VOLVO EX40", "2026-11-20", "10:00", ""])))
    }

    @Test("Put back by the server once; later the owner drags it in Calendar: that comes here")
    func revertThenOwnerInCalendar() async throws {
        let (context, a, calendar, stamps) = try await linkedWorld(event("2026-11-13", "14:30", "17:30"))
        a.set(day: "2026-11-13", time: "16:00", endTime: nil)
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        await calendar.put(event: "e", event("2026-11-13", "14:30", "17:30"))
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        await calendar.put(event: "e", event("2026-11-13", "15:00", "18:00"))
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        #expect(a.time == "15:00" && a.endTime == "18:00")
    }

    @Test("The last day of a stay changed here goes there and stays")
    func lastDayHere() async throws {
        let start = MatterStatus.date(of: "2026-11-13")!
        let stay = CalendarWorker.Seen(fields: ["Probefahrt mit dem VOLVO EX40", "2026-11-13", "", ""], start: start,
                                       end: start.addingTimeInterval(3 * 86_400), isAllDay: true)
        let (context, a, calendar, stamps) = try await linkedWorld(stay)
        #expect(a.endDay == "2026-11-15")
        a.set(day: "2026-11-13", time: nil, endTime: nil, endDay: "2026-11-17")
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        #expect(a.endDay == "2026-11-17")
        #expect(a.holds(day: "2026-11-13", time: nil, endTime: nil))
    }

    @Test("A timed stay: the end the owner sets in Calendar comes here")
    func timedStayEndThere() async throws {
        let start = Calendars.start(day: "2026-11-13", time: "10:00")!
        let stay = CalendarWorker.Seen(fields: ["Probefahrt mit dem VOLVO EX40", "2026-11-13", "10:00", ""], start: start,
                                       end: Calendars.start(day: "2026-11-14", time: "11:00"))
        let (context, a, calendar, stamps) = try await linkedWorld(stay)
        #expect(a.endDay == "2026-11-14" && a.endTime == "11:00")
        await calendar.put(event: "e", CalendarWorker.Seen(fields: stay.fields, start: start, end: Calendars.start(day: "2026-11-14", time: "15:00")))
        await calendar.forget()
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        #expect(a.endTime == "15:00")
        #expect(await calendar.written.isEmpty)
    }

    @Test("An invitation the organiser moves: it comes here — unless the owner set the date")
    func invitationMoved() async throws {
        var invite = event("2026-11-13", "14:00", "17:00"); invite.editable = false
        let (context, a, calendar, stamps) = try await linkedWorld(invite)
        var moved = event("2026-11-14", "10:00", "11:00"); moved.editable = false
        await calendar.put(event: "e", moved)
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        #expect(a.day == "2026-11-14" && a.time == "10:00" && a.endTime == "11:00")
        a.set(day: "2026-11-14", time: "10:30", endTime: nil)
        var again = event("2026-11-15", "09:00", "10:00"); again.editable = false
        await calendar.put(event: "e", again)
        _ = await synced(a, context, calendar: calendar, stamps: stamps)
        #expect(a.day == "2026-11-14" && a.time == "10:30")
        #expect(await calendar.written.isEmpty)
    }

    @Test("Moving the start keeps the length over midnight too")
    func overnight() throws {
        let (_, _, a) = try world()
        a.set(day: "2026-11-13", time: "22:00", endTime: "01:00")
        a.set(day: "2026-11-13", time: "21:00", endTime: nil)
        #expect(a.endTime == "00:00")
        a.set(day: "2026-11-13", time: "22:30", endTime: "23:30")
        a.set(day: "2026-11-13", time: "23:15", endTime: nil)
        #expect(a.endTime == "00:15")
    }

    @Test("A time written as \"9:00\" is kept as \"09:00\", and the receipt holds")
    func normalised() throws {
        let (_, _, a) = try world()
        a.set(day: "2026-11-13", time: "9:00", endTime: "10:30")
        #expect(a.time == "09:00")
        #expect(a.holds(day: "2026-11-13", time: "9:00", endTime: "10:30"))
    }

    @Test("\"bis 17 Uhr\" on a date with no time: no false \"changed back\"")
    func endOnNoTime() throws {
        let (_, _, a) = try world()
        a.set(day: "2026-11-13", time: nil, endTime: "17:00")
        #expect(a.holds(day: "2026-11-13", time: nil, endTime: "17:00"))
    }

    @Test("`replaces` with the day only and other words: no other date is moved")
    func dayOnlyOtherWords() throws {
        let (context, matter, a) = try world()
        a.time = "14:30"
        let other = Appointment(what: "Reifenwechsel", day: "2026-11-13", time: "09:00", place: nil,
                                source: Source(kind: .mail, pointer: "x", messageID: "tyres@garage", date: Date()))
        context.insert(other); other.matter = matter
        var item: [String: Any] = ["what": "Probefahrt EX40", "date": "2026-11-14", "time": "10:00", "place": NSNull(), "source_quote": "…"]
        item["replaces"] = "2026-11-13"
        let json: [String: Any] = ["email_id": "x1", "source": "imap://x", "date": "2026-11-09T18:00:00Z", "subject": "s", "from": "f",
                                   "is_bulk": false, "matter": "car", "matter_confidence": 0.9, "matter_reason": "", "decided_by": "claude",
                                   "parties": [], "todos": [], "deadlines": [], "appointments": [item], "done": []]
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        try MatterImport.apply([try decoder.decode(Judgement.self, from: JSONSerialization.data(withJSONObject: json))], to: context)
        #expect(other.day == "2026-11-13" && other.time == "09:00")
    }
}
