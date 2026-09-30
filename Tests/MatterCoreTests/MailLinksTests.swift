import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("Links in a mail: the doc that matters, not the footer")
@MainActor
struct MailLinksTests {
    let html = """
    From: Petra Lindner <petra@example.org>
    To: Jan Kramer <jan@example.com>
    Subject: Liste
    Message-ID: <liste-1@example.org>
    Content-Type: multipart/alternative; boundary="b"

    --b
    Content-Type: text/plain; charset=utf-8

    Hallo Jan, hier die Liste: Liste Sperrmüll <https://docs.google.com/spreadsheets/d/1AbC/edit>
    --b
    Content-Type: text/html; charset=utf-8

    <div>Hallo Jan, hier die <a href="https://docs.google.com/spreadsheets/d/1AbC/edit">Liste Sperrmüll</a>.
    Termin buchen: <a href="https://termine.example.net/buchen?id=42&amp;ort=3">hier</a>.
    <img src="https://example.org/logo.png"><a href="https://www.facebook.com/example">Facebook</a>
    <a href="https://example.org/">example.org</a>
    <a href="https://click.example.org/u/abc">Newsletter abbestellen</a></div>
    <div class="gmail_signature"><a href="https://example.org/team/petra">Petra Lindner, Hausverwaltung</a></div>
    <div class="gmail_quote">Am 1. Sept. schrieb Jan: <a href="https://docs.google.com/document/d/OLD/edit">alter Plan</a></div>
    --b--
    """

    @Test("From an HTML mail: the sheet and the booking page; signature, quote, social, homepage and unsubscribe left out")
    func fromHTML() {
        let email = EMLParser.parse(source: html, url: URL(fileURLWithPath: "/x.eml"))
        let kept = email.links.filter(MailLinks.isWorthKeeping)
        #expect(kept.map(\.address) == ["https://docs.google.com/spreadsheets/d/1AbC/edit", "https://termine.example.net/buchen?id=42&ort=3"])
        #expect(kept.map(MailLinks.name) == ["Liste Sperrmüll", ""])
        #expect(email.links.first { $0.address.contains("/team/") }?.place == .signature)
        #expect(email.links.first { $0.address.contains("OLD") }?.place == .quote)
        // The body the model reads is the plain part, as before.
        #expect(email.body == "Hallo Jan, hier die Liste: Liste Sperrmüll <https://docs.google.com/spreadsheets/d/1AbC/edit>")
    }

    @Test("From a plain mail: Gmail's \"words <address>\", and nothing from the quoted mail below")
    func plain() {
        let text = """
        Anbei das Formular: Schadenmeldung Dach <https://forms.example.net/f/77>
        Viele Grüße

        Am 3. Sept. 2026 um 10:12 schrieb Jan Kramer <jan@example.com>:
        > Kannst du mir den Link schicken? https://docs.google.com/document/d/OLD/edit
        """
        let links = MailLinks.fromPlain(text)
        #expect(links.filter(MailLinks.isWorthKeeping).map(\.address) == ["https://forms.example.net/f/77"])
        #expect(links.first?.text == "Anbei das Formular: Schadenmeldung Dach")
        #expect(links.last?.place == .quote)
    }

    @Test("Offered once in the matter that holds the mail; kept or set aside, never offered again")
    func suggest() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "sperrmuell")
        context.insert(matter)
        let entry = Entry(title: "Liste", from: "Petra Lindner <petra@example.org>", date: Date(),
                          source: Source(kind: .mail, pointer: "imap://x", messageID: "liste-1@example.org"))
        context.insert(entry)
        entry.matter = matter
        try context.save()
        let email = EMLParser.parse(source: html, url: URL(fileURLWithPath: "/x.eml"))
        #expect(MailLinks.suggest(email, in: context) == 2)
        #expect(MailLinks.suggest(email, in: context) == 0)
        let offered = (matter.links ?? []).filter(\.isSuggestion)
        #expect(offered.count == 2 && offered.allSatisfy { $0.messageID == "liste-1@example.org" })
        // Not yet kept: the assistant does not hear of them.
        #expect(!FactSheet.facts(for: [matter], today: "2026-09-28").text.contains("Liste Sperrmüll"))
        offered.forEach { $0.isSuggestion = false; $0.isDismissed = true }
        #expect(MailLinks.suggest(email, in: context) == 0)
    }
}
