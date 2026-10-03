import Foundation
import MatterCore
import SwiftData
import SwiftUI

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
        /// A draft: Mail opens with it, and the owner sends it — or not.
        case openMail(URL)
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
    static func label(_ ref: FactRef, in context: ModelContext) -> String {
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

    static func source(_ ref: FactRef, in context: ModelContext) -> SourceLine {
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
    private static let device = "iPhone"
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
        let keys = Set(([party.name] + party.spellings).map(PartyNames.key))
        var found: [String: (last: Date?, count: Int)] = [:]
        var seen = Set<String>()
        for matter in party.matters {
            for entry in matter.entries ?? [] {
                guard let name = Email.displayName(in: entry.from), keys.contains(PartyNames.key(name)) else { continue }
                let address = Email.address(in: entry.from).lowercased()
                // A mail filed in two matters counts once.
                guard address.contains("@"), seen.insert(entry.messageID.isEmpty ? "\(address) \(String(describing: entry.date))" : entry.messageID).inserted else { continue }
                let before = found[address]
                let last = [before?.last, entry.date].compactMap { $0 }.max()
                found[address] = (last, (before?.count ?? 0) + 1)
            }
        }
        return found.map { MailAddress(address: $0.key, last: $0.value.last, count: $0.value.count) }
            .sorted { ($0.last ?? .distantPast, $0.count, $1.address) > ($1.last ?? .distantPast, $1.count, $0.address) }
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
        case .draftMessage:
            // The one door out: Mail opens with the draft in it, and the owner sends it — or not.
            let to = recipient(card.party, refs: refs, question: question, mail: mail, scope: scope, in: context)?.address ?? ""
            var parts = URLComponents()
            parts.scheme = "mailto"
            parts.path = to
            parts.queryItems = [URLQueryItem(name: "subject", value: subject ?? card.subject ?? ""), URLQueryItem(name: "body", value: text)]
            guard let url = parts.url else { return .nothing }
            return .openMail(url)
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
        case .addNote:
            guard let todo = model(card.todo, as: Todo.self), !text.isEmpty else { return .nothing }
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
