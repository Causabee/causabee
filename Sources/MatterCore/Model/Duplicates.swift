import Foundation

/// What a new file would add that its matter has already: the same to-do in other words, the
/// same appointment or deadline on the same day. Found on the device, so a second screenshot of
/// the same chat, or a mail forwarded twice, does not fill a matter with doubles.
@MainActor
public enum Duplicates {
    static func words(_ text: String) -> Set<String> {
        Set(text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
            .split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count >= 4 })
    }

    /// Half the words of the shorter one are in the other.
    public static func alike(_ a: String, _ b: String) -> Bool {
        let x = words(a), y = words(b)
        guard !x.isEmpty, !y.isEmpty else { return false }
        return Double(x.intersection(y).count) / Double(min(x.count, y.count)) >= 0.5
    }

    /// Nearly the same words, few left over on either side: for things that are not the matter's own.
    public static func same(_ a: String, _ b: String) -> Bool {
        let x = words(a), y = words(b)
        guard !x.isEmpty, !y.isEmpty else { return false }
        return Double(x.intersection(y).count) / Double(x.union(y).count) >= 0.8
    }

    /// The matter's to-do this one already is, open or done.
    public static func todo(_ text: String, in matter: Matter) -> Todo? {
        (matter.todos ?? []).first { alike($0.text, text) }
    }

    /// The matter's appointment on the same day, at the same time or about the same thing.
    public static func appointment(on day: String, at time: String?, _ what: String, in matter: Matter) -> Appointment? {
        (matter.appointments ?? []).first { $0.day == day && ((time != nil && $0.time == time) || alike($0.what, what)) }
    }

    public static func deadline(on day: String, _ what: String, in matter: Matter) -> Deadline? {
        (matter.deadlines ?? []).first { $0.day == day && alike($0.what, what) }
    }
}
