import Foundation

/// Whose new mail is offered without a label: the people of the matters that are going on, and of
/// those closed in the last two months. A matter closed longer ago sleeps — mail for it is the
/// owner's to label again.
public enum KnownSenders {
    public static let sleepsAfterDays = 60

    public static func addresses(in matters: [Matter], now: Date = Date()) -> [String] {
        let awake = matters.filter { matter in
            guard let closed = matter.closedAt else { return true }
            return now.timeIntervalSince(closed) < Double(sleepsAfterDays) * 86_400
        }
        // The address put in by hand, where there is one — and the addresses a matter's people
        // wrote from: most people came in with their mail, and have no address of their own here.
        var found = awake.flatMap(\.parties).compactMap { $0.address?.trimmingCharacters(in: .whitespaces).lowercased() }
        for matter in awake {
            for entry in matter.entries ?? [] where matter.writer(entry.from) != nil {
                found.append(Email.address(in: entry.from))
            }
        }
        return Array(Set(found.filter { $0.contains("@") })).sorted()
    }
}
