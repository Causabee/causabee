import Foundation
import Testing
@testable import MatterCore

@Suite("The golden set")
struct GoldenSetTests {
    // MARK: CSV, as a spreadsheet writes it

    @Test("A comma inside a subject line is not a new column")
    func quotedCommas() {
        let rows = CSV.rows("file,subject\n01.eml,\"Heizung, Angebote, Termin\"\n")
        #expect(rows.count == 2)
        #expect(rows[1] == ["01.eml", "Heizung, Angebote, Termin"])
    }

    @Test("A quotation mark inside a quoted field is doubled, and comes back single")
    func doubledQuotes() {
        #expect(CSV.rows("a\n\"sie sagte \"\"ja\"\"\"\n")[1] == ["sie sagte \"ja\""])
    }

    @Test("A newline inside a cell keeps the row together")
    func newlineInCell() {
        let rows = CSV.rows("file,notes\n01.eml,\"zwei\nZeilen\"\n")
        #expect(rows.count == 2)
        #expect(rows[1][1] == "zwei\nZeilen")
    }

    @Test("CRLF and the byte-order mark Numbers leaves behind")
    func numbersExport() {
        let rows = CSV.rows("\u{FEFF}file,is_bulk\r\n01.eml,yes\r\n")
        #expect(rows[0] == ["file", "is_bulk"])
        #expect(rows[1] == ["01.eml", "yes"])
    }

    @Test("Semicolons, as Numbers writes them on a German Mac")
    func semicolonExport() {
        let rows = CSV.rows("\u{FEFF}file;subject;is_bulk\r\n01.eml;\"Heizung; Angebote, Termin\";yes\r\n")
        #expect(rows[0] == ["file", "subject", "is_bulk"])
        #expect(rows[1] == ["01.eml", "Heizung; Angebote, Termin", "yes"])
    }

    @Test("What is written can be read back")
    func roundTrip() {
        let line = CSV.line(["01.eml", "Heizung, Angebote", "sie sagte \"ja\""])
        #expect(CSV.rows(line + "\n")[0] == ["01.eml", "Heizung, Angebote", "sie sagte \"ja\""])
    }

    // MARK: The template

    @Test("The template fills in the facts and leaves every judgement blank")
    func templateIsNotAnAnswer() {
        let email = EMLParser.parse(source: """
        Message-ID: <abc@example.net>
        Date: Mon, 22 Sep 2025 09:14:02 +0200
        From: Hausverwaltung Berger GmbH <post@berger-hv.example>
        Subject: Heizungstausch, Angebote

        Hallo
        """, url: URL(fileURLWithPath: "/tmp/01-heizung.eml"))

        let rows = CSV.rows(GoldenSet.template(for: [email]))
        #expect(rows[0] == GoldenSet.columns)

        let row = rows[1]
        #expect(row[0] == "01-heizung.eml")
        #expect(row[1] == "abc@example.net")
        #expect(row[2] == "2025-09-22")
        #expect(row[4] == "Heizungstausch, Angebote")
        // is_bulk, matter, parties, todos, deadlines, notes
        #expect(row[5...10].allSatisfy { $0.isEmpty })
    }

    // MARK: Reading a filled-in one

    let filled = """
    file,email_id,date,from,subject,is_bulk,matter,parties,todos,deadlines,notes
    01.eml,<a@x>,2025-09-22,Berger,Heizung,no,hausverwaltung,"Annegret Berger (Hausverwaltung) | Thermotec Nowak GmbH (Anbieter)","Begehung bestätigen (me) -> 2025-10-09 | Angebote vergleichen (me)",Sonderumlage überweisen -> 2025-11-30,
    02.eml,<b@x>,2025-09-25,Baumarkt,Herbstaktion,yes,,,,,reiner Newsletter
    03.eml,<c@x>,2025-09-26,Helena,Samstag,no,,Helena Fuchs (Freundin),Wein mitbringen (me),,
    """

    @Test("A filled-in row becomes a label")
    func reading() throws {
        let reading = GoldenSet.read(filled)
        #expect(reading.complaints.isEmpty)
        #expect(reading.labels.count == 3)

        let first = try #require(reading.labels.first)
        #expect(first.isBulk == false)
        #expect(first.matter == "hausverwaltung")
        #expect(first.parties == [.init(name: "Annegret Berger", role: "Hausverwaltung"),
                                  .init(name: "Thermotec Nowak GmbH", role: "Anbieter")])
        #expect(first.todos == [.init(text: "Begehung bestätigen", owner: .me, due: "2025-10-09"),
                                .init(text: "Angebote vergleichen", owner: .me, due: nil)])
        #expect(first.deadlines == [.init(what: "Sonderumlage überweisen", date: "2025-11-30")])
    }

    @Test("A mail that belongs to no matter says so by saying nothing")
    func noMatter() {
        let labels = GoldenSet.read(filled).labels
        #expect(labels[1].matter == nil)
        #expect(labels[1].isBulk == true)
        #expect(labels[1].notes == "reiner Newsletter")
        #expect(labels[2].todos == [.init(text: "Wein mitbringen", owner: .me, due: nil)])
    }

    @Test("An empty is_bulk means not labelled yet, not `no`")
    func unlabelled() {
        let reading = GoldenSet.read("file,is_bulk\n01.eml,\n")
        #expect(reading.labels[0].isBulk == nil)
        #expect(!reading.labels[0].isLabelled)
        #expect(reading.complaints.isEmpty)
    }

    @Test("Both arrows work, because only one of them is on the keyboard",
          arguments: ["Sonderumlage -> 2025-11-30", "Sonderumlage → 2025-11-30", "Sonderumlage => 2025-11-30"])
    func arrows(cell: String) {
        #expect(GoldenSet.deadlines(cell) == [.init(what: "Sonderumlage", date: "2025-11-30")])
    }

    @Test("Yes and no in the spellings a person actually types",
          arguments: [("yes", true), ("Yes", true), ("y", true), ("ja", true), ("1", true),
                      ("no", false), ("NO", false), ("nein", false), ("0", false)])
    func spellings(written: String, meaning: Bool) {
        #expect(GoldenSet.read("file,is_bulk\n01.eml,\(written)\n").labels[0].isBulk == meaning)
    }

    @Test("Something that is not yes or no is a complaint, not a guess")
    func complainsAboutNonsense() {
        let reading = GoldenSet.read("file,is_bulk\n01.eml,vielleicht\n")
        #expect(reading.labels.isEmpty == false)
        #expect(reading.complaints.count == 1)
        #expect(reading.complaints[0].row == 2)
        #expect(reading.complaints[0].text.contains("vielleicht"))
    }

    @Test("A date that is not a date is a complaint")
    func complainsAboutDates() {
        let reading = GoldenSet.read("""
        file,is_bulk,deadlines
        01.eml,no,Sonderumlage -> 30.11.2025
        """)
        #expect(reading.complaints.count == 1)
        #expect(reading.complaints[0].text.contains("2025-10-15"))
    }

    @Test("A row with no file name cannot be matched to a mail, and says so")
    func complainsAboutMissingFile() {
        let reading = GoldenSet.read("file,is_bulk\n,yes\n")
        #expect(reading.labels.isEmpty)
        #expect(reading.complaints.count == 1)
    }

    @Test("A thread set comes out thread by thread, oldest first within each")
    func threadTemplate() {
        func mail(_ name: String, _ headers: String) -> Email {
            EMLParser.parse(source: headers + "\n\nx", url: URL(fileURLWithPath: "/tmp/\(name).eml"))
        }
        let emails = [
            mail("c", "Message-ID: <c@x>\nDate: Wed, 3 Sep 2026 10:00:00 +0200\nSubject: Re: Hausverwaltung Honigtauer\nReferences: <a@x>"),
            mail("b", "Message-ID: <b@x>\nDate: Tue, 2 Sep 2026 10:00:00 +0200\nSubject: Jobangebot Staff Designer"),
            mail("a", "Message-ID: <a@x>\nDate: Mon, 1 Sep 2026 10:00:00 +0200\nSubject: Hausverwaltung Honigtauer"),
            mail("d", "Message-ID: <d@x>\nDate: Thu, 4 Sep 2026 10:00:00 +0200\nSubject: AW: Jobangebot Staff Designer"),
        ]
        let rows = CSV.rows(GoldenSet.template(for: emails, kind: .threads))
        #expect(rows[0].contains("tapped") && !rows[0].contains("is_bulk"))
        #expect(rows.dropFirst().map { $0[0] } == ["a.eml", "c.eml", "b.eml", "d.eml"])
    }

    @Test("A thread set is labelled by `tapped`, and needs no is_bulk column")
    func tappedColumn() {
        let reading = GoldenSet.read("file;tapped;matter;todos\n01.eml;yes;hv;Liste schicken (me)\n02.eml;no;hv;\n03.eml;;;\n")
        #expect(reading.kind == .threads)
        #expect(reading.complaints.isEmpty)
        #expect(reading.labels.map(\.tapped) == [true, false, nil])
        #expect(reading.labels.filter(\.isLabelled).count == 2)
        #expect(reading.labels[0].todos.first?.owner == .me)
    }

    @Test("Parties separated by a comma instead of | are flagged, not silently merged")
    func commaInParties() {
        let flagged = GoldenSet.read("file;is_bulk;parties\n01.eml;no;Gerd Achter, Zirkel AG\n")
        #expect(flagged.complaints.contains { $0.text.contains("comma") })
        let fine = GoldenSet.read("file;is_bulk;parties\n01.eml;no;Gerd Achter (Liquidator) | Zirkel AG (Firma)\n")
        #expect(fine.complaints.isEmpty)
        #expect(fine.labels[0].parties.count == 2)
        let role = GoldenSet.read("file;is_bulk;parties\n01.eml;no;Karin Rasch (Schadenstelle N3, Wabenversicherung)\n")
        #expect(role.complaints.isEmpty)
        #expect(role.labels[0].parties.first?.role == "Schadenstelle N3, Wabenversicherung")
    }

    @Test("A mark in the suggest column says which rows are meant to be labelled")
    func suggestColumn() {
        let labels = GoldenSet.read("group;suggest;file;is_bulk\n1;label;01.eml;\n1;;02.eml;yes\n").labels
        #expect(labels.map(\.isSuggested) == [true, false])
        #expect(GoldenSet.read("file,is_bulk\n01.eml,\n").labels[0].isSuggested == false)
    }

    @Test("Columns in another order are still read by name")
    func columnOrder() {
        let reading = GoldenSet.read("is_bulk,notes,file\nno,kurz,01.eml\n")
        #expect(reading.labels[0].file == "01.eml")
        #expect(reading.labels[0].isBulk == false)
        #expect(reading.labels[0].notes == "kurz")
    }

    @Test("Labels written out and read back are the same labels")
    func labelRoundTrip() {
        let original = GoldenSet.read(filled).labels
        #expect(GoldenSet.read(GoldenSet.csv(original)).labels == original)
    }
}
