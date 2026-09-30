import Foundation

/// The parts of a mail file that are about carrying bytes rather than about meaning: how a
/// header was encoded so it could hold an umlaut, how a body was encoded so it could hold a
/// line longer than 76 characters.
///
/// None of this is interesting, and all of it has to be right. A `Straße` that arrives as
/// `Stra=C3=9Fe` is an entity the detector will not find, and an entity the detector does not
/// find is a name that goes to the API — so the dull end of the pipeline is where the privacy
/// promise is actually kept.
enum MIME {
    // MARK: Transfer encodings

    /// `=C3=9F` back to `ß`, and a trailing `=` back to nothing at all (a soft break, put there
    /// only so the line would fit).
    static func quotedPrintable(_ text: String, encoding: String.Encoding = .utf8) -> String {
        var bytes: [UInt8] = []
        var rest = Substring(text)

        while let index = rest.firstIndex(of: "=") {
            bytes.append(contentsOf: Array(rest[rest.startIndex..<index].utf8))
            let after = rest.index(after: index)

            // A soft line break: `=` with nothing but the newline behind it.
            if after < rest.endIndex, rest[after] == "\n" {
                rest = rest[rest.index(after: after)...]
                continue
            }
            guard let second = rest.index(after, offsetBy: 2, limitedBy: rest.endIndex),
                  let byte = UInt8(rest[after..<second], radix: 16) else {
                bytes.append(contentsOf: Array("=".utf8))
                rest = rest[after...]
                continue
            }
            bytes.append(byte)
            rest = rest[second...]
        }
        bytes.append(contentsOf: Array(rest.utf8))
        return String(data: Data(bytes), encoding: encoding) ?? String(decoding: bytes, as: UTF8.self)
    }

    static func base64(_ text: String, encoding: String.Encoding = .utf8) -> String {
        let packed = text.filter { !$0.isWhitespace }
        guard let data = Data(base64Encoded: packed, options: .ignoreUnknownCharacters) else { return text }
        return String(data: data, encoding: encoding) ?? String(decoding: data, as: UTF8.self)
    }

    /// Applies whatever `Content-Transfer-Encoding` said. Anything unrecognised is left alone,
    /// which is the right answer for `7bit`, `8bit` and `binary` and a survivable one otherwise.
    static func decode(body: String, transferEncoding: String?, charset: String?) -> String {
        let encoding = characterEncoding(charset)
        switch transferEncoding?.lowercased().trimmed {
        case "quoted-printable": return quotedPrintable(body, encoding: encoding)
        case "base64": return base64(body, encoding: encoding)
        default:
            guard encoding != .utf8, let data = body.data(using: .isoLatin1),
                  let reread = String(data: data, encoding: encoding) else { return body }
            return reread
        }
    }

    static func characterEncoding(_ charset: String?) -> String.Encoding {
        switch charset?.lowercased().trimmed {
        case "iso-8859-1", "latin1", "iso8859-1": .isoLatin1
        // Latin-9 — Western, with €. Not .isoLatin2, which is Central European and turned à, è, ñ
        // into other letters.
        case "iso-8859-15", "latin9": String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.isoLatin9.rawValue)))
        case "windows-1252", "cp1252": .windowsCP1252
        case "us-ascii", "ascii": .ascii
        default: .utf8
        }
    }

    // MARK: Encoded words

    /// RFC 2047: `=?UTF-8?Q?Nebenkostenabrechnung?=` in a Subject line. Mail clients write these
    /// whenever a header leaves ASCII, which in German mail is most of the time.
    static func decodedWords(in header: String) -> String {
        guard header.contains("=?") else { return header }
        var out = ""
        var rest = Substring(header)

        while let open = rest.range(of: "=?") {
            out += rest[rest.startIndex..<open.lowerBound]
            let body = rest[open.upperBound...]
            // charset ? encoding ? text ?= — and the end is looked for only once the text has
            // begun. A Q-encoded text that starts with an encoded character, `=28` for an opening
            // bracket, puts `?=` right after the encoding letter, and taking that for the end left
            // the rest of a subject undecoded: `…Kramer28Angebot=29_f=C3=BCr…`.
            guard let firstMark = body.firstIndex(of: "?"),
                  let secondMark = body[body.index(after: firstMark)...].firstIndex(of: "?"),
                  let close = body[body.index(after: secondMark)...].range(of: "?=") else {
                out += rest[open.lowerBound...]
                return out
            }
            let charset = String(body[body.startIndex..<firstMark])
            let kind = body[body.index(after: firstMark)..<secondMark].lowercased()
            let text = String(body[body.index(after: secondMark)..<close.lowerBound])
            let encoding = characterEncoding(charset)
            switch kind {
            case "q": out += quotedPrintable(text.replacingOccurrences(of: "_", with: " "), encoding: encoding)
            case "b": out += base64(text, encoding: encoding)
            default: out += text
            }
            rest = body[close.upperBound...]
            // Encoded words that sit next to each other are joined without the space between them.
            if rest.hasPrefix(" =?") { rest = rest.dropFirst() }
        }
        return out + rest
    }

    // MARK: Header parameters

    /// `text/plain; charset="UTF-8"` → the value and its parameters, lowercased keys, quotes gone.
    static func parameters(_ value: String) -> (value: String, parameters: [String: String]) {
        var pieces = value.split(separator: ";").map { String($0).trimmed }
        let head = pieces.isEmpty ? "" : pieces.removeFirst()
        var parameters: [String: String] = [:]
        for piece in pieces {
            guard let equals = piece.firstIndex(of: "=") else { continue }
            let key = String(piece[piece.startIndex..<equals]).lowercased().trimmed
            var raw = String(piece[piece.index(after: equals)...]).trimmed
            if raw.hasPrefix("\""), raw.hasSuffix("\""), raw.count >= 2 { raw = String(raw.dropFirst().dropLast()) }
            parameters[key] = raw
        }
        return (head, parameters)
    }
}

extension StringProtocol {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
