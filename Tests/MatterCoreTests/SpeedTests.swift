import Foundation
import SwiftData
import Testing
@testable import MatterCore

/// How long what the screens work out takes, on a store as big as a busy owner's: forty matters,
/// each with a hundred mails, forty tasks, twenty files, dates and people. Measured, and held to a
/// budget — a slow screen is caught here, not on the owner's iPhone.
@Suite("Speed: what a screen works out, on a big store", .serialized)
@MainActor
struct SpeedTests {
    static let matters = 40

    /// A store as big as a busy owner's.
    static func bigStore() throws -> (ModelContainer, [Matter]) {
        let container = try MatterSchema.container(at: nil)
        let context = container.mainContext
        var made: [Matter] = []
        let start = Date().addingTimeInterval(-200 * 86_400)
        for m in 0..<matters {
            let matter = Matter(key: "matter-\(m)", name: "Matter \(m)")
            context.insert(matter)
            for p in 0..<12 {
                _ = matter.addContact(name: "Person \(m)-\(p)", role: "Role", address: "p\(m)-\(p)@example.com", phone: "", in: context)
            }
            for e in 0..<100 {
                let date = start.addingTimeInterval(Double(e) * 86_400)
                let entry = Entry(title: "Re: Thread \(e % 12) of matter \(m)", from: "Person \(m)-\(e % 12) <p\(m)-\(e % 12)@example.com>", date: date,
                                  source: Source(kind: .mail, pointer: "imap://mail.example/INBOX;UIDVALIDITY=7/;UID=\(m * 1000 + e)",
                                                 messageID: "<\(m)-\(e)@x>", date: date, quote: "A line of the mail \(e)."))
                entry.matter = matter
                context.insert(entry)
            }
            for t in 0..<40 {
                let todo = Todo(text: "Task \(t) of matter \(m), with a few words more", owner: t % 3 == 0 ? .other : .me,
                                due: t % 4 == 0 ? MatterStatus.day(Date().addingTimeInterval(Double(t - 20) * 86_400)) : nil,
                                source: Source(kind: .mail, pointer: "x", messageID: "<\(m)-\(t)@x>"), origin: "t\(m)-\(t)")
                todo.isDone = t % 2 == 0
                todo.matter = matter
                context.insert(todo)
            }
            for d in 0..<20 {
                let document = Document(name: "File \(d).pdf", contentType: "application/pdf", byteCount: 100_000,
                                        source: Source(kind: .mail, pointer: "x", messageID: "<\(m)-\(d)@x>"))
                document.matter = matter
                context.insert(document)
            }
            for a in 0..<10 {
                let appointment = Appointment(what: "Appointment \(a)", day: MatterStatus.day(Date().addingTimeInterval(Double(a * 5 - 20) * 86_400)),
                                              time: "10:00", place: nil, source: Source(kind: .mail, pointer: "x"))
                appointment.matter = matter
                context.insert(appointment)
            }
            made.append(matter)
        }
        try context.save()
        return (container, made)
    }

    /// Milliseconds for one run of the work, the best of three: the first may pay for faulting.
    static func time(_ work: () -> Void) -> Double {
        var best = Double.infinity
        for _ in 0..<3 {
            let began = ContinuousClock.now
            work()
            let took = ContinuousClock.now - began
            best = min(best, Double(took.components.attoseconds) / 1e15 + Double(took.components.seconds) * 1000)
        }
        return best
    }

    @Test("What the screens work out, measured")
    func measured() throws {
        let (container, matters) = try Self.bigStore()
        _ = container
        let one = matters[0]
        var report: [(String, Double)] = []
        report.append(("MatterStatus + next step, one matter", Self.time { _ = MatterStatus(one).nextStep }))
        report.append(("next step, every matter", Self.time { for m in matters { _ = MatterStatus(m).nextStep } }))
        report.append(("record stamp, one matter", Self.time { _ = one.recordStamp }))
        report.append(("record stamp, every matter", Self.time { for m in matters { _ = m.recordStamp } }))
        report.append(("mail threads, one matter", Self.time { _ = MailThreads.build(MatterStatus(one).mailEntries) }))
        report.append(("record links, one matter", Self.time { _ = RecordLinks(one) }))
        report.append(("overview page, every matter", Self.time { _ = OverviewPages().page(for: matters, version: Int.random(in: 0..<1_000_000)) }))
        report.append(("known senders, every matter", Self.time { _ = KnownSenders.addresses(in: matters) }))
        report.append(("week, every matter", Self.time { _ = Week.things(on: MatterStatus.day(Date()), in: matters) }))
        let entries = one.entries ?? []
        report.append(("  · subject keys", Self.time { for e in entries { _ = ThreadMemory.subjectKey(e.title) } }))
        report.append(("  · writer names", Self.time { for e in entries { _ = one.writerName(e.from) } }))
        report.append(("  · reply ids", Self.time { for e in entries { _ = e.replyTo } }))
        report.append(("  · clean", Self.time { for e in entries { _ = MailThreads.clean(e.title) } }))
        for (name, ms) in report { print(String(format: "SPEED %8.2f ms  %@", ms, name)) }
        // The budget, in a debug build: what a screen works out while it draws has to fit a frame
        // or two. About four times what it takes now — slower than that is a step backwards.
        let budget: [String: Double] = [
            "next step, every matter": 40, "mail threads, one matter": 20, "record links, one matter": 15,
            "overview page, every matter": 50, "week, every matter": 25, "MatterStatus + next step, one matter": 4,
        ]
        for (name, ms) in report {
            guard let most = budget[name] else { continue }
            #expect(ms <= most, "\(name): \(String(format: "%.1f", ms)) ms, the budget is \(Int(most)) ms")
        }
    }
}

@Suite("The Calendar sync after a save here asks Calendar only about what changed here")
@MainActor
struct MirrorChangedHereTests {
    @Test("What this side holds as it was when last in step is left alone; anything else is not")
    func unchangedHere() {
        let stamp = ["Zahnarzt", "2026-10-30", "10:00", ""].joined(separator: Mirror.fieldSeparator) + Mirror.sideSeparator
            + ["Zahnarzt", "2026-10-30", "10:00", ""].joined(separator: Mirror.fieldSeparator)
        #expect(Mirror.unchangedHere(["Zahnarzt", "2026-10-30", "10:00", ""], stamp: stamp))
        #expect(!Mirror.unchangedHere(["Zahnarzt", "2026-10-31", "10:00", ""], stamp: stamp))
        #expect(!Mirror.unchangedHere(["Zahnarzt", "2026-10-30", "10:00", ""], stamp: nil))
    }
}
