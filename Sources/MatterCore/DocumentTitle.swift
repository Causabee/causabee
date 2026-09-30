import Foundation
import PDFKit

/// A readable name for a file whose own name says nothing: taken from the file itself, on the
/// Mac — the title a PDF carries, or the heading on its first page. Nothing leaves the Mac.
public enum DocumentTitle {
    /// "doc23848720260716151349.pdf", "scan_0012.pdf", "IMG_4411.jpg", "image001.png",
    /// "Dokument.pdf": a name a scanner, a camera or a mail program gave.
    public static func looksMachineMade(_ name: String) -> Bool {
        let stem = (name as NSString).deletingPathExtension.trimmingCharacters(in: .whitespaces)
        let letters = stem.filter(\.isLetter).count, digits = stem.filter(\.isNumber).count
        if letters < 3 || digits >= 6 && digits * 2 >= stem.count { return true }
        return stem.lowercased().firstMatch(of: /^(doc|docs|scan|scanned|img|image|dsc|pxl|photo|file|document|dokument|unbenannt|unnamed|untitled|attachment|anhang|pdf)[-_ .]?\d*$/) != nil
    }

    /// The first page's heading, or the title the PDF carries when it is a real one.
    public static func from(pdf url: URL) -> String? {
        guard let pdf = PDFDocument(url: url) else { return nil }
        if let own = pdf.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String, let title = clean(own) {
            return title
        }
        let text = (0..<min(pdf.pageCount, 2)).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")
        return from(text: text)
    }

    /// Words that start what a letter or a form is: the line with one of them is its name.
    static let kinds = ["rechnung", "angebot", "vertrag", "bescheid", "kündigung", "protokoll", "einladung", "mahnung",
                        "bestätigung", "abrechnung", "gutachten", "antrag", "vollmacht", "quittung", "beschluss",
                        "mitteilung", "information", "bescheinigung", "invoice", "offer", "contract", "receipt", "notice"]

    /// Out of a page's text: a line naming the kind of letter first, else the first line that
    /// reads like a heading — not an address, a phone number, a date or a page number.
    public static func from(text: String) -> String? {
        let lines = text.split(whereSeparator: \.isNewline).prefix(40)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter(isHeadingLike)
        if let kind = lines.first(where: { line in kinds.contains { line.lowercased().contains($0) } }) { return clean(kind) }
        return lines.first.flatMap(clean)
    }

    static func isHeadingLike(_ line: String) -> Bool {
        let lower = line.lowercased()
        guard line.count >= 4, line.filter(\.isLetter).count >= 4,
              line.filter(\.isLetter).count * 2 >= line.count else { return false }
        let noise = ["@", "http", "www.", "tel", "fax", "iban", "bic", "seite ", "page ", "ust-id", "steuer-nr", "telefon", "e-mail"]
        if noise.contains(where: { lower.contains($0) }) { return false }
        // An address line: a postcode, or a street with its number.
        if line.firstMatch(of: /\b\d{5}\b/) != nil || line.firstMatch(of: /(?i)(str\.|straße|weg|allee|platz)\s*\d/) != nil { return false }
        return true
    }

    /// One line, short enough to read, without the program's name or the file's ending.
    static func clean(_ raw: String) -> String? {
        var title = raw.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["Microsoft Word - ", "Microsoft PowerPoint - ", "Microsoft Excel - "] where title.hasPrefix(prefix) {
            title = String(title.dropFirst(prefix.count))
        }
        if let dot = title.lastIndex(of: "."), ["docx", "doc", "pdf", "pages", "odt", "xlsx"].contains(title[title.index(after: dot)...].lowercased()) {
            title = String(title[..<dot])
        }
        title = title.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard title.count >= 4, !looksMachineMade(title) else { return nil }
        return title.count > 80 ? String(title.prefix(79)) + "…" : title
    }
}
