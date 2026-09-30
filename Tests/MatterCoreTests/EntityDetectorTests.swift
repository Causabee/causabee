import Foundation
import Testing
@testable import MatterCore

/// The rule half is exact and is tested exactly. The tagger half is a model: what it finds
/// depends on the OS it runs on, so the tests here hold it to invariants it must never break
/// rather than to names it happened to find today. Measuring what it finds is the spike's job,
/// and that belongs in the report, not in an assertion.
private let rulesOnly = EntityDetector(runsTagger: false)

@Suite("Finding what would identify somebody")
struct EntityDetectorTests {
    func found(_ text: String, _ detector: EntityDetector = rulesOnly) -> [Entity] {
        detector.entities(in: text, field: .body)
    }

    @Test("An IBAN, spaced as people write it")
    func iban() {
        let hits = found("Bitte auf DE89 3704 0044 0532 0130 00 überweisen.")
        #expect(hits.filter { $0.kind == .iban }.map(\.text) == ["DE89 3704 0044 0532 0130 00"])
    }

    @Test("An IBAN is not also read as a phone number")
    func ibanIsNotAPhoneNumber() {
        let hits = found("IBAN DE89 3704 0044 0532 0130 00")
        #expect(hits.count == 1)
        #expect(hits[0].kind == .iban)
    }

    @Test("Phone numbers, German and international",
          arguments: ["030 0471 2288", "0176 00884410", "+49 30 09778110", "(030) 0471-2288"])
    func phones(number: String) {
        #expect(found("Telefon: \(number)").contains { $0.kind == .phone })
    }

    @Test("A date, an amount and a year are not phone numbers",
          arguments: ["am 30.11.2025", "1.200,00 EUR", "Angebot Nr. 2025-4471", "seit 2023"])
    func notPhones(text: String) {
        #expect(!found(text).contains { $0.kind == .phone })
    }

    @Test("A street, written as one word or as two",
          arguments: ["Honigwabenallee 47", "Wabenhöfer Allee 12", "Pollenfelder Straße 8",
                      "Drohnenberger Str. 3", "Schwarmburger Platz 4", "Summtaler Straße 112a"])
    func streets(address: String) {
        let hits = found("Wir treffen uns in der \(address) um zehn.")
        #expect(hits.filter { $0.kind == .street }.map(\.text) == [address])
    }

    @Test("An English address, where the number comes first")
    func englishStreet() {
        #expect(found("the workshop room at 14 Hivemead Road").filter { $0.kind == .street }
            .map(\.text) == ["14 Hivemead Road"])
    }

    @Test("Five digits and a town")
    func postalCity() {
        #expect(found("10435 Berlin").filter { $0.kind == .postalCity }.map(\.text) == ["10435 Berlin"])
    }

    @Test("A company writes its own name with its legal form on the end",
          arguments: ["Thermotec Nowak GmbH", "Hausverwaltung Berger GmbH", "Northlight Studios Ltd",
                      "Kiezgarten Prenzlauer Berg e. V."])
    func organisations(name: String) {
        #expect(found("Angebot von \(name) vom Montag").contains { $0.kind == .organization })
    }

    @Test("Email addresses, wherever they sit in a sentence")
    func emails() {
        #expect(found("per Mail an post@berger-hv.example oder a.berger@berger-hv.example.")
            .filter { $0.kind == .email }.map(\.text) == ["post@berger-hv.example", "a.berger@berger-hv.example"])
    }

    @Test("Nothing identifiable, nothing found")
    func quiet() {
        #expect(found("Bitte um kurze Rückmeldung bis Freitag.").isEmpty)
    }

    @Test("Every entity's offsets point at its own text, which is what a disguise will use")
    func offsetsAreUsable() {
        let text = """
        Sehr geehrte Frau Berger, anbei das Angebot von Thermotec Nowak GmbH,
        Pollenfelder Straße 8, 10243 Berlin, Telefon +49 30 09778110, IBAN
        DE89 3704 0044 0532 0130 00, Rückfragen an angebote@thermotec.example.
        """
        let source = text as NSString
        for entity in EntityDetector().entities(in: text, field: .body) {
            #expect(entity.start >= 0)
            #expect(entity.start + entity.length <= source.length)
            #expect(source.substring(with: NSRange(location: entity.start, length: entity.length)) == entity.text)
        }
    }

    @Test("No two entities cover the same characters")
    func noOverlaps() {
        let text = "Hausverwaltung Berger GmbH, Wabenhöfer Allee 12, 10435 Berlin, 030 0471 2288"
        let hits = EntityDetector().entities(in: text, field: .body)
        for (index, entity) in hits.enumerated() {
            for other in hits[(index + 1)...] {
                #expect(!entity.range.overlaps(other.range))
            }
        }
    }

    @Test("A match never keeps the whitespace it ran into")
    func matchesAreTrimmed() {
        for entity in found("im Haus Honigwabenallee 47\n  liegt die Wohnung") {
            #expect(entity.text == entity.text.trimmed)
        }
    }

    @Test("Turning the tagger off only ever takes entities away")
    func taggerOnlyAdds() {
        let text = "Annegret Berger von der Hausverwaltung Berger GmbH, Wabenhöfer Allee 12, 10435 Berlin"
        let withTagger = Set(EntityDetector().entities(in: text, field: .body).map(\.text))
        let without = Set(rulesOnly.entities(in: text, field: .body).map(\.text))
        #expect(without.isSubset(of: withTagger))
        #expect(without.contains("Wabenhöfer Allee 12"))
    }

    @Test("A pronoun is never a name, whatever the name tagger says")
    func pronounsAreNotNames() {
        let text = "Guten Tag, können Sie mir bitte das Angebot schicken? Wir danken Ihnen sehr."
        let names = EntityDetector(language: .german).entities(in: text, field: .body).filter { $0.source == .onDevice }
        for pronoun in ["Sie", "Wir", "Ihnen"] {
            #expect(!names.contains { $0.text.split(separator: " ").contains(Substring(pronoun)) }, "\(pronoun) in \(names.map(\.text))")
        }
    }

    // MARK: Headers

    @Test("A sender is their address and their name, both")
    func senderIsTwoEntities() {
        let email = EMLParser.parse(source: "From: Annegret Berger <post@berger-hv.example>\n\nx",
                                    url: URL(fileURLWithPath: "/tmp/x.eml"))
        let hits = rulesOnly.entities(in: email).filter { $0.field == .from }
        #expect(hits.contains { $0.kind == .email && $0.text == "post@berger-hv.example" })
        #expect(hits.contains { $0.kind == .person && $0.text == "Annegret Berger" })
    }

    @Test("A display name with a legal form on it is a company, whatever the tagger thinks")
    func incorporatedSenderIsAnOrganisation() {
        let email = EMLParser.parse(source: "From: Hausverwaltung Berger GmbH <post@berger-hv.example>\n\nx",
                                    url: URL(fileURLWithPath: "/tmp/x.eml"))
        let name = EntityDetector().entities(in: email).first { $0.field == .from && $0.kind == .organization }
        #expect(name?.text == "Hausverwaltung Berger GmbH")
    }

    @Test("A sender with no display name is just the address")
    func bareSender() {
        let email = EMLParser.parse(source: "From: post@berger-hv.example\n\nx",
                                    url: URL(fileURLWithPath: "/tmp/x.eml"))
        let hits = rulesOnly.entities(in: email).filter { $0.field == .from }
        #expect(hits.map(\.kind) == [.email])
    }
}

@Suite("What the tagger missed, found by what stands around it")
struct ContextRuleTests {
    let rules = EntityDetector(runsTagger: false)

    func found(_ text: String) -> [(Entity.Kind, String)] {
        rules.entities(in: text, field: .body).map { ($0.kind, $0.text) }
    }

    @Test("A name after a title or a greeting, and not a closing or a role", arguments: [
        ("Hallo Frau Behrend,\ndie Unterlagen", "Frau Behrend"),
        ("Inh. Petra Blume\nSteuernr", "Inh. Petra Blume"),
        ("mit Herrn Dr. Brenner gesprochen", "Herrn Dr. Brenner"),
        ("Hallo Georg,\nanbei", "Georg"),
    ])
    func names(text: String, name: String) {
        #expect(found(text).contains { $0.0 == .person && $0.1 == name }, "\(found(text))")
    }

    @Test("Not a name", arguments: ["Liebe Grüße\nJan", "Sehr geehrte Frau Rechtsanwältin,", "Hallo zusammen,", "Herr Hausmeister kommt",
                                    "Liebe Beiratsmitglieder,", "Liebe Angehörige,"])
    func notNames(text: String) {
        #expect(!found(text).contains { $0.0 == .person }, "\(found(text))")
    }

    @Test("A reference number by its label, or by its shape — never a date or an amount", arguments: [
        ("Versicherungsnummer: X8200001234567", "X8200001234567"),
        ("Vorgang-Nr.: 2.345.678 / Kunden-Nr. 123.456", "2.345.678"),
        ("Ust-Idnr. DE123 456 789\n", "DE123 456 789"),
        ("Aktenzeichen 12 O 345/26", "12 O 345/26"),
        ("die Nummer 8200001234567 bitte", "8200001234567"),
    ])
    func references(text: String, number: String) {
        #expect(found(text).contains { $0.0 == .reference && $0.1 == number }, "\(found(text))")
    }

    @Test("Dates and amounts stay", arguments: ["am 22.07.2026 um 10:00", "Kosten 1.234,56 €", "Zimmer 12, 3. Stock"])
    func notReferences(text: String) {
        #expect(!found(text).contains { $0.0 == .reference }, "\(found(text))")
    }

    @Test("A number learned with its spaces is disguised without them too")
    func bareNumber() {
        var p = Pseudonymizer(mode: .placeholder)
        p.learn(rules.entities(in: "Ust-Idnr. DE123 456 789\n", field: .body))
        let out = p.disguiser.apply("USt: DE123456789 und DE123 456 789").text
        #expect(!out.contains("313"), "\(out)")
    }
}

