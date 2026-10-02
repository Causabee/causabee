import Foundation
import MatterCore
import SwiftData

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

    /// A party's address, from the mail in the store: the sender line of a mail they wrote. It is
    /// never sent anywhere; it only fills the "To" of a draft the owner opens.
    static func address(of party: Party) -> String? {
        let keys = Set(([party.name] + party.spellings).map(PartyNames.key))
        for matter in party.matters {
            for entry in matter.entries ?? [] {
                guard let name = Email.displayName(in: entry.from), keys.contains(PartyNames.key(name)) else { continue }
                let address = Email.address(in: entry.from)
                if address.contains("@") { return address }
            }
        }
        return nil
    }

    static func recipient(_ id: String?, refs: [String: FactRef], in context: ModelContext) -> (name: String, address: String?)? {
        guard let id, let ref = refs[id], let party = live(ref, as: Party.self, in: context) else { return nil }
        return (party.name, address(of: party))
    }

    /// A card the owner ticked, with its text as the owner left it. Only now does anything change
    /// in the store. `scope` is the matter the answer is about: one made by a card of the same
    /// answer, the one it was asked in, or the one its facts come from.
    static func apply(_ card: AssistantPrompt.Reply.Card, text: String, subject: String?, refs: [String: FactRef],
                      links: [String: String]?, scope: Matter?, in context: ModelContext) -> Outcome {
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
            let to = recipient(card.party, refs: refs, in: context)?.address ?? ""
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
