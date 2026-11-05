import Foundation
import Testing
@testable import MatterCore

/// A link, a detail and a contact typed into their cards in the chat: each card's fields where the
/// card actions read them, and Add only once there is enough.
struct AssistantAddTests {
    @Test func aLinkKeepsItsAddressAndItsName() {
        let card = AssistantAdd.link.asTyped("tenant-portal.example.com/birch-road", "Tenant portal").reply.cards[0]
        #expect(card.kind == .addLink)
        #expect(card.from == "tenant-portal.example.com/birch-road")
        #expect(card.text == "Tenant portal")
    }

    @Test func aLinkWithoutANameIsCalledByItsHost() {
        let card = AssistantAdd.link.asTyped("https://www.carryco.example/quote/482", "").reply.cards[0]
        #expect(card.text == "www.carryco.example")
    }

    @Test func aDetailIsWhatItIsAndWhatItSays() {
        let card = AssistantAdd.detail.asTyped("Customer number", "FN-20391").reply.cards[0]
        #expect(card.kind == .addDetail)
        #expect(card.subject == "Customer number")
        #expect(card.text == "FN-20391")
    }

    @Test func aContactIsANameAndARole() {
        let card = AssistantAdd.contact.asTyped("Ms. Adler", "Neighbour at Birch Road 10").reply.cards[0]
        #expect(card.kind == .addContact)
        #expect(card.text == "Ms. Adler")
        #expect(card.subject == "Neighbour at Birch Road 10")
    }

    @Test func addOnlyOnceThereIsEnough() {
        #expect(!AssistantAdd.detail.isComplete("Customer number", ""))
        #expect(AssistantAdd.detail.isComplete("Customer number", "FN-20391"))
        #expect(!AssistantAdd.link.isComplete("not a link", ""))
        #expect(AssistantAdd.link.isComplete("carryco.example", ""))
        #expect(AssistantAdd.contact.isComplete("Ms. Adler", ""))
        #expect(!AssistantAdd.task.isComplete("  ", ""))
    }

    @Test func keptOnTheDeviceAndSaidSo() {
        for add in [AssistantAdd.link, .detail, .contact] {
            #expect(!add.asksAssistant)
        }
        // With Pro, a task and a note go to the assistant, as typed in the chat; without, kept as typed.
        #expect(AssistantAdd.task.asksAssistant && AssistantAdd.note.asksAssistant)
        for add in AssistantAdd.allCases { #expect(add.asTyped("a", "b").servedBy == DeviceTask.onDevice) }
        #expect(AssistantAdd.of("New detail: Customer number — FN-20391")?.add == .detail)
    }
}

/// With Pro, what the assistant answers for a note picked from the chips: its own `add_note`, or
/// the words as typed when it sent none — never lost to the answer.
struct AssistantAddNoteTests {
    @Test func theAssistantsNoteIsTaken() {
        let card = AssistantPrompt.Reply.Card(kind: .addNote, todo: "t1", text: "Mum prefers mornings", owner: "me", due: nil, reason: "", cites: [])
        let answer = AssistantAsk.Answer(reply: AssistantPrompt.Reply(lines: [], cards: [card], notInFacts: nil), sent: "x", cost: 0, seconds: 0, newNames: 0)
        let settled = AssistantAdd.note.settled(answer, words: "Mum prefers mornings")
        #expect(settled.card == 0)
        #expect(settled.answer.reply.cards[0].todo == "t1")
    }

    @Test func withoutOneTheWordsAreKept() {
        let answer = AssistantAsk.Answer(reply: AssistantPrompt.Reply(lines: [], cards: [], notInFacts: nil), sent: "x", cost: 0, seconds: 0, newNames: 0)
        let settled = AssistantAdd.note.settled(answer, words: "Mum prefers mornings")
        #expect(settled.answer.reply.cards[settled.card].kind == .addNote)
        #expect(settled.answer.reply.cards[settled.card].text == "Mum prefers mornings")
    }
}
