import Foundation

/// Something in a mail that would identify a person, a company or a place if it were sent
/// anywhere.
///
/// The spike's second question is how many of these the device misses, because a miss is not a
/// worse summary — it is a name leaving the phone. So an entity carries where it was found and
/// what found it: the report can then say "the tagger found 82 of 94, and the twelve it missed
/// were all company names" rather than "detection works".
public struct Entity: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case person, place, organization
        case email, phone, iban, street, postalCity
        /// A number that points at one person's file somewhere: a policy, a customer, a case, a
        /// contract, a tax ID. Harmless-looking, and as identifying as a name to whoever keeps it.
        case reference
    }

    /// Which layer found it. Both are on-device; the difference is whether a rule can be
    /// trusted to find every one of them (an IBAN, yes) or not (a name, no).
    public enum Source: String, Codable, Sendable {
        case rule
        case onDevice = "on_device"
    }

    /// Where in the mail. Headers carry as many names as the prose does, and a disguise that
    /// covers only the body is not a disguise.
    public enum Field: String, Codable, Sendable, CaseIterable {
        case subject, from, to, cc, body, attachmentName = "attachment_name"
    }

    public var kind: Kind
    public var text: String
    public var field: Field
    /// UTF-16 offset into that field's text, so a replacement can be made without searching.
    public var start: Int
    public var length: Int
    public var source: Source

    public init(kind: Kind, text: String, field: Field, start: Int, length: Int, source: Source) {
        self.kind = kind
        self.text = text
        self.field = field
        self.start = start
        self.length = length
        self.source = source
    }

    var range: Range<Int> { start..<(start + length) }
}
