import Foundation

/// Where a reply stops being new.
///
/// Nearly half of the text the first full run sent was quoted history: every reply in a long
/// thread carries the whole conversation below it, and each earlier message had already been
/// read when it arrived. So the model is sent the newest message and told that the rest was left
/// out — except when the history is the point. A forward is sent to pass on what is below it,
/// and a reply that says only "siehe unten" means nothing without it.
public enum Quotes {
    public struct Split: Equatable, Sendable {
        public var newest: String
        /// Characters left out. Zero when the whole body was kept.
        public var omitted: Int
        public var reason: String
    }

    /// Below this many letters, the newest part cannot stand on its own.
    static let shortest = 40

    public static func newest(of body: String, subject: String) -> Split {
        let lines = body.components(separatedBy: "\n")
        guard let cut = firstQuote(in: lines) else {
            return Split(newest: body, omitted: 0, reason: "no quoted history")
        }
        let newest = lines[..<cut.line].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let omitted = body.count - newest.count

        if cut.isForward || isForward(subject) {
            return Split(newest: body, omitted: 0, reason: "a forward: what is below is what was sent")
        }
        if newest.filter(\.isLetter).count < shortest {
            return Split(newest: body, omitted: 0, reason: "the new part is too short to stand alone")
        }
        return Split(newest: newest, omitted: omitted, reason: "quoted history left out")
    }

    static func isForward(_ subject: String) -> Bool {
        subject.trimmed.lowercased().firstMatch(of: /^(fwd?|wg|weitergeleitet)\s*:/) != nil
    }

    struct Cut { var line: Int; var isForward: Bool }

    /// The first line of quoted history, by the shapes mail clients write it in.
    static func firstQuote(in lines: [String]) -> Cut? {
        func line(_ index: Int) -> String { index < lines.count ? lines[index].trimmed : "" }

        for index in lines.indices {
            let text = line(index)
            let lowered = text.lowercased()

            // `---------- Forwarded message ---------`, `-----Ursprüngliche Nachricht-----`
            if lowered.firstMatch(of: /^-{2,}\s*(forwarded message|weitergeleitete nachricht|begin forwarded message)/) != nil
                || lowered.hasPrefix("begin forwarded message") || lowered.hasPrefix("anfang der weitergeleiteten") {
                return Cut(line: index, isForward: true)
            }
            if lowered.firstMatch(of: /^-{2,}\s*(original message|ursprüngliche nachricht|original-nachricht)/) != nil {
                return Cut(line: index, isForward: false)
            }
            // `Am 1. Sept. 2026 um 10:00 schrieb Jan <…>:` — often wrapped onto a second line.
            if lowered.firstMatch(of: /^(am|on|le|el)\s/) != nil {
                let joined = (text + " " + line(index + 1)).lowercased()
                if lowered.firstMatch(of: /(schrieb|wrote|a écrit|escribió)[^:]*:\s*$/) != nil
                    || (joined.firstMatch(of: /(schrieb|wrote|a écrit|escribió)[^:]*:\s*$/) != nil && text.count < 200) {
                    return Cut(line: index, isForward: false)
                }
            }
            // Outlook's header block: `Von: …` with `Gesendet:` or `An:` right below it.
            if lowered.firstMatch(of: /^\*?(von|from)\s*:\*?\s/) != nil {
                let below = (1...4).map { line(index + $0).lowercased() }
                if below.contains(where: { $0.firstMatch(of: /^\*?(gesendet|sent|datum|date|an|to|betreff|subject)\s*:/) != nil }) {
                    let previous = index > 0 ? line(index - 1) : ""
                    return Cut(line: previous.allSatisfy({ $0 == "_" || $0 == "-" }) && !previous.isEmpty ? index - 1 : index,
                               isForward: false)
                }
            }
            // Two or more `>` lines in a row.
            if text.hasPrefix(">"), line(index + 1).hasPrefix(">") {
                return Cut(line: index, isForward: false)
            }
        }
        return nil
    }
}
