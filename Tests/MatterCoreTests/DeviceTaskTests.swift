import Foundation
import Testing
@testable import MatterCore

/// A task typed into its card without Pro: a day in its words becomes its date, by rule, and is
/// taken out of them — the words otherwise as typed.
struct DeviceTaskTests {
    /// Thursday, 5 November 2026, at noon.
    private let today: Date = {
        var parts = DateComponents(year: 2026, month: 11, day: 5, hour: 12)
        parts.timeZone = .current
        return Calendar.current.date(from: parts)!
    }()

    @Test func aWeekdayBecomesTheDateAndLeavesTheWords() {
        let filled = DeviceTask.card("Call Ms. Adler on Friday about the van", today: today)
        #expect(filled.text == "Call Ms. Adler about the van")
        #expect(filled.due == "2026-11-06")
        #expect(filled.time == nil)
        #expect(filled.owner == "me")
    }

    @Test func aDayWithItsTime() {
        let filled = DeviceTask.card("Hand over the keys on 26 November at 10:00", today: today)
        #expect(filled.due == "2026-11-26")
        #expect(filled.time == "10:00")
        #expect(!filled.text.contains("November"))
    }

    @Test func noDayKeepsTheWordsAsTyped() {
        let filled = DeviceTask.card("  Ask Nina about the contract ", today: today)
        #expect(filled.text == "Ask Nina about the contract")
        #expect(filled.due == nil)
    }

    @Test func germanWordsToo() {
        let filled = DeviceTask.card("Frau Adler am Freitag wegen des Umzugswagens anrufen", today: today)
        #expect(filled.due == "2026-11-06")
        #expect(filled.text == "Frau Adler wegen des Umzugswagens anrufen")
    }

    @Test func aQuestionNeedsPro() {
        let answer = DeviceTask.answer(nil, onPad: false, inMatter: true)
        #expect(answer.reply.cards.isEmpty)
        #expect(answer.reply.lines.first?.text.contains("Pro") == true)
        #expect(answer.sent.isEmpty)
    }

    @Test func somethingToDoComesAsATaskToAdd() {
        let filled = DeviceTask.Filled(text: "Call Ms. Adler about the van", due: "2026-11-06", time: nil, owner: "me")
        let answer = DeviceTask.answer(filled, onPad: false, inMatter: true)
        #expect(answer.reply.cards.first?.kind == .newTodo)
        #expect(answer.reply.cards.first?.due == "2026-11-06")
        #expect(answer.reply.cards.first?.reason.contains("iPhone") == true)
    }
}

/// Without Apple's model, the words' own shape says whether they are something to do.
struct DeviceTaskShapeTests {
    @Test func aLineThatBeginsWithAVerbIsATask() {
        #expect(DeviceTask.readsAsTask("Call the plumber on Monday about the boiler"))
        #expect(DeviceTask.readsAsTask("Book Carry & Co for the 25th"))
        #expect(DeviceTask.readsAsTask("Frau Adler am Freitag anrufen"))
    }

    @Test func aQuestionIsNot() {
        #expect(!DeviceTask.readsAsTask("When does the van come?"))
        #expect(!DeviceTask.readsAsTask("Who has the spare key"))
        #expect(!DeviceTask.readsAsTask("Wann kommt der Umzugswagen"))
    }
}
