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
        for add in [AssistantAdd.link, .detail, .contact, .note] {
            #expect(!add.asksAssistant)
            #expect(add.asTyped("a", "b").servedBy == DeviceTask.onDevice)
        }
        #expect(AssistantAdd.of("New detail: Customer number — FN-20391")?.add == .detail)
    }
}
