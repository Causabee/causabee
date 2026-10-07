#if canImport(AppKit)
import AppKit
#endif
import Foundation
import MatterCore
import SwiftData

/// Nine made-up matters for screenshots and demos: `--demo` fills an empty store with them: a school project, a trip, care for a parent, a flat purchase, a wedding, a move, a tax return, a car accident and a bathroom renovation.
/// Every person, company and address is invented (`.example` domains), and every date is counted
/// from today, so the matters always look current: some things done, one thing late, the rest ahead.
///
/// Start it apart from the real store: `Causabee --store ~/Desktop/causabee-demo/matters.store --demo`.
@MainActor
enum DemoData {
    /// "Try the demo", kept until "Leave the demo": every start in between opens the demo's own store.
    nonisolated static let chosenKey = "demo.chosen"

    /// `--fresh-setup` runs on the demo too: the setup's test never touches the owner's store.
    /// A copy of the app under an identifier ending in `.demo` — CausabeeDemo, beside the owner's
    /// own Causabee — is the demo however it is started.
    nonisolated static var isRequested: Bool {
        CommandLine.arguments.contains("--demo") || CommandLine.arguments.contains("--fresh-setup")
            || UserDefaults.standard.bool(forKey: chosenKey)
            || Bundle.main.bundleIdentifier?.hasSuffix(".demo") == true
    }

    /// Into the demo, or back to the owner's own matters. A store is opened once, when Causabee
    /// starts, so Causabee starts again: the new one opens, then this one quits.
    #if os(macOS)
    static func restart(demo: Bool) {
        UserDefaults.standard.set(demo, forKey: chosenKey)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }
    #endif

    /// Counts up whenever the demo's words or matters change: a demo store filled with an older
    /// version is emptied and filled again — with today's dates too. Two things are overdue in it, in
    /// the care matter and the trip: enough to show what overdue looks like, not a page of it. Only ever the demo's own store.
    static let contentVersion = 3
    private static let seededKey = "demo.filled"

    static func seed(_ context: ModelContext) {
        // Filled again on a new day too: its dates are counted from the day it was filled, and a demo
        // left for a week would open with everything overdue.
        let stamp = "\(contentVersion) \(MatterStatus.day(Date()))"
        if UserDefaults.standard.string(forKey: seededKey) != stamp {
            func empty<Model: PersistentModel>(_ model: Model.Type) { try? context.delete(model: model) }
            for model in MatterSchema.models { empty(model) }
            try? context.save()
            UserDefaults.standard.set(stamp, forKey: seededKey)
        }
        guard ((try? context.fetchCount(FetchDescriptor<Matter>())) ?? 0) == 0 else { return }
        context.insert(Profile(names: ["Mara Voss", "mara.voss@mail.example"]))
        var book: [String: Party] = [:]
        let cases = [scienceFair(context, &book), lisbon(context, &book), care(context, &book), flat(context, &book),
                     wedding(context, &book), moving(context, &book), tax(context, &book), accident(context, &book),
                     renovation(context, &book)]
        try? context.save()
        for made in cases { made.talk() }
        try? context.save()
    }

    // MARK: New mail, for "Get new mail" in the demo

    /// Three mails that "come in" when the demo's "Get new mail" is tapped: made up, read from no
    /// mailbox and sent nowhere — so the whole round can be seen, from the button to the matters.
    struct NewMail {
        let matter: String
        let from: String
        let subject: String
        let digest: String
    }

    static let newMail = [
        NewMail(matter: "lisbon-october", from: "Marta Sousa <marta@casa-do-largo.example>", subject: "The key box by the door",
                digest: "Marta puts the keys in a box by the door. She sends its code the day before you arrive."),
        NewMail(matter: "move-birch-road", from: "Carry & Co <office@carry-co.example>", subject: "Your move is confirmed",
                digest: "Two movers and a van from 8 to 12 o'clock. Small things should be packed by then."),
        NewMail(matter: "wedding-june", from: "Gut Birkenhof <events@gut-birkenhof.example>", subject: "Menu tasting: two Saturdays",
                digest: "The kitchen offers a tasting on two Saturdays and needs an answer by next Friday."),
    ]

    /// What the three bring, as the result of a real round shows it.
    /// What the chosen ones of the three bring.
    static func newMailItems(_ chosen: Set<Int>) -> [IntakeSummary.Item] {
        newMailItems.enumerated().filter { chosen.contains($0.offset) }.map(\.element)
    }

    static var newMailItems: [IntakeSummary.Item] {
        [IntakeSummary.Item(symbol: "checklist", text: "Ask Marta for the key box code"),
         IntakeSummary.Item(symbol: "calendar", text: "\(IntakeSummary.day(day(20))), 08:00 · Carry & Co come with the van"),
         IntakeSummary.Item(symbol: "flag", text: "by \(IntakeSummary.day(day(9))) · Answer Gut Birkenhof about the tasting")]
    }

    /// What an earlier round brought, taken out again — the three mails, their task, their dates
    /// and their lines in the history — so the demo's "Get new mail" shows the whole round every time.
    static func removeNewMail(_ context: ModelContext) {
        let isNew = { (id: String?) in id?.hasPrefix("demo-new-") == true }
        for entry in (try? context.fetch(FetchDescriptor<Entry>())) ?? [] where isNew(entry.messageID) { context.delete(entry) }
        for todo in (try? context.fetch(FetchDescriptor<Todo>())) ?? [] where todo.origin.hasPrefix("demo-new-") { context.delete(todo) }
        for item in (try? context.fetch(FetchDescriptor<Appointment>())) ?? [] where item.sources.contains(where: { isNew($0.messageID) }) {
            context.delete(item)
        }
        for item in (try? context.fetch(FetchDescriptor<Deadline>())) ?? [] where item.sources.contains(where: { isNew($0.messageID) }) {
            context.delete(item)
        }
        for turn in (try? context.fetch(FetchDescriptor<ThreadTurn>())) ?? []
        where String(decoding: turn.payload, as: UTF8.self).contains(demoIntakeMark) { context.delete(turn) }
        try? context.save()
    }

    /// In the history line of a demo round, so the next round can find and replace it.
    static let demoIntakeMark = "sorted in the demo"

    /// Sorts the three in, as "Sort in" would: a mail each, with what it brings — a task for
    /// Lisbon, the movers' day for the move, a deadline for the wedding. Returns the matters.
    static func takeInNewMail(_ context: ModelContext) -> [Matter] { takeInNewMail(context, only: Set(newMail.indices)).map(\.matter) }

    /// Only the ticked ones of the three, each with its place in `newMail`.
    static func takeInNewMail(_ context: ModelContext, only chosen: Set<Int>) -> [(index: Int, matter: Matter)] {
        removeNewMail(context)
        let matters = (try? context.fetch(FetchDescriptor<Matter>())) ?? []
        var touched: [(index: Int, matter: Matter)] = []
        for (index, mail) in newMail.enumerated() where chosen.contains(index) {
            guard let matter = matters.first(where: { $0.key == mail.matter }) else { continue }
            let source = Source(kind: .mail, pointer: "imap://demo.example/INBOX;UID=\(900 + index)",
                                messageID: "demo-new-\(index)@mail.example", date: Date())
            let entry = Entry(title: mail.subject, from: mail.from, date: source.date, source: source)
            entry.digest = mail.digest
            entry.matter = matter
            context.insert(entry)
            switch index {
            case 0:
                let todo = Todo(text: "Ask Marta for the key box code", owner: .me, due: day(14),
                                source: source.quoting("She sends its code the day before"), origin: source.messageID! + "#code")
                todo.matter = matter
                context.insert(todo)
            case 1:
                let movers = Appointment(what: "Carry & Co come with the van", day: day(20), time: "08:00", place: "Old flat",
                                         source: source.quoting("from 8 to 12 o'clock"))
                movers.matter = matter
                context.insert(movers)
            default:
                let answer = Deadline(what: "Answer Gut Birkenhof about the tasting", day: day(9), source: source.quoting("an answer by next Friday"))
                answer.matter = matter
                context.insert(answer)
            }
            touched.append((index, matter))
        }
        try? context.save()
        return touched
    }

    // MARK: Dates

    nonisolated private static let calendar = Calendar(identifier: .gregorian)

    /// Today plus `offset` days, as the store writes a day.
    nonisolated private static func day(_ offset: Int) -> String { MatterStatus.day(date(offset)) }

    nonisolated private static func date(_ offset: Int, hour: Int = 9) -> Date {
        let start = calendar.startOfDay(for: Date())
        let moved = calendar.date(byAdding: .day, value: offset, to: start) ?? start
        return calendar.date(byAdding: .hour, value: hour, to: moved) ?? moved
    }

    // MARK: One matter, built up

    @MainActor
    private final class Case {
        let context: ModelContext
        let matter: Matter
        var todos: [String: Todo] = [:]
        var mails = 0
        /// What the assistant said in this matter, written by `talk()` once the store has ids.
        var talking: () -> Void = {}

        init(_ context: ModelContext, key: String, name: String) {
            self.context = context
            matter = Matter(key: key, name: name)
            matter.createdAt = DemoData.date(-45)
            context.insert(matter)
        }

        func talk() { talking() }

        @discardableResult
        func mail(_ offset: Int, _ from: String, _ title: String, _ digest: String, files: [(String, String, Int)] = []) -> Source {
            mails += 1
            let id = "demo-\(matter.key)-\(mails)@mail.example"
            let source = Source(kind: .mail, pointer: "imap://demo.example/INBOX;UID=\(mails)", messageID: id, date: DemoData.date(offset, hour: 8 + mails % 9))
            let entry = Entry(title: title, from: from, date: source.date, source: source)
            entry.digest = digest
            entry.matter = matter
            context.insert(entry)
            for (name, type, size) in files {
                let document = Document(name: name, contentType: type, byteCount: size, source: source)
                document.matter = matter
                context.insert(document)
            }
            return source
        }

        func todo(_ handle: String, _ text: String, _ owner: Todo.Owner, due: Int? = nil, time: String? = nil, from mail: Source,
                  quote: String, done: Int? = nil, note: String? = nil, info: Bool = false, again: [(Source, String)] = []) {
            let made = Todo(text: text, owner: owner, due: due.map(DemoData.day), source: mail.quoting(quote), origin: mail.messageID! + "#" + handle)
            made.dueTime = time
            made.note = note
            made.isInfo = info
            for (source, words) in again { made.sources.append(source.quoting(words)) }
            if let done {
                made.isDone = true
                made.doneAt = DemoData.date(done)
                made.doneSource = mail.quoting(quote)
            }
            made.matter = matter
            context.insert(made)
            todos[handle] = made
        }

        func waits(_ handle: String, for other: String) { todos[handle]?.waitsFor = todos[other] }

        func appointment(_ what: String, _ offset: Int, _ time: String, at place: String, from mail: Source, quote: String) {
            let made = Appointment(what: what, day: DemoData.day(offset), time: time, place: place, source: mail.quoting(quote))
            made.matter = matter
            context.insert(made)
        }

        func deadline(_ what: String, _ offset: Int, from mail: Source, quote: String) {
            let made = Deadline(what: what, day: DemoData.day(offset), source: mail.quoting(quote))
            made.matter = matter
            context.insert(made)
        }

        func decision(_ what: String, why: String, _ offset: Int, from: [Source]) {
            let made = Decision(what: what, why: why, decidedAt: DemoData.date(offset), sources: from)
            made.matter = matter
            context.insert(made)
        }

        func link(_ address: String, _ title: String, todo handle: String? = nil) {
            let made = WebLink(address: address, title: title)
            made.createdAt = DemoData.date(-10)
            made.matter = matter
            made.todo = handle.flatMap { todos[$0] }
            context.insert(made)
        }

        func party(_ name: String, _ role: String, mentions: Int, _ book: inout [String: Party]) {
            let party = book[name] ?? {
                let made = Party(name: name)
                made.spellings = [name]
                made.keys = [PartyNames.key(name)]
                context.insert(made)
                return made
            }()
            book[name] = party
            let membership = Membership()
            membership.roles = [role]
            membership.mentions = mentions
            membership.party = party
            membership.matter = matter
            context.insert(membership)
        }

        /// The steps the app suggested and wrote, as if asked for with a click today.
        func summarise(_ summary: String, next: String, why: String, todo handle: String) {
            matter.summary = summary
            matter.summaryAt = DemoData.date(0, hour: 8)
            matter.nextStep = next
            matter.nextStepWhy = why
            matter.nextStepAt = DemoData.date(0, hour: 8)
            matter.nextStepTodo = todos[handle]?.origin
        }

        // MARK: The assistant's thread

        var refs: [String: FactRef] = [:]

        /// `T1` in a line is a door to the to-do it names.
        func cite(_ id: String, _ handle: String) {
            if let todo = todos[handle] { refs[id] = .todo(todo.persistentModelID) }
        }

        var seen: String {
            let open = matter.openTodos.count
            let dates = (matter.appointments ?? []).count + (matter.deadlines ?? []).count
            return "\(matter.entries?.count ?? 0) mails, \(open) open tasks, \(dates) dates"
        }

        func note(_ offset: Int, _ text: String) {
            var turn = Navigation.Turn(question: "", scope: "Mail", inHand: nil, seen: "", refs: [:], matter: matter.persistentModelID)
            turn.date = DemoData.date(offset, hour: 7)
            turn.note = text
            turn.state = .failed("")
            keep(turn)
        }

        func ask(_ offset: Int, _ question: String, lines: [(String, [String])], cards: [[String: Any]] = [], applied: Set<Int> = []) {
            var turn = Navigation.Turn(question: question, scope: "about \(matter.name)", inHand: nil, seen: seen, refs: refs,
                                       matter: matter.persistentModelID)
            // Never ahead of the clock: a question asked in the demo before ten would stand above them.
            turn.date = min(DemoData.date(offset, hour: 10), Date().addingTimeInterval(-3600))
            turn.state = .answered(DemoData.answer(lines: lines, cards: cards))
            turn.applied = applied
            keep(turn)
        }

        private func keep(_ turn: Navigation.Turn) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            guard let data = try? encoder.encode(turn) else { return }
            let record = ThreadTurn(id: turn.id, date: turn.date, payload: data)
            context.insert(record)
            record.matter = matter
        }
    }

    /// An answer as the assistant returns it. Read from JSON: the types have no public initialiser.
    nonisolated private static func answer(lines: [(String, [String])], cards: [[String: Any]]) -> AssistantAsk.Answer {
        let json: [String: Any] = [
            "reply": ["lines": lines.map { ["text": $0.0, "cites": $0.1] }, "cards": cards],
            "sent": "", "cost": 0.04, "seconds": 8.6, "newNames": 0,
        ]
        let data = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
        return try! JSONDecoder().decode(AssistantAsk.Answer.self, from: data)
    }

    nonisolated private static func card(_ kind: String, text: String, owner: String = "me", due: Int? = nil, todo: String? = nil,
                             reason: String, cites: [String]) -> [String: Any] {
        var card: [String: Any] = ["kind": kind, "text": text, "owner": owner, "reason": reason, "cites": cites]
        if let due { card["due"] = day(due) }
        if let todo { card["todo"] = todo }
        return card
    }

    // MARK: 1 · A school project

    private static func scienceFair(_ context: ModelContext, _ book: inout [String: Party]) -> Case {
        let c = Case(context, key: "science-fair-9b", name: "Science fair: rainwater filter (Noa, 9b)")
        let okafor = "Ms. Okafor <okafor@northfield-school.example>"
        let elif = "Elif Demir <elif.demir@mail.example>"

        let briefing = c.mail(-38, okafor, "Science fair 2026: project briefing for class 9b",
            "Groups of three build a working model and a poster. The fair is on Friday 16 October in the school gym. The written summary (one page) is due on 7 October. Judges ask every group three questions.",
            files: [("Project-briefing-9b.pdf", "application/pdf", 212_000), ("Grading-rubric.pdf", "application/pdf", 96_000)])
        let form = c.mail(-33, okafor, "Topic approval form: parents please sign",
            "Each group needs its topic approved. Parents sign the form and the child hands it in. Topics that need no special safety rules are approved within a week.",
            files: [("Topic-approval-form.pdf", "application/pdf", 64_000)])
        let chat = c.mail(-30, elif, "Group chat: who brings what?",
            "Elif suggests a rainwater filter made from bottles, sand and coffee filters. Deniz brings the bottles. She asks who has a garden tap for testing.")
        let approved = c.mail(-24, okafor, "Topic approved: rainwater filter",
            "Approved. Ms. Okafor asks the group to test the filter with muddy water and to bring a safety form for the test with cleaning agent.",
            files: [("Safety-form-experiments.pdf", "application/pdf", 58_000)])
        let materials = c.mail(-18, elif, "Materials list and costs",
            "Elif shared a sheet with the materials. Total about 18 euros. Filter sand and tubing have to be bought; the rest is at home.")
        let office = c.mail(-12, "Mr. Haas <office@northfield-school.example>", "Fair: table booking and setup times",
            "Each group gets one table, 1 metre wide. Setup is on Thursday 15 October at 15:30. Power sockets are only at the walls.")
        let reminder = c.mail(-7, okafor, "Reminder: written summary due 7 October",
            "Please send the summary to Ms. Okafor a few days early so she can read it. The poster may only go to print after she has approved the layout.")
        let flu = c.mail(-4, elif, "Deniz has the flu: can we build at yours on Saturday?",
            "Deniz is ill, but can join on Saturday afternoon. Elif asks if the group can build at Mara's place, because of the garden tap.")
        let store = c.mail(-2, "Nordlicht Hardware <service@nordlicht-hardware.example>", "Your order is ready for pickup",
            "The filter sand (3 bags) and the clear tubing (2 m) are ready at the store.")
        let feedback = c.mail(-1, okafor, "Feedback on the draft poster",
            "Nice start. The text is too long: three short sentences under each picture. Ms. Okafor wants to see the new layout before printing.",
            files: [("Poster-draft-v2.png", "image/png", 1_420_000)])

        c.todo("sign", "Sign the topic approval", .me, from: form, quote: "Parents sign the form", done: -31)
        c.todo("safety", "Return the safety form", .me, due: 1, from: approved,
               quote: "bring a safety form for the test", note: "Noa has it in her school bag.")
        c.todo("pickup", "Pick up filter sand and tubing", .me, due: 2, from: store,
               quote: "ready at the store", again: [(materials, "have to be bought")])
        c.todo("summary", "Send the summary to Ms. Okafor", .me, due: 5, from: reminder,
               quote: "send the summary to Ms. Okafor a few days early", again: [(briefing, "due on 7 October")])
        c.todo("layout", "Approve the poster layout", .other, due: 4, from: feedback, quote: "wants to see the new layout before printing")
        c.todo("print", "Print the poster", .me, due: 11, from: reminder,
               quote: "only go to print after she has approved the layout")
        c.waits("print", for: "layout")
        c.todo("build", "Build the model on Saturday", .we, due: 3, time: "14:00", from: flu, quote: "build at Mara's place")
        c.todo("bottles", "Deniz brings bottles and filters", .other, due: 3, from: chat, quote: "Deniz brings the bottles")
        c.todo("stand", "Buy a poster stand", .me, due: 12, from: office, quote: "one table, 1 metre wide",
               note: "It has to fit a 1 m table.")
        c.todo("tables", "Tables 1 m wide, sockets at the walls", .unknown, from: office,
               quote: "Power sockets are only at the walls", info: true)
        c.todo("judges", "Judges ask three questions", .unknown, from: briefing,
               quote: "Judges ask every group three questions", info: true)

        c.appointment("Build afternoon at our place", 3, "14:00", at: "Home", from: flu, quote: "build at Mara's place")
        c.appointment("Fair setup, class 9b", 15, "15:30", at: "School gym", from: office, quote: "Setup is on Thursday 15 October at 15:30")
        c.appointment("Science fair", 16, "09:00", at: "School gym", from: briefing, quote: "The fair is on Friday 16 October")
        c.deadline("Written summary due", 7, from: briefing, quote: "due on 7 October")
        c.deadline("Poster to the copy shop", 12, from: reminder, quote: "only go to print after she has approved")

        c.decision("Rainwater filter, not the solar oven",
                   why: "Under €20, and it can be tested live.",
                   -34, from: [chat, approved])
        c.decision("Build at our place, not at Elif's",
                   why: "The test needs a garden tap.", -4, from: [flu])

        c.party("Ms. Okafor", "Teacher, class 9b", mentions: 5, &book)
        c.party("Elif Demir", "Parent of Deniz, in the group", mentions: 3, &book)
        c.party("Mr. Haas", "School office", mentions: 1, &book)
        c.party("Nordlicht Hardware", "Shop for the materials", mentions: 1, &book)

        c.link("https://docs.google.com/document/d/demo-group-notes/edit", "Group notes")
        c.link("https://docs.google.com/spreadsheets/d/demo-materials/edit", "Materials list", todo: "pickup")

        c.matter.notes = "Noa presents the test. Practise once on Sunday."
        c.summarise("A rainwater filter for the fair on 16 October. Open: the summary, and the poster once Ms. Okafor approves it.",
                    next: "Send the summary to Ms. Okafor",
                    why: "Due on 7 October; she wants it early.", todo: "summary")

        c.talking = {
            c.cite("T1", "summary"); c.cite("T2", "layout"); c.cite("T3", "print"); c.cite("T4", "safety")
            c.note(-1, "📥 2 mails taken in · 2 new tasks · shown 0 done · sorted by Claude Opus\n• Feedback on the draft poster\n• Your order is ready for pickup")
            c.ask(0, "What has to happen before the poster can be printed?",
                  lines: [("The poster can only go to print after Ms. Okafor has approved the new layout, and she has not answered yet.", ["T2", "T3"]),
                          ("The print is planned for 11 October at the latest, so there is time, but the summary to her is due first.", ["T1"]),
                          ("One thing is late: the signed safety form is still in Noa's bag.", ["T4"])],
                  cards: [card("new_todo", text: "Send Ms. Okafor the new poster layout", due: 3,
                               reason: "She asked to see it before printing, and she has not seen the shorter version.", cites: ["T2"])])
        }
        return c
    }

    // MARK: 2 · A trip

    private static func lisbon(_ context: ModelContext, _ book: inout [String: Party]) -> Case {
        let c = Case(context, key: "lisbon-october", name: "Lisbon, 17–24 October (family trip)")
        let airline = "Aerolusa <booking@aerolusa.example>"
        let marta = "Marta Sousa <marta@casa-do-largo.example>"
        let tomas = "Tomás Ribeiro <tomas.ribeiro@mail.example>"

        let flights = c.mail(-35, airline, "Your booking: Frankfurt to Lisbon, 17 and 24 October",
            "Three seats booked. Out: Saturday 17 October, 07:10. Back: Saturday 24 October, 18:45. Hand luggage only; a checked bag costs 35 euros each way.",
            files: [("Booking-confirmation-flights.pdf", "application/pdf", 148_000)])
        let stay = c.mail(-30, marta, "Casa do Largo: booking confirmed",
            "Apartment in Alfama, seven nights, two bedrooms. Check-in from 15:00, key box code comes the day before. Free cancellation until 10 October.",
            files: [("Casa-do-Largo-booking.pdf", "application/pdf", 121_000)])
        let friend = c.mail(-26, tomas, "You are coming!! Dinner at mine?",
            "Tomás lives in Alfama and invites the family to dinner on Tuesday 20 October. He will send the address and the door code.")
        let city = c.mail(-20, "Citizens' Office Kessel <termin@kessel-city.example>", "Your appointment: ID card for Lena",
            "Appointment on Friday 9 October at 10:20. Standard processing takes four to six weeks. Express processing (three working days) costs an extra 32 euros and has to be asked for at the appointment.")
        let change = c.mail(-12, airline, "Schedule change: your outbound flight on 17 October",
            "Your flight now leaves at 09:05 instead of 07:10. If the new time does not suit you, you can rebook free of charge until 3 October.")
        let insurance = c.mail(-9, "Nordhaven Insurance <offers@nordhaven-insurance.example>", "Your travel insurance offer",
            "Family plan for one week: 38 euros, cancellation and health cover. The offer is valid until 12 October.",
            files: [("Insurance-offer.pdf", "application/pdf", 88_000)])
        let host = c.mail(-6, marta, "Arrival time? Key box and tram tips",
            "Marta asks when the family arrives, so someone can be there or the key box can be prepared. She added a page with tram tips.")
        let museum = c.mail(-3, "Oceanário Tickets <tickets@oceanario-tickets.example>", "Your reservation is held until 5 October",
            "Three tickets for Thursday 22 October, 10:30, are held. Please pay by 5 October or the reservation is released.",
            files: [("Oceanario-reservation.pdf", "application/pdf", 76_000)])
        let again = c.mail(-1, marta, "Re: Arrival time?",
            "Marta asks again for the arrival time. She travels on Friday and wants to arrange the key box before.")

        c.todo("flights", "Book the flights", .me, from: flights, quote: "Three seats booked", done: -35)
        c.todo("stay", "Book the apartment", .me, from: stay, quote: "booking confirmed", done: -30)
        c.todo("arrival", "Tell Marta when we arrive", .me, due: -1, from: host, quote: "Marta asks when the family arrives",
               again: [(again, "asks again for the arrival time")])
        c.todo("id", "Ask for express ID card for Lena", .me, due: 9, time: "10:20", from: city,
               quote: "Express processing has to be asked for at the appointment",
               note: "Take the old card, a photo and the birth certificate.")
        c.todo("museum", "Pay for the Oceanário", .me, due: 5, from: museum, quote: "Please pay by 5 October")
        c.todo("insurance", "Get travel insurance", .me, due: 10, from: insurance, quote: "The offer is valid until 12 October")
        c.todo("day", "Choose the Sintra day", .we, due: 7, from: friend, quote: "dinner on Tuesday 20 October")
        c.todo("train", "Book the Sintra train", .me, due: 12, from: friend, quote: "Sintra")
        c.waits("train", for: "day")
        c.todo("address", "Tomás sends the dinner address", .other, due: 14, from: friend,
               quote: "He will send the address and the door code")
        c.todo("checkin", "Check in online", .me, due: 16, from: flights, quote: "Out: Saturday 17 October")
        c.todo("bag", "Hand luggage only", .unknown, from: flights,
               quote: "a checked bag costs 35 euros each way", info: true)
        c.todo("keybox", "Key box code comes the day before", .unknown, from: stay,
               quote: "key box code comes the day before", info: true)

        c.appointment("Citizens' office: Lena's ID card", 9, "10:20", at: "Citizens' Office Kessel", from: city, quote: "Friday 9 October at 10:20")
        c.appointment("Flight Frankfurt → Lisbon", 17, "09:05", at: "Frankfurt Airport, Terminal 1", from: change, quote: "now leaves at 09:05")
        c.appointment("Dinner at Tomás's", 20, "19:30", at: "Alfama", from: friend, quote: "dinner on Tuesday 20 October")
        c.appointment("Oceanário", 22, "10:30", at: "Parque das Nações", from: museum, quote: "Thursday 22 October, 10:30")
        c.appointment("Flight Lisbon → Frankfurt", 24, "18:45", at: "Lisbon Airport", from: flights, quote: "Back: Saturday 24 October, 18:45")
        c.deadline("Oceanário: pay by", 5, from: museum, quote: "pay by 5 October")
        c.deadline("Apartment: free cancellation ends", 10, from: stay, quote: "Free cancellation until 10 October")
        c.deadline("Insurance offer expires", 12, from: insurance, quote: "valid until 12 October")

        c.decision("Apartment in Alfama, not a hotel",
                   why: "Two bedrooms for the price of one hotel room.", -31, from: [stay])
        c.decision("Hand luggage only",
                   why: "A checked bag costs €35 each way.", -34, from: [flights])

        c.party("Aerolusa", "Airline", mentions: 2, &book)
        c.party("Marta Sousa", "Host of the apartment", mentions: 3, &book)
        c.party("Tomás Ribeiro", "Friend in Lisbon", mentions: 1, &book)
        c.party("Citizens' Office Kessel", "Office for Lena's ID card", mentions: 1, &book)
        c.party("Nordhaven Insurance", "Travel insurance", mentions: 1, &book)

        c.link("https://docs.google.com/document/d/demo-packing/edit", "Packing list")
        c.link("https://docs.google.com/spreadsheets/d/demo-days/edit", "Day plan Lisbon")
        c.link("https://www.casa-do-largo.example/tram-tips", "Tram tips from Marta")

        c.matter.notes = "Keep Thursday afternoon free."
        c.summarise("Booked for 17 to 24 October. Lena needs a new ID card, and Marta still waits for our arrival time.",
                    next: "Tell Marta when we arrive",
                    why: "She has asked twice.", todo: "arrival")

        c.talking = {
            c.cite("T1", "arrival"); c.cite("T2", "id"); c.cite("T3", "museum"); c.cite("T4", "train"); c.cite("T5", "day")
            c.note(-1, "📥 3 mails taken in · 3 new tasks · 1 date · sorted by Claude Opus\n• Re: Arrival time?\n• Your reservation is held until 5 October\n• Your travel insurance offer")
            c.ask(0, "What can go wrong before we fly?",
                  lines: [("Lena's ID card is expired. The standard wait is four to six weeks, so it only works if you ask for express processing at the appointment on 9 October.", ["T2"]),
                          ("The Oceanário reservation is released if it is not paid by 5 October.", ["T3"]),
                          ("Marta still does not know when you arrive, and she asked twice.", ["T1"]),
                          ("The Sintra train tickets wait for your decision on the day.", ["T4", "T5"])],
                  cards: [card("new_todo", text: "Call the citizens' office and ask if express processing is still possible", due: 2,
                               reason: "If the office has no express slot, you have nine days to find another way.", cites: ["T2"])])
        }
        return c
    }

    // MARK: 3 · Organising care

    private static func care(_ context: ModelContext, _ book: inout [String: Party]) -> Case {
        let c = Case(context, key: "care-for-helga", name: "Care for Mum (Helga) after her fall")
        let gp = "Dr. Anselm Brandt <praxis@brandt-clinic.example>"
        let nina = "Nina Voss <nina.voss@mail.example>"
        let fund = "Healthbridge Care Fund <pflege@healthbridge.example>"
        let sunrise = "Yusuf Kaya <y.kaya@sunrise-homecare.example>"

        let discharge = c.mail(-42, gp, "After your mother's hospital stay: what she needs",
            "Helga is recovering well but walks with a rollator and needs help with showering and shopping for about six weeks. Physiotherapy twice a week. A prescription for the rollator is ready.",
            files: [("Doctors-report.pdf", "application/pdf", 132_000)])
        let rota = c.mail(-40, nina, "Who does what this week?",
            "Nina suggests taking Wednesdays and the weekend, since she lives ten minutes from Mum. She asks Mara to cover the start of the week.")
        let social = c.mail(-37, "Ilse Kranz <social@st-elm-hospital.example>", "Discharge and how to apply for a care level",
            "The hospital's social worker recommends applying for a care level at the health insurer now, because the decision takes several weeks. The hospital letter must go with the application.",
            files: [("Hospital-discharge-letter.pdf", "application/pdf", 174_000)])
        let received = c.mail(-30, fund, "Application received: care level for Helga Voss",
            "The application arrived. The insurer decides within 25 working days. A visit by the medical service will be arranged.",
            files: [("Care-level-application.pdf", "application/pdf", 205_000)])
        let offer = c.mail(-24, sunrise, "Offer: Sunrise Home Care visits for Helga",
            "Visits on Monday, Wednesday and Friday at 08:00, 45 minutes each, help with showering and breakfast. Starting in October. Cost is covered in part once a care level is granted.")
        let physio = c.mail(-18, "Anja Bergmann <hello@bergmann-physio.example>", "Physio appointments for Helga",
            "Helga has physiotherapy on Tuesdays and Fridays at 11:00, starting Friday 2 October.")
        let visit = c.mail(-14, fund, "Visit by the medical service on 6 October",
            "The assessment visit takes place at Helga's flat on Tuesday 6 October at 10:00 and lasts about an hour. A family member should be there.")
        let split = c.mail(-10, nina, "Re: Who does what?",
            "Nina takes Wednesday and the weekend. She asks Mara to take Monday, Tuesday and Thursday. Uncle Karl could help on Monday mornings.")
        let contract = c.mail(-7, sunrise, "Contract draft: please sign and return by 2 October",
            "The contract for the visits is attached. The first visit is Wednesday 7 October at 08:00 if the signed contract is back by 2 October.",
            files: [("Sunrise-contract-draft.pdf", "application/pdf", 96_000)])
        let seat = c.mail(-3, gp, "Prescription for the bath seat is ready",
            "The prescription for the bath seat can be collected at the practice. The medical supply store needs it before delivery.")
        let papers = c.mail(-1, fund, "Please have these documents ready for the visit",
            "For the visit on 6 October, have ready: the current medication list, the doctor's report and the hospital letter.")
        // Mara's own answer, from the sent mail: last, so the mails above keep their numbers.
        c.mail(-39, "Mara Voss <mara.voss@mail.example>", "Re: Who does what this week?",
            "Mara can take Monday and Tuesday this week and will ask Uncle Karl about Thursday.")

        c.todo("apply", "Apply for a care level", .me, from: social, quote: "apply for a care level", done: -29)
        c.todo("rollator", "Get the rollator prescription", .me, from: discharge, quote: "A prescription for the rollator is ready", done: -38)
        c.todo("bathseat", "Get the bath seat prescription", .me, due: -2, from: seat,
               quote: "can be collected at the practice")
        c.todo("read", "Read the Sunrise contract with Nina", .we, due: 1, from: contract, quote: "The contract for the visits is attached")
        c.todo("sign", "Sign the Sunrise contract", .me, due: 2, from: contract, quote: "signed contract is back by 2 October")
        c.waits("sign", for: "read")
        c.todo("papers", "Gather the papers for the visit", .me, due: 5, from: papers,
               quote: "have ready: the current medication list", again: [(visit, "A family member should be there")])
        c.todo("physio", "Move Tuesday's physio", .me, due: 3, from: physio,
               quote: "Tuesdays and Fridays at 11:00", note: "The visit on the 6th starts at 10:00 and may run long.")
        c.todo("karl", "Ask Karl about Monday mornings", .other, due: 3, from: split, quote: "Uncle Karl could help on Monday mornings")
        c.todo("plan", "Agree who is with Mum when", .we, due: 1, from: rota, quote: "Who does what this week?")
        c.todo("decision", "Decision within 25 working days", .unknown, from: received,
               quote: "The insurer decides within 25 working days", info: true)
        c.todo("budget", "A care level pays part of home care", .unknown, from: offer,
               quote: "covered in part once a care level is granted", info: true)

        c.appointment("Physio", 1, "11:00", at: "Bergmann Physio", from: physio, quote: "starting Friday 2 October")
        c.appointment("Assessment visit (medical service)", 6, "10:00", at: "Mum's flat", from: visit, quote: "Tuesday 6 October at 10:00")
        c.appointment("First visit by Sunrise Home Care", 7, "08:00", at: "Mum's flat", from: contract, quote: "first visit is Wednesday 7 October at 08:00")
        c.deadline("Sunrise contract: send back signed", 2, from: contract, quote: "back by 2 October")
        c.deadline("Care level: decision expected", 14, from: received, quote: "decides within 25 working days")

        c.decision("Sunrise Home Care, not the other two services",
                   why: "They come at 08:00 and have a place from October.",
                   -20, from: [offer])
        c.decision("Split the week: Mara Monday, Tuesday, Thursday; Nina Wednesday and the weekend",
                   why: "Nina lives close; Mara works from home early in the week.", -9, from: [rota, split])

        c.party("Dr. Anselm Brandt", "Family doctor", mentions: 3, &book)
        c.party("Nina Voss", "Sister, shares the care", mentions: 3, &book)
        c.party("Yusuf Kaya", "Sunrise Home Care", mentions: 2, &book)
        c.party("Healthbridge Care Fund", "Health insurer", mentions: 3, &book)
        c.party("Ilse Kranz", "Hospital social worker", mentions: 1, &book)
        c.party("Anja Bergmann", "Physiotherapist", mentions: 1, &book)

        c.link("https://docs.google.com/spreadsheets/d/demo-rota/edit", "Care rota (shared with Nina)")
        c.link("https://docs.google.com/document/d/demo-medication/edit", "Medication list")

        c.matter.notes = "Not before 08:00. Spare key: Mrs. Adler next door."
        c.summarise("Mum is home again. Assessment on 6 October; Sunrise starts on 7 October if the contract is back by 2 October.",
                    next: "Read and sign the Sunrise contract",
                    why: "It has to be back by 2 October.", todo: "sign")

        c.talking = {
            c.cite("T1", "papers"); c.cite("T2", "physio"); c.cite("T3", "sign"); c.cite("T4", "bathseat")
            c.note(-1, "📥 2 mails taken in · 2 new tasks · sorted by Claude Opus\n• Please have these documents ready for the visit\n• Prescription for the bath seat is ready")
            c.ask(0, "What do I need to do before Tuesday's visit?",
                  lines: [("Put the medication list, the doctor's report and the hospital letter together; the insurer asked for them twice.", ["T1"]),
                          ("Move the physio that day to the afternoon: the visit starts at 10:00 and may run into the 11:00 slot.", ["T2"]),
                          ("Also still open: the signed Sunrise contract, due back on 2 October.", ["T3"])],
                  cards: [card("new_todo", text: "Ask a neighbour to be at Mum's flat by 09:45 on 6 October", owner: "other", due: 4,
                               reason: "A family member should be there, and Mrs. Adler has the spare key.", cites: ["T1"])])
        }
        return c
    }

    // MARK: 4 · Buying a flat

    private static func flat(_ context: ModelContext, _ book: inout [String: Party]) -> Case {
        let c = Case(context, key: "flat-linden-street", name: "Buying the flat at Linden Street 8")
        let agent = "Petra Holm <p.holm@holm-estates.example>"
        let bank = "Jonas Reiter <j.reiter@northbank.example>"
        let notary = "Office of Dr. Wendt <office@notary-wendt.example>"

        let viewing = c.mail(-44, agent, "Viewing: 3-room flat, Linden Street 8",
            "Third floor, 78 square metres, balcony, built 1994. Asking price 385,000 euros. Petra suggests a second viewing with a building expert.",
            files: [("Expose-Linden-Street-8.pdf", "application/pdf", 2_100_000)])
        let offer = c.mail(-31, agent, "Your offer was accepted",
            "The sellers accept 372,000 euros. They ask for a written financing commitment from the bank within three weeks.")
        let bankMail = c.mail(-27, bank, "Mortgage: documents we need",
            "For the commitment Northbank needs three salary slips each, the tax notices of the last two years and the sales exposé.")
        let manager = c.mail(-20, "Frank Aydin <f.aydin@linden-management.example>", "Building: minutes and reserve fund",
            "Minutes of the last three owners' meetings attached. The reserve fund is healthy; a new roof is planned in about eight years.",
            files: [("Owners-meeting-minutes.pdf", "application/pdf", 640_000)])
        let expert = c.mail(-15, "Ines Vogt <ines.vogt@vogt-survey.example>", "Survey of the flat: short report",
            "No serious defects. Windows in the bedroom should be resealed within two years; estimate 900 euros.",
            files: [("Survey-report.pdf", "application/pdf", 1_300_000)])
        let commit = c.mail(-8, bank, "Financing commitment is ready",
            "The commitment for 300,000 euros is ready once the last salary slip is sent. Interest fixed for ten years.")
        let draft = c.mail(-5, notary, "Draft of the purchase contract",
            "Draft attached. Please read it and send questions before the appointment. Signing is on 12 October.",
            files: [("Purchase-contract-draft.pdf", "application/pdf", 380_000)])
        let insure = c.mail(-2, "Lea Bauer <l.bauer@safehome-insurance.example>", "Building insurance: offer for Linden Street 8",
            "Contents and liability insurance for the flat, 19 euros a month. Cover can start on the day of handover.")

        c.todo("offer", "Make an offer", .me, from: offer, quote: "The sellers accept", done: -32)
        c.todo("survey", "Book a building survey", .me, from: viewing, quote: "second viewing with a building expert", done: -18)
        c.todo("slip", "Send the salary slip to Northbank", .me, due: 1, from: commit, quote: "once the last salary slip is sent",
               again: [(bankMail, "three salary slips each")])
        c.todo("read", "Read the contract, note questions", .me, due: 6, from: draft, quote: "read it and send questions")
        c.todo("questions", "Send questions to the notary", .me, due: 8, from: draft, quote: "send questions before the appointment")
        c.waits("questions", for: "read")
        c.todo("bankDocs", "Get the last two tax notices", .me, due: 2, from: bankMail,
               quote: "the tax notices of the last two years")
        c.todo("insurance", "Accept the building insurance", .me, due: 11, from: insure, quote: "Cover can start on the day of handover")
        c.todo("sellers", "Sellers confirm the handover date", .other, due: 9, from: offer, quote: "written financing commitment")
        c.todo("price", "Price €372,000, loan €300,000", .unknown, from: offer,
               quote: "accept 372,000 euros", info: true)
        c.todo("windows", "Windows need resealing (about €900)", .unknown, from: expert,
               quote: "resealed within two years", info: true)

        c.appointment("Signing at the notary", 12, "11:00", at: "Notary Dr. Wendt, Market Square 3", from: draft, quote: "Signing is on 12 October")
        c.appointment("Handover of the keys", 40, "10:00", at: "Linden Street 8", from: offer, quote: "handover")
        c.deadline("Financing commitment to the sellers", 5, from: offer, quote: "within three weeks")
        c.deadline("Questions on the contract to the notary", 8, from: draft, quote: "before the appointment")

        c.decision("The flat at Linden Street, not the house in the suburbs",
                   why: "Close to work, and no new heating needed.",
                   -33, from: [viewing, manager])
        c.decision("Fixed interest for ten years",
                   why: "The same monthly payment, for longer.", -8, from: [commit])

        c.party("Petra Holm", "Estate agent", mentions: 3, &book)
        c.party("Jonas Reiter", "Mortgage adviser, Northbank", mentions: 3, &book)
        c.party("Dr. Clara Wendt", "Notary", mentions: 1, &book)
        c.party("Frank Aydin", "Building manager", mentions: 1, &book)
        c.party("Ines Vogt", "Building expert", mentions: 1, &book)
        c.party("Lea Bauer", "Insurance adviser", mentions: 1, &book)

        c.link("https://docs.google.com/spreadsheets/d/demo-costs/edit", "Costs and monthly budget")
        c.link("https://docs.google.com/document/d/demo-contract-questions/edit", "Questions on the contract", todo: "read")
        c.matter.notes = "Keep €20,000 free. Ask them to leave the kitchen."
        c.summarise("Offer accepted at €372,000. Notary on 12 October; questions due by 8 October.",
                    next: "Send the salary slip to Northbank",
                    why: "The commitment is ready once it arrives.", todo: "slip")
        c.talking = {
            c.cite("T1", "slip"); c.cite("T2", "bankDocs"); c.cite("T3", "read"); c.cite("T4", "questions")
            c.note(-2, "📥 2 mails taken in · 2 new tasks · sorted by Claude Opus\n• Building insurance: offer for Linden Street 8\n• Draft of the purchase contract")
            c.ask(0, "Is anything holding up the financing?",
                  lines: [("The bank only waits for the last salary slip.", ["T1"]),
                          ("The tax notices from the last two years are also on their list, and that task is already late.", ["T2"]),
                          ("After that the contract: read it first, then send your questions to the notary by 8 October.", ["T3", "T4"])],
                  cards: [card("new_todo", text: "Ask Northbank whether the tax notices can follow after the commitment", due: 1,
                               reason: "It may save a day if the portal is slow.", cites: ["T2"])])
        }
        return c
    }

    // MARK: 5 · A wedding

    private static func wedding(_ context: ModelContext, _ book: inout [String: Party]) -> Case {
        let c = Case(context, key: "wedding-june", name: "Wedding, 12 June 2027 (Mara and Sam)")
        let venue = "Anke Roth <anke@birkenhof.example>"
        let cater = "Lindenblatt Catering <hello@lindenblatt-catering.example>"

        let visit = c.mail(-60, venue, "Gut Birkenhof: your visit and the date",
            "12 June 2027 is free. Room for 90 guests, ceremony in the garden with a rain plan in the barn. Deposit of 2,000 euros holds the date for four weeks.",
            files: [("Birkenhof-price-list.pdf", "application/pdf", 310_000)])
        let deposit = c.mail(-14, venue, "Deposit reminder",
            "The date is held until 10 October. After that it goes back to the calendar.")
        let food = c.mail(-40, cater, "Menu proposal for 90 guests",
            "Three menu options, vegetarian included. Tasting is possible in November. 68 euros per person with drinks.",
            files: [("Menu-proposal.pdf", "application/pdf", 450_000)])
        let photo = c.mail(-30, "Ravi Nair <ravi@nair-photo.example>", "Photography: packages and availability",
            "Ravi is free on 12 June. Full-day package 2,400 euros, second photographer 600 euros extra.")
        let band = c.mail(-22, "Jule Brandt <jule@bandwagon-music.example>", "Live band or DJ?",
            "The band plays three sets and costs 1,800 euros; a DJ is 900. Jule needs a decision by end of November.")
        let registry = c.mail(-9, "Registry Office Kessel <trauung@kessel-city.example>", "Civil ceremony: documents",
            "For the civil ceremony on 11 June both need ID, birth certificates and proof of residence. Bring them to a preparatory appointment.")
        let sam = c.mail(-3, "Sam Keller <sam.keller@mail.example>", "Guest list, first version",
            "Sam sent the first list: 74 names, 12 not sure. Sam's parents want to invite six more.")

        c.todo("date", "Pay the €2,000 deposit", .we, due: 8, from: deposit, quote: "held until 10 October",
               again: [(visit, "Deposit of 2,000 euros holds the date")])
        c.todo("tasting", "Book the menu tasting", .me, due: 20, from: food, quote: "Tasting is possible in November")
        c.todo("photo", "Decide on the photographer", .we, due: 25, from: photo, quote: "Ravi is free on 12 June")
        c.todo("band", "Decide: live band or DJ", .we, due: 45, from: band, quote: "decision by end of November")
        c.todo("docs", "Get birth certificates", .we, due: 14, from: registry,
               quote: "birth certificates and proof of residence")
        c.todo("prep", "Book the registry appointment", .me, due: 10, from: registry, quote: "preparatory appointment")
        c.waits("docs", for: "prep")
        c.todo("guests", "Sam sends the guest list", .other, due: 12, from: sam, quote: "first list: 74 names, 12 not sure")
        c.todo("save", "Send the save-the-dates", .me, due: 18, from: sam, quote: "first list")
        c.waits("save", for: "guests")
        c.todo("tables", "Rain plan: the barn", .unknown, from: visit,
               quote: "rain plan in the barn", info: true)
        c.todo("budget", "Budget €24,000, €9,000 saved", .unknown, from: food, quote: "68 euros per person", info: true)

        c.appointment("Wedding day", 255, "14:00", at: "Gut Birkenhof", from: visit, quote: "12 June 2027")
        c.appointment("Civil ceremony", 254, "10:30", at: "Registry Office Kessel", from: registry, quote: "ceremony on 11 June")
        c.deadline("Birkenhof deposit: date is held until", 10, from: deposit, quote: "held until 10 October")
        c.deadline("Band or DJ: decision", 45, from: band, quote: "by end of November")

        c.decision("Gut Birkenhof, not the town hall",
                   why: "A garden, a barn for rain, and our date.", -58, from: [visit])
        c.party("Anke Roth", "Venue manager, Gut Birkenhof", mentions: 2, &book)
        c.party("Lindenblatt Catering", "Caterer", mentions: 1, &book)
        c.party("Ravi Nair", "Photographer", mentions: 1, &book)
        c.party("Jule Brandt", "Band leader", mentions: 1, &book)
        c.party("Sam Keller", "Partner", mentions: 4, &book)
        c.link("https://docs.google.com/spreadsheets/d/demo-guests/edit", "Guest list")
        c.link("https://docs.google.com/spreadsheets/d/demo-wedding-budget/edit", "Budget")
        c.matter.notes = "No speeches before the food."
        c.summarise("Gut Birkenhof is held until 10 October. Caterer, photographer and music still open.",
                    next: "Pay the deposit for Gut Birkenhof",
                    why: "Otherwise the date goes on 10 October.", todo: "date")
        c.talking = {
            c.cite("T1", "date"); c.cite("T2", "guests"); c.cite("T3", "save")
            c.note(-3, "📥 1 mail taken in · 2 new tasks · sorted by Claude Opus\n• Guest list, first version")
            c.ask(0, "What do we have to decide first?",
                  lines: [("The deposit: the date goes back on the venue's calendar after 10 October.", ["T1"]),
                          ("The final guest list comes next, because the save-the-date cards wait for it.", ["T2", "T3"])],
                  cards: [card("new_todo", text: "Ask Sam's parents for their six names by Sunday", owner: "other", due: 4,
                               reason: "The list is 74 plus six, and the caterer prices per person.", cites: ["T2"])])
        }
        return c
    }

    // MARK: 6 · Moving house

    private static func moving(_ context: ModelContext, _ book: inout [String: Party]) -> Case {
        let c = Case(context, key: "move-birch-road", name: "Moving to Birch Road 12")
        let old = "Mr. Krüger <kruger@krueger-houses.example>"
        let mover = "Carry & Co <booking@carry-and-co.example>"

        let lease = c.mail(-50, "Ms. Almeida <almeida@birch-lettings.example>", "Lease for Birch Road 12 signed",
            "The lease starts on 21 October. Keys are handed over at 10:00 on that day. The deposit of two months' rent is paid.",
            files: [("Lease-Birch-Road-12.pdf", "application/pdf", 420_000)])
        let notice = c.mail(-45, old, "Your notice: confirmation",
            "The notice is confirmed for 31 October. The handover of the old flat is on 31 October at 12:00.")
        let movers = c.mail(-28, mover, "Quote: moving on 21 October",
            "Two people and a van, four hours, 620 euros. Boxes can be rented. The offer holds until 7 October.",
            files: [("Moving-quote.pdf", "application/pdf", 150_000)])
        let net = c.mail(-16, "FiberNest <service@fibernest.example>", "Moving your internet connection",
            "Your line can be moved for free if you ask four weeks before the move. The technician needs a day at the new address.")
        let hand = c.mail(-9, old, "Handover of the flat: what to prepare",
            "Walls must be repainted white or the deposit is reduced. Bring all keys, including the cellar key.")
        let power = c.mail(-4, "Northlight Energy <contracts@northlight.example>", "Reading of the meter on moving day",
            "Please send the meter reading on 31 October and the new address.")
        let neighbour = c.mail(-1, "Ms. Adler <adler@mail.example>", "Parking for the van?",
            "Ms. Adler from Birch Road 10 says the van can use her drive on Wednesday morning if asked in time.")

        c.todo("lease", "Sign the lease", .me, from: lease, quote: "Lease for Birch Road 12 signed", done: -50)
        c.todo("notice", "Give notice for the old flat", .me, from: notice, quote: "The notice is confirmed", done: -45)
        c.todo("internet", "Ask FiberNest to move the internet", .me, due: 3, from: net,
               quote: "if you ask four weeks before the move")
        c.todo("movers", "Book Carry & Co", .me, due: 6, from: movers, quote: "The offer holds until 7 October")
        c.todo("paint", "Paint the old flat white", .me, due: 24, from: hand, quote: "Walls must be repainted white")
        c.todo("keys", "Collect all keys for the handover", .me, due: 30, from: hand, quote: "Bring all keys")
        c.todo("forward", "Set up mail forwarding", .me, due: 15, from: net, quote: "new address")
        c.todo("register", "Register the new address", .me, due: 30, from: lease, quote: "The lease starts on 21 October")
        c.waits("register", for: "movers")
        c.todo("power", "Send the meter reading", .me, due: 31, from: power, quote: "send the meter reading on 31 October")
        c.todo("drive", "Ask Ms. Adler about Wednesday", .me, due: 14, from: neighbour, quote: "if asked in time")
        c.todo("tech", "Be home for the technician", .other, due: 21, from: net, quote: "technician needs a day")
        c.todo("boxes", "Boxes from Carry & Co", .unknown, from: movers, quote: "Boxes can be rented", info: true)

        c.appointment("Key handover, Birch Road 12", 21, "10:00", at: "Birch Road 12", from: lease, quote: "10:00 on that day")
        c.appointment("Moving day", 21, "12:00", at: "Old flat", from: movers, quote: "moving on 21 October")
        c.appointment("Handover of the old flat", 31, "12:00", at: "Old flat", from: notice, quote: "12:00")
        c.deadline("Carry & Co: offer holds until", 7, from: movers, quote: "until 7 October")
        c.deadline("Old flat: notice ends", 31, from: notice, quote: "31 October")
        c.decision("Professional movers, not friends with a van",
                   why: "€620, and the piano is too heavy for friends.",
                   -27, from: [movers])
        c.party("Ms. Almeida", "New landlord", mentions: 1, &book)
        c.party("Mr. Krüger", "Old landlord", mentions: 2, &book)
        c.party("Carry & Co", "Movers", mentions: 1, &book)
        c.party("FiberNest", "Internet provider", mentions: 1, &book)
        c.party("Northlight Energy", "Electricity", mentions: 1, &book)
        c.link("https://docs.google.com/document/d/demo-move-checklist/edit", "Move checklist")
        c.matter.notes = "Label boxes by room."
        c.summarise("Moving on 21 October. Open: the movers, and the internet, which is already late.",
                    next: "Ask FiberNest to move the internet",
                    why: "It needs four weeks; the move is in three.", todo: "internet")
        c.talking = {
            c.cite("T1", "internet"); c.cite("T2", "movers"); c.cite("T3", "paint")
            c.note(-1, "📥 2 mails taken in · 1 new task · sorted by Claude Opus\n• Parking for the van?\n• Reading of the meter on moving day")
            c.ask(0, "What is urgent this week?",
                  lines: [("Ask FiberNest to move the line: the free move needed four weeks' notice, so call them and ask for an exception.", ["T1"]),
                          ("Book Carry & Co before 7 October, or the price may change.", ["T2"])],
                  cards: [card("new_todo", text: "Call FiberNest and ask for the connection on 21 October", due: 1,
                               reason: "It is already inside the four weeks.", cites: ["T1"])])
        }
        return c
    }

    // MARK: 7 · A tax return

    private static func tax(_ context: ModelContext, _ book: inout [String: Party]) -> Case {
        let c = Case(context, key: "tax-return-2025", name: "Tax return 2025")
        let advisor = "Jana Falk <jana@falk-tax.example>"

        let start = c.mail(-30, advisor, "Tax return 2025: what I need from you",
            "Please send the employer's tax certificate, bank and interest statements, donation receipts and the costs of the home office. The deadline with the tax office is 31 October.",
            files: [("Checklist-tax-2025.pdf", "application/pdf", 90_000)])
        let employer = c.mail(-21, "Payroll <payroll@brightwork.example>", "Your tax certificate for 2025",
            "The certificate is in the employee portal. It shows gross pay, tax paid and social security.")
        let bank = c.mail(-14, "Northbank <statements@northbank.example>", "Annual statement 2025",
            "Interest income 312 euros; the tax certificate for capital gains is attached.",
            files: [("Annual-statement-2025.pdf", "application/pdf", 210_000)])
        let health = c.mail(-10, "Healthbridge Care Fund <service@healthbridge.example>", "Your contributions in 2025",
            "The contribution statement for 2025 is attached. It counts as a deduction.",
            files: [("Contributions-2025.pdf", "application/pdf", 130_000)])
        let donation = c.mail(-6, "Green Roofs Association <donations@greenroofs.example>", "Donation receipt",
            "Thank you for your donations. The receipt for 2025 is attached: 240 euros.",
            files: [("Donation-receipt-2025.pdf", "application/pdf", 60_000)])
        let ask = c.mail(-2, advisor, "Reminder: two things are missing",
            "Still missing: the home office days and the receipt for the new desk. Without them the deduction can not be claimed.")

        c.todo("cert", "Get the tax certificate", .me, from: employer, quote: "The certificate is in the employee portal", done: -20)
        c.todo("bank", "Send the bank statement to Jana", .me, due: 2, from: bank, quote: "the tax certificate for capital gains is attached")
        c.todo("health", "Send the health statement to Jana", .me, due: 2, from: health, quote: "counts as a deduction")
        c.todo("days", "Count the home office days", .me, due: 4, from: ask,
               quote: "the home office days", again: [(start, "the costs of the home office")])
        c.todo("desk", "Find the desk receipt", .me, due: 2, from: ask, quote: "the receipt for the new desk",
               note: "Probably in the mail from March, from Werkstatt Möbel.")
        c.todo("donate", "Send the donation receipt", .me, due: 3, from: donation, quote: "The receipt for 2025 is attached")
        c.todo("sign", "Sign the return", .me, due: 18, from: start, quote: "The deadline with the tax office is 31 October")
        c.todo("prepare", "Jana prepares the return", .other, due: 14, from: start, quote: "Please send")
        c.waits("sign", for: "prepare")
        c.todo("deadline", "Due at the tax office on 31 October", .unknown, from: start,
               quote: "The deadline with the tax office is 31 October", info: true)

        c.appointment("Call with Jana to check the return", 16, "16:00", at: "Phone", from: start, quote: "Please send")
        c.deadline("Documents to Jana", 5, from: ask, quote: "Still missing")
        c.deadline("Tax return with the tax office", 31, from: start, quote: "31 October")
        c.decision("Use a tax advisor this year",
                   why: "Too complicated this year; the fee pays for itself.",
                   -29, from: [start])
        c.party("Jana Falk", "Tax advisor", mentions: 2, &book)
        c.party("Brightwork Payroll", "Employer", mentions: 1, &book)
        c.party("Green Roofs Association", "Donations", mentions: 1, &book)
        c.link("https://docs.google.com/spreadsheets/d/demo-home-office/edit", "Home office days 2025", todo: "days")
        c.matter.notes = "Send PDFs only."
        c.summarise("Almost all in. Jana needs the home office days and the desk receipt by 5 October.",
                    next: "Find the desk receipt",
                    why: "Without it, no deduction.", todo: "desk")
        c.talking = {
            c.cite("T1", "desk"); c.cite("T2", "days"); c.cite("T3", "bank")
            c.note(-2, "📥 1 mail taken in · 2 new tasks · sorted by Claude Opus\n• Reminder: two things are missing")
            c.ask(0, "What is Jana still waiting for?",
                  lines: [("The receipt for the new desk, which is late.", ["T1"]),
                          ("The home office days for 2025.", ["T2"]),
                          ("The bank and health statements are ready to send, so they can go at the same time.", ["T3"])],
                  cards: [card("new_todo", text: "Search the mailbox for the desk order in March", due: 1,
                               reason: "You noted it is probably in that mail.", cites: ["T1"])])
        }
        return c
    }

    // MARK: 8 · A car accident

    private static func accident(_ context: ModelContext, _ book: inout [String: Party]) -> Case {
        let c = Case(context, key: "parking-accident", name: "Parking-lot accident, 14 September")
        let claims = "Sabine Ott <s.ott@clearroad-insurance.example>"
        let garage = "Kessel Auto <werkstatt@kessel-auto.example>"

        let report = c.mail(-16, claims, "Claim received: your report of 14 September",
            "The claim number is CR-40917. Please send photos, the other driver's details and a repair estimate.")
        let other = c.mail(-15, "Tobias Lindqvist <t.lindqvist@mail.example>", "Re: what happened",
            "Tobias confirms he backed into the parked car. His insurer is Nordic Mutual. He asks to settle it quickly.")
        let estimate = c.mail(-11, garage, "Repair estimate for your car",
            "Rear bumper and the tail light: 1,840 euros including paint. Three working days once the parts are here.",
            files: [("Repair-estimate.pdf", "application/pdf", 230_000)])
        let expert = c.mail(-8, claims, "An assessor will look at the car",
            "Because the estimate is over 1,500 euros, an assessor inspects the car at the garage before repair.")
        let rental = c.mail(-6, "Rent-a-Wheel <booking@rentawheel.example>", "Rental car: your quote",
            "A small car costs 39 euros a day. The other party's insurer usually pays for the rental time of the repair.")
        let assess = c.mail(-3, "Kai Marek <k.marek@marek-assessors.example>", "Inspection appointment",
            "The assessor can come on Thursday 1 October at 14:00 to Kessel Auto.")
        let pay = c.mail(-1, claims, "Please confirm your bank details",
            "For the payment, please confirm the account holder and the IBAN.")

        c.todo("photos", "Send photos of the damage", .me, from: report, quote: "Please send photos", done: -14)
        c.todo("details", "Send the other driver's details", .me, from: report, quote: "the other driver's details", done: -13)
        c.todo("estimate", "Send the repair estimate", .me, due: 1, from: report, quote: "a repair estimate",
               again: [(estimate, "Rear bumper and the tail light")])
        c.todo("iban", "Confirm your bank details", .me, due: 2, from: pay, quote: "confirm the account holder and the IBAN")
        c.todo("rental", "Decide on a rental car", .me, due: 3, from: rental, quote: "A small car costs 39 euros a day")
        c.todo("appt", "Car to the garage on Thursday", .me, due: 1, from: assess, quote: "Thursday 1 October at 14:00")
        c.todo("repair", "Kessel Auto repairs it afterwards", .other, due: 10, from: estimate, quote: "Three working days once the parts are here")
        c.waits("repair", for: "appt")
        c.todo("share", "Their insurer pays, no excess", .unknown, from: other, quote: "His insurer is Nordic Mutual", info: true)

        c.appointment("Assessor at the garage", 1, "14:00", at: "Kessel Auto", from: assess, quote: "Thursday 1 October at 14:00")
        c.appointment("Pick up the repaired car", 12, "16:00", at: "Kessel Auto", from: estimate, quote: "Three working days")
        c.deadline("Documents to the insurer", 3, from: expert, quote: "inspects the car at the garage before repair")
        c.decision("Repair at Kessel Auto, not the cheaper garage",
                   why: "They deal with the insurer directly.",
                   -10, from: [estimate])
        c.party("Sabine Ott", "Claims handler, ClearRoad Insurance", mentions: 3, &book)
        c.party("Tobias Lindqvist", "Other driver", mentions: 1, &book)
        c.party("Kessel Auto", "Garage", mentions: 1, &book)
        c.party("Kai Marek", "Assessor", mentions: 1, &book)
        c.party("Rent-a-Wheel", "Rental car", mentions: 1, &book)
        c.link("https://docs.google.com/document/d/demo-accident-notes/edit", "Notes of what happened")
        c.matter.notes = "Claim CR-40917."
        c.summarise("Their insurer pays. The assessor comes first; the estimate still has to go to ClearRoad.",
                    next: "Send the repair estimate",
                    why: "The claim waits for it.", todo: "estimate")
        c.talking = {
            c.cite("T1", "estimate"); c.cite("T2", "appt"); c.cite("T3", "rental")
            c.note(-1, "📥 1 mail taken in · 1 new task · sorted by Claude Opus\n• Please confirm your bank details")
            c.ask(0, "What happens before the car is repaired?",
                  lines: [("The assessor comes to the garage on Thursday at 14:00, so the car has to be there.", ["T2"]),
                          ("ClearRoad still needs the repair estimate from you.", ["T1"]),
                          ("Decide about the rental car soon: it costs 39 euros a day.", ["T3"])],
                  cards: [card("new_todo", text: "Ask ClearRoad if they cover the rental car", due: 2,
                               reason: "The rental quote mentions that the other insurer usually pays.", cites: ["T3"])])
        }
        return c
    }

    // MARK: 9 · A bathroom renovation

    private static func renovation(_ context: ModelContext, _ book: inout [String: Party]) -> Case {
        let c = Case(context, key: "bathroom-renovation", name: "Bathroom renovation")
        let builder = "Oskar Lenz <oskar@lenz-bau.example>"
        let plumber = "Mia Vogel <mia@vogel-plumbing.example>"

        let quote1 = c.mail(-35, builder, "Quote: bathroom renovation, 6 square metres",
            "Complete work including tiles and fittings: 14,800 euros. Four weeks. Start possible in November.",
            files: [("Quote-Lenz-Bau.pdf", "application/pdf", 320_000)])
        let quote2 = c.mail(-32, "Dieter Wolf <d.wolf@wolf-renovations.example>", "Our quote for the bathroom",
            "Complete work: 12,900 euros, five weeks, start in January. Tiles from a cheaper range.",
            files: [("Quote-Wolf.pdf", "application/pdf", 280_000)])
        c.mail(-26, "Housing Association North <service@wohnen-nord.example>", "Permission for structural changes",
            "Moving the shower needs written permission. Send drawings and the plumber's plan. A decision takes up to three weeks.")
        let tile = c.mail(-20, "Tile Hall <sales@tile-hall.example>", "Your sample tiles are ready",
            "Three samples are ready at the store. The chosen tile has a delivery time of five weeks.")
        let plan = c.mail(-13, plumber, "Plumbing plan for the new shower",
            "The drawing is attached. The floor drain moves 40 centimetres. Cost for the plumbing part: 3,100 euros, included in Lenz's quote.",
            files: [("Plumbing-plan.pdf", "application/pdf", 540_000)])
        let deposit = c.mail(-7, builder, "Confirmation and deposit",
            "Thank you for choosing us. The start is Monday 2 November. Please pay the deposit of 30 percent by 9 October.")
        let update = c.mail(-2, "Housing Association North <service@wohnen-nord.example>", "Your request: still in review",
            "The drawings arrived. The decision on the shower move is expected by 14 October.")

        c.todo("quotes", "Compare the two quotes", .me, from: quote1, quote: "14,800 euros", done: -30)
        c.todo("choose", "Confirm Lenz Bau", .me, from: deposit, quote: "Thank you for choosing us", done: -8)
        c.todo("deposit", "Pay the €4,440 deposit", .me, due: 9, from: deposit, quote: "deposit of 30 percent by 9 October")
        c.todo("permit", "Wait for the shower permission", .other, due: 14, from: update,
               quote: "expected by 14 October")
        c.todo("tiles", "Order the tiles at Tile Hall", .me, due: 2, from: tile, quote: "delivery time of five weeks")
        c.todo("tilesLate", "Ask Oskar about late tiles", .me, due: 4, from: tile, quote: "five weeks")
        c.todo("fixtures", "Choose taps and shower head", .we, due: 10, from: quote1, quote: "tiles and fittings")
        c.todo("bathroom", "Find a place to wash", .me, due: 30, from: quote1, quote: "Four weeks")
        c.waits("deposit", for: "permit")
        c.todo("drain", "Drain moves 40 cm (€3,100)", .unknown, from: plan,
               quote: "The floor drain moves 40 centimetres", info: true)

        c.appointment("Start of the work", 32, "08:00", at: "Bathroom", from: deposit, quote: "Monday 2 November")
        c.appointment("Site visit with Oskar", 6, "17:00", at: "Home", from: deposit, quote: "start")
        c.deadline("Deposit to Lenz Bau", 9, from: deposit, quote: "by 9 October")
        c.deadline("Permission expected", 14, from: update, quote: "14 October")
        c.decision("Lenz Bau, not Wolf Renovations",
                   why: "€2,000 more, but starting in November.",
                   -9, from: [quote1, quote2])
        c.party("Oskar Lenz", "Builder, Lenz Bau", mentions: 2, &book)
        c.party("Dieter Wolf", "Builder, second quote", mentions: 1, &book)
        c.party("Mia Vogel", "Plumber", mentions: 1, &book)
        c.party("Housing Association North", "Landlord, permission", mentions: 2, &book)
        c.party("Tile Hall", "Tile shop", mentions: 1, &book)
        c.link("https://docs.google.com/spreadsheets/d/demo-bath-costs/edit", "Cost overview")
        c.matter.notes = "Keep the receipts for taxes."
        c.summarise("Lenz Bau starts on 2 November, if the shower may move. Tiles take five weeks.",
                    next: "Order the tiles at Tile Hall",
                    why: "Five weeks' delivery: every day counts.", todo: "tiles")
        c.talking = {
            c.cite("T1", "tiles"); c.cite("T2", "deposit"); c.cite("T3", "permit")
            c.note(-2, "📥 1 mail taken in · 1 new task · sorted by Claude Opus\n• Your request: still in review")
            c.ask(0, "Can the work start on 2 November?",
                  lines: [("Only if the permission comes by 14 October as expected.", ["T3"]),
                          ("The tiles take five weeks, so they arrive after the start unless they are ordered now.", ["T1"]),
                          ("The deposit is due on 9 October, before the permission is known.", ["T2"])],
                  cards: [card("new_todo", text: "Ask Oskar to start with the plumbing and the tiles last", due: 4,
                               reason: "Then a late tile delivery does not delay the start.", cites: ["T1"])])
        }
        return c
    }
}
