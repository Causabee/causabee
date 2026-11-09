import Foundation

/// How a message is written: how it opens and how it closes — "Hallo Ralf" … "Gruß, Jens". What a
/// summary loses, and what a draft needs to sound like the owner to that person (principle 13).
public enum Register {
    public struct Lines: Equatable, Sendable {
        public var opens: String
        public var closes: String
    }

    /// The first line and the last lines of the newest part — above any quoted history. Nil when
    /// there is too little to tell.
    public static func of(_ body: String) -> Lines? {
        var lines = body.components(separatedBy: "\n")
        if let cut = Quotes.firstQuote(in: lines) { lines = Array(lines[..<cut.line]) }
        let kept = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !$0.hasPrefix(">") }
        guard kept.count >= 2, let first = kept.first else { return nil }
        // The sign-off and the name under it — not the address, phone and register of a signature block.
        let rest = Array(kept.dropFirst())
        if let at = rest.lastIndex(where: isSignOff) {
            let closes = rest[at...].prefix(2).map { String($0.prefix(60)) }
            return Lines(opens: String(first.prefix(80)), closes: closes.joined(separator: " / "))
        }
        let tail = rest.suffix(2).filter { $0.count <= 40 }
        guard !tail.isEmpty else { return nil }
        return Lines(opens: String(first.prefix(80)), closes: tail.joined(separator: " / "))
    }

    /// "Viele Grüße", "Gruß", "LG", "Best regards", "Cheers", "Merci" — a line that ends a message.
    static func isSignOff(_ line: String) -> Bool {
        let words = line.lowercased()
        guard words.count <= 40 else { return false }
        return words.firstMatch(of: /gr(u|ü|ue)(ß|ss)|regards|^best\b|^cheers|^thanks|^thank you|^danke|^lg\b|^vg\b|^bg\b|^mfg\b|^liebe|^herzlich|^beste|^ciao|^bis (bald|dann|morgen|freitag)|^cordialement|^bien à vous|^merci|^saludos|^un saluto|^take care|^yours|^sincerely|^bye/) != nil
    }
}
