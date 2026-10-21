import Foundation
import SwiftData

/// The names the owner marked as public — Expedia, Lufthansa, the Techniker Krankenkasse: a big
/// company or a brand, nothing about anyone. They are never disguised, so the AI reads them as they
/// are, and a general question looked up on the web may name them. Kept as rules in the store, so
/// every device has the same list; read into memory here, where every disguise is made.
public enum PublicNames {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var keys: Set<String> = []

    /// The list as it is now, by the keys names are compared by.
    public static func set(_ names: [String]) {
        let made = Set(names.map(Pseudonymizer.key).filter { !$0.isEmpty })
        lock.lock(); keys = made; lock.unlock()
    }

    static var current: Set<String> { lock.lock(); defer { lock.unlock() }; return keys }

    /// Is this name public — itself, or with a word of the company's form after it ("Expedia Inc.")?
    public static func covers(_ name: String) -> Bool {
        let keys = current
        guard !keys.isEmpty else { return false }
        let key = Pseudonymizer.key(name)
        return keys.contains(key) || keys.contains { key.hasPrefix($0 + " ") }
    }

    /// Reads the list from the store's rules.
    @MainActor
    public static func refresh(in context: ModelContext) {
        set(names(in: context))
    }

    @MainActor
    public static func names(in context: ModelContext) -> [String] {
        let raw = Rule.Kind.publicName.rawValue
        let rules = (try? context.fetch(FetchDescriptor<Rule>(predicate: #Predicate { $0.kindRaw == raw && $0.isOn }))) ?? []
        return rules.map(\.subject).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Marks a name public, or not: one rule each, the same everywhere.
    @MainActor
    public static func mark(_ name: String, public isPublic: Bool, in context: ModelContext) {
        let raw = Rule.Kind.publicName.rawValue
        let key = Pseudonymizer.key(name)
        let rules = (try? context.fetch(FetchDescriptor<Rule>(predicate: #Predicate { $0.kindRaw == raw }))) ?? []
        let same = rules.filter { Pseudonymizer.key($0.subject) == key }
        if isPublic {
            if same.isEmpty { context.insert(Rule(.publicName, subject: name, object: "", matterKey: nil, origin: "owner")) }
            else { same.forEach { $0.isOn = true } }
        } else {
            same.forEach(context.delete)
        }
        try? context.save()
        refresh(in: context)
    }
}
