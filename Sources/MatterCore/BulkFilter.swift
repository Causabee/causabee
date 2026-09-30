import Foundation

/// Step 2 of the spike: throw out the mail that was never addressed to anybody in particular,
/// using headers alone.
///
/// This layer exists to be cheap. Every mail it settles is a mail no model has to read and no
/// text has to be disguised for, and the first question the spike has to answer is how much of
/// the pile that is. It is also the layer where a mistake is quiet: a bulk verdict on a real
/// letter does not show an error, it shows nothing at all, which is why each verdict names the
/// rule that made it — a rule with false positives can then be found and dropped rather than
/// guessed at.
public enum BulkFilter {
    public enum Rule: String, Codable, Sendable, CaseIterable {
        case listUnsubscribe = "list_unsubscribe"
        case listId = "list_id"
        case precedenceBulk = "precedence_bulk"
        case autoSubmitted = "auto_submitted"
        /// The weak one, and the only one that reads the sender rather than a header a sending
        /// system put there on purpose. A statement notice and a newsletter both come from
        /// `noreply@`, and only one of them can belong to a matter.
        case noreplySender = "noreply_sender"

        public var reason: String {
            switch self {
            case .listUnsubscribe: "List-Unsubscribe header"
            case .listId: "List-Id header"
            case .precedenceBulk: "Precedence: bulk"
            case .autoSubmitted: "Auto-Submitted header"
            case .noreplySender: "sender is a noreply address"
            }
        }
    }

    public struct Verdict: Equatable, Sendable {
        public var isBulk: Bool
        public var rule: Rule?
        public var reason: String?
    }

    /// Local parts that say "nobody reads answers to this". Deliberately short: `info@`,
    /// `service@` and `kontakt@` are where a Hausverwaltung writes from.
    static let noreplyLocalParts = [
        "noreply", "no-reply", "no_reply", "no.reply",
        "donotreply", "do-not-reply", "do_not_reply",
        "nicht-antworten", "nichtantworten", "keine-antwort",
        "mailer-daemon", "bounce", "bounces",
    ]

    public static func verdict(for email: Email) -> Verdict {
        if email.hasHeader("list-unsubscribe") { return caught(.listUnsubscribe) }
        if email.hasHeader("list-id") { return caught(.listId) }

        let precedence = email.header("precedence")?.lowercased().trimmed
        if precedence == "bulk" || precedence == "list" || precedence == "junk" {
            return caught(.precedenceBulk)
        }
        if let auto = email.header("auto-submitted")?.lowercased().trimmed, auto != "no" {
            return caught(.autoSubmitted)
        }
        if isNoreply(email.fromAddress) { return caught(.noreplySender) }

        return Verdict(isBulk: false, rule: nil, reason: nil)
    }

    static func caught(_ rule: Rule) -> Verdict { Verdict(isBulk: true, rule: rule, reason: rule.reason) }

    static func isNoreply(_ address: String) -> Bool {
        let local = String(address.split(separator: "@").first ?? "").lowercased()
        guard !local.isEmpty else { return false }
        return noreplyLocalParts.contains {
            // `noreply-github@` and `bounces+4711@` count; `informations@` must not match
            // `info`, and the dot is left out on purpose — a dash or a plus is how a sending
            // system tags an address, a dot is how a person spells their name.
            local == $0 || local.hasPrefix($0 + "-") || local.hasPrefix($0 + "+")
        }
    }
}
