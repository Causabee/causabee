import AppKit
import Foundation
import Testing
@testable import MatterCore

/// A chat drawn the way WhatsApp draws one, so the reading can be tested without a real
/// screenshot: status bar, header, a date line, bubbles on both sides with their minutes, the
/// field to type in.
private func drawChat() throws -> URL {
    let size = NSSize(width: 1179, height: 2556)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor(calibratedRed: 0.93, green: 0.9, blue: 0.85, alpha: 1).setFill()
    NSRect(origin: .zero, size: size).fill()
    func text(_ string: String, x: CGFloat, top: CGFloat, size points: CGFloat, bold: Bool = false, color: NSColor = .black) {
        let font = bold ? NSFont.boldSystemFont(ofSize: points) : NSFont.systemFont(ofSize: points)
        (string as NSString).draw(at: NSPoint(x: x, y: size.height - top - points * 1.2), withAttributes: [.font: font, .foregroundColor: color])
    }
    func bubble(x: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat, mine: Bool) {
        (mine ? NSColor(calibratedRed: 0.85, green: 0.98, blue: 0.8, alpha: 1) : NSColor.white).setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: size.height - top - height, width: width, height: height), xRadius: 24, yRadius: 24).fill()
    }
    text("9:41", x: 90, top: 40, size: 44, bold: true)
    text("Sperrmüll Haus", x: 380, top: 170, size: 50, bold: true)
    text("Anna, Tom, Du", x: 420, top: 240, size: 36, color: .darkGray)
    text("Heute", x: 530, top: 420, size: 36, color: .darkGray)
    bubble(x: 40, top: 520, width: 800, height: 230, mine: false)
    text("Anna", x: 80, top: 540, size: 38, bold: true, color: .systemTeal)
    text("Der Termin ist am 26. Oktober.", x: 80, top: 610, size: 42)
    text("10:12", x: 700, top: 680, size: 30, color: .darkGray)
    bubble(x: 40, top: 800, width: 800, height: 230, mine: false)
    text("Tom", x: 80, top: 820, size: 38, bold: true, color: .systemOrange)
    text("Wer bringt die Liste zu Georg?", x: 80, top: 890, size: 42)
    text("10:15", x: 700, top: 960, size: 30, color: .darkGray)
    bubble(x: 380, top: 1080, width: 760, height: 170, mine: true)
    text("Ich schicke sie bis Freitag.", x: 420, top: 1100, size: 42)
    text("10:17", x: 1000, top: 1180, size: 30, color: .darkGray)
    text("Nachricht", x: 160, top: 2400, size: 40, color: .gray)
    image.unlockFocus()
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("chat-\(UUID()).png")
    let tiff = try #require(image.tiffRepresentation)
    let bitmap = try #require(NSBitmapImageRep(data: tiff))
    let png = try #require(bitmap.representation(using: .png, properties: [:]))
    try png.write(to: url)
    return url
}

@Suite("A chat screenshot, read as a chat")
struct ScreenshotTests {
    @Test("Header, day, speakers, minutes, whose bubble — and the status bar and the field left out")
    func readsAChat() throws {
        let url = try drawChat()
        defer { try? FileManager.default.removeItem(at: url) }
        let (lines, _) = try ScreenText.lines(in: url)
        let chat = ChatReader.read(lines)

        #expect(chat.title == "Sperrmüll Haus")
        #expect(chat.participants == ["Anna", "Tom", "Du"])
        #expect(chat.leftOut.contains { $0.text == "9:41" })
        #expect(chat.leftOut.contains { $0.text == "Nachricht" })
        #expect(chat.messages.count == 3)
        #expect(chat.messages.first?.day == "Heute")
        #expect(chat.messages.map(\.speaker) == ["Anna", "Tom", nil])
        #expect(chat.messages.map(\.side) == [.theirs, .theirs, .mine])
        #expect(chat.messages.map(\.time) == ["10:12", "10:15", "10:17"])
        #expect(chat.messages.last?.text.contains("bis Freitag") == true)

        let text = chat.text(owner: "Jan Kramer")
        #expect(text.contains("10:17 Jan Kramer: Ich schicke sie bis Freitag."))
        #expect(!text.contains("9:41"))
    }

    @Test("A name is written on the first of someone's messages only; a quote of the owner is not a speaker")
    func speakersCarryOver() {
        func line(_ text: String, _ x: CGFloat, _ top: CGFloat, width: CGFloat = 0.5) -> ScreenText.Line {
            ScreenText.Line(text: text, box: CGRect(x: x, y: top, width: width, height: 0.018))
        }
        let lines = [
            line("17:58", 0.1, 0.026, width: 0.1), line("Mira & Rosa", 0.3, 0.089, width: 0.28),
            line("Rosa Kramer", 0.14, 0.160, width: 0.25), line("Hab wieder Probleme", 0.14, 0.185), line("16:19", 0.63, 0.212, width: 0.08),
            line("Es drückt", 0.14, 0.250, width: 0.2), line("16:19", 0.35, 0.263, width: 0.08),
            line("Rauchst du?", 0.52, 0.330, width: 0.24), line("16:21", 0.80, 0.343, width: 0.08),
            line("Mira", 0.14, 0.400, width: 0.12), line("You", 0.16, 0.425, width: 0.08), line("Rauchst du?", 0.16, 0.450, width: 0.3),
            line("Nein nie", 0.14, 0.478, width: 0.2), line("16:22", 0.60, 0.500, width: 0.08),
            line("+", 0.03, 0.917, width: 0.07),
        ]
        let chat = ChatReader.read(lines)
        #expect(chat.notes.isEmpty)
        #expect(chat.messages.map(\.speaker) == ["Rosa Kramer", "Rosa Kramer", nil, "Mira"])
        #expect(chat.messages.map(\.side) == [.theirs, .theirs, .mine, .theirs])
        #expect(chat.messages.last?.text.hasPrefix("[antwortet auf eine Nachricht von dir]") == true)
        #expect(chat.leftOut.contains { $0.text == "+" })
        #expect(chat.people == ["Rosa Kramer", "Mira"])
    }

    @Test("A day is a day, and a sentence is not", arguments: [
        ("Heute", true), ("Gestern", true), ("Montag", true), ("12. Sept.", true), ("26.10.26", true),
        ("Der Termin ist am 26. Oktober.", false), ("Tom", false),
    ])
    func days(text: String, isDay: Bool) {
        #expect(ChatReader.isDay(text) == isDay)
    }

    @Test("A PDF page with text is read from it; a scanned page by text recognition, and said so")
    func pdfPages() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("brief-\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        let pdf = try #require(CGContext(url as CFURL, mediaBox: &box, nil))
        // Page one: real text.
        pdf.beginPDFPage(nil)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: pdf, flipped: false)
        ("Bitte zahlen Sie die Sonderumlage bis zum 30. November." as NSString)
            .draw(at: NSPoint(x: 60, y: 700), withAttributes: [.font: NSFont.systemFont(ofSize: 16)])
        pdf.endPDFPage()
        // Page two: a picture of text, as a scanner makes it.
        let picture = NSImage(size: NSSize(width: 1190, height: 300))
        picture.lockFocus()
        NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 1190, height: 300).fill()
        ("Die Begehung ist am 9. Oktober um 10 Uhr." as NSString)
            .draw(at: NSPoint(x: 40, y: 120), withAttributes: [.font: NSFont.systemFont(ofSize: 48)])
        picture.unlockFocus()
        let scan = try #require(picture.cgImage(forProposedRect: nil, context: nil, hints: nil))
        pdf.beginPDFPage(nil)
        pdf.draw(scan, in: CGRect(x: 0, y: 500, width: 595, height: 150))
        pdf.endPDFPage()
        pdf.closePDF()

        let (text, notes, _) = try ScreenshotDoor.read(pdf: url)
        #expect(text.contains("— Seite 1 —") && text.contains("Sonderumlage"))
        #expect(text.contains("— Seite 2 —") && text.contains("Begehung"))
        #expect(notes == ["Page 2: scanned, no text layer — read with text recognition on the Mac"])
    }

    @Test("A screenshot with a home stays where it is; one from a temporary folder is copied in")
    func home() {
        #expect(ScreenshotDoor.hasHome(URL(fileURLWithPath: "/Users/x/Desktop/Bildschirmfoto.png")))
        #expect(!ScreenshotDoor.hasHome(URL(fileURLWithPath: "/private/var/folders/ab/T/TemporaryItems/NSIRD/x.png")))
    }
}
