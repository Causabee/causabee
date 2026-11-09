import Foundation
import SwiftData

/// Everything a matter holds, handled from the chat as by hand: put away, opened again, one thing
/// changed, moved to another matter. Each says what it was before, so it can be undone, and does
/// nothing — saying so — when it cannot be done. No schema change: what can be put away has
/// `isHidden`; a decision, which has not, goes and is made anew on undo.
public enum ChatControl {
    /// What it was, for undo: one value, or nothing when it was empty.
    public struct Before: Sendable, Equatable {
        public var value: String?
    }

    // MARK: Put away

    /// Put away: hidden, as by hand. What came in and the owner took out is not suggested again
    /// (as `deleteByHand`). Returns the words now not wanted, for undo, or nil when it could not be.
    public static func putAway(_ model: any PersistentModel, from matter: Matter?) -> (done: Bool, unwanted: String?) {
        switch model {
        case let todo as Todo:
            guard !todo.isHidden else { return (false, nil) }
            todo.isHidden = true
            return (true, unwant(todo.text, brought: !todo.sources.filter { $0.kind != .conversation }.isEmpty, in: todo.matter))
        case let item as Appointment:
            guard !item.isHidden else { return (false, nil) }
            item.isHidden = true
            return (true, unwant(item.what, brought: !item.sources.filter { $0.kind != .conversation }.isEmpty, in: item.matter))
        case let item as Deadline:
            guard !item.isHidden else { return (false, nil) }
            item.isHidden = true
            return (true, unwant(item.what, brought: !item.sources.filter { $0.kind != .conversation }.isEmpty, in: item.matter))
        case let party as Party:
            guard let matter, let membership = matter.membership(of: party), !membership.isHidden else { return (false, nil) }
            membership.isHidden = true
            return (true, nil)
        case let hideable as Hideable:
            guard !hideable.isHidden else { return (false, nil) }
            hideable.isHidden = true
            return (true, nil)
        default:
            return (false, nil)
        }
    }

    private static func unwant(_ words: String, brought: Bool, in matter: Matter?) -> String? {
        guard brought, let matter, !(matter.shownBrief?.unwanted ?? []).contains(words) else { return nil }
        matter.notWanted(words)
        return words
    }

    /// Shown again — and wanted again, when putting it away made it unwanted.
    public static func showAgain(_ model: any PersistentModel, in matter: Matter?, unwanted: String?) {
        if let party = model as? Party, let matter { matter.membership(of: party)?.isHidden = false }
        else if let hideable = model as? Hideable { hideable.isHidden = false }
        if let unwanted, let matter, var brief = matter.shownBrief {
            brief.unwanted.removeAll { $0 == unwanted }
            matter.shownBrief = brief
        }
    }

    // MARK: One thing changed

    /// The fields each kind of item has, as the chat names them.
    public static func fields(of model: any PersistentModel) -> [String] {
        switch model {
        case is Todo: ["text", "note", "kind"]
        case is Appointment: ["text", "place"]
        case is Deadline: ["text"]
        case is MatterNote: ["text"]
        case is MatterDetail: ["label", "value"]
        case is WebLink: ["title"]
        case is Document: ["name"]
        case is Party: ["phone", "mail"]
        case is Matter: ["name"]
        case is Decision: ["text", "why"]
        default: []
        }
    }

    /// Sets one field; returns what it was, or nil when the item has no such field or the value
    /// cannot be — an empty name, a kind that is neither. Empty clears what may be empty.
    public static func change(_ model: any PersistentModel, field: String, to raw: String) -> Before? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let field = field.lowercased()
        func clearable(_ text: String) -> String? { text.isEmpty ? nil : text }
        switch (model, field) {
        case (let todo as Todo, "text"):
            guard !value.isEmpty else { return nil }
            defer { todo.text = value }
            return Before(value: todo.text)
        case (let todo as Todo, "note"):
            defer { todo.note = clearable(value) }
            return Before(value: todo.note)
        case (let todo as Todo, "kind"):
            let info: Bool
            switch value.lowercased() {
            case "info", "fact", "good to know", "worth knowing": info = true
            case "task", "todo", "to-do": info = false
            default: return nil
            }
            defer { todo.isInfo = info }
            return Before(value: todo.isInfo ? "info" : "task")
        case (let item as Appointment, "text"):
            guard !value.isEmpty else { return nil }
            defer { item.what = value; item.claim() }
            return Before(value: item.what)
        case (let item as Appointment, "place"):
            defer { item.place = clearable(value); item.claim() }
            return Before(value: item.place)
        case (let item as Deadline, "text"):
            guard !value.isEmpty else { return nil }
            defer { item.what = value }
            return Before(value: item.what)
        case (let note as MatterNote, "text"):
            guard !value.isEmpty else { return nil }
            defer { note.text = value }
            return Before(value: note.text)
        case (let detail as MatterDetail, "label"):
            guard !value.isEmpty else { return nil }
            defer { detail.label = value }
            return Before(value: detail.label)
        case (let detail as MatterDetail, "value"):
            guard !value.isEmpty else { return nil }
            defer { detail.value = value }
            return Before(value: detail.value)
        case (let link as WebLink, "title"):
            defer { link.title = value }
            return Before(value: link.title)
        case (let file as Document, "name"):
            guard !value.isEmpty else { return nil }
            defer { file.title = value }
            return Before(value: file.title)
        case (let party as Party, "phone"):
            defer { party.phone = clearable(value) }
            return Before(value: party.phone)
        case (let party as Party, "mail"):
            defer { party.address = clearable(value) }
            return Before(value: party.address)
        case (let matter as Matter, "name"):
            guard !value.isEmpty, value != matter.name else { return nil }
            defer { matter.rename(to: value) }
            return Before(value: matter.name)
        case (let decision as Decision, "text"):
            guard !value.isEmpty else { return nil }
            defer { decision.what = value }
            return Before(value: decision.what)
        case (let decision as Decision, "why"):
            defer { decision.why = value }
            return Before(value: decision.why)
        default:
            return nil
        }
    }

    /// Sets it back as it was. A matter's name goes back without keeping the new one as an alias.
    public static func restore(_ model: any PersistentModel, field: String, to before: Before) {
        if let matter = model as? Matter, field.lowercased() == "name", let old = before.value {
            let new = matter.name
            matter.name = old
            matter.aliases.removeAll { $0 == old || $0 == new }
            return
        }
        // What may not be empty by hand was empty before: set back as it was, all the same.
        switch (model, field.lowercased()) {
        case (let file as Document, "name"): file.title = before.value
        case (let link as WebLink, "title"): link.title = before.value ?? ""
        default: _ = change(model, field: field, to: before.value ?? "")
        }
    }

    // MARK: Moved

    /// Into another matter. Returns the matter it was in, or nil when it cannot be moved.
    public static func move(_ model: any PersistentModel, into target: Matter) -> Matter?? {
        func moved(_ from: Matter?, _ set: () -> Void) -> Matter?? {
            guard from !== target else { return nil }
            set()
            return .some(from)
        }
        switch model {
        case let todo as Todo: return moved(todo.matter) { todo.matter = target }
        case let item as Appointment: return moved(item.matter) { item.matter = target }
        case let item as Deadline: return moved(item.matter) { item.matter = target }
        case let note as MatterNote: return moved(note.matter) { note.matter = target }
        case let link as WebLink: return moved(link.matter) { link.matter = target }
        case let file as Document: return moved(file.matter) { file.matter = target }
        case let detail as MatterDetail: return moved(detail.matter) { detail.matter = target }
        case let entry as Entry: return moved(entry.matter) { entry.matter = target }
        case let decision as Decision: return moved(decision.matter) { decision.matter = target }
        default: return nil
        }
    }

    /// The matter a name means: exactly, then by its words, among the open ones first.
    public static func matter(named name: String, in context: ModelContext) -> Matter? {
        let words = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !words.isEmpty else { return nil }
        let all = ((try? context.fetch(FetchDescriptor<Matter>())) ?? []).sorted { !$0.isClosed && $1.isClosed }
        return all.first { $0.name.lowercased() == words || $0.aliases.contains { $0.lowercased() == words } }
            ?? all.first { $0.name.lowercased().contains(words) || words.contains($0.name.lowercased()) }
    }
}
