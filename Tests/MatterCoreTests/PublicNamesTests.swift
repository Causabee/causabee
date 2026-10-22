import Foundation
import Testing
@testable import MatterCore

/// A made-up brand, so no other test that runs at the same time is touched by the list.
@Suite(.serialized)
struct PublicNamesTests {
    private func entity(_ kind: Entity.Kind, _ text: String) -> Entity {
        Entity(kind: kind, text: text, field: .body, start: 0, length: (text as NSString).length, source: .rule)
    }

    @Test func aPublicNameIsNotDisguisedAndEverythingElseStillIs() {
        PublicNames.set(["Wanderlustia"])
        defer { PublicNames.set([]) }
        var pseudonymizer = Pseudonymizer(mode: .placeholder)
        let skipped = pseudonymizer.learn([entity(.organization, "Wanderlustia Inc."), entity(.person, "Annegret Berger")])
        #expect(skipped.contains { $0.text == "Wanderlustia Inc." && $0.reason.contains("public") })
        let out = pseudonymizer.disguiser.apply("Annegret Berger booked the hotel with Wanderlustia Inc. in March.").text
        #expect(out.contains("Wanderlustia Inc."))
        #expect(!out.contains("Annegret"))
    }

    @Test func aNameLearnedBeforeItWasMarkedIsLeftAloneToo() {
        var pseudonymizer = Pseudonymizer(mode: .placeholder)
        pseudonymizer.learn([entity(.organization, "Wanderlustia")])
        #expect(!pseudonymizer.disguiser.apply("Refund from Wanderlustia").text.contains("Wanderlustia"))
        PublicNames.set(["Wanderlustia"])
        defer { PublicNames.set([]) }
        #expect(pseudonymizer.disguiser.apply("Refund from Wanderlustia").text == "Refund from Wanderlustia")
    }

    @Test func aQuestionNamingAPublicNameMayGoOut() {
        let people = ["Wanderlustia", "Helga Voss"]
        #expect(WebLookup.refusal("How long does Wanderlustia take to refund a cancelled hotel?", personal: WebLookup.personal(people)) != nil)
        PublicNames.set(["Wanderlustia"])
        defer { PublicNames.set([]) }
        #expect(WebLookup.refusal("How long does Wanderlustia take to refund a cancelled hotel?", personal: WebLookup.personal(people)) == nil)
        #expect(WebLookup.refusal("Does Helga get the refund?", personal: WebLookup.personal(people)) != nil)
    }

    @Test func aPublicNameStaysPublicInAnotherSpelling() {
        PublicNames.set(["Wanderlustia"])
        defer { PublicNames.set([]) }
        // As a company is kept: its name, and how a booking site wrote it.
        let people = ["Wanderlustia", "Tripvista", "Tripvista/Wanderlustia"]
        #expect(WebLookup.refusal("Where are Wanderlustia car rental stations located?", personal: WebLookup.personal(people)) == nil)
        #expect(WebLookup.refusal("Does Tripvista refund it?", personal: WebLookup.personal(people)) != nil)
    }
}
