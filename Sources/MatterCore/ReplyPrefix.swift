import Foundation

/// "Re:", "AW:", "Fwd:" and the like at the head of a subject, taken off — by hand, letter by
/// letter. A regular expression did it before, a quarter of a millisecond each time: a matter's
/// conversations, built after every change, spent thirty milliseconds on it.
enum ReplyPrefix {
    enum Colon { case required, optional }

    /// Tried in this order, as the expression did: the first that fits is taken.
    private static let words = ["re", "aw", "antw", "wg", "fwd", "fw"]

    static func strip(_ text: Substring, colon: Colon, brackets: Bool) -> Substring {
        var rest = text
        while let after = prefix(of: rest, colon: colon, brackets: brackets), after != rest.startIndex {
            rest = rest[after...]
        }
        return rest
    }

    /// Where the text goes on after one prefix and the space and colon behind it; nil when it has none.
    private static func prefix(of text: Substring, colon: Colon, brackets: Bool) -> Substring.Index? {
        var heads: [Substring.Index] = []
        if brackets, text.first == "[", let close = text.firstIndex(of: "]") { heads.append(text.index(after: close)) }
        for word in words where text.count >= word.count {
            let end = text.index(text.startIndex, offsetBy: word.count)
            if text[..<end].lowercased() == word { heads.append(end) }
        }
        for head in heads {
            var at = head
            while at < text.endIndex, text[at].isWhitespace { at = text.index(after: at) }
            if at < text.endIndex, text[at] == ":" {
                at = text.index(after: at)
            } else if colon == .required {
                continue
            }
            while at < text.endIndex, text[at].isWhitespace { at = text.index(after: at) }
            return at
        }
        return nil
    }
}
