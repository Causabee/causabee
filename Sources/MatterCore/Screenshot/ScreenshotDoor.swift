import CoreGraphics
import CryptoKit
import Foundation
import PDFKit

/// A file as a door in — a chat screenshot, a mail saved as `.eml`, a PDF — the way a labelled
/// mail is: read on the device, shown before anything is sent, sent pseudonymised on a yes, and
/// answered once — the same file twice is the same answer, from the record.
public struct ScreenshotDoor: Sendable {
    public var log: URL
    public var mapping: URL
    public var cache: URL
    public var model: Claude.Model
    public var strict = false

    public init(besides store: URL, model: Claude.Model = .opus) {
        let folder = store.deletingLastPathComponent()
        log = folder.appendingPathComponent("decisions-fetch.jsonl")
        mapping = folder.appendingPathComponent("mapping.json")
        cache = folder.appendingPathComponent(".matter-cache")
        self.model = model
    }

    /// Where an image with no home of its own is kept: beside the store.
    public static func attachments(besides store: URL) -> URL {
        store.deletingLastPathComponent().appendingPathComponent(attachmentsFolder, isDirectory: true)
    }
    public static let attachmentsFolder = "Anhänge"

    /// A file in a folder of the owner's has a home and is kept by reference. One in a temporary
    /// folder — dragged out of another app, pasted — has none, and is copied in.
    public static func hasHome(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return !["/private/var/folders/", "/var/folders/", "/private/tmp/", "/tmp/", "TemporaryItems"].contains { path.contains($0) }
    }

    public enum Kind: String, Sendable { case chat, mail, document }

    public static let chatTypes: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "gif"]
    public static let readable: Set<String> = chatTypes.union(["eml", "emlx", "pdf"])

    public struct Look: Sendable {
        public var file: URL
        public var kind: Kind
        /// For a chat. Empty for a mail or a document.
        public var transcript: ChatTranscript
        /// What it is, for the preview: a mail's subject, a document's title, a chat's name.
        public var heading: String
        /// Who and when: "Frau Behrend · 22. Juni", "PDF · 3 Seiten".
        public var byline: String
        /// The start of what was read.
        public var preview: String
        /// What could not be read as text, page by page, and how it was read instead.
        public var notes: [String]
        public var report: Spike.Report
        public var answered: [String: Judgement]
        /// This very image was read and answered before.
        public var earlier: Judgement?
        public var estimate: Double
        /// Exactly what would be sent, pseudonymised.
        public var sent: String
    }

    public static func id(of data: Data) -> String {
        "screenshot:" + SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    /// A screenshot that is no chat, as text: its lines from the top, without the status bar, and
    /// its first line of some length as the heading. Nil when there are no words in it at all.
    public static func pictureText(_ lines: [ScreenText.Line]) -> (heading: String, body: String)? {
        // The status bar sits lower beside the Dynamic Island: a clock or a few signs near the top.
        func isStatusBar(_ line: ScreenText.Line) -> Bool {
            let text = line.text.trimmingCharacters(in: .whitespaces)
            return line.bottom < 0.045 || (line.top < 0.07 && (text.wholeMatch(of: /\d{1,2}[:.]\d{2}/) != nil || text.count <= 4))
        }
        let words = lines.filter { !isStatusBar($0) && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { abs($0.top - $1.top) < 0.008 ? $0.box.minX < $1.box.minX : $0.top < $1.top }
            .map { $0.text.trimmingCharacters(in: .whitespaces) }
        guard !words.isEmpty else { return nil }
        let heading = words.first { $0.count >= 8 } ?? words[0]
        return (String(heading.prefix(70)), words.joined(separator: "\n"))
    }

    /// Reads it on the device and pseudonymises it. Nothing is sent.
    public func look(at file: URL, owner: String, taken: Date? = nil) throws -> Look {
        let data = try Data(contentsOf: file)
        let date = taken ?? (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
        let kind: Kind
        var transcript = ChatTranscript(title: nil, subtitle: nil, messages: [], leftOut: [], notes: [])
        var notes: [String] = []
        var picture: (heading: String, body: String)?
        let email: Email
        switch file.pathExtension.lowercased() {
        case "eml", "emlx":
            kind = .mail
            email = try EMLParser.parse(contentsOf: file)
        case "pdf":
            kind = .document
            let (text, pageNotes, title) = try Self.read(pdf: file)
            notes = pageNotes
            let name = title ?? file.deletingPathExtension().lastPathComponent
            email = Email(source: file, id: "document:" + Self.id(of: data).dropFirst("screenshot:".count), headers: ["subject": [name]],
                          subject: name, from: "Dokument", to: [owner], cc: [], date: date, body: text, attachments: [])
        default:
            kind = .chat
            let (lines, _) = try ScreenText.lines(in: file)
            transcript = ChatReader.read(lines)
            if transcript.messages.isEmpty, let text = Self.pictureText(lines) {
                // Not a chat — a note, a portal page, a letter on screen: its words as they stand,
                // under an id of their own, so an earlier reading as an empty chat is not reused.
                picture = text
                transcript = ChatTranscript(title: nil, subtitle: nil, messages: [], leftOut: [], notes: [])
                email = Email(source: file, id: Self.id(of: data) + "-text", headers: ["subject": ["Screenshot: \(text.heading)"]],
                              subject: "Screenshot: \(text.heading)", from: "Screenshot", to: [owner], cc: [], date: date,
                              body: text.body, attachments: [])
            } else {
                let title = transcript.title ?? "ohne Namen"
                email = Email(source: file, id: Self.id(of: data), headers: ["subject": ["Chat: \(title)"]],
                              subject: "Chat: \(title)", from: title, to: [owner], cc: [], date: date,
                              body: transcript.text(owner: owner), attachments: [])
            }
        }
        let id = email.id

        var mapping = Pseudonymizer.Mapping()
        if let stored = try? Data(contentsOf: self.mapping) { mapping = try JSONDecoder().decode(Pseudonymizer.Mapping.self, from: stored) }
        mapping.upgrade()
        let report = Spike(detector: EntityDetector())
            .run(emails: [email], labelled: [id], pseudonymizer: Pseudonymizer(mode: .placeholder, entries: mapping.placeholder))
        let answered = DailyDoor.readLog(log)
        let sent = report.outcomes.first?.judgement.disguise.map { Extractor.text(of: $0) } ?? ""
        let when = email.date.map { MatterStatus.day($0) } ?? ""
        let pages = max(notes.count, email.body.components(separatedBy: "— Seite ").count - 1)
        let byline = switch kind {
        case .chat: picture != nil ? "Screenshot · text" : (transcript.subtitle ?? "Chat")
        case .mail: [Email.displayName(in: email.from) ?? email.fromAddress, when].filter { !$0.isEmpty }.joined(separator: " · ")
        case .document: pages == 1 ? "PDF · 1 page" : "PDF · \(pages) pages"
        }
        return Look(file: file, kind: kind, transcript: transcript,
                    heading: picture?.heading ?? (kind == .chat ? (transcript.title ?? "Chat without a name") : (email.subject.isEmpty ? file.lastPathComponent : email.subject)),
                    byline: byline, preview: String(email.body.prefix(600)), notes: notes,
                    report: report, answered: answered,
                    earlier: answered[id].flatMap { Extractor.isSettled($0) ? $0 : nil },
                    estimate: DailyDoor.costPerMail(model), sent: sent)
    }

    /// A PDF's text, page by page. A page with a text layer is read from it; a page without one — a
    /// scan — is drawn and read by text recognition, and the notes say so; a page that gives nothing
    /// either way is said to be unread, never quietly skipped.
    static func read(pdf url: URL) throws -> (text: String, notes: [String], title: String?) {
        guard let document = PDFDocument(url: url) else { throw ScreenText.Failure.unreadable(url) }
        var parts: [String] = []
        var notes: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            var text = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.count < 20 {
                let bounds = page.bounds(for: .mediaBox)
                let scale: CGFloat = 2.5
                let width = Int(bounds.width * scale), height = Int(bounds.height * scale)
                if let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                           space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
                    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                    context.scaleBy(x: scale, y: scale)
                    page.draw(with: .mediaBox, to: context)
                    if let image = context.makeImage(), let lines = try? ScreenText.lines(in: image) {
                        text = lines.map(\.text).joined(separator: "\n")
                    }
                }
                notes.append(text.isEmpty ? "Page \(index + 1): nothing readable — not even with text recognition"
                                          : "Page \(index + 1): scanned, no text layer — read with text recognition on this device")
            }
            parts.append("— Seite \(index + 1) —\n" + (text.isEmpty ? "[nicht lesbar]" : text))
        }
        let title = (document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return (parts.joined(separator: "\n\n"), notes, title)
    }

    /// Sends it, pseudonymised, with the matters and open to-dos as context, and keeps the answer in
    /// the record. What comes back is a judgement for the owner to look at before it goes in.
    public func classify(_ look: Look, claude: Claude, owner: [String], matters: [(key: String, about: String)] = []) async throws -> Judgement {
        if let earlier = look.earlier { return earlier }
        var outcomes = look.report.outcomes
        guard let pseudonymizer = look.report.pseudonymizer else { throw Claude.Failure.unreadable("nothing to send") }
        // A saved mail is read like a labelled one, newest message first; a chat or a document whole.
        var extractor = Extractor(model: model, claude: claude, cache: cache, newestOnly: look.kind == .mail, quietAfter: 0)
        extractor.strict = strict
        extractor.storeMatters = matters
        let summary = try await extractor
            .run(&outcomes, pseudonymizer: pseudonymizer, owner: owner, known: look.answered)
        if let failure = summary.failed.first { throw Claude.Failure.unreadable(failure.error) }
        guard let judgement = outcomes.first?.judgement, judgement.extraction != nil else { throw Claude.Failure.unreadable("no answer") }

        var mapping = Pseudonymizer.Mapping()
        if let stored = try? Data(contentsOf: self.mapping) { mapping = try JSONDecoder().decode(Pseudonymizer.Mapping.self, from: stored) }
        mapping.upgrade()
        mapping.placeholder = pseudonymizer.entries
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(mapping).write(to: self.mapping, options: .atomic)
        try DailyDoor.write(Array(look.answered.values), plus: [judgement], to: log)
        return judgement
    }
}
