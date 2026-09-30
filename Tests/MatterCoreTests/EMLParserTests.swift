import Foundation
import Testing
@testable import MatterCore

private func parse(_ source: String, name: String = "test.eml") -> Email {
    EMLParser.parse(source: source, url: URL(fileURLWithPath: "/tmp/\(name)"))
}

@Suite("Reading a mail file")
struct EMLParserTests {
    @Test("Headers are unfolded and their names are case-insensitive")
    func unfolding() {
        let email = parse("""
        Subject: Heizungstausch
         Honigwabenallee 47
        FROM: Anna <anna@example.net>

        Hallo
        """)
        #expect(email.subject == "Heizungstausch Honigwabenallee 47")
        #expect(email.header("from") == "Anna <anna@example.net>")
        #expect(email.fromAddress == "anna@example.net")
        #expect(Email.displayName(in: email.from) == "Anna")
    }

    @Test("An encoded subject comes through as the words it stood for")
    func encodedWords() {
        let email = parse("""
        Subject: =?UTF-8?B?SGVpenVuZ3N0YXVzY2ggw5xiZXJzaWNodA==?=

        x
        """)
        #expect(email.subject == "Heizungstausch Übersicht")
    }

    @Test("Quoted-printable in a Q word, where an underscore is a space")
    func encodedWordQ() {
        let email = parse("""
        Subject: =?ISO-8859-1?Q?Gr=FC=DFe_aus_Berlin?=

        x
        """)
        #expect(email.subject == "Grüße aus Berlin")
    }

    @Test("CRLF line endings, as every real mail file has them")
    func carriageReturns() {
        let email = parse("Subject: Test\r\nFrom: a@example.net\r\n\r\nZeile eins\r\nZeile zwei\r\n")
        #expect(email.subject == "Test")
        #expect(email.body == "Zeile eins\nZeile zwei")
    }

    @Test("A quoted-printable body is decoded, soft breaks and all")
    func quotedPrintableBody() {
        let email = parse("""
        Content-Type: text/plain; charset="UTF-8"
        Content-Transfer-Encoding: quoted-printable

        Sehr geehrte Eigent=C3=BCmer, die Sonderumlage ist bis zum 30.11. zu =
        =C3=BCberweisen.
        """)
        #expect(email.body == "Sehr geehrte Eigentümer, die Sonderumlage ist bis zum 30.11. zu überweisen.")
    }

    @Test("When a mail carries both, the plain part wins")
    func prefersPlain() {
        let email = parse("""
        Content-Type: multipart/alternative; boundary="b"

        --b
        Content-Type: text/plain; charset="UTF-8"

        Was der Absender getippt hat
        --b
        Content-Type: text/html; charset="UTF-8"

        <p>Was sein Programm daraus gemacht hat</p>
        --b--
        """)
        #expect(email.body == "Was der Absender getippt hat")
    }

    @Test("An HTML-only mail still has readable text")
    func htmlOnly() {
        let email = parse("""
        Content-Type: text/html; charset="UTF-8"

        <html><head><style>p{color:red}</style></head><body>
        <h1>Herbstaktion</h1><p>bis zu 30&nbsp;% auf Werkzeug</p>
        <script>track()</script></body></html>
        """)
        #expect(email.body.contains("Herbstaktion"))
        #expect(email.body.contains("bis zu 30 % auf Werkzeug"))
        #expect(!email.body.contains("track()"))
        #expect(!email.body.contains("color:red"))
    }

    @Test("An attachment is counted and named, and stays out of the body")
    func attachments() {
        let payload = Data("%PDF-1.4 nicht wirklich ein PDF".utf8).base64EncodedString()
        let email = parse("""
        Content-Type: multipart/mixed; boundary="m"

        --m
        Content-Type: text/plain; charset="UTF-8"

        Anbei das Angebot.
        --m
        Content-Type: application/pdf; name="Angebot.pdf"
        Content-Transfer-Encoding: base64
        Content-Disposition: attachment; filename="Angebot.pdf"

        \(payload)
        --m--
        """)
        #expect(email.body == "Anbei das Angebot.")
        #expect(email.attachments.count == 1)
        #expect(email.attachments.first?.filename == "Angebot.pdf")
        #expect(email.attachments.first?.contentType == "application/pdf")
        #expect(email.attachments.first?.byteCount == 31)
    }

    @Test("Several recipients are several addresses, commas in quoted names and all")
    func recipients() {
        let email = parse("""
        To: "Berger, Annegret" <a.berger@example.net>, weg@example.net
        Cc: Tomasz <t@example.net>

        x
        """)
        #expect(email.to.count == 2)
        #expect(Email.address(in: email.to[0]) == "a.berger@example.net")
        #expect(Email.address(in: email.to[1]) == "weg@example.net")
        #expect(email.cc.count == 1)
    }

    @Test("The Date header becomes a date, time zone comment and all")
    func dates() throws {
        let email = parse("""
        Date: Mon, 22 Sep 2025 09:14:02 +0200 (CEST)

        x
        """)
        let date = try #require(email.date)
        #expect(date.timeIntervalSince1970 == 1758525242)
    }

    @Test("A mail without a Message-ID is still identified, by its own bytes")
    func identity() {
        let source = "Subject: Ohne ID\n\nHallo"
        let first = parse(source)
        let second = parse(source, name: "kopie.eml")
        #expect(first.id.hasPrefix("sha256:"))
        #expect(first.id == second.id)
    }

    @Test("A Latin-1 body is read as Latin-1 when the part says so")
    func latin1() throws {
        var raw = Data("Content-Type: text/plain; charset=\"ISO-8859-1\"\n\n".utf8)
        raw.append(contentsOf: "Schlüssel bei Bernd".data(using: .isoLatin1)!)
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("latin1.eml")
        try raw.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(try EMLParser.parse(contentsOf: url).body == "Schlüssel bei Bernd")
    }

    @Test("A Q-encoded word whose text starts with an encoded character is decoded whole")
    func encodedWordStartingWithEscape() {
        let header = "=?UTF-8?Q?Gutachten_f=C3=BCr_Dach=2DSchaden_erbeten_=E2=80=93_Angebot_?= =?UTF-8?Q?=28neu=29_f=C3=BCr_Frau_Greta_Kramer?="
        #expect(MIME.decodedWords(in: header) == "Gutachten für Dach-Schaden erbeten – Angebot (neu) für Frau Greta Kramer")
        #expect(MIME.decodedWords(in: "=?utf-8?q?=3Fwarum=3F?=") == "?warum?")
        // A word split in the middle of a letter: the second half starts with its second byte.
        #expect(MIME.decodedWords(in: "Jetzt Anmeldung =?utf-8?Q?best?= =?utf-8?Q?=C3=A4tigen?=") == "Jetzt Anmeldung bestätigen")
    }
}

@Suite("A file attached to a mail, taken out when it is wanted")
struct AttachmentTests {
    static let mail = """
    Message-ID: <a@hv.example>
    From: Sabine Hartwig <sabine@hv.example>
    Subject: Angebot
    Content-Type: multipart/mixed; boundary="XYZ"

    --XYZ
    Content-Type: text/plain; charset=utf-8

    Anbei das Angebot.
    --XYZ
    Content-Type: application/pdf; name="Angebot 2026.pdf"
    Content-Disposition: attachment; filename="Angebot 2026.pdf"
    Content-Transfer-Encoding: base64

    \(Data("%PDF-1.4 Angebot".utf8).base64EncodedString())
    --XYZ--
    """

    @Test("By the name it was recorded under, decoded")
    func takesItOut() throws {
        let email = EMLParser.parse(source: Self.mail, url: URL(fileURLWithPath: "/tmp/a.eml"))
        #expect(email.attachments.map(\.filename) == ["Angebot 2026.pdf"])
        let bytes = try #require(EMLParser.attachment(named: "Angebot 2026.pdf", in: Data(Self.mail.utf8)))
        #expect(String(decoding: bytes, as: UTF8.self) == "%PDF-1.4 Angebot")
        #expect(EMLParser.attachment(named: "anders.pdf", in: Data(Self.mail.utf8)) == nil)
    }

    @Test("A mail's pointer taken apart")
    func pointer() {
        let parsed = MailFetch.parse("imap://imap.gmail.com/%5BGmail%5D/Alle%20Nachrichten;UIDVALIDITY=7/;UID=42")
        #expect(parsed?.folder == "[Gmail]/Alle Nachrichten" && parsed?.validity == 7 && parsed?.uid == 42)
    }
}


@Suite("Letters and markup the way a mail writes them")
struct MailTextTests {
    @Test("ISO-8859-15 is read as Western Latin-9, not as Central European")
    func latin9() {
        let bytes = Data([0xE0, 0xE8, 0xF1, 0xA4])  // à è ñ €
        let text = String(data: bytes, encoding: MIME.characterEncoding("ISO-8859-15"))
        #expect(text == "àèñ€")
    }

    @Test("A style block over several lines is taken out whole")
    func multiLineStyle() {
        let html = "<html><style type=\"text/css\">\n.a { color: red; }\n.b { margin: 0; }\n</style><p>Hallo</p></html>"
        let text = HTMLText.strip(html)
        #expect(!text.contains("color") && !text.contains("margin"))
        #expect(text.contains("Hallo"))
    }
}
