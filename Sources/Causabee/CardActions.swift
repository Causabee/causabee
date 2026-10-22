import Foundation
import MatterCore
import SwiftData
import SwiftUI
import UserNotifications
#if os(iOS)
import UIKit
#endif

/// What a card the owner ticks does to the store, and how to take it back — the same on the Mac and
/// the iPhone: both apps take this file in. What each app does around it — keeping the turn, opening
/// Mail, showing a matter — stays with that app.
@MainActor
enum CardActions {
    /// What a ticked card changed, kept so it can be put back as it was.
    enum Undo {
        case reopen(PersistentIdentifier)
        case remove(PersistentIdentifier)
        case owner(PersistentIdentifier, Todo.Owner)
        case name(PersistentIdentifier, String, rule: PersistentIdentifier)
        case texts([(PersistentIdentifier, String)])
        case roles(PersistentIdentifier, [String])
        case note(PersistentIdentifier, String?)
        case date(PersistentIdentifier, day: String?, time: String?)
        case madeMatter(PersistentIdentifier)
        /// A link a card kept, to take out again.
        case removeLink(PersistentIdentifier)
        /// What the owner said of a matter, kept in its brief.
        case said(PersistentIdentifier, UUID)
        /// A contact a card added or completed: its membership when the card made it, and how it was reached before.
        /// A date, a detail or a matter's note a card added, to take out again.
        case added(PersistentIdentifier)
        case contact(PersistentIdentifier, matter: PersistentIdentifier, joined: Bool, address: String?, phone: String?)
        /// What a to-do waited for before.
        case waits(PersistentIdentifier, PersistentIdentifier?)
        /// A merge folds one party into another and the first is gone; its rule can be switched
        /// off, but the two are not split again here.
        case merged(rule: PersistentIdentifier)
    }

    /// What taking a card in came to.
    enum Outcome {
        /// Nothing could be done: what the card names is gone, or its words are empty.
        case nothing
        case taken(Undo)
        /// A matter was made; the cards beside it put their to-dos there.
        case madeMatter(Matter, Undo)
        /// A draft: Mail opens with it, and the owner sends it — or not. With the files it names,
        /// when the matter has them on this device: a `mailto:` cannot carry a file, so the draft is
        /// handed over whole as well.
        case openMail(URL, MailDraft)
    }

    struct MailDraft {
        var to: String
        var subject: String
        var body: String
        /// The matter's files the draft or the question names, where they are on this device.
        var files: [URL] = []
        /// Named, and not on this device — a mail's attachment never opened here.
        var missing: [String] = []
    }

    /// What a draft's card says of its files before it is opened: "Attached: memo.pdf", and what is
    /// named but not on this device. Nil when the draft names no file of the matter.
    static func attachmentLine(text: String, question: String?, scope: Matter?, attach: [String] = []) -> String? {
        let along = attachments(text: text, question: question, scope: scope, attach: attach)
        var parts: [String] = []
        if !along.files.isEmpty { parts.append("Attached: " + along.files.map(\.lastPathComponent).joined(separator: ", ")) }
        if !along.missing.isEmpty { parts.append("Not on this \(ThisDevice.name), attach by hand: " + along.missing.joined(separator: ", ")) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The files a draft takes along: those its card lists to attach, and the matter's files named
    /// in its words or in what was asked.
    static func attachments(text: String, question: String?, scope: Matter?, attach: [String] = []) -> (files: [URL], missing: [String]) {
        var files: [URL] = [], missing: [String] = []
        for document in DraftAttachments.named(in: [text, question ?? ""] + attach, among: scope?.documents ?? []) {
            let own = document.source.fileURL.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
            // The file as kept: a picture too big for a mail is made smaller only when the mail is
            // opened, away from the screen — never while a card draws.
            if let file = own ?? MatterFolders.kept(document) { files.append(file) } else { missing.append(document.shownName) }
        }
        return (files, missing)
    }

    /// A fact by its id, if it is still there. A party merged away or a to-do deleted is gone,
    /// and `context.model(for:)` would hand back an object that crashes when read.
    static func live<T: PersistentModel>(_ id: PersistentIdentifier, as type: T.Type, in context: ModelContext) -> T? {
        var descriptor = FetchDescriptor<T>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    static func live<T: PersistentModel>(_ ref: FactRef, as type: T.Type, in context: ModelContext) -> T? {
        switch ref {
        case .matter(let id), .entry(let id), .todo(let id), .appointment(let id), .deadline(let id), .party(let id):
            return live(id, as: type, in: context)
        }
    }

    static func matter(of ref: FactRef, in context: ModelContext) -> Matter? {
        switch ref {
        case .matter: return live(ref, as: Matter.self, in: context)
        case .entry: return live(ref, as: Entry.self, in: context)?.matter
        case .todo: return live(ref, as: Todo.self, in: context)?.matter
        case .appointment: return live(ref, as: Appointment.self, in: context)?.matter
        case .deadline: return live(ref, as: Deadline.self, in: context)?.matter
        case .party: return live(ref, as: Party.self, in: context)?.matters.first
        }
    }

    /// What a chip says: the kind and its day, or the name — never `T20`.
    /// Read once per change: every chip of every card asked the store each time the thread drew.
    static func label(_ ref: FactRef, in context: ModelContext) -> String {
        StoredChanges.shared.kept("label \(ref)") { labelNow(ref, in: context) }
    }

    private static func labelNow(_ ref: FactRef, in context: ModelContext) -> String {
        switch ref {
        case .matter: return live(ref, as: Matter.self, in: context)?.name ?? "Matter (no longer there)"
        case .entry: return "Mail " + (live(ref, as: Entry.self, in: context)?.date.map(Dates.short) ?? "")
        case .todo:
            guard let todo = live(ref, as: Todo.self, in: context) else { return "Task (no longer there)" }
            let words = todo.text.split(separator: " ").prefix(4).joined(separator: " ")
            return (todo.isDone ? "✓ " : "") + words + (todo.text.split(separator: " ").count > 4 ? " …" : "")
        case .appointment: return "Appointment " + (live(ref, as: Appointment.self, in: context).map { Dates.short($0.day) } ?? "")
        case .deadline: return "Deadline " + (live(ref, as: Deadline.self, in: context).map { Dates.short($0.day) } ?? "")
        case .party: return live(ref, as: Party.self, in: context)?.name ?? "merged"
        }
    }

    /// A source in the list under an answer: what it is, its whole name, and its day.
    struct SourceLine {
        var symbol: String
        var title: String
        var detail: String
        /// Still there, in a matter: the row is a door to it.
        var isThere = true
    }

    /// Read once per change, as the labels are.
    static func source(_ ref: FactRef, in context: ModelContext) -> SourceLine {
        StoredChanges.shared.kept("source \(ref)") { sourceNow(ref, in: context) }
    }

    private static func sourceNow(_ ref: FactRef, in context: ModelContext) -> SourceLine {
        switch ref {
        case .matter:
            guard let matter = live(ref, as: Matter.self, in: context) else { return gone("folder", "A matter", "not found on this \(device)") }
            return SourceLine(symbol: "folder", title: matter.name, detail: "Matter")
        case .entry:
            guard let entry = live(ref, as: Entry.self, in: context) else { return gone("envelope", "A mail of the matter", "not found on this \(device)") }
            let symbol = switch entry.source.kind {
            case .mail: "envelope"
            case .screenshot, .photo: "photo"
            case .document: "doc"
            case .spokenNote: "waveform"
            case .phoneCall: "phone"
            case .conversation: "bubble.left"
            }
            let who = Email.displayName(in: entry.from) ?? Email.address(in: entry.from)
            let title = entry.title.isEmpty ? "(no subject)" : entry.title
            return SourceLine(symbol: symbol, title: who.isEmpty ? title : "\(who) — \(title)", detail: entry.date.map(Dates.short) ?? "")
        case .todo:
            guard let todo = live(ref, as: Todo.self, in: context) else { return gone("circle", "A task of the matter", "not found on this \(device)") }
            let detail = todo.isDone ? "done" + (todo.doneAt.map { " " + Dates.short($0) } ?? "") : todo.due.map { "due " + Dates.short($0) } ?? "Task"
            return SourceLine(symbol: todo.isDone ? "checkmark.circle" : "circle", title: todo.text, detail: detail)
        case .appointment:
            guard let appointment = live(ref, as: Appointment.self, in: context) else { return gone("calendar", "An appointment of the matter", "not found on this \(device)") }
            return SourceLine(symbol: "calendar", title: appointment.what, detail: Dates.short(appointment.day) + (appointment.time.map { ", " + $0 } ?? ""))
        case .deadline:
            guard let deadline = live(ref, as: Deadline.self, in: context) else { return gone("calendar.badge.clock", "A deadline of the matter", "not found on this \(device)") }
            return SourceLine(symbol: "calendar.badge.clock", title: deadline.what, detail: "Deadline " + Dates.short(deadline.day))
        case .party:
            guard let party = live(ref, as: Party.self, in: context) else { return gone("person", "A person of the matter", "not found on this \(device)") }
            return SourceLine(symbol: "person", title: party.name, detail: "Person")
        }
    }

    /// A source this store does not know — a thread asked on another device names that device's
    /// facts: what kind it is, by the letter of its id.
    static func source(named cite: String) -> SourceLine {
        switch cite.first {
        case "E", "M": gone("envelope", "A mail of the matter")
        case "T": gone("circle", "A task of the matter")
        case "A": gone("calendar", "An appointment of the matter")
        case "D": gone("calendar.badge.clock", "A deadline of the matter")
        case "P": gone("person", "A person of the matter")
        default: gone("doc", cite)
        }
    }

    /// Not in this store: deleted or merged since — or asked on another device before the thread
    /// kept what finds it here.
    private static func gone(_ symbol: String, _ title: String, _ detail: String = "") -> SourceLine {
        SourceLine(symbol: symbol, title: title, detail: detail, isThere: false)
    }

    #if os(iOS)
    private static let device = ThisDevice.name
    #else
    private static let device = "Mac"
    #endif

    // MARK: The same fact on another device

    /// A fact in words that are the same on every device. Its id is this store's own: the Mac's
    /// store and the iPhone's give the same mail different ids, so a thread asked on one keeps
    /// these beside the ids, and the other finds its own copy by them.
    static func key(_ ref: FactRef, in context: ModelContext) -> String? {
        let s = "\u{1F}"
        switch ref {
        case .matter: return live(ref, as: Matter.self, in: context).map { "M" + s + $0.name }
        case .entry:
            guard let entry = live(ref, as: Entry.self, in: context) else { return nil }
            if !entry.messageID.isEmpty { return "E" + s + entry.messageID }
            return "E" + s + entry.title + s + String(Int(entry.date?.timeIntervalSince1970 ?? 0))
        case .todo: return live(ref, as: Todo.self, in: context).map { "T" + s + $0.text }
        case .appointment: return live(ref, as: Appointment.self, in: context).map { "A" + s + $0.day + s + $0.what }
        case .deadline: return live(ref, as: Deadline.self, in: context).map { "D" + s + $0.day + s + $0.what }
        case .party: return live(ref, as: Party.self, in: context).map { "P" + s + $0.name }
        }
    }

    static func keys(of refs: [String: FactRef], in context: ModelContext) -> [String: String] {
        refs.compactMapValues { key($0, in: context) }
    }

    /// The refs of a turn as this store knows them: one whose id is another device's is looked up
    /// by its key — in the turn's matter, or in every matter for a question about all of them.
    static func local(_ refs: [String: FactRef], keys: [String: String], matter: Matter?, in context: ModelContext) -> [String: FactRef] {
        guard !keys.isEmpty else { return refs }
        var result = refs
        var matters: [Matter]?
        for (cite, ref) in refs where self.matter(of: ref, in: context) == nil {
            guard let key = keys[cite] else { continue }
            if matters == nil { matters = matter.map { [$0] } ?? ((try? context.fetch(FetchDescriptor<Matter>())) ?? []) }
            if let found = find(key, in: matters ?? [], context: context) { result[cite] = found }
        }
        return result
    }

    private static func find(_ key: String, in matters: [Matter], context: ModelContext) -> FactRef? {
        let parts = key.split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2 else { return nil }
        for matter in matters {
            switch parts[0] {
            case "M":
                if matter.name == parts[1] { return .matter(matter.persistentModelID) }
            case "E":
                let entries = matter.entries ?? []
                let found = parts.count == 2
                    ? entries.first { $0.messageID == parts[1] }
                    : entries.first { $0.title == parts[1] && String(Int($0.date?.timeIntervalSince1970 ?? 0)) == parts[2] }
                if let found { return .entry(found.persistentModelID) }
            case "T":
                if let found = (matter.todos ?? []).first(where: { $0.text == parts[1] }) { return .todo(found.persistentModelID) }
            case "A":
                guard parts.count == 3 else { return nil }
                if let found = (matter.appointments ?? []).first(where: { $0.day == parts[1] && $0.what == parts[2] }) { return .appointment(found.persistentModelID) }
            case "D":
                guard parts.count == 3 else { return nil }
                if let found = (matter.deadlines ?? []).first(where: { $0.day == parts[1] && $0.what == parts[2] }) { return .deadline(found.persistentModelID) }
            case "P":
                if let found = matter.parties.first(where: { $0.name == parts[1] }) { return .party(found.persistentModelID) }
            default: return nil
            }
        }
        return nil
    }

    /// What a source's row jumps to in its matter: the fact itself — a matter has no row of its own.
    static func row(of ref: FactRef) -> PersistentIdentifier? {
        switch ref {
        case .matter: nil
        case .entry(let id), .todo(let id), .appointment(let id), .deadline(let id), .party(let id): id
        }
    }

    /// An address a party wrote from, and when they last did.
    struct MailAddress: Identifiable {
        let address: String
        let last: Date?
        let count: Int
        var id: String { address }
        /// "2 mails, last Oct 2" — what tells one address from the person's other.
        var note: String {
            if count == 0 { return "added by you" }
            let mails = count == 1 ? "1 mail" : "\(count) mails"
            return last.map { "\(mails), last \(Dates.short($0))" } ?? mails
        }
        /// Mail opens with a new message to it; the owner writes and sends it.
        var url: URL? {
            var parts = URLComponents()
            parts.scheme = "mailto"
            parts.path = address
            return parts.url
        }
    }

    /// Every address a party wrote from, the one they last used first: from the sender lines of the
    /// mail in the store. They are never sent anywhere; they only fill the "To" of a mail the owner opens.
    static func addresses(of party: Party) -> [MailAddress] {
        // Read through every mail of every matter the person is in: once per change to the store,
        // not two or three times per person each time the People part draws.
        StoredChanges.shared.kept("addresses \(party.persistentModelID.hashValue)") { workOutAddresses(of: party) }
    }

    private static func workOutAddresses(of party: Party) -> [MailAddress] {
        let keys = Set(([party.name] + party.spellings).map(PartyNames.key))
        var found: [String: (last: Date?, count: Int)] = [:]
        var seen = Set<String>()
        for matter in party.matters {
            for entry in matter.entries ?? [] {
                // By the name in the sender line; a line that is an address alone, by whose it is here.
                if let name = Email.displayName(in: entry.from) {
                    guard keys.contains(PartyNames.key(name)) else { continue }
                } else {
                    guard matter.writer(entry.from) === party else { continue }
                }
                let address = Email.address(in: entry.from).lowercased()
                // A mail filed in two matters counts once.
                guard address.contains("@"), seen.insert(entry.messageID.isEmpty ? "\(address) \(String(describing: entry.date))" : entry.messageID).inserted else { continue }
                let before = found[address]
                let last = [before?.last, entry.date].compactMap { $0 }.max()
                found[address] = (last, (before?.count ?? 0) + 1)
            }
        }
        let wrote = found.map { MailAddress(address: $0.key, last: $0.value.last, count: $0.value.count) }
            .sorted { ($0.last ?? .distantPast, $0.count, $1.address) > ($1.last ?? .distantPast, $1.count, $0.address) }
        // The address the owner put in by hand comes first: it is the one they mean.
        guard let typed = party.address?.lowercased(), typed.contains("@") else { return wrote }
        return [wrote.first { $0.address == typed } ?? MailAddress(address: typed, last: nil, count: 0)] + wrote.filter { $0.address != typed }
    }

    /// What a draft's card says of whom it goes to: the name and the address — or that none is known,
    /// so it is not found out only in Mail.
    static func toLine(_ recipient: (name: String, address: String?)) -> String {
        "To " + recipient.name + " · " + (recipient.address ?? "no address known — add one under People")
    }

    /// The address a party last wrote from.
    static func address(of party: Party) -> String? { addresses(of: party).first?.address }

    /// Who a draft goes to. The party the card names; without one, the one person of the matter the
    /// owner named in the question — "Schreibe Georg …" — and failing that, whoever wrote the mail in hand.
    static func recipient(_ id: String?, refs: [String: FactRef], question: String = "", mail: String? = nil,
                          scope: Matter? = nil, in context: ModelContext) -> (name: String, address: String?)? {
        if let id, let ref = refs[id], let party = live(ref, as: Party.self, in: context) {
            return (party.name, address(of: party))
        }
        guard let scope else { return nil }
        func words(_ text: String) -> Set<String> {
            Set(text.lowercased().split { !$0.isLetter }.filter { $0.count > 2 }.map(String.init))
        }
        let particles: Set<String> = ["von", "van", "der", "den", "del", "ten", "ter", "und", "the", "and", "gmbh"]
        let asked = words(question)
        let named = scope.parties.filter { party in
            !asked.isDisjoint(with: words(([party.name] + party.spellings).joined(separator: " ")).subtracting(particles))
        }
        if named.count == 1, let party = named.first { return (party.name, address(of: party)) }
        if let mail, let entry = (scope.entries ?? []).first(where: { $0.title == mail }) {
            let address = Email.address(in: entry.from)
            guard address.contains("@") else { return nil }
            return (Email.displayName(in: entry.from) ?? address, address)
        }
        return nil
    }

    /// A card the owner ticked, with its text as the owner left it. Only now does anything change
    /// in the store. `scope` is the matter the answer is about: one made by a card of the same
    /// answer, the one it was asked in, or the one its facts come from.
    static func apply(_ card: AssistantPrompt.Reply.Card, text: String, subject: String?, refs: [String: FactRef],
                      links: [String: String]?, scope: Matter?, question: String = "", mail: String? = nil,
                      in context: ModelContext) -> Outcome {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = Source(kind: .conversation, pointer: "assistant", date: Date(), quote: card.reason)
        func model<T: PersistentModel>(_ id: String?, as type: T.Type) -> T? {
            guard let id, let ref = refs[id] else { return nil }
            return live(ref, as: type, in: context)
        }
        let origin = "you, in the assistant\(scope.map { ", in \($0.name)" } ?? ""), \(Dates.short(Date()))"

        let undo: Undo
        switch card.kind {
        case .markDone:
            guard let todo = model(card.todo, as: Todo.self), !todo.isDone else { return .nothing }
            todo.isDone = true
            todo.doneAt = Date()
            todo.doneSource = source
            undo = .reopen(todo.persistentModelID)
        case .newTodo:
            guard let matter = scope, !text.isEmpty else { return .nothing }
            let todo = Todo(text: text, owner: Todo.Owner(rawValue: card.owner) ?? .me, due: card.due, source: source,
                            origin: "assistant#" + text.lowercased())
            // A time of day counts only with its day, and only as HH:MM.
            if card.due != nil, let time = card.time, time.wholeMatch(of: /\d{2}:\d{2}/) != nil { todo.dueTime = time }
            context.insert(todo)
            todo.matter = matter
            try? context.save()
            undo = .remove(todo.persistentModelID)
        case .sameParty:
            guard let party = model(card.party, as: Party.self), let into = model(card.into, as: Party.self), party !== into,
                  let matter = scope ?? into.matters.first else { return .nothing }
            PartyBook.confirmSame(party, as: into, in: matter, context: context, origin: origin)
            try? context.save()
            let rules = (try? context.fetch(FetchDescriptor<Rule>())) ?? []
            guard let rule = rules.max(by: { $0.createdAt < $1.createdAt }) else { return .nothing }
            undo = .merged(rule: rule.persistentModelID)
        case .changeRole:
            guard let party = model(card.party, as: Party.self), !text.isEmpty,
                  let membership = (scope ?? party.matters.first)?.membership(of: party) else { return .nothing }
            undo = .roles(membership.persistentModelID, membership.roles)
            membership.setRole(text)
        case .renameParty:
            guard let party = model(card.party, as: Party.self), !text.isEmpty, text != party.name else { return .nothing }
            let old = party.name
            party.rename(to: text)
            let rule = Rule(.partyName, subject: old, object: text, matterKey: scope?.key, origin: origin)
            context.insert(rule)
            try? context.save()
            undo = .name(party.persistentModelID, old, rule: rule.persistentModelID)
        case .correctText:
            guard let matter = scope, let from = card.from, !from.isEmpty, !text.isEmpty else { return .nothing }
            var before: [(PersistentIdentifier, String)] = []
            for todo in matter.todos ?? [] where todo.text.contains(from) {
                before.append((todo.persistentModelID, todo.text))
                todo.text = todo.text.replacingOccurrences(of: from, with: text)
            }
            for item in matter.appointments ?? [] where item.what.contains(from) {
                before.append((item.persistentModelID, item.what))
                item.what = item.what.replacingOccurrences(of: from, with: text)
            }
            for item in matter.deadlines ?? [] where item.what.contains(from) {
                before.append((item.persistentModelID, item.what))
                item.what = item.what.replacingOccurrences(of: from, with: text)
            }
            undo = .texts(before)
        case .shortMessage:
            // Copied by its card, into a chat by the owner's own hand: nothing changes in a matter.
            return .nothing
        case .draftMessage:
            // The one door out: Mail opens with the draft in it, and the owner sends it — or not.
            let to = recipient(card.party, refs: refs, question: question, mail: mail, scope: scope, in: context)?.address ?? ""
            var parts = URLComponents()
            parts.scheme = "mailto"
            parts.path = to
            parts.queryItems = [URLQueryItem(name: "subject", value: subject ?? card.subject ?? ""), URLQueryItem(name: "body", value: text)]
            guard let url = parts.url else { return .nothing }
            let along = attachments(text: text, question: question, scope: scope, attach: card.attach ?? [])
            return .openMail(url, MailDraft(to: to, subject: subject ?? card.subject ?? "", body: text, files: along.files, missing: along.missing))
        case .newMatter:
            guard !text.isEmpty, let matter = try? Matter.make(named: text, in: context) else { return .nothing }
            return .madeMatter(matter, .madeMatter(matter.persistentModelID))
        case .changeDate:
            guard let day = card.due else { return .nothing }
            if let todo = model(card.todo, as: Todo.self) {
                undo = .date(todo.persistentModelID, day: todo.due, time: todo.dueTime)
                todo.due = day
                todo.dueTime = card.time ?? todo.dueTime
            } else if let appointment = model(card.todo, as: Appointment.self) {
                undo = .date(appointment.persistentModelID, day: appointment.day, time: appointment.time)
                appointment.day = day
                appointment.time = card.time ?? appointment.time
            } else if let deadline = model(card.todo, as: Deadline.self) {
                undo = .date(deadline.persistentModelID, day: deadline.day, time: nil)
                deadline.day = day
            } else { return .nothing }
        case .lookUp:
            // Looked up by its own card, on a tap, away from here: it changes nothing in the store.
            return .nothing
        case .correctBrief:
            guard !text.isEmpty, let matter = scope else { return .nothing }
            matter.say(text)
            try? context.save()
            guard let said = matter.shownBrief?.said.last else { return .nothing }
            return .taken(.said(matter.persistentModelID, said.id))
        case .addNote:
            guard !text.isEmpty else { return .nothing }
            // With no to-do it is one of the matter's own notes.
            guard let todo = model(card.todo, as: Todo.self) else {
                guard let matter = scope else { return .nothing }
                let note = MatterNote(text: text)
                context.insert(note)
                note.matter = matter
                try? context.save()
                return .taken(.added(note.persistentModelID))
            }
            undo = .note(todo.persistentModelID, todo.note)
            todo.note = [todo.note, text].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: "\n")
        case .addLink:
            guard let standIn = card.from, let address = links?[standIn] ?? WebLink.address(in: standIn) else { return .nothing }
            let todo = model(card.todo, as: Todo.self)
            guard let matter = todo?.matter ?? scope else { return .nothing }
            let link = WebLink(address: address, title: text)
            context.insert(link)
            link.matter = matter
            link.todo = todo
            try? context.save()
            undo = .removeLink(link.persistentModelID)
        case .newAppointment:
            guard let matter = scope, !text.isEmpty, let day = card.due else { return .nothing }
            let item = Appointment(what: text, day: day, time: card.time, place: nil, source: source)
            context.insert(item)
            item.matter = matter
            try? context.save()
            undo = .added(item.persistentModelID)
        case .newDeadline:
            guard let matter = scope, !text.isEmpty, let day = card.due else { return .nothing }
            let item = Deadline(what: text, day: day, source: source)
            context.insert(item)
            item.matter = matter
            try? context.save()
            undo = .added(item.persistentModelID)
        case .addDetail:
            guard let matter = scope, let label = card.subject,
                  let detail = matter.addDetail(label: label, value: text, of: model(card.party, as: Party.self), in: context) else { return .nothing }
            try? context.save()
            undo = .added(detail.persistentModelID)
        case .addContact:
            guard let matter = scope, !text.isEmpty else { return .nothing }
            // A party the facts know is completed as it is; anyone else is added, by the name given.
            let known = model(card.party, as: Party.self) ?? matter.parties.first { $0.name.caseInsensitiveCompare(text) == .orderedSame }
            let joined = known.map { matter.membership(of: $0) == nil } ?? true
            let before = (known?.address, known?.phone)
            guard let party = matter.addContact(name: known?.name ?? text, role: card.subject ?? "", address: card.from ?? "", phone: card.time ?? "", in: context) else { return .nothing }
            try? context.save()
            undo = .contact(party.persistentModelID, matter: matter.persistentModelID, joined: joined, address: before.0, phone: before.1)
        case .waitsFor:
            guard let todo = model(card.todo, as: Todo.self), let other = model(card.into, as: Todo.self) else { return .nothing }
            let before = todo.waitsFor?.persistentModelID
            guard todo.wait(for: other) else { return .nothing }
            undo = .waits(todo.persistentModelID, before)
        case .changeOwner:
            guard let todo = model(card.todo, as: Todo.self), let owner = Todo.Owner(rawValue: card.owner) else { return .nothing }
            undo = .owner(todo.persistentModelID, todo.owner)
            todo.owner = owner
        }
        try? context.save()
        return .taken(undo)
    }

    /// Puts back what a ticked card changed. False when it cannot be: a matter made by a card is
    /// not undone by a tap once it has mail or to-dos in it.
    static func undo(_ undo: Undo, in context: ModelContext) -> Bool {
        switch undo {
        case .reopen(let id):
            if let todo = live(id, as: Todo.self, in: context) { todo.isDone = false; todo.doneAt = nil; todo.doneSource = nil }
        case .remove(let id):
            if let todo = live(id, as: Todo.self, in: context) { context.delete(todo) }
        case .owner(let id, let owner):
            live(id, as: Todo.self, in: context)?.owner = owner
        case .name(let id, let old, let rule):
            if let party = live(id, as: Party.self, in: context) { party.name = old }
            if let rule = live(rule, as: Rule.self, in: context) { context.delete(rule) }
        case .texts(let before):
            for (id, text) in before {
                if let todo = live(id, as: Todo.self, in: context) { todo.text = text }
                else if let item = live(id, as: Appointment.self, in: context) { item.what = text }
                else if let item = live(id, as: Deadline.self, in: context) { item.what = text }
            }
        case .madeMatter(let id):
            guard let matter = live(id, as: Matter.self, in: context), (matter.entries ?? []).isEmpty, (matter.todos ?? []).isEmpty else { return false }
            context.delete(matter)
        case .date(let id, let day, let time):
            if let todo = live(id, as: Todo.self, in: context) { todo.due = day; todo.dueTime = time }
            else if let item = live(id, as: Appointment.self, in: context), let day { item.day = day; item.time = time }
            else if let item = live(id, as: Deadline.self, in: context), let day { item.day = day }
        case .note(let id, let note):
            live(id, as: Todo.self, in: context)?.note = note
        case .removeLink(let id):
            if let link = live(id, as: WebLink.self, in: context) { context.delete(link) }
        case .said(let id, let said):
            live(id, as: Matter.self, in: context)?.unsay(said)
        case .added(let id):
            if let item = live(id, as: Appointment.self, in: context) { context.delete(item) }
            else if let item = live(id, as: Deadline.self, in: context) { context.delete(item) }
            else if let item = live(id, as: MatterDetail.self, in: context) { context.delete(item) }
            else if let item = live(id, as: MatterNote.self, in: context) { context.delete(item) }
        case .contact(let id, let matter, let joined, let address, let phone):
            guard let party = live(id, as: Party.self, in: context) else { return false }
            party.address = address
            party.phone = phone
            // Out of the matter again when the card brought it in; gone when it is in no other.
            if joined, let matter = live(matter, as: Matter.self, in: context), let membership = matter.membership(of: party) {
                context.delete(membership)
                if (party.memberships ?? []).allSatisfy({ $0 === membership }) { context.delete(party) }
            }
        case .waits(let id, let before):
            live(id, as: Todo.self, in: context)?.waitsFor = before.flatMap { live($0, as: Todo.self, in: context) }
        case .roles(let id, let roles):
            live(id, as: Membership.self, in: context)?.roles = roles
        case .merged(let rule):
            // Switched off, so the next mail's spelling is its own party again.
            live(rule, as: Rule.self, in: context)?.isOn = false
        }
        try? context.save()
        return true
    }
}

/// What an answer rests on, as one list under it: each source with what it is, its whole name and
/// its day — and a door to that very mail, task or date in its matter.
struct SourceList: View {
    let cites: [String]
    let refs: [String: FactRef]
    let open: (FactRef) -> Void
    @Environment(\.modelContext) private var context

    #if os(iOS)
    private static let radius: CGFloat = 12
    #else
    private static let radius: CGFloat = 10
    #endif

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(cites.enumerated()), id: \.offset) { index, cite in
                if index > 0 { Rectangle().fill(Theme.line).frame(height: 1) }
                let ref = refs[cite]
                let line = ref.map { CardActions.source($0, in: context) } ?? CardActions.source(named: cite)
                SourceRow(line: line, open: ref.flatMap { ref in line.isThere ? { open(ref) } : nil })
            }
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Self.radius))
        .overlay(RoundedRectangle(cornerRadius: Self.radius).stroke(Theme.line))
    }
}

private struct SourceRow: View {
    let line: CardActions.SourceLine
    let open: (() -> Void)?
    @State private var hovering = false

    var body: some View {
        #if os(iOS)
        let title = Font.subheadline, symbol = Font.body, gap: CGFloat = 10, across: CGFloat = 12, down: CGFloat = 10
        #else
        let title = Font.callout, symbol = Font.callout, gap: CGFloat = 8, across: CGFloat = 10, down: CGFloat = 6
        #endif
        Button { open?() } label: {
            HStack(alignment: .center, spacing: gap) {
                Image(systemName: line.symbol).font(symbol).foregroundStyle(.secondary).frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(line.title).font(title).foregroundStyle(open == nil ? .secondary : .primary)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    if !line.detail.isEmpty { Text(line.detail).font(.caption2).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 8)
                if open != nil { Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, across).padding(.vertical, down)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hovering && open != nil ? Theme.box : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(open == nil)
        .onHover { hovering = $0 }
        .accessibilityHint(open == nil ? "" : "Shows it in its matter")
    }
}

/// A person's address under their name: the one they last wrote from, and how many others there are.
struct MailAddressLine: View {
    let addresses: [CardActions.MailAddress]

    var body: some View {
        if let first = addresses.first {
            Text(addresses.count > 1 ? "\(first.address) · last used of \(addresses.count)" : first.address)
                .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}

/// "Write mail" and "Copy address" in a person's menu. With several addresses each is offered, the
/// one last written from first, with when it was last used.
struct MailAddressItems: View {
    let addresses: [CardActions.MailAddress]
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let first = addresses.first {
            if addresses.count == 1 {
                Button("Write mail", systemImage: "envelope") { write(first) }
                Button("Copy address", systemImage: "doc.on.doc") { copy(first) }
            } else {
                Menu("Write mail", systemImage: "envelope") {
                    ForEach(addresses) { item in
                        Button { write(item) } label: { Text(item.address); Text(item.note) }
                    }
                }
                Menu("Copy address", systemImage: "doc.on.doc") {
                    ForEach(addresses) { item in
                        Button { copy(item) } label: { Text(item.address); Text(item.note) }
                    }
                }
            }
            Divider()
        }
    }

    private func write(_ item: CardActions.MailAddress) {
        if let url = item.url { openURL(url) }
    }

    private func copy(_ item: CardActions.MailAddress) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.address, forType: .string)
        #else
        UIPasteboard.general.string = item.address
        #endif
    }
}


/// A short message for a chat — WhatsApp, Signal, a text: the words to change, and on the
/// clipboard as soon as the card lands, again whenever they are changed, and with a tap. Pasted
/// into the chat by the owner; nothing is sent from here and nothing changes in a matter.
struct MessageCard: View {
    /// The turn and the card's place in it: a card is copied by itself once, when it lands.
    let id: String
    /// When its question was asked: only a card that has just come copies itself — not every one
    /// in the thread each time the thread is opened.
    let asked: Date
    let to: String?
    let words: String
    let reason: String
    /// Put aside: a small card that says so, and brings it back.
    var dismissed = false
    var setDismissed: (Bool) -> Void = { _ in }
    @State private var text: String
    @State private var copied = false
    @State private var waits: Task<Void, Never>?

    @MainActor private static var landed: Set<String> = []

    /// With its words from the first moment: a card that got them only once it showed grew after
    /// it was laid out, and the thread jumped under the finger.
    init(id: String, asked: Date, to: String?, words: String, reason: String,
         dismissed: Bool = false, setDismissed: @escaping (Bool) -> Void = { _ in }) {
        (self.id, self.asked, self.to, self.words, self.reason) = (id, asked, to, words, reason)
        (self.dismissed, self.setDismissed) = (dismissed, setDismissed)
        _text = State(initialValue: words)
    }

    var body: some View {
        if dismissed {
            // As a suggestion put aside: small, on the soft ground, with the way back.
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("You dismissed this message").font(.caption2)
                    Text(text).font(.footnote).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button(Say.showAgain) { setDismissed(false) }
                    .font(.footnote.weight(.medium)).foregroundStyle(Theme.gold).buttonStyle(.plain).fixedSize()
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        } else {
            card
        }
    }

    private var card: some View {
        #if os(iOS)
        let disc: CGFloat = 30
        #else
        let disc: CGFloat = 24
        #endif
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(to.map { "Message · for \($0)" } ?? "Message").font(.caption).foregroundStyle(.secondary)
                    .padding(.leading, 4)
                Spacer(minLength: 4)
                // Always there, seen only for a moment: the line keeps its height.
                Label("Copied", systemImage: "checkmark").font(.caption.weight(.medium)).foregroundStyle(Theme.done)
                    .opacity(copied ? 1 : 0)
                    .accessibilityHidden(!copied)
                Button { withAnimation { setDismissed(true) } } label: {
                    Image(systemName: "xmark").font(.system(size: disc * 0.4, weight: .semibold)).foregroundStyle(.secondary)
                        .frame(width: disc, height: disc)
                        .background(Color.primary.opacity(0.08), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
            // On the soft writing area, as the other cards' words are.
            TextField("", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...14)
                // As tall as its words, decided once: not measured again while the thread scrolls.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                .padding(.top, 14)
                .accessibilityIdentifier("message.text")
            Text((reason.isEmpty ? "" : reason + " ") + "On your clipboard: paste it into the chat.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10).padding(.leading, 4)
            HStack {
                Spacer(minLength: 0)
                #if os(iOS)
                // The chat is one tap away in the share sheet; the words are on the clipboard as well.
                ShareLink(item: text.trimmingCharacters(in: .whitespacesAndNewlines)) { Text("Share") }.buttonStyle(.phoneFilled)
                #else
                Button("Copy") { copy() }.inkButton()
                #endif
                Spacer(minLength: 0)
            }
            .padding(.top, 18)
        }
        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.box, in: RoundedRectangle(cornerRadius: 20))
        .onAppear {
            // Landed just now, and not copied yet while the app is open.
            guard !Self.landed.contains(id), Date().timeIntervalSince(asked) < 300 else { return }
            Self.landed.insert(id)
            copy()
        }
        // Changed: on the clipboard again, once the typing rests.
        .onChange(of: text) { old, new in
            guard new != old else { return }
            waits?.cancel()
            waits = Task {
                try? await Task.sleep(for: .seconds(0.8))
                if !Task.isCancelled { copy() }
            }
        }
    }

    private func copy() {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return }
        #if os(iOS)
        UIPasteboard.general.string = words
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(words, forType: .string)
        #endif
        withAnimation(.easeOut(duration: 0.15)) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeIn(duration: 0.2)) { copied = false }
        }
    }
}


/// Where a line of a mail round's receipt is now — the mail, the task, the date — so that a tap on
/// it opens its matter at that very line, as a source under an answer does.
@MainActor
enum Receipt {
    static func place(ofMail messageID: String, in context: ModelContext) -> (matter: Matter, row: PersistentIdentifier)? {
        guard let entry = try? context.fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.messageID == messageID })).first,
              let matter = entry.matter else { return nil }
        return (matter, entry.persistentModelID)
    }

    /// A task by its words, a date by what it is for: the receipt keeps the words, not the thing.
    /// The newest of that name, when there are several.
    static func place(of item: IntakeSummary.Item, in context: ModelContext) -> (matter: Matter, row: PersistentIdentifier)? {
        // "Oct 27, 08:00 · Carry & Co come with the van", "by Oct 16 · Answer …": what it is for comes last.
        let what = item.text.components(separatedBy: " · ").dropFirst().joined(separator: " · ")
        switch item.symbol {
        case "checklist":
            let text = item.text
            let found = (try? context.fetch(FetchDescriptor<Todo>(predicate: #Predicate { $0.text == text }))) ?? []
            return found.last(where: { $0.matter != nil }).flatMap { todo in todo.matter.map { ($0, todo.persistentModelID) } }
        case "calendar":
            let found = (try? context.fetch(FetchDescriptor<Appointment>(predicate: #Predicate { $0.what == what }))) ?? []
            return found.last(where: { $0.matter != nil }).flatMap { item in item.matter.map { ($0, item.persistentModelID) } }
        case "flag":
            let found = (try? context.fetch(FetchDescriptor<Deadline>(predicate: #Predicate { $0.what == what }))) ?? []
            return found.last(where: { $0.matter != nil }).flatMap { item in item.matter.map { ($0, item.persistentModelID) } }
        default:
            return nil
        }
    }
}

/// The adviser's brief for a matter: written in one request, in place of the summary and the step,
/// put into the matter, and its proposals taken one by one — the same on every device.
@MainActor
enum Adviser {
    /// The whole request: the facts, disguised, sent, and the answer put into the matter. Returns its cost.
    @discardableResult
    static func write(_ matter: Matter, names: AutoUpdate.Names, owner: String?, in context: ModelContext) async throws -> Double {
        let model = ModelChoice.assistant
        guard let claude = ModelChoice.client(for: model) else { throw Missing.key }
        let today = MatterStatus.day(Date())
        let facts = FactSheet.facts(for: [matter], today: today, mails: 40)
        let dismissed = self.dismissed(in: matter)
        let asked = (matter.shownBrief?.lookups ?? []).map(\.question)
        // The mails since the brief before, as the facts list them: what its news is to be about.
        let new = matter.mailsSinceBrief
        let since = new.map { "\($0.date.map(MatterStatus.day) ?? "") \($0.from) — \($0.title)" }
        #if os(iOS)
        // Switched away or locked meanwhile, the answer still comes: iOS gives the app time to finish
        // it — without, the request was cut off, and the brief said "Stopped."
        let background = UIApplication.shared.beginBackgroundTask(withName: "brief")
        defer { UIApplication.shared.endBackgroundTask(background) }
        #endif
        let advice: AssistantAsk.Advice
        switch names {
        case .file(let url):
            advice = try await AssistantAsk.advise(facts: facts, dismissed: dismissed, asked: asked, since: since, owner: owner, today: today, mapping: url, claude: claude, model: model)
        case .list(let mapping, let others):
            advice = try await AssistantAsk.advise(facts: facts, dismissed: dismissed, asked: asked, since: since, owner: owner, today: today, mapping: mapping,
                                                   others: others, claude: claude, model: model)
        }
        let before = matter.shownBrief?.writtenAt
        put(advice, facts: facts, into: matter, owner: owner,
            news: advice.news.isEmpty || new.isEmpty ? nil : Brief.News(lines: advice.news, mails: new.count, since: before ?? Date()), in: context)
        return advice.cost
    }

    enum Missing: LocalizedError {
        case key
        var errorDescription: String? { "No key for the assistant's model is saved." }
    }

    /// What the owner put away, said to the adviser so it is not proposed again.
    static func dismissed(in matter: Matter) -> [String] {
        (matter.shownBrief?.dismissed ?? []).suffix(15).map { "\($0.card.kind.rawValue): \($0.card.text)" }
    }

    /// The summary, the step and the brief, with its proposals — each with the facts its ids stand
    /// for, and their keys, so another device finds them.
    static func put(_ advice: AssistantAsk.Advice, facts: Facts, into matter: Matter, owner: String? = nil, news: Brief.News? = nil,
                    in context: ModelContext, at now: Date = Date()) {
        matter.nextStep = advice.step
        matter.nextStepWhy = advice.why
        if case .todo(let id) = advice.todo { matter.nextStepTodo = (matter.todos ?? []).first { $0.persistentModelID == id }?.origin }
        else { matter.nextStepTodo = nil }
        matter.nextStepAt = now
        if !advice.summary.isEmpty {
            matter.summary = advice.summary.joined(separator: "\n")
            matter.summaryAt = now
        }
        let proposals = advice.proposals.map { card in
            let ids = Set([card.todo, card.into].compactMap { $0 } + card.cites)
            let refs = facts.refs.filter { ids.contains($0.key) }
            return Brief.Proposal(card: card, refs: refs, keys: CardActions.keys(of: refs, in: context))
        }
        // A question to look up is shown only when it names no one of the matter, and not the owner.
        let personal = WebLookup.personal(matter.parties.flatMap { [$0.name] + $0.spellings } + [owner].compactMap { $0 })
        let questions = advice.research.filter { WebLookup.refusal($0, personal: personal) == nil }
        matter.shownBrief = (matter.shownBrief ?? Brief()).rewritten(lines: advice.lines, proposals: proposals, questions: questions, news: news, at: now)
        try? context.save()
    }

    /// A question from the assistant, looked up: kept with the matter's lookups, so its brief knows
    /// it; without a matter, only answered. Returns what was found.
    static func lookUp(question: String, in matter: Matter?, context: ModelContext) async throws -> (answer: String, sources: [WebLookup.Source]) {
        let model = ModelChoice.assistant
        guard let claude = ModelChoice.client(for: model) else { throw Missing.key }
        let found = try await WebLookup.ask(question, language: AssistantAsk.language(of: [question]),
                                            country: Locale.current.region?.identifier, claude: claude, model: model)
        if let matter {
            let id = matter.ask(question, fromAssistant: true)
            matter.settle(id, answer: found.answer, sources: found.sources)
            try? context.save()
        }
        return (found.answer, found.sources)
    }

    /// A question the owner chose to have looked up: it alone goes out, checked once more, in a
    /// request of its own; the answer and its sources are kept under the brief. Returns its cost.
    @discardableResult
    static func lookUp(_ lookup: WebLookup.Lookup, in matter: Matter, context: ModelContext) async throws -> Double {
        let model = ModelChoice.assistant
        guard let claude = ModelChoice.client(for: model) else { throw Missing.key }
        let language = AssistantAsk.language(of: [lookup.question])
        let found = try await WebLookup.ask(lookup.question, language: language, country: Locale.current.region?.identifier,
                                            claude: claude, model: model)
        matter.settle(lookup.id, answer: found.answer, sources: found.sources)
        try? context.save()
        return found.cost
    }

    /// A proposal ticked: done as the assistant's card would be. False when what it names is gone.
    @discardableResult
    static func take(_ proposal: Brief.Proposal, text: String? = nil, in matter: Matter, context: ModelContext) -> Bool {
        let refs = CardActions.local(proposal.refs, keys: proposal.keys, matter: matter, in: context)
        switch CardActions.apply(proposal.card, text: text ?? proposal.card.text, subject: nil, refs: refs, links: nil, scope: matter, in: context) {
        case .taken(let undo):
            // A task it added says where it came from: the brief, not a question in the assistant.
            if case .remove(let id) = undo, let todo = CardActions.live(id, as: Todo.self, in: context) {
                todo.sources = todo.sources.map { var source = $0; source.pointer = "brief"; return source }
            }
            matter.decide(proposal.id, .taken)
            try? context.save()
            return true
        case .madeMatter:
            matter.decide(proposal.id, .taken)
            try? context.save()
            return true
        default:
            return false
        }
    }

    static func dismiss(_ proposal: Brief.Proposal, in matter: Matter, context: ModelContext) {
        matter.decide(proposal.id, .dismissed)
        try? context.save()
    }
}

/// What a draft's files wait for before its mail opens, said on its card: a file still in iCloud
/// is fetched first, a picture too big for a mail is made smaller — each can take a moment, and the
/// card said nothing meanwhile. The same on every device.
@MainActor
@Observable
final class MailPreparing {
    static let shared = MailPreparing()
    /// By card: "<turn id>-<card index>".
    private(set) var notes: [String: String] = [:]

    static func key(_ turn: UUID, _ index: Int) -> String { "\(turn)-\(index)" }

    /// The files' work, done away from the screen, with what it waits for said on the card meanwhile.
    func prepare<Result: Sendable>(_ key: String, files: [URL], _ work: @escaping @Sendable ([URL]) -> Result) async -> Result {
        notes[key] = Self.note(for: files)
        defer { notes[key] = nil }
        return await Task.detached { work(files) }.value
    }

    /// "Getting photo.jpg from iCloud …" for a file not on this device yet; "Making photo.jpg
    /// smaller for the mail …" for a big picture; nil when nothing takes a moment.
    static func note(for files: [URL]) -> String? {
        if let away = files.first(where: { !isHere($0) }) { return "Getting \(away.lastPathComponent) from iCloud …" }
        if let big = files.first(where: { (try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { $0 } ?? 0 > ImageSize.limit }) {
            return "Making \(big.lastPathComponent) smaller for the mail …"
        }
        return nil
    }

    /// On this device, whole: not a file of iCloud Drive that is only listed here.
    private static func isHere(_ file: URL) -> Bool {
        guard let status = try? file.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus else { return true }
        return status == .current
    }
}

extension Notification.Name {
    /// Open the matter of this key — from a notification tapped.
    static let openMatterKey = Notification.Name("causabee.openMatterKey")
}

/// What new mail changes in a matter, told as a notification — once, on whichever device sees the
/// news first, Auto's or a sync's. Allowed by the owner when the first news comes; nothing without.
@MainActor
enum NewsNotice {
    private static let toldKey = "news.told"
    private static var looked = -1

    /// Each matter's news not told yet, as a notification: looked at once per change to the store.
    static func tell(_ matters: () -> [Matter]) {
        guard !DemoData.isRequested, looked != StoredChanges.shared.count else { return }
        looked = StoredChanges.shared.count
        var told = UserDefaults.standard.stringArray(forKey: toldKey) ?? []
        for matter in matters() where !matter.isClosed && matter.brief != nil {
            guard let news = matter.shownBrief?.news, !news.seen, let line = news.lines.first else { continue }
            let mark = "\(matter.key)|\(Int(news.since.timeIntervalSince1970))|\(news.mails)"
            guard !told.contains(mark) else { continue }
            told.append(mark)
            post(title: matter.name, body: line, mails: news.mails, key: matter.key)
        }
        UserDefaults.standard.set(Array(told.suffix(200)), forKey: toldKey)
    }

    private static func post(title: String, body: String, mails: Int, key: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = mails == 1 ? "1 new mail" : "\(mails) new mails"
        content.body = body
        content.sound = .default
        content.threadIdentifier = key
        content.userInfo = ["matter": key]
        let request = UNNotificationRequest(identifier: "news-\(key)", content: content, trigger: nil)
        let center = UNUserNotificationCenter.current()
        Task {
            if await center.notificationSettings().authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
            }
            try? await center.add(request)
        }
    }

    /// Notifications show while Causabee is open too, and a tap opens the matter.
    static func listen() { UNUserNotificationCenter.current().delegate = Listener.shared }

    final class Listener: NSObject, UNUserNotificationCenterDelegate, Sendable {
        static let shared = Listener()

        func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
            [.banner, .list, .sound]
        }

        func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
            guard let key = response.notification.request.content.userInfo["matter"] as? String else { return }
            await MainActor.run { NotificationCenter.default.post(name: .openMatterKey, object: key) }
        }
    }
}
