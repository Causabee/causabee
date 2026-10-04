import Foundation
import SwiftData

// Phase 1's data model: what a matter is made of, kept as facts with a way back to where each
// one came from.
//
// Written for CloudKit from the start, because moving a store to it later means a migration:
// every attribute has a default, every relationship is optional, and nothing is marked unique.
// Kinds are stored as their raw strings, which CloudKit and every future version can read.

/// Where an entry came from. Every fact carries one, because that is what makes a history
/// checkable: "the property manager wrote this on 9 June" rather than "the app thinks so".
public struct Source: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case mail, spokenNote = "spoken_note", photo, phoneCall = "phone_call", document, screenshot
        /// Something the owner accepted from the assistant: a card they ticked.
        case conversation
    }
    public var kind: Kind
    /// The way back: `imap://…;UID=…` for a mail, a file path for a document.
    public var pointer: String
    /// A mail's Message-ID. The same mail read from two folders is one source.
    public var messageID: String?
    public var date: Date?
    /// The words a fact was read out of.
    public var quote: String?

    public init(kind: Kind, pointer: String, messageID: String? = nil, date: Date? = nil, quote: String? = nil) {
        self.kind = kind
        self.pointer = pointer
        self.messageID = messageID
        self.date = date
        self.quote = quote
    }

    /// The same source, pointing at the words of one fact.
    public func quoting(_ quote: String) -> Source {
        var copy = self
        copy.quote = quote.isEmpty ? nil : quote
        return copy
    }
}

@Model
public final class Matter {
    public var name: String = ""
    /// The name the model gave it. Kept when the owner renames it, so the next mail the model
    /// files under the old name still arrives here.
    public var key: String = ""
    /// Every other name this matter has had or has absorbed — a merged matter's key lives on here.
    public var aliases: [String] = []
    public var createdAt: Date = Date()
    public var closedAt: Date?
    /// When the owner pinned it to the top of the overview; nil when it is not pinned.
    public var pinnedAt: Date?
    /// The icon the owner chose for it, a system symbol's name; nil while Causabee suggests one
    /// from the name.
    public var icon: String?
    /// The phase the matter is in, from its template. Nil until templates exist.
    public var phase: String?
    /// Three or four lines on what it is about, where it stands and what comes next — written
    /// on request, from the facts, and dated, because it is only true as of then.
    public var summary: String?
    public var summaryAt: Date?
    /// The owner's own notes on the matter: what was agreed on the phone, what to keep in mind.
    public var notes: String?
    /// The next step as Claude suggested it, with why, and when — asked for with a click.
    public var nextStep: String?
    public var nextStepWhy: String?
    public var nextStepAt: Date?
    /// The name of its folder in iCloud Drive, as last made: renamed with the matter.
    public var folderName: String?
    /// When its mails were last searched for links, on the owner's click.
    public var linksSearchedAt: Date?
    /// The `origin` of the to-do Claude's step is about, to find it again for its buttons.
    public var nextStepTodo: String?

    @Relationship(deleteRule: .cascade, inverse: \Entry.matter) public var entries: [Entry]? = []
    @Relationship(deleteRule: .cascade, inverse: \Todo.matter) public var todos: [Todo]? = []
    @Relationship(deleteRule: .cascade, inverse: \Appointment.matter) public var appointments: [Appointment]? = []
    @Relationship(deleteRule: .cascade, inverse: \Deadline.matter) public var deadlines: [Deadline]? = []
    @Relationship(deleteRule: .cascade, inverse: \Decision.matter) public var decisions: [Decision]? = []
    @Relationship(deleteRule: .cascade, inverse: \Membership.matter) public var memberships: [Membership]? = []
    @Relationship(deleteRule: .cascade, inverse: \Document.matter) public var documents: [Document]? = []
    @Relationship(deleteRule: .cascade, inverse: \WebLink.matter) public var links: [WebLink]? = []
    /// The owner's thoughts on it, each a small block with its day.
    @Relationship(deleteRule: .cascade, inverse: \MatterNote.matter) public var noteBlocks: [MatterNote]? = []
    /// The assistant's turns about this matter. A matter that goes leaves them in the thread.
    @Relationship(deleteRule: .nullify, inverse: \ThreadTurn.matter) public var turns: [ThreadTurn]? = []

    public init(key: String, name: String? = nil) {
        self.key = key
        self.name = name ?? key
    }

    /// True for its key, its name or any alias, ignoring case.
    public func answers(to name: String) -> Bool {
        let wanted = name.lowercased()
        return ([key, self.name] + aliases).contains { $0.lowercased() == wanted }
    }

    public var openTodos: [Todo] { (todos ?? []).filter { !$0.isDone && !$0.isInfo } }

    /// What the mail said that is worth knowing but is nothing to do: the owner moved it here.
    public var infos: [Todo] { (todos ?? []).filter(\.isInfo) }

    /// The people in this matter, each once.
    public var parties: [Party] { (memberships ?? []).compactMap(\.party) }

    public func membership(of party: Party) -> Membership? {
        (memberships ?? []).first { $0.party === party }
    }
}

/// One thing that happened in a matter — for now, one mail. The timeline is made of these.
@Model
public final class Entry {
    public var date: Date?
    public var title: String = ""
    public var from: String = ""
    public var source: Source = Source(kind: .mail, pointer: "")
    /// The Message-ID, kept outside `source` so it can be searched for.
    public var messageID: String = ""
    /// What the mail says, in two or three sentences, from when it was sorted in.
    public var digest: String?
    /// The Message-ID of the mail this one answers: "" when it answers none, nil when not yet
    /// known — mail sorted in before it was kept, read once from the mailbox's headers.
    public var replyTo: String?
    public var matter: Matter?

    public init(title: String, from: String, date: Date?, source: Source) {
        self.title = title
        self.from = from
        self.date = date
        self.source = source
        self.messageID = source.messageID ?? source.pointer
    }
}

@Model
public final class Todo {
    /// Whose it is: `me`, `we` (the owner with others, the owners of a building as one), or
    /// `other` — someone else's that the owner is waiting for.
    public enum Owner: String, Codable, Sendable, CaseIterable { case me, we, other, unknown }

    public var text: String = ""
    public var ownerRaw: String = Owner.unknown.rawValue
    /// `YYYY-MM-DD`, as the mail gave it; nil when it gave none.
    public var due: String?
    /// `HH:MM`, when the owner gave the day a time.
    public var dueTime: String?
    /// The owner's own words to go with it: a list, a detail, a reminder of what was agreed.
    public var note: String?
    public var isDone: Bool = false
    /// Not a to-do after all, only something worth knowing. Kept, and not counted as open.
    public var isInfo: Bool = false
    public var doneAt: Date?
    /// The mail that showed it done.
    public var doneSource: Source?
    /// Every mail that asked for it. The first is where it came from; the rest are it being
    /// asked again, which is why a to-do list stays one line per thing.
    public var sources: [Source] = []
    /// The first mail's Message-ID and the text, which is how the same to-do is found again when
    /// a later run is imported.
    public var origin: String = ""
    public var createdAt: Date = Date()
    public var matter: Matter?
    /// The to-do this one can only be done after: the proof waits for the answer it needs.
    public var waitsFor: Todo?
    /// The to-dos that wait for this one.
    @Relationship(deleteRule: .nullify, inverse: \Todo.waitsFor) public var unblocks: [Todo]? = []
    /// The reminder it is connected to, by the id that is the same on every device.
    public var reminderID: String?
    /// What it and its reminder agreed on when they were last in step: text, day, time, done.
    public var reminderStamp: String?
    /// Links the owner put with it. A to-do that goes keeps them in its matter.
    @Relationship(deleteRule: .nullify, inverse: \WebLink.todo) public var links: [WebLink]? = []

    public var owner: Owner {
        get { Owner(rawValue: ownerRaw) ?? .unknown }
        set { ownerRaw = newValue.rawValue }
    }

    public init(text: String, owner: Owner, due: String?, source: Source, origin: String) {
        self.text = text
        self.ownerRaw = owner.rawValue
        self.due = due
        self.sources = [source]
        self.origin = origin
        self.createdAt = source.date ?? Date()
    }
}

/// A meeting, call or visit at a set time. Not a to-do and not a deadline.
@Model
public final class Appointment {
    public var what: String = ""
    /// `YYYY-MM-DD`.
    public var day: String = ""
    /// `HH:MM`, or nil when only the day is known.
    public var time: String?
    public var place: String?
    public var sources: [Source] = []
    /// The calendar event it is connected to, by the id that is the same on every device.
    public var calendarID: String?
    /// What it and its event agreed on when they were last in step.
    public var calendarStamp: String?
    public var matter: Matter?

    public init(what: String, day: String, time: String?, place: String?, source: Source) {
        self.what = what
        self.day = day
        self.time = time
        self.place = place
        self.sources = [source]
    }
}

/// A date by which something has to be done.
@Model
public final class Deadline {
    public var what: String = ""
    /// `YYYY-MM-DD`.
    public var day: String = ""
    public var sources: [Source] = []
    /// The calendar event it is connected to, by the id that is the same on every device.
    public var calendarID: String?
    /// What it and its event agreed on when they were last in step.
    public var calendarStamp: String?
    public var matter: Matter?

    public init(what: String, day: String, source: Source) {
        self.what = what
        self.day = day
        self.sources = [source]
    }
}

/// Someone a matter involves — a person or a company. One party across matters: the property
/// manager of two buildings is one party with two memberships, and a role in one matter is not
/// shown in another.
@Model
public final class Party {
    /// The plainest full name it has been written as: `Petra Lindner`, not `Frau Dr. Petra
    /// Lindner (Mimi)`.
    public var name: String = ""
    /// Every way it has been written, as written.
    public var spellings: [String] = []
    /// The same, folded for looking up: no title, no brackets, no case, no spaces, `ü` as `ue`.
    public var keys: [String] = []
    @Relationship(deleteRule: .cascade, inverse: \Membership.party) public var memberships: [Membership]? = []

    public init(name: String) {
        self.name = name
    }

    public var matters: [Matter] { (memberships ?? []).compactMap(\.matter) }

    /// The spellings other than the name, for "also written as".
    public var otherSpellings: [String] { spellings.filter { $0 != name } }
}

/// A party in one matter, and what they are there: "Beirat" in the house, "Gutachterin" in the
/// insurer's mail about the roof.
@Model
public final class Membership {
    public var party: Party?
    public var matter: Matter?
    /// Newest last.
    public var roles: [String] = []
    /// How many mails named them.
    public var mentions: Int = 0

    public init() {}

    /// The latest role that says something. "unklar" does not.
    public var role: String? { roles.last { !Membership.isVague($0) } ?? roles.last }

    static func isVague(_ role: String) -> Bool {
        let text = role.lowercased()
        return text.isEmpty || text.hasPrefix("unklar") || text == "unknown"
    }

    /// How much they are in the matter, in words: "in 3 of 8 mails", "in all 4 mails" — and
    /// whether they are the one named most, alone at the top of more than one. Nil when no mail
    /// named them.
    public var share: (text: String, isMost: Bool)? {
        let total = matter?.entries?.count ?? 0
        let named = min(mentions, total)
        guard named > 0 else { return nil }
        let text = named == total
            ? (total == 1 ? "in its one mail" : "in all \(total) mails")
            : "in \(named) of \(total) \(total == 1 ? "mail" : "mails")"
        let others = (matter?.memberships ?? []).filter { $0 !== self && $0.party != nil }
        let isMost = !others.isEmpty && others.allSatisfy { $0.mentions < mentions }
        return (text, isMost)
    }
}

/// A standing instruction from the owner, with where it came from, how often it has been used,
/// and a switch. Nothing Causabee learns is learned where the owner cannot see it.
@Model
public final class Rule {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        /// `subject` is the same party as `object`.
        case sameParty = "same_party"
        /// `subject` and `object` are two parties; do not suggest them again.
        case notSameParty = "not_same_party"
        /// The party called `subject` is really called `object`.
        case partyName = "party_name"
        /// The party called `subject` is not part of the matter `matterKey`: the owner took them out.
        case notInMatter = "not_in_matter"
    }
    public var kindRaw: String = Kind.sameParty.rawValue
    public var subject: String = ""
    public var object: String = ""
    /// The matter it holds in, by key. Nil for everywhere.
    public var matterKey: String?
    /// Where it came from, in words: "you, in hausverwaltung, 28 Sep 2026".
    public var origin: String = ""
    public var createdAt: Date = Date()
    public var fired: Int = 0
    public var isOn: Bool = true

    /// Nil for a kind this version does not know — one a newer Causabee on another device made.
    /// Such a rule is left alone, never taken for another kind: read as "the same person", it would
    /// merge people.
    public var kind: Kind? {
        get { Kind(rawValue: kindRaw) }
        set { if let newValue { kindRaw = newValue.rawValue } }
    }

    public init(_ kind: Kind, subject: String, object: String, matterKey: String?, origin: String) {
        self.kindRaw = kind.rawValue
        self.subject = subject
        self.object = object
        self.matterKey = matterKey
        self.origin = origin
    }
}

/// Who the owner is: the names and addresses they go by. They are never a party in their own
/// matters.
@Model
public final class Profile {
    public var names: [String] = []
    /// Which model sorts the mail and which answers, as the owner chose on any device: the others
    /// take it over. Nil until chosen; then each device's own choice, or Opus, stands.
    public var mailModel: String?
    public var assistantModel: String?

    public init(names: [String]) {
        self.names = names
    }
}

/// A file attached to a mail of the matter. Kept as a fact and a way back, not as a copy: it lives
/// in the mail, and "Öffnen" takes it out of the mail when it is wanted.
@Model
public final class Document {
    public var name: String = ""
    public var contentType: String = ""
    public var byteCount: Int = 0
    /// The mail it is attached to.
    public var source: Source = Source(kind: .mail, pointer: "")
    public var messageID: String = ""
    /// When the owner had it read and took what it says into the matter.
    public var readAt: Date?
    /// Out of date, or nothing to do with the matter: the owner took it off the list. Not deleted —
    /// it lives in the mail — and it can be put back.
    public var isHidden: Bool = false
    /// A name to read, given by the owner or taken from the file's first page, for a file whose
    /// own name a scanner or a mail program made up ("doc23848720260716151349.pdf"). Nil: the
    /// file's name is shown. The file keeps its own name in the mail and in its folder.
    public var title: String?
    public var matter: Matter?

    /// What the file is called on screen.
    public var shownName: String {
        let own = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return own.isEmpty ? name : own
    }

    public init(name: String, contentType: String, byteCount: Int, source: Source) {
        self.name = name
        self.contentType = contentType
        self.byteCount = byteCount
        self.source = source
        self.messageID = source.messageID ?? ""
    }

    /// Dropped in by the owner — a scanned letter, a PDF, a screenshot — rather than attached to a
    /// mail: the file itself, at its source's path on this Mac.
    public var isOwnFile: Bool { [.screenshot, .document].contains(source.kind) }

    /// A logo in a signature, a spacer: an image small enough to be nothing anyone attached. A file
    /// the owner dropped in is never one.
    public var isSmallImage: Bool { !isOwnFile && contentType.hasPrefix("image/") && byteCount < 30_000 }

    /// The name the owner gave the file: one copied in beside the store is kept as
    /// `1A2B3C4D-Brief.pdf`, and is called `Brief.pdf` again here.
    public static func ownName(of file: URL) -> String {
        let name = file.lastPathComponent
        let head = name.prefix(9)
        guard file.deletingLastPathComponent().lastPathComponent == ScreenshotDoor.attachmentsFolder,
              name.count > 9, head.last == "-", head.dropLast().allSatisfy(\.isHexDigit) else { return name }
        return String(name.dropFirst(9))
    }

    /// A PDF or a picture can be read; a Word file or an invitation cannot, yet.
    public var isReadable: Bool {
        contentType == "application/pdf" || name.lowercased().hasSuffix(".pdf")
            || (contentType.hasPrefix("image/") && !isSmallImage)
    }
}

/// One thought of the owner's on a matter — what was agreed, what to remember — written down
/// when it came, and dated. Many short ones, not one long text. The assistant reads them too.
@Model
public final class MatterNote {
    public var text: String = ""
    public var createdAt: Date = Date()
    /// An answer of the assistant's the owner kept, not the owner's own words.
    public var fromAssistant: Bool = false
    public var matter: Matter?

    public init(text: String, createdAt: Date = Date(), fromAssistant: Bool = false) {
        self.text = text
        self.createdAt = createdAt
        self.fromAssistant = fromAssistant
    }
}

extension Matter {
    /// The note blocks, the newest first.
    public var sortedNotes: [MatterNote] { (noteBlocks ?? []).sorted { $0.createdAt > $1.createdAt } }

    /// The one note a matter had before notes were blocks; it stays, as the oldest of them.
    public var earlierNote: String? {
        let text = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }

    public var noteCount: Int { (noteBlocks ?? []).count + (earlierNote == nil ? 0 : 1) }

    /// Every note as the assistant reads it: the oldest first, each block with its day.
    public var notesText: String? {
        var lines: [String] = []
        if let earlierNote { lines.append(earlierNote) }
        for note in sortedNotes.reversed() where !note.text.isEmpty {
            lines.append("\(MatterStatus.day(note.createdAt))\(note.fromAssistant ? " (an answer of yours the owner kept)" : ""): \(note.text)")
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}

/// A link the owner put into a matter — a Google Doc, a sheet, a page — and, if they want, with
/// one of its to-dos. Only the address is kept; the page is never opened by the app, since a
/// private doc shows a stranger only its login. The assistant is told the name, never the address:
/// whoever has the address of a shared doc may be able to open it.
@Model
public final class WebLink {
    public var address: String = ""
    /// The owner's own name for it. Empty until given; then what kind of page it is stands in.
    public var title: String = ""
    public var createdAt: Date = Date()
    public var matter: Matter?
    public var todo: Todo?
    /// The mail it was found in, when it was: then it is offered, not yet kept.
    public var messageID: String = ""
    /// Found in a mail and not yet looked at by the owner.
    public var isSuggestion: Bool = false
    /// Found in a mail and set aside: not offered again.
    public var isDismissed: Bool = false

    public init(address: String, title: String = "") {
        self.address = address
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var url: URL? { URL(string: address) }

    /// What kind of page it is, read from the address alone: "Google Doc", "Google Tabelle".
    public var kind: String { Self.kind(of: url) }

    public var shownName: String { title.isEmpty ? kind : title }

    /// The owner's: added by hand, or offered from a mail and kept.
    public var isKept: Bool { !isSuggestion && !isDismissed }

    /// For the assistant: the name and the kind, never the address.
    public var forFacts: String { title.isEmpty ? "a \(kind), not named" : "\(title) (\(kind))" }

    public static func kind(of url: URL?) -> String {
        guard let url, let host = url.host?.lowercased() else { return "Link" }
        let path = url.path.lowercased()
        if host == "docs.google.com" {
            if path.hasPrefix("/document") { return "Google Doc" }
            if path.hasPrefix("/spreadsheets") { return "Google Sheet" }
            if path.hasPrefix("/presentation") { return "Google Slides" }
            if path.hasPrefix("/forms") { return "Google Form" }
            return "Google Docs"
        }
        if host == "drive.google.com" { return "Google Drive" }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// The addresses in a note, each with a name from the words before it on its line —
    /// "Link zum Dokument 'Umzug Liste': https://…" is "Umzug Liste" — and the note without those lines.
    public static func split(note: String) -> (links: [(address: String, title: String)], rest: String?) {
        var links: [(String, String)] = []
        var kept: [String] = []
        for line in note.components(separatedBy: "\n") {
            let addresses = LinkStandIns.addresses(in: line)
            guard let first = addresses.first, let at = line.range(of: first) else { kept.append(line); continue }
            var name = String(line[..<at.lowerBound])
            for prefix in ["Link zum Dokument", "Link zur Tabelle", "Link zum", "Link zur", "Link zu", "Link", "Dokument"]
            where name.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix(prefix.lowercased()) {
                name = String(name.trimmingCharacters(in: .whitespaces).dropFirst(prefix.count))
                break
            }
            name = name.trimmingCharacters(in: CharacterSet(charactersIn: " :-–—'\"„“‚‘«»"))
            for (index, address) in addresses.enumerated() { links.append((address, index == 0 ? name : "")) }
        }
        let rest = kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (links, rest.isEmpty ? nil : rest)
    }

    /// The web address in what was pasted or typed, if there is one: `https://…` or `http://…`,
    /// with a missing scheme added for `docs.google.com/…`.
    public static func address(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.lowercased().hasPrefix("http") ? trimmed : (trimmed.contains(".") && !trimmed.contains(" ") ? "https://" + trimmed : "")
        guard let url = URL(string: candidate), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, host.contains(".") else { return nil }
        return url.absoluteString
    }
}

/// One turn of the assistant's thread — a question and what came back, or a screenshot brought
/// in — one record each, so a Mac and an iPhone adding turns at the same time never overwrite
/// each other, as two copies of one file would.
@Model
public final class ThreadTurn {
    public var id: UUID = UUID()
    public var date: Date = Date()
    /// The turn as the app writes it: the question, the answer, the cards ticked. The core does
    /// not read it.
    public var payload: Data = Data()
    public var matter: Matter?

    public init(id: UUID, date: Date, payload: Data) {
        self.id = id
        self.date = date
        self.payload = payload
    }
}

/// Something the owner decided, and why. Not the pipeline's judgement about a mail — that is a
/// `Judgement` — but the entry that will be asked about in six months: "Thermotec gets the job,
/// because they alone are bound until 31 October." Made by the owner, never by an import.
@Model
public final class Decision {
    public var what: String = ""
    public var why: String = ""
    public var decidedAt: Date = Date()
    /// What it was decided from: the offers, the mail, the call.
    public var sources: [Source] = []
    public var matter: Matter?

    public init(what: String, why: String, decidedAt: Date = Date(), sources: [Source] = []) {
        self.what = what
        self.why = why
        self.decidedAt = decidedAt
        self.sources = sources
    }
}

/// Everything above, for a `ModelContainer`.
/// A Mac's list of names — its `mapping.json`, which disguises every name before anything goes to
/// a model — for the owner's other devices: the iPhone asks with it, so the names it sends are
/// disguised as the Mac disguises them. One record a Mac, written by that Mac only; compressed,
/// and end-to-end encrypted in iCloud, so Apple cannot read a name of it.
@Model
public final class NameList {
    /// The Mac it is from, as that Mac calls itself once: a random id, and its name for the screen.
    public var device: String = ""
    public var deviceName: String = ""
    @Attribute(.allowsCloudEncryption) public var data: Data = Data()
    /// A checksum of the list, so a Mac writes it again only when it changed.
    @Attribute(.allowsCloudEncryption) public var digest: String = ""
    public var updatedAt: Date = Date()

    public init(device: String, deviceName: String) {
        self.device = device
        self.deviceName = deviceName
    }
}

/// One mail from the label that has been sorted — on whichever device — with what the answer
/// found in it. The record of what the label has answered, shared, so the Mac and the iPhone never
/// send the same mail twice. Without its disguised text and the names found in it: those stay in
/// the device's own log. Compressed, and end-to-end encrypted in iCloud.
@Model
public final class SortedMail {
    public var messageID: String = ""
    public var date: Date?
    public var sortedAt: Date = Date()
    /// The device that sorted it, as `NameList.device`.
    public var device: String = ""
    @Attribute(.allowsCloudEncryption) public var data: Data = Data()

    public init(messageID: String, device: String) {
        self.messageID = messageID
        self.device = device
    }
}

public enum MatterSchema {
    public static let models: [any PersistentModel.Type] = [
        Matter.self, Entry.self, Todo.self, Appointment.self, Deadline.self, Party.self, Membership.self,
        Decision.self, Rule.self, Profile.self, Document.self, WebLink.self, ThreadTurn.self, NameList.self,
        SortedMail.self, MatterNote.self,
    ]

    /// A store on disk, or in memory when `url` is nil.
    /// `cloudKit`: the iCloud container to mirror the store into, in the owner's private database.
    /// Nil keeps it on this Mac only, as the command line always does.
    public static func container(at url: URL?, cloudKit: String? = nil) throws -> ModelContainer {
        let configuration = url.map { ModelConfiguration(url: $0, cloudKitDatabase: cloudKit.map { .private($0) } ?? .none) }
            ?? ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Schema(models), configurations: configuration)
    }
}
