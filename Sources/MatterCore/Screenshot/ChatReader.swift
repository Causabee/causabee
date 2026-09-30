import CoreGraphics
import Foundation

/// A chat screenshot read as a chat: who is in it, who said what and at what minute, and which
/// of it the owner said. Not a blob of text — a WhatsApp group has a name, participants, speakers,
/// times and date separators, and a bubble on the right is the owner's own, so the owner's own
/// promises come out of it too.
///
/// And a screenshot carries more than was meant. The status bar, a notification that slid in,
/// the field to type in: named and left out, never quietly sent. What is cut off at the top is
/// said, because a to-do read from half a message is a guess.
public struct ChatTranscript: Sendable, Equatable {
    public struct Message: Sendable, Equatable {
        public enum Side: String, Sendable { case mine, theirs }
        public var side: Side
        public var speaker: String?
        public var text: String
        public var time: String?
        /// The date separator above it, as written: "Heute", "Gestern", "12. Sept.".
        public var day: String?
    }

    public var title: String?
    /// What the header says under the title: participants, "online", "zuletzt online …".
    public var subtitle: String?
    public var messages: [Message]
    /// Read, and deliberately not used, with why.
    public var leftOut: [(text: String, why: String)]
    /// What could not be read as a whole.
    public var notes: [String]

    public static func == (a: ChatTranscript, b: ChatTranscript) -> Bool {
        a.title == b.title && a.subtitle == b.subtitle && a.messages == b.messages && a.notes == b.notes
            && a.leftOut.map(\.text) == b.leftOut.map(\.text)
    }

    /// Who is in it, as the header says: "Anna, Tom, Du" under the name, or a group named
    /// "Mira & Rosa".
    public var participants: [String] {
        if let subtitle, subtitle.contains(",") {
            return subtitle.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        guard let title, title.contains("&") || title.contains(",") else { return [] }
        return title.split(whereSeparator: { $0 == "&" || $0 == "," }).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// The people in the chat other than the owner: who spoke, and who the header names.
    public var people: [String] {
        let own: Set<String> = ["du", "you", "ich", "me"]
        var out: [String] = []
        for name in messages.compactMap(\.speaker) + participants where !own.contains(name.lowercased()) {
            // "Rosa" from the header is the "Rosa Kramer" who spoke.
            if out.contains(where: { $0.lowercased().hasPrefix(name.lowercased() + " ") || $0.lowercased() == name.lowercased() }) { continue }
            out.removeAll { name.lowercased().hasPrefix($0.lowercased() + " ") }
            out.append(name)
        }
        return out
    }

    /// As the model reads it: one message a line, with the day, the minute and who spoke.
    public func text(owner: String) -> String {
        var lines: [String] = []
        lines.append("Chat: \(title ?? "(no name)")" + (subtitle.map { " — \($0)" } ?? ""))
        for note in notes { lines.append("[\(note)]") }
        var day: String?
        for message in messages {
            if let next = message.day, next != day { lines.append("— \(next) —"); day = next }
            let who = message.side == .mine ? owner : (message.speaker ?? title ?? "Other")
            lines.append("\(message.time.map { "\($0) " } ?? "")\(who): \(message.text)")
        }
        return lines.joined(separator: "\n")
    }
}

public enum ChatReader {
    public static func read(_ lines: [ScreenText.Line]) -> ChatTranscript {
        var leftOut: [(String, String)] = []
        var notes: [String] = []
        var rest = lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }

        // The status bar: the clock, the network, the battery, in the top few percent.
        let statusBar = rest.filter { $0.bottom < 0.045 }
        for line in statusBar { leftOut.append((line.text, "Statusleiste")) }
        rest.removeAll { $0.bottom < 0.045 }

        // The field to type in, and the keyboard's suggestions under it.
        let inputWords = ["nachricht", "message", "imessage", "tippen", "type a message"]
        let footer = rest.filter { line in
            line.top > 0.9 && (inputWords.contains { line.text.lowercased().contains($0) } || line.top > 0.95 || line.text.count <= 3)
        }
        for line in footer { leftOut.append((line.text, "Eingabefeld")) }
        rest.removeAll { line in footer.contains(line) }

        // The header: the chat's name, and under it who is in it or when they were last there.
        var title: String?
        var subtitle: String?
        let header = rest.filter { $0.bottom < 0.14 }
        if let name = header.filter({ $0.midX > 0.2 && $0.midX < 0.8 }).min(by: { $0.top < $1.top })
            ?? header.min(by: { $0.top < $1.top }) {
            title = name.text
            let under = header.filter { $0 != name && $0.top >= name.bottom - 0.005 && abs($0.midX - name.midX) < 0.25 }
            if let first = under.min(by: { $0.top < $1.top }) { subtitle = first.text }
            let used = [name] + under.prefix(1)
            for line in header where !used.contains(line) {
                // A back arrow's count, a call button, or a notification that slid over the top.
                if line.text.count > 3 { leftOut.append((line.text, "über dem Chat")) }
            }
            rest.removeAll { line in header.contains(line) }
        }

        // What is left is the conversation, top to bottom.
        rest.sort { ($0.top, $0.box.minX) < ($1.top, $1.box.minX) }
        // Cut off at the top when the first line sits right against the header.
        let headerBottom = header.map(\.bottom).max() ?? 0.1
        if let first = rest.first, first.top < headerBottom + 0.03 {
            notes.append("Oben abgeschnitten: die erste Nachricht beginnt vielleicht über dem Bildrand")
        }
        let isGroup = (subtitle?.contains(",") ?? false) || (title?.contains("&") ?? false) || (title?.contains(",") ?? false)

        var messages: [ChatTranscript.Message] = []
        var day: String?
        // WhatsApp writes the name on the first of someone's messages only; the ones after it,
        // until the owner speaks or someone else does, are theirs too.
        var lastSpeaker: String?
        var current: (side: ChatTranscript.Message.Side, lines: [ScreenText.Line], time: String?)?

        func finish() {
            guard let bubble = current else { return }
            current = nil
            var texts = bubble.lines.map(\.text)
            var speaker: String?
            // In a group, someone else's bubble starts with their name, short and on its own line.
            var quotesOwner = false
            if isGroup, bubble.side == .theirs, texts.count >= 2, let first = texts.first, Self.looksLikeName(first) {
                speaker = first.trimmingCharacters(in: CharacterSet(charactersIn: "~ "))
                texts.removeFirst()
            }
            // A reply quotes what it answers, under the quoted person's name — "You" or "Du" when
            // it is the owner. That is not who is speaking.
            if let named = speaker, Self.ownerWords.contains(named.lowercased()) {
                speaker = nil
                quotesOwner = true
            } else if bubble.side == .theirs, let first = texts.first, Self.ownerWords.contains(first.lowercased()), texts.count >= 2 {
                texts.removeFirst()
                quotesOwner = true
            }
            if bubble.side == .mine { lastSpeaker = nil }
            else if let named = speaker { lastSpeaker = named }
            else if isGroup { speaker = lastSpeaker }
            let text = ((quotesOwner ? "[antwortet auf eine Nachricht von dir] " : "") + texts.joined(separator: " "))
                .trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return }
            messages.append(.init(side: bubble.side, speaker: speaker, text: text, time: bubble.time, day: day))
        }

        for line in rest {
            let text = line.text.trimmingCharacters(in: .whitespaces)
            // A date separator: short, in the middle, and a day.
            if abs(line.midX - 0.5) < 0.12, line.box.width < 0.4, isDay(text) {
                finish()
                day = text
                continue
            }
            // The minute a message was sent, alone at the bubble's foot, with its ticks.
            if let time = Self.time(in: text), text.count <= 8 {
                if current != nil { current?.time = time; finish() } else if let last = messages.indices.last, messages[last].time == nil {
                    messages[last].time = time
                }
                continue
            }
            let side: ChatTranscript.Message.Side = line.box.minX > 0.3 && line.box.maxX > 0.7 ? .mine : .theirs
            if let open = current, open.side == side, let previous = open.lines.last, line.top - previous.bottom < max(previous.box.height, 0.012) * 1.6 {
                current?.lines.append(line)
            } else {
                finish()
                current = (side, [line], nil)
            }
            // A line that ends with its own minute: "Bin um 8 da 21:14".
            if let trailing = text.firstMatch(of: /\s(\d{1,2}:\d{2})\s*[✓✔︎]*$/) {
                if var open = current, !open.lines.isEmpty {
                    open.lines[open.lines.count - 1].text = String(text[..<trailing.range.lowerBound])
                    open.time = String(trailing.output.1)
                    current = open
                }
                finish()
            }
        }
        finish()
        if messages.isEmpty { notes.append("Keine Nachrichten erkannt — ist das ein Chat?") }
        return ChatTranscript(title: title, subtitle: subtitle, messages: messages, leftOut: leftOut, notes: notes)
    }

    /// A speaker's name line: a few words, each with a capital, no sentence mark — or a number,
    /// which is how WhatsApp names someone not in the address book.
    static let ownerWords: Set<String> = ["you", "du", "ich"]

    static func looksLikeName(_ text: String) -> Bool {
        let words = text.trimmingCharacters(in: CharacterSet(charactersIn: "~ ")).split(separator: " ")
        guard (1...4).contains(words.count), !text.contains(where: { ".?!:,".contains($0) }) else { return false }
        if text.firstMatch(of: /^~?\s?\+?[\d\s]{6,}$/) != nil { return true }
        return words.allSatisfy { $0.first?.isUppercase == true || ["von", "van", "de", "v", "zu"].contains($0.lowercased()) }
    }

    static func time(in text: String) -> String? {
        text.wholeMatch(of: /(\d{1,2}:\d{2})\s*[✓✔︎]*/).map { String($0.output.1) }
    }

    static let dayWords: Set<String> = ["heute", "gestern", "today", "yesterday", "montag", "dienstag", "mittwoch", "donnerstag",
                                         "freitag", "samstag", "sonntag", "monday", "tuesday", "wednesday", "thursday", "friday",
                                         "saturday", "sunday"]

    static func isDay(_ text: String) -> Bool {
        let lower = text.lowercased()
        if dayWords.contains(lower) { return true }
        if lower.firstMatch(of: /^\d{1,2}\.\s?(\d{1,2}\.(\d{2,4})?|[a-zäöü]{3,9}\.?(\s\d{4})?)$/) != nil { return true }
        if lower.firstMatch(of: /^(mo|di|mi|do|fr|sa|so)\.?,?\s\d{1,2}\./) != nil { return true }
        return false
    }
}
