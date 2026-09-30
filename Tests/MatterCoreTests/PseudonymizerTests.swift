import Foundation
import Testing
@testable import MatterCore

/// Entities are made by hand here rather than by the detector, so these tests hold the disguise
/// to what it does with what it is given — not to what the tagger happens to find on this OS.
private func found(_ kind: Entity.Kind, _ text: String, by source: Entity.Source = .rule) -> Entity {
    Entity(kind: kind, text: text, field: .body, start: 0, length: (text as NSString).length, source: source)
}

private func learned(_ mode: Pseudonymizer.Mode, _ entities: [Entity]) -> Pseudonymizer {
    var pseudonymizer = Pseudonymizer(mode: mode)
    pseudonymizer.learn(entities)
    return pseudonymizer
}

@Suite("Disguising a mail before it leaves the device")
struct PseudonymizerTests {
    let hausverwaltung = [
        found(.person, "Annegret Berger", by: .onDevice),
        found(.organization, "Hausverwaltung Berger GmbH"),
        found(.street, "Honigtauer Str. 14"),
        found(.postalCity, "10437 Berlin"),
        found(.email, "a.berger@berger-hv.example"),
        found(.phone, "030 0471 2288"),
        found(.iban, "DE89 3704 0044 0532 0130 00"),
    ]

    let letter = """
    Sehr geehrte Frau Berger,
    die Begehung in der Honigtauer Str 51 ist am 9. Oktober. WEG Honigtauer, 10437 Berlin.
    Rückfragen an a.berger@berger-hv.example oder 030 0471 2288, IBAN DE89 3704 0044 0532 0130 00.
    Berlin, im September. Annegret Berger, Hausverwaltung Berger GmbH
    """

    @Test("Nothing that was learned survives, in either mode", arguments: Pseudonymizer.Mode.allCases)
    func nothingSurvives(mode: Pseudonymizer.Mode) {
        let out = learned(mode, hausverwaltung).disguiser.apply(letter).text
        for word in ["Berger", "Annegret", "Honigtauer", "Berlin", "10437", "berger-hv", "0471", "0532"] {
            #expect(!out.contains(word), "\(word) reached the disguised text: \(out)")
        }
    }

    @Test("Stand-ins: what comes back is exactly what went in")
    func roundTrip() {
        let pseudonymizer = learned(.standin, hausverwaltung)
        let disguised = pseudonymizer.disguiser.apply(letter).text
        #expect(disguised != letter)
        #expect(pseudonymizer.restore(disguised) == letter.precomposedStringWithCanonicalMapping)
    }

    /// `[Person A]` stood for `Annegret Berger` and for `Berger`, so the way back cannot know
    /// which was written. It brings the fullest one, which is what a fact about a party wants.
    @Test("Placeholders: every tag comes back, as the fullest name it stood for")
    func placeholderRoundTrip() {
        let pseudonymizer = learned(.placeholder, hausverwaltung)
        let restored = pseudonymizer.restore(pseudonymizer.disguiser.apply(letter).text)
        #expect(!restored.contains("["))
        #expect(pseudonymizer.restore("[Person A] schreibt") == "Annegret Berger schreibt")
    }

    @Test("Placeholders: one tag for one person, and a Frau stays readable")
    func placeholderPerson() {
        let pseudonymizer = learned(.placeholder, hausverwaltung)
        let out = pseudonymizer.disguiser.apply("Annegret Berger. Frau Berger. Berger. Annegret.").text
        #expect(out == "[Person A]. Frau [Person A]. [Person A]. [Person A].")
    }

    @Test("Three people known only with a title get three tags, not one")
    func titledPeopleApart() {
        // "Kurz" and "Post" are ordinary words and "Li" is short, so none is learned on its own;
        // the tag then stands only inside "Frau [Person A]" — and must still count as handed out.
        let pseudonymizer = learned(.placeholder, [found(.person, "Frau Kurz"), found(.person, "Herr Li"), found(.person, "Frau Post")])
        let tags = ["Frau Kurz", "Herr Li", "Frau Post"].map { pseudonymizer.disguiser.apply($0).text }
        #expect(Set(tags).count == 3, "\(tags)")
        #expect(pseudonymizer.restorer.apply(tags[0]).text == "Frau Kurz")
        #expect(pseudonymizer.restorer.apply(tags[2]).text == "Frau Post")
    }

    @Test("A shared tag comes back as the plainest full name, not the longest")
    func plainestNameComesBack() {
        let pseudonymizer = learned(.placeholder, [
            found(.person, "Jan Kramer via TestFlight"),
            found(.person, "Frau Kramer"),
            found(.person, "Jan Kramer"),
            found(.person, "Robin Keller Contractor"),
            found(.person, "Robin Keller"),
        ])
        let me = pseudonymizer.standIn(for: "Jan Kramer") ?? ""
        let robbie = pseudonymizer.standIn(for: "Robin Keller") ?? ""
        #expect(pseudonymizer.restore(me) == "Jan Kramer")
        #expect(pseudonymizer.restore(robbie) == "Robin Keller")
        #expect(pseudonymizer.standIn(for: "Jan Kramer via TestFlight") == "\(me) via [Company A]")
    }

    @Test("A company's name is learned without its legal form")
    func companyWithoutLegalForm() {
        let entities = [found(.organization, "Thermotec Nowak GmbH")]
        for mode in Pseudonymizer.Mode.allCases {
            let out = learned(mode, entities).disguiser.apply("das Angebot von Thermotec Nowak").text
            #expect(!out.contains("Thermotec"), "\(mode): \(out)")
        }
    }

    @Test("Stand-ins keep the shape: the title, the legal form, the kind of business, the house number")
    func standInShape() throws {
        let pseudonymizer = learned(.standin, hausverwaltung + [found(.person, "Garcia, Mariana")])

        let frau = try #require(pseudonymizer.disguiser.apply("Frau Berger").text.split(separator: " ").map(String.init))
        #expect(frau.count == 2 && frau[0] == "Frau")

        let company = try #require(pseudonymizer.standIn(for: "Hausverwaltung Berger GmbH"))
        #expect(company.hasPrefix("Hausverwaltung ") && company.hasSuffix(" GmbH"))
        // The company was named after the person, and in disguise it still is.
        #expect(company.split(separator: " ")[1] == frau[1])

        let street = try #require(pseudonymizer.standIn(for: "Honigtauer Str. 14"))
        #expect(street.contains(" Str. ") && street.last?.isNumber == true && !street.hasSuffix(" 51"))

        #expect(pseudonymizer.standIn(for: "Garcia, Mariana")?.contains(", ") == true)
    }

    @Test("A stand-in is never one of the originals, even when the original is in the pool")
    func standInIsNeverAnOriginal() {
        let entities = [found(.person, "Birgit Albers"), found(.person, "Jonas Brandt"), found(.person, "Heike Dietz")]
        let pseudonymizer = learned(.standin, entities)
        let originals = Set(entities.flatMap { $0.text.split(separator: " ").map(String.init) })
        for entry in pseudonymizer.entries {
            for word in entry.standIn.split(separator: " ") {
                #expect(!originals.contains(String(word)), "\(entry.original) became \(entry.standIn)")
            }
        }
    }

    @Test("Numbers keep their shape and lose their digits")
    func numbers() throws {
        let pseudonymizer = learned(.standin, hausverwaltung + [found(.phone, "+49 30 09778110")])
        let phone = try #require(pseudonymizer.standIn(for: "030 0471 2288"))
        #expect(phone.hasPrefix("03") && phone.count == "030 0471 2288".count && phone != "030 0471 2288")
        #expect(try #require(pseudonymizer.standIn(for: "+49 30 09778110")).hasPrefix("+49 "))
        // Written without a space, it once kept every digit and never came back.
        let unspaced = learned(.standin, [found(.phone, "+493009778110")]).standIn(for: "+493009778110")
        #expect(unspaced?.hasPrefix("+49") == true && unspaced != "+493009778110")
        let iban = try #require(pseudonymizer.standIn(for: "DE89 3704 0044 0532 0130 00"))
        #expect(iban.hasPrefix("DE") && iban.count == 27 && iban != "DE89 3704 0044 0532 0130 00")
    }

    @Test("The tagger's common-word guesses are left alone, and said to be")
    func taggerNoise() {
        var pseudonymizer = Pseudonymizer(mode: .placeholder)
        let skipped = pseudonymizer.learn([
            found(.person, "Sie", by: .onDevice),
            found(.organization, "Mit", by: .onDevice),
            found(.place, "Eigentuemer Honigwabenallee 47", by: .onDevice),
            found(.person, "Martin", by: .onDevice),
        ])
        #expect(Set(skipped.map(\.text)) == ["Sie", "Mit", "Eigentuemer Honigwabenallee 47"])
        #expect(pseudonymizer.disguiser.apply("Mit Sie und Martin").text == "Mit Sie und [Person A]")
    }

    @Test("The ordinary words at the edge of a tagger's span come off; a misread sentence is dropped whole")
    func trimming() {
        var pseudonymizer = Pseudonymizer(mode: .placeholder)
        let skipped = pseudonymizer.learn([
            found(.person, "Liebe Frau Stein", by: .onDevice),
            found(.person, "Bis Montag", by: .onDevice),
            found(.person, "Sie behalten jederzeit den Kalender", by: .onDevice),
        ])
        #expect(pseudonymizer.standIn(for: "Frau Stein") == "Frau [Person A]")
        #expect(pseudonymizer.standIn(for: "Liebe") == nil)
        #expect(pseudonymizer.standIn(for: "Montag") == nil)
        #expect(pseudonymizer.standIn(for: "Sie") == nil)
        #expect(Set(skipped.map(\.text)).isSuperset(of: ["Bis Montag", "Sie behalten jederzeit den Kalender"]))
    }

    @Test("A lowercase surname or a `von` does not make a name a sentence")
    func lowercaseInsideAName() {
        let pseudonymizer = learned(.placeholder, [
            found(.person, "Elisa ueckerhof", by: .onDevice),
            found(.person, "Jonas von Ostwerth", by: .onDevice),
            found(.person, "wendgard wirtz"),
        ])
        #expect(pseudonymizer.standIn(for: "Elisa ueckerhof") != nil)
        #expect(pseudonymizer.standIn(for: "Jonas von Ostwerth") != nil)
        #expect(pseudonymizer.disguiser.apply("Herr Wirtz").text == "Herr [Person C]")
    }

    @Test("A surname the tagger rarely finds alone is still learned from a full name")
    func partsAreNotOutvoted() {
        let prose = String(repeating: "Hausmeister Brenner kommt. Brenner sagt. ", count: 10)
        var pseudonymizer = Pseudonymizer(mode: .placeholder)
        pseudonymizer.learn([found(.person, "Karl Brenner", by: .onDevice)], vocabulary: Vocabulary([prose]))
        #expect(pseudonymizer.standIn(for: "Brenner") != nil)
    }

    @Test("A title is never learned as a name, not even out of a company's")
    func titleIsNeverAName() {
        let pseudonymizer = learned(.placeholder, [found(.organization, "Frau e.V."), found(.person, "Abend Frau", by: .onDevice)])
        #expect(pseudonymizer.standIn(for: "Frau e.V.") != nil)
        #expect(pseudonymizer.disguiser.apply("Liebe Frau Weber").text == "Liebe Frau Weber")
    }

    @Test("A noun the tagger passes over nearly every time is not a name; one it finds is")
    func nounsTheTaggerIgnores() {
        let prose = String(repeating: "Rückfragen bitte an Brenner. ", count: 10)
        var pseudonymizer = Pseudonymizer(mode: .placeholder)
        let entities = [found(.person, "Rückfragen", by: .onDevice)]
            + Array(repeating: found(.person, "Brenner", by: .onDevice), count: 8)
        pseudonymizer.learn(entities, vocabulary: Vocabulary([prose]))
        #expect(pseudonymizer.standIn(for: "Rückfragen") == nil)
        #expect(pseudonymizer.standIn(for: "Brenner") != nil)
    }

    @Test("What a rule found is trusted however rarely the tagger agrees")
    func rulesAreNotOutvoted() {
        let prose = String(repeating: "WEG Honigtauer. ", count: 20)
        var pseudonymizer = Pseudonymizer(mode: .placeholder)
        pseudonymizer.learn([found(.street, "Honigtauer Str. 14")], vocabulary: Vocabulary([prose]))
        #expect(pseudonymizer.standIn(for: "Honigtauer") != nil)
    }

    @Test("A rule's find is never skipped, however short")
    func rulesAreTrusted() {
        var pseudonymizer = Pseudonymizer(mode: .placeholder)
        #expect(pseudonymizer.learn([found(.organization, "WEG AG")]).isEmpty)
        #expect(pseudonymizer.standIn(for: "WEG AG") != nil)
    }

    @Test("Whole words only, whatever the case, however the umlaut was encoded")
    func matching() {
        let pseudonymizer = learned(.placeholder, [found(.person, "Sebastian Süß")])
        let decomposed = "Herr Su\u{0308}ß, SÜß und die Bergerstraße"
        #expect(pseudonymizer.disguiser.apply(decomposed).text == "Herr [Person A], [Person A] und die Bergerstraße")
    }

    @Test("A mapping read back carries on where it stopped")
    func mappingCarriesOn() throws {
        let first = learned(.placeholder, [found(.person, "Annegret Berger")])
        let data = try JSONEncoder().encode(first.entries)
        var second = Pseudonymizer(mode: .placeholder, entries: try JSONDecoder().decode([Pseudonymizer.Entry].self, from: data))
        second.learn([found(.person, "Tomasz Wierzbicki"), found(.person, "Annegret Berger")])
        #expect(second.standIn(for: "Annegret Berger") == "[Person A]")
        #expect(second.standIn(for: "Tomasz Wierzbicki") == "[Person B]")
    }

    @Test("The same folder gives the same stand-ins every time")
    func deterministic() {
        #expect(learned(.standin, hausverwaltung).entries == learned(.standin, hausverwaltung).entries)
    }

    @Test("A person and their company in one display name are learned as each")
    func displayNameWithCompany() {
        let pseudonymizer = learned(.placeholder, [found(.person, "Süß, Sebastian (Radwerk Berlin GmbH)")])
        let out = pseudonymizer.disguiser.apply("Süß, Sebastian (Radwerk Berlin GmbH) und Radwerk Berlin").text
        #expect(!out.contains("Süß") && !out.contains("Radwerk"))
    }
}

@Suite("The pipeline with a disguise in it")
struct DisguisedSpikeTests {
    @Test("A name found in one mail is disguised in all of them, and bulk mail is not touched")
    func folder() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("disguise-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let mails = [
            "01.eml": "From: someone@example.net\nSubject: Heizung\n\nDie Heizung in der Honigwabenallee ist kaputt.",
            "02.eml": "From: Hausverwaltung Berger GmbH <post@berger-hv.example>\n\nHonigwabenallee 47, 10435 Berlin",
            "03.eml": "From: news@shop.example\nList-Unsubscribe: <https://shop.example/x>\n\nAngebot Honigwabenallee 47",
        ]
        for (name, source) in mails {
            try source.write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }

        let spike = Spike(detector: EntityDetector(runsTagger: false))
        let report = try spike.run(folder: folder, log: nil, pseudonymizer: Pseudonymizer(mode: .placeholder))
        let byFile = Dictionary(uniqueKeysWithValues: report.outcomes.map { ($0.email.source.lastPathComponent, $0.judgement) })

        // Mail 1 names the street without a number, so no rule finds it there. Mail 2 taught it.
        let first = try #require(byFile["01.eml"]?.disguise)
        #expect(!first.body.contains("Honigwabenallee"))
        #expect(byFile["01.eml"]?.stages == Spike.stages)

        #expect(byFile["03.eml"]?.disguise == nil)
        #expect(byFile["03.eml"]?.stages.contains("pseudonymize") == false)
        #expect(report.pseudonymizer?.standIn(for: "Honigwabenallee") != nil)
    }
}

@Suite("Two people with one name in common are still two people")
struct SharedNameTests {
    let people = [
        found(.person, "Sebastian Albers"),
        found(.person, "Sebastian Süß"),
        found(.person, "Jan Kramer"),
        found(.person, "Greta Kramer"),
        found(.person, "Herr Albers"),
        found(.person, "Albers, Sebastian"),
    ]

    @Test("Each full name has its own tag; the same first and last name share one")
    func ownTags() throws {
        let p = learned(.placeholder, people)
        let albers = try #require(p.standIn(for: "Sebastian Albers"))
        #expect(p.standIn(for: "Sebastian Süß") != albers)
        #expect(p.standIn(for: "Greta Kramer") != p.standIn(for: "Jan Kramer"))
        #expect(p.standIn(for: "Albers, Sebastian") == albers)
        #expect(p.standIn(for: "Herr Albers") == "Herr \(albers)")
        #expect(learned(.placeholder, people + [found(.person, "'Jan Kramer'")]).standIn(for: "'Jan Kramer'")
                == p.standIn(for: "Jan Kramer"))
    }

    @Test("Each one comes back as who they were, and a shared word alone comes back as itself")
    func wayBack() {
        let p = learned(.placeholder, people)
        let text = "Sebastian Süß und Sebastian Albers. Meine Mutter Greta Kramer, ich Jan Kramer. Hallo Sebastian, Familie Kramer"
        let disguised = p.disguiser.apply(text).text
        for word in ["Sebastian", "Süß", "Albers", "Greta", "Kramer", "Jan"] {
            #expect(!disguised.contains(word), "\(word) reached the disguised text: \(disguised)")
        }
        #expect(p.restore(disguised) == text)
    }

    @Test("A shared first name next to the full name comes back once, not twice")
    func noDoubleName() {
        let p = learned(.placeholder, [found(.person, "Petra Lindner"), found(.person, "Petra Schaller"),
                                       found(.person, "Dr. Petra")])
        let disguised = p.disguiser.apply("Dr. Petra\u{00A0}Lindner").text
        #expect(!disguised.contains("Petra"))
        let cornelia = p.standIn(for: "Petra") ?? "", harz = p.standIn(for: "Petra Lindner") ?? ""
        #expect(p.restore("Dr. \(cornelia) \(harz)") == "Dr. Petra Lindner")
        #expect(p.restore("\(harz) \(p.standIn(for: "Lindner") ?? "")") == "Petra Lindner")
        #expect(p.restore("\(cornelia) und \(harz)") == "Petra und Petra Lindner")
    }

    @Test("A caretaker is a role, not a first name: the word stays readable and the name comes back alone")
    func roleIsNotAName() {
        let p = learned(.placeholder, [found(.person, "Hausmeister Brenner"), found(.street, "Honigtauer Str. 14")])
        let out = p.disguiser.apply("Der Hausmeister kommt. Herr Brenner und Hausmeister Brenner.").text
        #expect(out.hasPrefix("Der Hausmeister kommt."))
        #expect(!out.contains("Brenner"))
        let tag = p.standIn(for: "Brenner") ?? "?"
        #expect(p.restore("Herr \(tag)") == "Herr Brenner")
        let street = p.standIn(for: "Honigtauer Str. 14") ?? "?"
        #expect(p.restore("Treffen in der \(street) 14, 10437") == "Treffen in der Honigtauer Str. 14, 10437")
        #expect(p.restore("\(street) 142") == "Honigtauer Str. 14 142")
    }

    @Test("A name typed without its umlaut or its ß is still disguised")
    func otherSpellings() {
        let p = learned(.placeholder, [found(.person, "Sebastian Süß"), found(.person, "Ulf Mühlberger"), found(.person, "Hans Gross")])
        let out = p.disguiser.apply("bei Herrn Süss, Herr Muehlberger und Herr Suess. Das ist groß.").text
        for word in ["Süss", "Muehlberger", "Suess"] { #expect(!out.contains(word), "\(word): \(out)") }
        #expect(out.hasSuffix("Das ist groß."))
        #expect(p.restore(p.disguiser.apply("Herrn Süss").text) == "Herrn Sebastian Süß")
    }

    @Test("A name learned with quote marks is disguised without them; kurz the word stays")
    func quotedAndLowercase() {
        let p = Pseudonymizer(mode: .placeholder, entries: [
            .init(kind: .person, original: "'Kurz, Anna'", standIn: "[Person A]"),
            .init(kind: .person, original: "'Kurz", standIn: "[Person A]", partOf: "'Kurz, Anna'"),
        ])
        let out = p.disguiser.apply("Sehr geehrte Frau Kurz, ich frage kurz nach.").text
        #expect(out == "Sehr geehrte Frau [Person A], ich frage kurz nach.")
    }

    @Test("An old mapping that merged them is repaired when it is read")
    func upgrade() {
        var mapping = Pseudonymizer.Mapping()
        mapping.version = 1
        mapping.placeholder = [
            .init(kind: .person, original: "Sebastian Albers", standIn: "[Person A]"),
            .init(kind: .person, original: "Sebastian", standIn: "[Person A]", partOf: "Sebastian Albers"),
            .init(kind: .person, original: "Albers", standIn: "[Person A]", partOf: "Sebastian Albers"),
            .init(kind: .person, original: "Sebastian Süß", standIn: "[Person A]"),
            .init(kind: .person, original: "Süß", standIn: "[Person A]", partOf: "Sebastian Süß"),
            .init(kind: .place, original: "Berlin", standIn: "[Place A]"),
        ]
        #expect(mapping.upgrade() > 0)
        #expect(mapping.version == Pseudonymizer.Mapping.current)
        let p = Pseudonymizer(mode: .placeholder, entries: mapping.placeholder)
        #expect(p.standIn(for: "Sebastian Albers") != p.standIn(for: "Sebastian Süß"))
        #expect(p.standIn(for: "Berlin") == "[Place A]")
        #expect(p.restore(p.disguiser.apply("Sebastian Süß").text) == "Sebastian Süß")
        #expect(mapping.upgrade() == 0)
    }

    @Test("Version 2 to 3 changes only the entries with a role in them")
    func rolesUpgrade() {
        var mapping = Pseudonymizer.Mapping()
        mapping.version = 2
        mapping.placeholder = [
            .init(kind: .person, original: "Sebastian Süß", standIn: "[Person A]"),
            .init(kind: .person, original: "Hausmeister Brenner", standIn: "[Person B]"),
            .init(kind: .person, original: "Hausmeister", standIn: "[Person B]", partOf: "Hausmeister Brenner"),
            .init(kind: .person, original: "Brenner", standIn: "[Person B]", partOf: "Hausmeister Brenner"),
        ]
        #expect(mapping.upgrade() == 2)
        let p = Pseudonymizer(mode: .placeholder, entries: mapping.placeholder)
        #expect(p.standIn(for: "Sebastian Süß") == "[Person A]")
        #expect(p.standIn(for: "Hausmeister") == nil)
        #expect(p.disguiser.apply("Hausmeister Brenner").text == "Hausmeister [Person B]")
        #expect(p.restore("Herr [Person B]") == "Herr Brenner")
    }
}
