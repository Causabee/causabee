import Foundation
import CryptoKit

/// One message, as far as the spike needs it: the headers it was asked about, the readable
/// text, and the names of whatever was hanging off it.
///
/// Note what is *not* here — the raw source. Matterbee stores facts and a pointer to the
/// original, never a copy of the mailbox, and the spike keeps that promise from the first
/// commit so the shape of the thing cannot quietly drift later.
public struct Email: Equatable, Sendable {
    /// Where the original lives. For the spike that is a file; later it will be a message ID
    /// in an account.
    public var source: URL
    /// `Message-ID` when the mail has one, otherwise a hash of the file, so every record in the
    /// log can be traced to exactly one message and re-runs give the same identifier.
    public var id: String
    /// Every header, unfolded, names lowercased, encoded words decoded. A header that appears
    /// more than once (`Received`, `List-Unsubscribe`) keeps all its values.
    public var headers: [String: [String]]
    public var subject: String
    public var from: String
    public var to: [String]
    public var cc: [String]
    public var date: Date?
    /// The body as prose: the `text/plain` part when there is one, otherwise the HTML part with
    /// its tags taken out. This is the only text that is ever looked at for entities, which is
    /// why an HTML-only mail must not silently come through as an empty string.
    public var body: String
    public var attachments: [Attachment]
    /// Every web link in the mail, with its words and where it sits. Kept beside the body, never
    /// in it: what goes to the model is the body, and it must stay as it was.
    public var links: [Link] = []

    public struct Link: Equatable, Codable, Sendable {
        public enum Place: String, Codable, Sendable {
            /// What the sender wrote.
            case body
            /// Under "-- ", or in the signature block a mail client marks as one.
            case signature
            /// An earlier mail quoted below the new one.
            case quote
        }
        public var address: String
        /// The words that were the link, when it had any: "Kostenaufstellung", "hier".
        public var text: String
        public var place: Place
    }

    public struct Attachment: Equatable, Codable, Sendable {
        public var filename: String
        public var contentType: String
        /// Bytes after decoding, as a number. The file itself is not kept.
        public var byteCount: Int
    }

    public func header(_ name: String) -> String? { headers[name.lowercased()]?.first }
    public func allHeaders(_ name: String) -> [String] { headers[name.lowercased()] ?? [] }
    public func hasHeader(_ name: String) -> Bool { headers[name.lowercased()] != nil }

    /// Just the address out of `Hausverwaltung Berger <post@berger-hv.example>`.
    public var fromAddress: String { Email.address(in: from) }
    public var fromDomain: String { String(fromAddress.split(separator: "@").last ?? "") }

    public static func address(in field: String) -> String {
        if let open = field.lastIndex(of: "<"), let close = field[open...].firstIndex(of: ">") {
            return String(field[field.index(after: open)..<close]).trimmed.lowercased()
        }
        return field.trimmed.lowercased()
    }

    /// The display name, when the sender gave one. `Hausverwaltung Berger` — a party's name
    /// arrives in the envelope as often as in the prose.
    public static func displayName(in field: String) -> String? {
        guard let open = field.lastIndex(of: "<") else { return nil }
        var name = String(field[field.startIndex..<open]).trimmed
        if name.hasPrefix("\""), name.hasSuffix("\""), name.count >= 2 { name = String(name.dropFirst().dropLast()) }
        return name.isEmpty ? nil : name
    }

    static func fingerprint(_ data: Data) -> String {
        "sha256:" + SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}

extension Email {
    /// A mail known only by what an earlier run recorded about it — enough to remember its
    /// thread by, without reading it again.
    init(standingIn judgement: Judgement) {
        self.init(source: URL(string: judgement.source) ?? URL(fileURLWithPath: judgement.source), id: judgement.emailID,
                  headers: ["from": [judgement.from], "subject": [judgement.subject]], subject: judgement.subject,
                  from: judgement.from, to: [], cc: [], date: judgement.date, body: "", attachments: [])
    }
}
