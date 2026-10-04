import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("The matter's vault: contacts and details put in by hand")
@MainActor
struct VaultTests {
    func matter(_ context: ModelContext) throws -> Matter {
        let matter = try Matter.make(named: "Reha Mama", in: context)
        try context.save()
        return matter
    }

    @Test("A contact added by hand is in the matter, with its role and how to reach it")
    func contact() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = try matter(context)
        let hkk = try #require(matter.addContact(name: "HKK", role: "Insurer", address: "reha@hkk.de", phone: "", in: context))
        try context.save()
        #expect(matter.parties.map(\.name) == ["HKK"])
        #expect(hkk.address == "reha@hkk.de")
        #expect(hkk.phone == nil)
        #expect(hkk.addedAt != nil)
        #expect(matter.membership(of: hkk)?.role == "Insurer")
    }

    @Test("Added twice, it is one contact: the second fills in what the first left out")
    func twice() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = try matter(context)
        matter.addContact(name: "HKK", role: "Insurer", address: "reha@hkk.de", phone: "", in: context)
        matter.addContact(name: "hkk", role: "", address: "", phone: "0421 3655 0", in: context)
        try context.save()
        #expect(matter.parties.count == 1)
        #expect(matter.parties.first?.address == "reha@hkk.de")
        #expect(matter.parties.first?.phone == "0421 3655 0")
    }

    @Test("Without a name there is no contact")
    func nameless() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = try matter(context)
        #expect(matter.addContact(name: "  ", role: "Insurer", address: "reha@hkk.de", phone: "", in: context) == nil)
        #expect(matter.parties.isEmpty)
    }

    @Test("A detail is kept with its matter and whose it is — and its value never goes to the assistant")
    func detail() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = try matter(context)
        let hkk = matter.addContact(name: "HKK", role: "Insurer", address: "", phone: "", in: context)
        try #require(matter.addDetail(label: "Versichertennummer", value: "A 123 456 789", of: hkk, in: context))
        try context.save()
        #expect(matter.sortedDetails.map(\.label) == ["Versichertennummer"])
        #expect(matter.sortedDetails.first?.party?.name == "HKK")
        let facts = FactSheet.facts(for: [matter], today: "2026-10-04")
        #expect(facts.text.contains("Versichertennummer (HKK)"))
        #expect(!facts.text.contains("123 456 789"))
        #expect(matter.addDetail(label: "", value: "x", in: context) == nil)
    }
}
