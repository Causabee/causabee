import Foundation
import Testing
@testable import MatterCore

@Suite("A readable name for a file whose own name says nothing")
struct DocumentTitleTests {
    @Test("Names a scanner, a camera or a mail program made up", arguments: [
        "doc23848720260716151349.pdf", "scan_0012.pdf", "IMG_4411.jpg", "image001.png", "Dokument.pdf", "20260716.pdf",
    ])
    func machineMade(_ name: String) { #expect(DocumentTitle.looksMachineMade(name)) }

    @Test("Names a person gave", arguments: ["Angebot Dachrinne.pdf", "Protokoll Eigentümerversammlung 2026.pdf", "Vollmacht.pdf"])
    func given(_ name: String) { #expect(!DocumentTitle.looksMachineMade(name)) }

    @Test("The line naming the kind of letter, not the letterhead above it")
    func heading() {
        let page = """
        Dachdeckerei Wetterfest GmbH
        Honigwabenallee 12 · 10437 Berlin
        Tel. 030 0471 2288
        Frau Greta Kramer
        12.09.2026
        Angebot Nr. 2026-117: Erneuerung der Dachrinne
        Sehr geehrte Frau Kramer,
        """
        #expect(DocumentTitle.from(text: page) == "Angebot Nr. 2026-117: Erneuerung der Dachrinne")
    }

    @Test("Without a kind word, the first line that reads like a heading")
    func firstHeading() {
        #expect(DocumentTitle.from(text: "Seite 1 von 3\n12.09.2026\nNiederschrift der Sitzung des Beirats\nAnwesend: …") == "Niederschrift der Sitzung des Beirats")
    }

    @Test("A program's name and a file ending are not part of the title")
    func cleaned() {
        #expect(DocumentTitle.clean("Microsoft Word - Hausordnung neu.docx") == "Hausordnung neu")
        #expect(DocumentTitle.clean("doc2384872026.pdf") == nil)
    }
}
