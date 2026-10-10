import Foundation
import SwiftData

/// How a name as the model wrote it becomes a party: the same person written six ways is one
/// party, the owner is none, and what is only likely is asked rather than done.
///
/// Three levels, from sure to unsure:
///
/// - **Automatic.** The same name once the title, the brackets, the case, the spaces and the way
///   an umlaut was typed are taken away: `Frau Dr. Petra Lindner (Mimi)`, `Doktor Petra Lindner`
///   and `Petralindner` are one party. So are `Süß`, `Süss` and `suess`. This is spelling, not
///   judgement.
/// - **Suggested.** A name that is part of exactly one other in the same matter — `Süß` and
///   `Sebastian Süß`, `Nordblick` and `Nordblick Hausverwaltung` — is offered as a merge with its reason.
///   The owner says yes or no; a no is kept, so it is not asked again.
/// - **By hand.** Any two, merged by the owner.
///
/// A merge the owner made is a `Rule`: it holds for the next mail too, it is counted each time it
/// is used, and it can be switched off.
public enum PartyNames {
    /// The name without what is around it: `Frau Dr. Petra Lindner (Mimi)` → `Petra Lindner`,
    /// `Frau Kurz (anna.kurz@firma.example)` → `Kurz`, `Süß, Sebastian` → `Sebastian Süß`.
    public static func core(_ name: String) -> String {
        var text = name.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"<?[^\s<>]+@[^\s<>]+>?"#, with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: " '\"‘’‚“”„"))
        if let slash = text.range(of: " / ") { text = String(text[..<slash.lowerBound]) }
        if let comma = text.firstIndex(of: ","), !text.contains(where: { $0.isNumber }) {
            let family = text[..<comma].trimmingCharacters(in: .whitespaces)
            let given = text[text.index(after: comma)...].trimmingCharacters(in: .whitespaces)
            if !family.isEmpty, !given.isEmpty, !family.contains(" ") { text = given + " " + family }
        }
        var words = text.split(whereSeparator: \.isWhitespace).map {
            String($0).trimmingCharacters(in: CharacterSet(charactersIn: "'\"‘’‚“”„,;:"))
        }.filter { !$0.isEmpty }
        while words.count > 1, let first = words.first, Pseudonymizer.honorifics.contains(Pseudonymizer.key(first)) {
            words.removeFirst()
        }
        return words.joined(separator: " ")
    }

    static let legalForms: Set<String> = ["gmbh", "mbh", "ag", "kg", "ug", "se", "ohg", "gbr", "ev", "ltd", "inc", "llc", "co", "und"]

    /// The words of the core, folded: lowercase, `ü` as `ue`, `ß` as `ss`, legal forms left out.
    public static func tokens(_ name: String) -> [String] {
        core(name).split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "&" }).map { fold(String($0)) }
            .filter { !$0.isEmpty && !legalForms.contains($0) }
    }

    /// One string per name, to look it up by.
    public static func key(_ name: String) -> String { tokens(name).joined() }

    static func fold(_ word: String) -> String {
        var text = word.lowercased()
        for (from, to) in [("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss")] { text = text.replacingOccurrences(of: from, with: to) }
        text = text.applyingTransform(.stripDiacritics, reverse: false) ?? text
        return text.filter { $0.isLetter || $0.isNumber }
    }
}

/// The owner's names, to keep the owner out of their own parties.
public struct OwnerNames: Sendable {
    let full: Set<String>
    let parts: Set<String>

    public init(_ names: [String]) {
        var full: Set<String> = [], parts: Set<String> = []
        for name in names where !name.contains("@") {
            let tokens = PartyNames.tokens(name)
            guard !tokens.isEmpty else { continue }
            full.insert(tokens.joined())
            full.insert(tokens.reversed().joined())
            for token in tokens where token.count >= 3 { parts.insert(token) }
        }
        self.full = full
        self.parts = parts
    }

    /// `Jan Kramer`, `Kramer Jan`, `Jan` are the owner. A bare `Kramer` is the owner only
    /// when nobody else in the matter is called Kramer — in the mother's matter it is her.
    /// `Jan Kramer` or `Kramer Jan`, not `Jan` alone.
    func isFullName(_ name: String) -> Bool { full.contains(PartyNames.tokens(name).joined()) }

    func isOwner(_ name: String, others: Set<String>) -> Bool {
        let tokens = PartyNames.tokens(name)
        if full.contains(tokens.joined()) { return true }
        guard tokens.count == 1, let only = tokens.first, parts.contains(only) else { return false }
        return !others.contains(only)
    }
}

public struct PartyBook {
    private var byKey: [String: Party] = [:]
    private let rules: [Rule]
    public let owner: OwnerNames

    public init(context: ModelContext, owner: OwnerNames) throws {
        self.owner = owner
        rules = try context.fetch(FetchDescriptor<Rule>())
        for party in try context.fetch(FetchDescriptor<Party>()) {
            for key in party.keys { byKey[key] = byKey[key] ?? party }
        }
    }

    /// A name alone in one word — `Kramer`, `Stein` — could be anyone, so it is kept apart per
    /// matter until the owner says who it is. A full name is the same person in every matter.
    static func lookupKey(_ name: String, in matter: Matter) -> String {
        let tokens = PartyNames.tokens(name)
        return tokens.count == 1 ? tokens[0] + "@" + matter.key : tokens.joined()
    }

    /// The party a name in `matter` stands for, made if it is new. Nil for the owner, and for a
    /// name with nothing left of it once the title is gone. `others` is every word of every
    /// other full name in the matter.
    public mutating func party(named written: String, in matter: Matter, others: Set<String>, context: ModelContext) -> Party? {
        let core = PartyNames.core(written)
        let key = Self.lookupKey(written, in: matter)
        guard !key.isEmpty, !key.hasPrefix("@"), !owner.isOwner(written, others: others) else { return nil }

        let party: Party
        if let rule = rules.first(where: { $0.isOn && $0.kind == .sameParty && Self.lookupKey($0.subject, in: matter) == key
                                           && ($0.matterKey.map(matter.answers(to:)) ?? true) }),
           let target = byKey[Self.lookupKey(rule.object, in: matter)] ?? byKey[PartyNames.key(rule.object)] {
            rule.fired += 1
            party = target
        } else if let known = byKey[key] ?? byKey[PartyNames.key(written)] {
            // The second: `Petralindner`, one word, is Petra Lindner with the space lost.
            party = known
        } else {
            party = Party(name: core)
            party.keys = [key]
            context.insert(party)
            byKey[key] = party
        }
        if !party.spellings.contains(written) { party.spellings.append(written) }
        if PartyNames.tokens(core).count > PartyNames.tokens(party.name).count { party.name = core }
        return party
    }

    /// `other` becomes `party`: every spelling and every matter it was in. Its own keys are not
    /// taken over — the rule that asked for the merge is what sends the next mail's `Dr. Lindner`
    /// here, so switching the rule off stops it.
    public static func merge(_ other: Party, into party: Party, context: ModelContext) {
        guard other !== party else { return }
        for spelling in other.spellings where !party.spellings.contains(spelling) { party.spellings.append(spelling) }
        let memberships = other.memberships ?? []
        other.memberships = []
        for membership in memberships {
            if let matter = membership.matter, let existing = matter.membership(of: party) {
                // The roles of the one merged in go before its own, so its own latest role still
                // says what it is: Mimi's "Mitverfasserin" does not overwrite Petra Lindner's "Beirätin".
                existing.roles = membership.roles.filter { !existing.roles.contains($0) } + existing.roles
                existing.mentions += membership.mentions
                membership.party = nil
                membership.matter = nil
                context.delete(membership)
            } else {
                membership.party = party
            }
        }
        if PartyNames.tokens(other.name).count > PartyNames.tokens(party.name).count { party.name = other.name }
        context.delete(other)
    }

    public struct Suggestion {
        public var party: Party
        public var into: Party
        public var reason: String
    }

    /// Merges worth asking about in one matter: two parties with the same name, and a name that
    /// is part of exactly one other name there — unless the owner has already said they are two.
    public static func suggestions(in matter: Matter, rules: [Rule]) -> [Suggestion] {
        let parties = matter.parties
        var out: [Suggestion] = []
        func refused(_ a: Party, _ b: Party) -> Bool {
            rules.contains { rule in
                rule.kind == .notSameParty && rule.isOn
                    && Set([PartyNames.key(rule.subject), PartyNames.key(rule.object)]) == Set([PartyNames.key(a.name), PartyNames.key(b.name)])
            }
        }
        // The same name twice: after a rename, or two spellings that came to one.
        var seen: [String: Party] = [:]
        for party in parties.sorted(by: { (matter.membership(of: $0)?.mentions ?? 0) > (matter.membership(of: $1)?.mentions ?? 0) }) {
            let key = PartyNames.key(party.name)
            if let first = seen[key] {
                if !refused(party, first) { out.append(Suggestion(party: party, into: first, reason: "the same name twice")) }
            } else {
                seen[key] = party
            }
        }
        for party in parties {
            let words = Set(PartyNames.tokens(party.name))
            guard !words.isEmpty, !out.contains(where: { $0.party === party }) else { continue }
            let wider = parties.filter { other in
                other !== party && Set(PartyNames.tokens(other.name)).count > words.count
                    && words.isSubset(of: Set(PartyNames.tokens(other.name)))
            }
            guard wider.count == 1, let into = wider.first, !refused(party, into) else { continue }
            let reason = words.count == 1
                ? "“\(party.name)” is in only one other name in this matter"
                : "“\(party.name)” is part of “\(into.name)”, and of no other name here"
            out.append(Suggestion(party: party, into: into, reason: reason))
        }
        return out
    }
}

extension Matter {
    /// Who of the matter's people wrote a mail, by its sender line. By the name in it, in any way
    /// it is written; a line that is an address alone — `lutz.barbara@gmx.net` — is the person who
    /// has that address, or the one person here whose whole name is in it. Two it could be is nobody.
    public func writer(_ from: String) -> Party? {
        if let name = Email.displayName(in: from) {
            let key = PartyNames.key(name)
            return parties.first { ([$0.name] + $0.spellings).contains { PartyNames.key($0) == key } }
        }
        let address = Email.address(in: from)
        guard address.contains("@") else { return nil }
        if let known = parties.first(where: { $0.address?.lowercased() == address }) { return known }
        // The words before the @ and the domain's own name; not its ending.
        let parts = address.split(separator: "@")
        let domain = parts.last.map { $0.split(separator: ".").dropLast().joined(separator: ".") } ?? ""
        let words = Set(((parts.first.map(String.init) ?? "") + " " + domain).split { !$0.isLetter }
            .map { PartyNames.fold(String($0)) }.filter { $0.count >= 3 })
        let fits = parties.filter { party in
            let tokens = PartyNames.tokens(party.name)
            return !tokens.isEmpty && tokens.allSatisfy(words.contains)
        }
        return fits.count == 1 ? fits[0] : nil
    }

    /// The name a mail's sender is shown by: the one in its sender line; for an address alone, the
    /// person of the matter it is, and only failing that the address.
    public func writerName(_ from: String) -> String {
        Email.displayName(in: from) ?? writer(from)?.name ?? Email.address(in: from)
    }
}

extension Party {
    /// A name the owner gave. The old one stays among the spellings, so the next mail that
    /// writes it still finds this party.
    /// Going back to a name it had before forgets the one in between: that was a mistake.
    public func rename(to newName: String) {
        guard !newName.isEmpty, newName != name else { return }
        if spellings.contains(newName) {
            spellings.removeAll { $0 == newName }
        } else if !spellings.contains(name) {
            spellings.append(name)
        }
        name = newName
    }
}

extension Membership {
    /// The role the owner says they have here. It goes last, so it is the one shown.
    public func setRole(_ role: String) {
        let role = role.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !role.isEmpty else { return }
        roles.removeAll { $0 == role }
        roles.append(role)
    }
}

extension Membership {
    /// The owner's rule that this person is not part of the matter, if there is one that is on.
    public static func removal(of name: String, from matter: Matter, in context: ModelContext) -> Rule? {
        let key = PartyNames.key(name)
        return ((try? context.fetch(FetchDescriptor<Rule>())) ?? []).first { rule in
            rule.isOn && rule.kind == .notInMatter && rule.matterKey.map(matter.answers) == true && PartyNames.key(rule.subject) == key
        }
    }

    /// Takes the person out of the matter, and keeps it as a rule so the next mail does not bring
    /// them back. The person stays in other matters; nothing else is deleted.
    public func remove(in context: ModelContext, origin: String) {
        guard let party, let matter else { return }
        context.insert(Rule(.notInMatter, subject: party.name, object: "", matterKey: matter.key, origin: origin))
        context.delete(self)
    }

    /// The same by the owner's hand, and to be taken back: Undo puts the person in the matter
    /// again — their role, how often they were named — and takes the rule out that kept them away.
    @MainActor
    public func removeByHand(in context: ModelContext, origin: String, undo: UndoManager?) {
        guard let party, let matter else { return }
        let who = party.persistentModelID, where_ = matter.persistentModelID
        let name = party.name, key = matter.key, roles = roles, mentions = mentions
        remove(in: context, origin: origin)
        try? context.save()
        undo?.registerUndo(withTarget: context) { context in
            MainActor.assumeIsolated {
                func live<T: PersistentModel>(_ id: PersistentIdentifier, _ type: T.Type) -> T? {
                    var descriptor = FetchDescriptor<T>(predicate: #Predicate { $0.persistentModelID == id })
                    descriptor.fetchLimit = 1
                    return (try? context.fetch(descriptor))?.first
                }
                // Gone meanwhile — the person merged away, the matter merged — there is nothing to put back.
                guard let party = live(who, Party.self), let matter = live(where_, Matter.self) else { return }
                let rules = (try? context.fetch(FetchDescriptor<Rule>())) ?? []
                for rule in rules where rule.kind == .notInMatter && rule.subject == name && rule.matterKey == key { context.delete(rule) }
                if !(matter.memberships ?? []).contains(where: { $0.party === party }) {
                    let membership = Membership()
                    context.insert(membership)
                    membership.party = party
                    membership.matter = matter
                    membership.roles = roles
                    membership.mentions = mentions
                    try? context.save()
                    // Registered while undoing, this is the Redo: they go again.
                    undo?.registerUndo(withTarget: context) { context in
                        MainActor.assumeIsolated { membership.removeByHand(in: context, origin: origin, undo: undo) }
                    }
                    undo?.setActionName("Remove Person")
                }
                try? context.save()
            }
        }
        undo?.setActionName("Remove Person")
    }
}
