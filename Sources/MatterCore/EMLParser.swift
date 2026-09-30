import Foundation

/// Step 1 of the spike: read an `.eml` file into headers, readable text and a list of what was
/// attached.
///
/// This is a reader for mail as mail clients actually write it, not a complete RFC 5322
/// implementation — good enough that a German mail with an umlaut in the subject, a
/// quoted-printable body and a PDF hanging off it comes through whole, and honest about the
/// rest. Anything it cannot read it leaves as it found it rather than guessing.
public enum EMLParser {
    public enum Failure: Error, CustomStringConvertible {
        case unreadable(URL)
        public var description: String {
            switch self { case .unreadable(let url): "cannot read \(url.lastPathComponent)" }
        }
    }

    public static func parse(contentsOf url: URL) throws -> Email {
        guard let data = try? Data(contentsOf: url) else { throw Failure.unreadable(url) }
        return parse(data: data, url: url)
    }

    /// A message as it came, from a file or from the mail server. `url` is where it lives.
    public static func parse(data: Data, url: URL) -> Email {
        // Most mail is UTF-8; what is not is usually Latin-1, and reading it as Latin-1 at least
        // keeps every byte so a per-part charset can put it right afterwards.
        let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        let source = url.isFileURL && url.pathExtension.lowercased() == "emlx" ? unwrapEMLX(text) : text
        return parse(source: source, url: url, fingerprint: Email.fingerprint(data))
    }

    /// Mail's own on-disk format: a byte count on the first line, the message, then a property
    /// list of Mail's flags. Dragging a message into Finder gives a plain `.eml` and this is
    /// not needed — but a folder copied out of `~/Library/Mail` is full of these, and silently
    /// reading Mail's flags as the body would be a bad way to find that out.
    static func unwrapEMLX(_ text: String) -> String {
        var body = text
        if let firstBreak = body.firstIndex(of: "\n"),
           Int(body[body.startIndex..<firstBreak].trimmed) != nil {
            body = String(body[body.index(after: firstBreak)...])
        }
        if let plist = body.range(of: "\n<?xml", options: .backwards) {
            body = String(body[body.startIndex..<plist.lowerBound])
        }
        return body
    }

    public static func parse(source: String, url: URL, fingerprint: String? = nil) -> Email {
        let normalised = source.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let (headerBlock, bodyBlock) = split(normalised)
        let headers = parseHeaders(headerBlock)

        let part = Part(headers: headers, body: bodyBlock)
        var attachments: [Email.Attachment] = []
        let body = readableText(of: part, collecting: &attachments)

        func first(_ name: String) -> String { headers[name]?.first ?? "" }

        var email = Email(
            source: url,
            id: first("message-id").isEmpty
                ? (fingerprint ?? Email.fingerprint(Data(normalised.utf8)))
                : first("message-id").trimmingCharacters(in: CharacterSet(charactersIn: "<> ")),
            headers: headers,
            subject: first("subject"),
            from: first("from"),
            to: addresses(first("to")),
            cc: addresses(first("cc")),
            date: date(first("date")),
            body: body,
            attachments: attachments
        )
        email.links = MailLinks.collect(in: part)
        return email
    }

    // MARK: Headers

    static func split(_ source: String) -> (headers: String, body: String) {
        guard let blank = source.range(of: "\n\n") else { return (source, "") }
        return (String(source[source.startIndex..<blank.lowerBound]),
                String(source[blank.upperBound...]))
    }

    /// Unfolds continuation lines (a header may be broken across lines as long as the next one
    /// starts with a space) and decodes encoded words, so the rest of the pipeline sees
    /// `Nebenkostenabrechnung 2024` and never `=?UTF-8?Q?...?=`.
    static func parseHeaders(_ block: String) -> [String: [String]] {
        var headers: [String: [String]] = [:]
        var name: String?
        var value = ""

        func flush() {
            guard let name else { return }
            headers[name, default: []].append(MIME.decodedWords(in: value).trimmed)
            value = ""
        }

        for line in block.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                value += " " + line.trimmed
                continue
            }
            guard let colon = line.firstIndex(of: ":") else { continue }
            flush()
            name = String(line[line.startIndex..<colon]).lowercased().trimmed
            value = String(line[line.index(after: colon)...]).trimmed
        }
        flush()
        return headers
    }

    static func addresses(_ field: String) -> [String] {
        guard !field.isEmpty else { return [] }
        var out: [String] = []
        var current = ""
        var inQuotes = false
        var inAngle = false
        for character in field {
            switch character {
            case "\"": inQuotes.toggle(); current.append(character)
            case "<" where !inQuotes: inAngle = true; current.append(character)
            case ">" where !inQuotes: inAngle = false; current.append(character)
            case "," where !inQuotes && !inAngle:
                if !current.trimmed.isEmpty { out.append(current.trimmed) }
                current = ""
            default: current.append(character)
            }
        }
        if !current.trimmed.isEmpty { out.append(current.trimmed) }
        return out
    }

    static func date(_ field: String) -> Date? {
        guard !field.isEmpty else { return nil }
        // `(CEST)` and friends are a comment, and no formatter wants them.
        var cleaned = field
        if let comment = cleaned.range(of: " (") { cleaned = String(cleaned[cleaned.startIndex..<comment.lowerBound]) }
        for format in ["EEE, d MMM yyyy HH:mm:ss Z", "d MMM yyyy HH:mm:ss Z",
                       "EEE, d MMM yyyy HH:mm Z", "d MMM yyyy HH:mm Z"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: cleaned.trimmed) { return date }
        }
        return nil
    }

    // MARK: Body

    struct Part {
        var headers: [String: [String]]
        var body: String

        var contentType: (value: String, parameters: [String: String]) {
            MIME.parameters(headers["content-type"]?.first ?? "text/plain")
        }
        var disposition: (value: String, parameters: [String: String]) {
            MIME.parameters(headers["content-disposition"]?.first ?? "")
        }
        var transferEncoding: String? { headers["content-transfer-encoding"]?.first }
    }

    /// Walks the tree and returns the text a person would have read, collecting anything that
    /// was attached rather than written on the way.
    ///
    /// `text/plain` wins over `text/html` when a mail carries both, which is the usual case and
    /// the one worth getting right: the plain part is what the sender typed, the HTML part is
    /// what their client made of it.
    static func readableText(of part: Part, collecting attachments: inout [Email.Attachment]) -> String {
        let (type, parameters) = part.contentType
        let lowered = type.lowercased()

        if lowered.hasPrefix("multipart/"), let boundary = parameters["boundary"] {
            let children = parts(of: part.body, boundary: boundary)
            var plain: String?
            var html: String?
            for child in children {
                let text = readableText(of: child, collecting: &attachments)
                guard !text.isEmpty else { continue }
                let childType = child.contentType.value.lowercased()
                if childType.hasPrefix("text/html") { html = html ?? text } else { plain = plain ?? text }
            }
            return plain ?? html ?? ""
        }

        let decoded = MIME.decode(body: part.body,
                                  transferEncoding: part.transferEncoding,
                                  charset: parameters["charset"])

        let filename = part.disposition.parameters["filename"] ?? parameters["name"]
        let isAttachment = part.disposition.value.lowercased().hasPrefix("attachment")
            || (filename != nil && !lowered.hasPrefix("text/"))
        if isAttachment {
            attachments.append(Email.Attachment(
                filename: filename ?? "unnamed",
                contentType: lowered,
                byteCount: byteCount(part.body, transferEncoding: part.transferEncoding)))
            return ""
        }

        if lowered.hasPrefix("text/html") { return HTMLText.strip(decoded) }
        return decoded.trimmed
    }

    /// The bytes of one attachment, found by the name it was recorded under.
    public static func attachment(named name: String, in data: Data) -> Data? {
        let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        let normalised = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let (headerBlock, bodyBlock) = split(normalised)
        return find(name, in: Part(headers: parseHeaders(headerBlock), body: bodyBlock))
    }

    static func find(_ name: String, in part: Part) -> Data? {
        let (type, parameters) = part.contentType
        if type.lowercased().hasPrefix("multipart/"), let boundary = parameters["boundary"] {
            for child in parts(of: part.body, boundary: boundary) {
                if let found = find(name, in: child) { return found }
            }
            return nil
        }
        guard (part.disposition.parameters["filename"] ?? parameters["name"]) == name else { return nil }
        switch part.transferEncoding?.lowercased().trimmed {
        case "base64":
            return Data(base64Encoded: part.body.filter { !$0.isWhitespace }, options: .ignoreUnknownCharacters)
        case "quoted-printable":
            return Data(MIME.decode(body: part.body, transferEncoding: "quoted-printable", charset: parameters["charset"]).utf8)
        default:
            return Data(part.body.utf8)
        }
    }

    static func byteCount(_ body: String, transferEncoding: String?) -> Int {
        if transferEncoding?.lowercased().trimmed == "base64" {
            let packed = body.filter { !$0.isWhitespace }
            return Data(base64Encoded: packed, options: .ignoreUnknownCharacters)?.count ?? packed.utf8.count
        }
        return body.trimmed.utf8.count
    }

    static func parts(of body: String, boundary: String) -> [Part] {
        let opening = "--" + boundary
        var out: [Part] = []
        // The preamble before the first boundary is not a part; the epilogue after `--boundary--`
        // is not either.
        let chunks = body.components(separatedBy: opening).dropFirst()
        for chunk in chunks {
            if chunk.hasPrefix("--") { break }
            let piece = chunk.hasPrefix("\n") ? String(chunk.dropFirst()) : chunk
            let (headerBlock, partBody) = split(piece)
            out.append(Part(headers: parseHeaders(headerBlock), body: partBody))
        }
        return out
    }
}

/// HTML down to the words in it. Newsletters are HTML and nothing else, and a newsletter that
/// reads as an empty body is one the entity detector never gets to look at.
enum HTMLText {
    static func strip(_ html: String) -> String {
        var text = html
        for block in ["script", "style", "head"] {
            text = text.replacingOccurrences(
                // (?s): a block over several lines — as a mail's <style> nearly always is — too.
                of: "(?s)<\(block)[^>]*>.*?</\(block)>", with: " ",
                options: [.regularExpression, .caseInsensitive])
        }
        for breaking in ["</p>", "<br>", "<br/>", "<br />", "</div>", "</tr>", "</li>", "</h1>", "</h2>", "</h3>"] {
            text = text.replacingOccurrences(of: breaking, with: "\n", options: .caseInsensitive)
        }
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        text = entities(text)
        text = text.replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: " *\n *", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return text.trimmed
    }

    static func entities(_ text: String) -> String {
        var out = text
        let named = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
                     "&apos;": "'", "&auml;": "ä", "&ouml;": "ö", "&uuml;": "ü", "&Auml;": "Ä",
                     "&Ouml;": "Ö", "&Uuml;": "Ü", "&szlig;": "ß", "&euro;": "€", "&ndash;": "–",
                     "&mdash;": "—", "&hellip;": "…"]
        for (entity, character) in named { out = out.replacingOccurrences(of: entity, with: character) }
        // Numeric references, decimal and hex.
        for pattern in ["&#([0-9]{1,6});", "&#[xX]([0-9a-fA-F]{1,5});"] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let radix = pattern.contains("x") ? 16 : 10
            var result = ""
            var last = out.startIndex
            for match in regex.matches(in: out, range: NSRange(out.startIndex..., in: out)) {
                guard let whole = Range(match.range, in: out), let digits = Range(match.range(at: 1), in: out),
                      let value = UInt32(out[digits], radix: radix), let scalar = Unicode.Scalar(value)
                else { continue }
                result += out[last..<whole.lowerBound] + String(Character(scalar))
                last = whole.upperBound
            }
            result += out[last...]
            out = result
        }
        return out
    }
}
