import Foundation

/// One response from the server, with its literals taken out.
///
/// A literal is IMAP's way of sending bytes that are not a line — a whole mail arrives as
/// `BODY[] {48213}` followed by exactly that many bytes. Those bytes can hold anything, a line
/// that starts with the command's own tag included, so they are never read as text: `text`
/// has a NUL where each one was, and the bytes are in `literals`, in order.
public struct IMAPResponse: Sendable, Equatable {
    public var text: String
    public var literals: [Data]

    public init(text: String, literals: [Data] = []) {
        self.text = text
        self.literals = literals
    }

    static let marker: Character = "\u{0}"

    /// `OK`, `NO` or `BAD` when this is the answer to the command tagged `tag`.
    func status(tag: String) -> (ok: Bool, rest: String)? {
        guard text.hasPrefix(tag + " ") else { return nil }
        let rest = text.dropFirst(tag.count + 1)
        return (rest.uppercased().hasPrefix("OK"), String(rest))
    }

    var isUntagged: Bool { text.hasPrefix("* ") }

    /// Everything after `* `, as tokens.
    var tokens: [Token] {
        guard isUntagged else { return [] }
        var literals = self.literals.makeIterator()
        var rest = text.dropFirst(2)
        return Token.list(from: &rest, literals: &literals, closing: false)
    }

    public indirect enum Token: Equatable, Sendable {
        case atom(String)
        case string(String)
        case literal(Data)
        case list([Token])
        case nil_

        var text: String? {
            switch self {
            case .atom(let text), .string(let text): text
            case .literal(let data): String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
            case .list, .nil_: nil
            }
        }

        var data: Data? {
            switch self {
            case .literal(let data): data
            case .string(let text): Data(text.utf8)
            default: nil
            }
        }

        static func list(from rest: inout Substring, literals: inout IndexingIterator<[Data]>, closing: Bool) -> [Token] {
            var out: [Token] = []
            while let first = rest.first {
                switch first {
                case " ":
                    rest = rest.dropFirst()
                case "(":
                    rest = rest.dropFirst()
                    out.append(.list(list(from: &rest, literals: &literals, closing: true)))
                case ")":
                    rest = rest.dropFirst()
                    if closing { return out }
                case "\"":
                    rest = rest.dropFirst()
                    var value = ""
                    while let next = rest.first, next != "\"" {
                        rest = rest.dropFirst()
                        if next == "\\", let escaped = rest.first { value.append(escaped); rest = rest.dropFirst() }
                        else { value.append(next) }
                    }
                    rest = rest.dropFirst()
                    out.append(.string(value))
                case IMAPResponse.marker:
                    rest = rest.dropFirst()
                    out.append(.literal(literals.next() ?? Data()))
                default:
                    // An atom runs to the next space or bracket — except that a section such as
                    // `BODY[HEADER.FIELDS (MESSAGE-ID)]` has both inside its square brackets.
                    var atom = ""
                    var depth = 0
                    while let next = rest.first {
                        if depth == 0, next == " " || next == "(" || next == ")" || next == IMAPResponse.marker { break }
                        if next == "[" { depth += 1 }
                        if next == "]" { depth = max(0, depth - 1) }
                        atom.append(next)
                        rest = rest.dropFirst()
                    }
                    out.append(atom.uppercased() == "NIL" ? .nil_ : .atom(atom))
                }
            }
            return out
        }
    }
}

/// Reads responses out of a byte stream, a line at a time, literals whole.
struct IMAPReader {
    private var buffer = Data()

    mutating func append(_ data: Data) { buffer.append(data) }

    /// The next complete response, or nil when more bytes are needed first. Nothing is consumed
    /// until a whole response is there, so a mail that arrives in forty pieces is read once.
    mutating func next() -> IMAPResponse? {
        var text = ""
        var literals: [Data] = []
        var position = buffer.startIndex
        while true {
            guard let end = buffer[position...].firstRange(of: Data([0x0D, 0x0A])) else { return nil }
            let line = Self.string(buffer[position..<end.lowerBound])
            position = end.upperBound
            guard let match = line.firstMatch(of: /\{(\d+)\+?\}$/), let count = Int(match.output.1) else {
                text += line
                buffer.removeSubrange(buffer.startIndex..<position)
                return IMAPResponse(text: text, literals: literals)
            }
            guard buffer.distance(from: position, to: buffer.endIndex) >= count else { return nil }
            let literalEnd = buffer.index(position, offsetBy: count)
            literals.append(Data(buffer[position..<literalEnd]))
            position = literalEnd
            text += line[line.startIndex..<match.range.lowerBound] + String(IMAPResponse.marker)
        }
    }

    static func string(_ bytes: Data) -> String {
        String(data: bytes, encoding: .utf8) ?? String(data: bytes, encoding: .isoLatin1) ?? ""
    }
}
