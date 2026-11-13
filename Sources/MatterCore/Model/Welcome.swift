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

    public static let firstTitle = "What’s on your mind?"
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
        guard !line.isEmpty else { return "A new matter" }
        guard line.count > 60 else { return line }
        // Cut at a word, never in one.
        let cut = String(line.prefix(60))
        let words = cut.split(separator: " ").dropLast()
        return (words.isEmpty ? cut : words.joined(separator: " ")).trimmingCharacters(in: CharacterSet(charactersIn: " ,;:—-"))
    }

    /// Typed words as a file that comes in like any other: a `.txt`, read by `ScreenshotDoor` as the
    /// owner's own note. Named by its words, so the same words twice are one file.
    /// The file the first step wrote: shown as the owner's words, never by its file name.
    public static func isTyped(_ file: URL) -> Bool {
        file.pathExtension.lowercased() == "txt" && file.lastPathComponent.contains("typed-")
    }

    /// The first step's own words are read on this device, with Pro too (the owner, 13 November):
    /// Apple's model names the first matter and finds its dates, and nothing leaves the device at
    /// the door. What is added there, and every word after, is read as anything that comes in.
    public static func readsOnDevice(_ file: URL, matters: Int) -> Bool {
        isTyped(file) && matters == 0
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

extension Source {
    /// The owner's own typed words (F008): kept as the kind every build knows, with "you" as where
    /// they came from — so they read as the owner's, never as the assistant's.
    public static let ownWords = "you"
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
