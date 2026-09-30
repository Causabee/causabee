import Foundation
import Testing
@testable import MatterCore

@Suite("Names hidden and put back, in the owner's own sentences")
struct NameRestoreTests {
    @Test("A name learned in capitals does not take the ordinary word")
    func shouted() {
        let pseudonymizer = Pseudonymizer(mode: .placeholder, entries: [
            .init(kind: .person, original: "BERLIN SONNE", standIn: "[Person A]"),
            .init(kind: .person, original: "SONNE", standIn: "[Person A]", partOf: "BERLIN SONNE"),
        ])
        let out = pseudonymizer.disguiser.apply("Die sonne scheint, SONNE steht im Briefkopf.").text
        #expect(out == "Die sonne scheint, [Person A] steht im Briefkopf.")
    }

    @Test("Last name first comes back as first name first, and beside the surname tag it is one name")
    func surnameFirst() {
        let pseudonymizer = Pseudonymizer(mode: .placeholder, entries: [
            .init(kind: .person, original: "Lindner, Petra", standIn: "[Person A]"),
            .init(kind: .person, original: "Petra", standIn: "[Person A]", partOf: "Lindner, Petra"),
            .init(kind: .person, original: "Lindner", standIn: "[Person B]", partOf: "Lindner, Petra"),
        ])
        #expect(pseudonymizer.restorer.apply("Sehr geehrte Frau [Person A] [Person B],").text == "Sehr geehrte Frau Petra Lindner,")
        #expect(pseudonymizer.restorer.apply("Grüße an [Person A].").text == "Grüße an Petra Lindner.")
    }

    @Test("A name that ran on into a signature's Tel comes back without it")
    func signatureLabel() {
        let pseudonymizer = Pseudonymizer(mode: .placeholder, entries: [
            .init(kind: .person, original: "Frau Berger", standIn: "Frau [Person A]"),
            .init(kind: .person, original: "Frau Berger Tel", standIn: "Frau [Person A]"),
        ])
        #expect(pseudonymizer.restorer.apply("Guten Tag Frau [Person A],").text == "Guten Tag Frau Berger,")
        let found = EntityDetector(runsTagger: false).entities(in: "Ihre Frau Berger Tel.: 0331 1234567", field: .body)
        #expect(found.contains { $0.kind == .person && $0.text == "Frau Berger" })
        #expect(!found.contains { $0.text.hasSuffix("Tel") })
    }
}
