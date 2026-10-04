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

@Suite("What a photographed letter offers the vault")
@MainActor
struct VaultOffersTests {
    static let letter = """
        hkk Krankenkasse
        Martinistraße 26, 28195 Bremen
        Telefon 0421 3655 0
        Fax 0421 3655 3700
        reha@hkk.de

        Versichertennummer: A123456789
        Unser Zeichen: RH 4711/26

        Sehr geehrte Frau Muster,
        bitte senden Sie uns den Befundbericht bis zum 20.10.2026.
        """

    @Test("The insurer's address and phone, not its fax, and the numbers with their labels")
    func letter() {
        let offers = VaultOffers(text: Self.letter)
        #expect(offers.contact == .init(name: "HKK", address: "reha@hkk.de", phone: "0421 3655 0"))
        #expect(offers.details == [.init(label: "Versichertennummer", value: "A123456789"), .init(label: "Unser Zeichen", value: "RH 4711/26")])
    }

    @Test("The owner's own address is no contact, and a private mailbox gives no name")
    func own() {
        #expect(VaultOffers(text: "Von: me@chille.example\nKundennummer 998877", own: ["me@chille.example"]).contact == nil)
        #expect(VaultOffers(text: "Schreib mir: anna@gmail.com").contact == nil)
        #expect(VaultOffers(text: "Nichts von Belang, am 12.10.2026 um 10 Uhr.").isEmpty)
    }

    @Test("A company is named by its own name before its address's")
    func company() {
        let offers = VaultOffers(text: "Thermotec Nowak GmbH\ninfo@thermotec.example\nAuftragsnummer: 2026-0042")
        #expect(offers.contact?.name == "Thermotec Nowak GmbH")
        #expect(offers.details.first == .init(label: "Auftragsnummer", value: "2026-0042"))
    }

    @Test("Taken in, the contact is in the matter and the details are its; twice is once")
    func taken() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = try Matter.make(named: "Reha Mama", in: context)
        let offers = VaultOffers(text: Self.letter)
        matter.take(offers, role: "Insurer", in: context)
        matter.take(offers, in: context)
        try context.save()
        #expect(matter.parties.map(\.name) == ["HKK"])
        #expect(matter.sortedDetails.map(\.value).sorted() == ["A123456789", "RH 4711/26"])
        #expect(matter.sortedDetails.allSatisfy { $0.party?.name == "HKK" })
    }

    @Test("A date of birth is disguised by the word before it; a deadline's date is not")
    func birth() {
        let found = EntityDetector().ruleMatches(in: "Geburtsdatum Ulrike Chille, 11.11.1951. Bitte bis 20.10.2026 antworten.", field: .body)
        #expect(found.contains { $0.kind == .reference && $0.text == "11.11.1951" })
        #expect(!found.contains { $0.text.contains("20.10.2026") })
    }
}
