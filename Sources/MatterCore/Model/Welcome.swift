import CryptoKit
import Foundation

/// F008: the first start, the same on every device — the promise, three calm pages, then the
/// person's own Causabee with one first step. Nothing is asked at the door: the name and mail come
/// once a matter exists. The words live here so the Mac, the iPhone and the iPad say the same.
public enum Welcome {
    public struct Page: Sendable {
        /// The picture in the app's bundle: "welcome-N" on the Mac (png), "phone-welcome-N" on the iPhone and iPad (jpg).
        public let image: String
        public let title: String
        public let line: String
    }

    public static var promise: String { String(localized: "Every matter.\nIn its place.", bundle: .module) }
    public static var promiseLine: String { String(localized: "Mum’s care, a claim, a move: each in its own place — with what comes next, and who does what by when.", bundle: .module) }
    /// Said once, on the first page.
    public static var privacy: String { String(localized: "Names are disguised before anything is sent.", bundle: .module) }

    public static var pages: [Page] { [
        Page(image: "welcome-1", title: String(localized: "One page for each matter", bundle: .module),
             line: String(localized: "What comes next, and who does what by when.", bundle: .module)),
        Page(image: "welcome-2", title: String(localized: "From whatever you have", bundle: .module),
             line: String(localized: "A screenshot, a photo, a letter, a few words: the bee finds the dates and the tasks.", bundle: .module)),
        Page(image: "welcome-3", title: String(localized: "Ask about it", bundle: .module),
             line: String(localized: "Ask, and get an answer with where it came from.", bundle: .module)),
    ] }

    // MARK: The first step

    public static var firstTitle: String { String(localized: "What’s on your mind?", bundle: .module) }
    public static var firstLine: String { String(localized: "Type it in a few words, or add what you have.", bundle: .module) }
    public static var placeholder: String { String(localized: "Mum’s care, a claim, a move …", bundle: .module) }
    public static var demoAsk: String { String(localized: "Not sure yet?", bundle: .module) }
    public static var demo: String { String(localized: "Look around in an example.", bundle: .module) }
    public static var reading: String { String(localized: "Reading …", bundle: .module) }
    public static var cloudLine: String { String(localized: "Looking in iCloud for your matters …", bundle: .module) }
    public static var unreadable: String { String(localized: "Causabee can't read this file.", bundle: .module) }
    public static var notRead: String { String(localized: "Not read yet — your words are kept.", bundle: .module) }

    /// With no matters at all there is nothing to choose: what is added goes into a new matter at
    /// once, named as the bee proposes, and opens.
    public static func takesAtOnce(matters: Int) -> Bool { matters == 0 }

    /// The first matter's name: the bee's, or the typed words' first line when it gives none.
    /// `within`: all the words read — a screenshot's or a file's whole text; the typed line by default.
    public static func matterName(proposed: String?, typed: String, within: String? = nil) -> String {
        if let proposed = proposed?.trimmingCharacters(in: .whitespacesAndNewlines), !proposed.isEmpty,
           grounded(proposed, in: within ?? typed) { return proposed }
        let first = typed.split(whereSeparator: \.isNewline).first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !first.isEmpty else { return "A new matter" }
        let line = beforeDate(first)
        guard line.count > 60 else { return line }
        // Cut at a word, never in one.
        let cut = String(line.prefix(60))
        let words = cut.split(separator: " ").dropLast()
        return (words.isEmpty ? cut : words.joined(separator: " ")).trimmingCharacters(in: CharacterSet(charactersIn: " ,;:—-"))
    }

    /// A first matter's dates: one made up — a "what" with no word of the line, or only the date —
    /// takes the matter's name; two on one day from one line are one, the appointment kept
    /// ("die Verteilung" and "den Tag" on 1 February are "Umzug" on 1 February).
    public static func nameDates(_ judgement: inout Judgement, name: String, line: String) {
        for index in judgement.appointments.indices where !grounded(judgement.appointments[index].what, in: line) {
            judgement.appointments[index].what = name
        }
        for index in judgement.deadlines.indices where !grounded(judgement.deadlines[index].what, in: line) {
            judgement.deadlines[index].what = name
        }
        let days = Set(judgement.appointments.map(\.date))
        judgement.deadlines.removeAll { days.contains($0.date) }
        var seen = Set<String>()
        judgement.appointments.removeAll { !seen.insert($0.date).inserted }
        seen = []
        judgement.deadlines.removeAll { !seen.insert($0.date).inserted }
    }

    /// Whether a name or a label is the line's own: one of its words — three letters or more, not a
    /// little word as "the" or "die" — is in the line; a word of five or more also with one letter
    /// more, less or other, as a typo fixed is.
    public static func grounded(_ text: String, in line: String) -> Bool {
        func words(_ s: String) -> [String] {
            s.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
                .filter { $0.count >= 3 && $0.contains { $0.isLetter } && !little.contains($0) }
        }
        let theirs = words(line)
        return words(text).contains { word in theirs.contains { $0 == word || (word.count >= 5 && close($0, word)) } }
    }

    static let little: Set<String> = ["the", "and", "for", "are", "was", "has", "not", "but", "you", "our", "with", "from",
                                      "der", "die", "das", "den", "dem", "des", "und", "ist", "mit", "von", "für", "auf", "aus",
                                      "bei", "ein", "eine", "einen", "zum", "zur", "sie", "wir", "ich"]

    /// One letter more, less or other.
    static func close(_ a: String, _ b: String) -> Bool {
        let a = Array(a), b = Array(b)
        guard abs(a.count - b.count) <= 1 else { return false }
        var i = 0, j = 0, edits = 0
        while i < a.count, j < b.count {
            if a[i] == b[j] { i += 1; j += 1; continue }
            edits += 1
            if edits > 1 { return false }
            if a.count > b.count { i += 1 } else if b.count > a.count { j += 1 } else { i += 1; j += 1 }
        }
        return edits + (a.count - i) + (b.count - j) <= 1
    }

    /// The line before its first date, without the words that lead to it: "Muttis Reha started am
    /// 2.12.2026" is "Muttis Reha". A line that starts with its date stays as it is.
    static func beforeDate(_ line: String) -> String {
        let months = "January|February|March|April|May|June|July|August|September|October|November|December|Januar|Februar|März|Mai|Juni|Juli|Oktober|Dezember"
        let pattern = "\\b(\\d{1,2}\\.\\s?\\d{1,2}\\.(\\d{2,4})?|\\d{4}-\\d{2}-\\d{2}|\\d{1,2}/\\d{1,2}(/\\d{2,4})?|\\d{1,2}\\.?\\s(\(months))|(\(months))\\s\\d{1,2})"
        guard let date = line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return line }
        let leadIn: Set<String> = ["am", "an", "ab", "bis", "vom", "zum", "zur", "um", "on", "by", "at", "from", "until", "till",
                                   "due", "fällig", "start", "starts", "started", "startet", "beginnt", "begins", "is", "ist"]
        var words = line[..<date.lowerBound].split(separator: " ").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ",;:—-")) }
        while let last = words.last, last.isEmpty || leadIn.contains(last.lowercased()) { words.removeLast() }
        return words.isEmpty ? line : words.joined(separator: " ")
    }

    /// Typed words as a file that comes in like any other: a `.txt`, read by `ScreenshotDoor` as the
    /// owner's own note. Named by its words, so the same words twice are one file.
    /// The file the first step wrote: shown as the owner's words, never by its file name.
    // MARK: The start credit (AC-14 – AC-17)

    /// Under the first step, while the start credit is there and unused (AC-15).
    public static var startLine: String { String(localized: "A start credit is yours: Pro reads your first things, names disguised.", bundle: .module) }
    /// Pro's use names it so while it is all there is beyond the month (AC-15).
    public static var startName: String { String(localized: "Start credit", bundle: .module) }
    /// The card once it is used (AC-17), and its "Not now".
    public static var startUsedTitle: String { String(localized: "Your start credit is used.", bundle: .module) }
    public static var startUsedLine: String { String(localized: "Apple's model on this device reads from now on. A top-up lets Pro read again.", bundle: .module) }
    public static let startUsedLaterKey = "start.used.later"
    /// Asked once on this device; `--fresh-start` forgets it, for the owner's tries.
    public static let startAskedKey = "start.asked"

    /// "Use Pro" turned on by the start credit (AC-16): it is there, something of it is left, and the
    /// owner has never set the switch — their own choice, on or off, always stays.
    public static func switchesProOn(startCredit: Bool, extra: Bool, setByOwner: Bool) -> Bool {
        startCredit && extra && !setByOwner
    }

    /// The line under the first step: the credit is there, and nothing of it is used yet.
    public static func showsStartLine(startCredit: Bool, extraShare: Double) -> Bool {
        startCredit && extraShare >= 0.33
    }

    /// The card: a matter exists, the start credit is all there was and is used, no Pro month,
    /// not put away — counted by the beeserver since this launch.
    public static func offersTopUp(matters: Int, startCredit: Bool, extraShare: Double, pro: Bool, counted: Bool, later: Bool) -> Bool {
        matters > 0 && startCredit && extraShare <= 0 && !pro && counted && !later
    }

    /// All the words read from what came in, to check a name or a date against.
    public static func words(of look: ScreenshotDoor.Look) -> String {
        look.heading + "\n" + (look.report.outcomes.first?.email.body ?? "")
    }

    public static func isTyped(_ file: URL) -> Bool {
        file.pathExtension.lowercased() == "txt" && file.lastPathComponent.contains("typed-")
    }

    public static func typedFile(_ text: String, in folder: URL) throws -> URL {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hash = SHA256.hash(data: Data(words.utf8)).prefix(6).map { String(format: "%02x", $0) }.joined()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("typed-\(hash).txt")
        try words.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    /// While iCloud may still be bringing the matters of another device: signed in, nothing
    /// imported yet, and not yet thirty seconds.
    public static let cloudWait: TimeInterval = 30
    public static func waitsForCloud(signedIn: Bool, imported: Bool, since: Date, now: Date = Date()) -> Bool {
        signedIn && !imported && now.timeIntervalSince(since) < cloudWait
    }

    // MARK: Afterwards

    /// How often Causabee has been started on this device (F008 AC-13).
    public static let startsKey = "app.starts"
    /// Counted once per start, as the app comes up.
    public static func countStart() {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: startsKey) + 1, forKey: startsKey)
    }
    /// The system's question about notifications waits for the second start: the first is for
    /// getting in, not for being asked (the owner, 12 November). It is asked then only when there is
    /// something to tell — a date, or something new — which is where it is called from.
    public static func mayAskNotifications(starts: Int = UserDefaults.standard.integer(forKey: startsKey)) -> Bool {
        starts >= 2
    }

    /// The name is asked while none is known.
    public static func asksName(names: [String]) -> Bool {
        names.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    public static var nameAskMac: String { String(localized: "This is you:", bundle: .module) }
    public static var nameAsk: String { String(localized: "Your name, so your tasks show as yours.", bundle: .module) }

    /// Mail is offered once a matter exists, while no mailbox is set up, until Not now.
    public static let mailLaterKey = "mail.offer.later"
    public static func offersMail(matters: Int, hasMailbox: Bool, later: Bool) -> Bool {
        matters > 0 && !hasMailbox && !later
    }
    public static var mailTitle: String { String(localized: "Also what comes by mail?", bundle: .module) }
    public static var mailLine: String { String(localized: "Causabee reads one label or folder you choose — nothing else in your mailbox.", bundle: .module) }
}

extension Source {
    /// The owner's own typed words (F008): kept as the kind every build knows, with "you" as where
    /// they came from — so they read as the owner's, never as the assistant's.
    public static var ownWords: String { String(localized: "you", bundle: .module) }
    public var isOwnWords: Bool { kind == .conversation && pointer == Self.ownWords }
}

extension Source.Kind {
    /// What kind of source an intake's id makes: a screenshot, a document, the owner's typed words,
    /// or a mail.
    public static func of(emailID: String) -> Source.Kind {
        emailID.hasPrefix("screenshot:") ? .screenshot
            : emailID.hasPrefix("document:") ? .document
            : emailID.hasPrefix("typed:") ? .conversation : .mail
    }
}

import SwiftData

extension Welcome {
    /// Typed words, read: kept on their matter as the owner's own note as well, word for word —
    /// so the first matter holds what was typed, whatever the bee found in it. Once.
    public static func keepTyped(_ look: ScreenshotDoor.Look, in matter: Matter, context: ModelContext) {
        guard look.file.pathExtension.lowercased() == "txt",
              let words = look.report.outcomes.first?.email.body.trimmingCharacters(in: .whitespacesAndNewlines), !words.isEmpty,
              !(matter.noteBlocks ?? []).contains(where: { $0.text == words }) else { return }
        let note = MatterNote(text: words)
        context.insert(note)
        note.matter = matter
    }
}
