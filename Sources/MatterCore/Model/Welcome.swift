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

    public static let promise = "Every matter.\nIn its place."
    public static let promiseLine = "Mum’s care, a claim, a move: each in its own place — with what comes next, and who does what by when."
    /// Said once, on the first page.
    public static let privacy = "Names are disguised before anything is sent."

    public static let pages = [
        Page(image: "welcome-1", title: "One page for each matter", line: "What comes next, and who does what by when."),
        Page(image: "welcome-2", title: "From whatever you have", line: "A screenshot, a photo, a letter, a few words: the bee finds the dates and the tasks."),
        Page(image: "welcome-3", title: "Ask about it", line: "Ask, and get an answer with where it came from."),
    ]

    // MARK: The first step

    public static let firstTitle = "What's on your mind?"
    public static let firstLine = "Type it in a few words, or add what you have."
    public static let placeholder = "Mum’s care, a claim, a move …"
    public static let demoAsk = "Not sure yet?"
    public static let demo = "Look around in an example."
    public static let reading = "Reading …"
    public static let cloudLine = "Looking in iCloud for your matters …"
    public static let unreadable = "Causabee can't read this file."
    public static let notRead = "Not read yet — your words are kept."

    /// With no matters at all there is nothing to choose: what is added goes into a new matter at
    /// once, named as the bee proposes, and opens.
    public static func takesAtOnce(matters: Int) -> Bool { matters == 0 }

    /// The first matter's name: the bee's, or the typed words' first line when it gives none.
    public static func matterName(proposed: String?, typed: String) -> String {
        if let proposed = proposed?.trimmingCharacters(in: .whitespacesAndNewlines), !proposed.isEmpty { return proposed }
        let line = typed.split(whereSeparator: \.isNewline).first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? ""
        return String((line.isEmpty ? "A new matter" : line).prefix(60))
    }

    /// Typed words as a file that comes in like any other: a `.txt`, read by `ScreenshotDoor` as the
    /// owner's own note. Named by its words, so the same words twice are one file.
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

    /// The name is asked while none is known.
    public static func asksName(names: [String]) -> Bool {
        names.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    public static let nameAskMac = "This is you:"
    public static let nameAsk = "Your name, so your tasks show as yours."

    /// Mail is offered once a matter exists, while no mailbox is set up, until Not now.
    public static let mailLaterKey = "mail.offer.later"
    public static func offersMail(matters: Int, hasMailbox: Bool, later: Bool) -> Bool {
        matters > 0 && !hasMailbox && !later
    }
    public static let mailTitle = "Also what comes by mail?"
    public static let mailLine = "Causabee reads one label or folder you choose — nothing else in your mailbox."
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
