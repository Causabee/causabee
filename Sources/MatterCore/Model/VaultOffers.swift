import Foundation
import SwiftData

/// What a photographed letter, a scan or a screenshot offers the matter's vault besides its tasks:
/// who wrote, with how to reach them, and the numbers it is filed under. Found on the device, in
/// the words as they were read — nothing of it is sent, and nothing goes in without the owner's tick.
public struct VaultOffers: Sendable, Equatable {
    public struct Contact: Sendable, Equatable {
        public var name: String
        public var address: String
        public var phone: String
        /// "HKK · reha@hkk.de · 0421 36550"
        public var line: String { [name, address, phone].filter { !$0.isEmpty }.joined(separator: " · ") }
    }
    public struct Detail: Sendable, Equatable {
        public var label: String
        public var value: String
    }

    public var contact: Contact?
    public var details: [Detail] = []
    public var isEmpty: Bool { contact == nil && details.isEmpty }

    /// Each offer under the key its tick goes by — "c" for the contact, "v0", "v1" for the details.
    public var lines: [(id: String, text: String)] {
        (contact.map { [("c", "Contact: " + $0.line)] } ?? []) + details.enumerated().map { ("v\($0.offset)", "\($0.element.label): \($0.element.value)") }
    }
    /// Only what the owner left ticked.
    public func keeping(_ keep: (String) -> Bool) -> VaultOffers {
        VaultOffers(contact: keep("c") ? contact : nil, details: details.enumerated().filter { keep("v\($0.offset)") }.map(\.element))
    }

    /// A number with the word that says what it is in front of it. The label is kept as written.
    static let labelled = try! NSRegularExpression(pattern:
        #"((?i:\b(?:versicherten|versicherungs|kunden|vorgangs?|vertrags|mitglieds|rechnungs|policen|referenz|buchungs|auftrags|schadens?|fall|patienten|akten|steuer|mandanten|bestell|antrags|kassen|renten(?:versicherungs)?|personal)[\- ]?(?:nummer|nr\.?|zeichen)|\b(?:unser|ihr|geschäfts)[\- ]?zeichen|\baz\.|\biban|\bsteuer[\- ]?id|\bust[\-. ]?id[\-. ]?nr\.?|\b(?:customer|policy|case|invoice|member(?:ship)?|reference|claim|account)[ ](?:number|no\.?)))\s*[:#.]?\s*((?:[A-Z0-9][A-Z0-9./\-]*)(?:[ ][A-Z0-9][A-Z0-9./\-]*(?![a-zäöüß]))*)(?<=[A-Z0-9])"#)

    /// Addresses anyone can have: the part before the @ says nothing about who wrote.
    static let freeMail: Set<String> = ["gmail", "googlemail", "gmx", "web", "t-online", "icloud", "me", "mac", "outlook", "hotmail",
                                        "yahoo", "posteo", "mailbox", "freenet", "aol", "live", "proton", "protonmail"]

    public init(contact: Contact? = nil, details: [Detail] = []) {
        self.contact = contact
        self.details = details
    }

    /// - Parameter own: the owner's own addresses and names, never offered as a contact.
    public init(text: String, own: [String] = []) {
        let whole = NSRange(text.startIndex..., in: text)
        func all(_ kind: Entity.Kind) -> [(text: String, at: Int)] {
            EntityDetector.compiled.filter { $0.pattern.kind == kind }.flatMap { pattern, regex in
                regex.matches(in: text, range: whole).compactMap { match -> (String, Int)? in
                    let span = match.range(at: pattern.group)
                    guard span.location != NSNotFound, let range = Range(span, in: text) else { return nil }
                    let hit = String(text[range])
                    if pattern.minimumDigits > 0, hit.filter(\.isNumber).count < pattern.minimumDigits { return nil }
                    return (hit, span.location)
                }
            }.sorted { $0.1 < $1.1 }
        }
        let mine = Set(own.map { $0.lowercased() })

        var seen: Set<String> = []
        for match in Self.labelled.matches(in: text, range: whole) {
            guard let labelRange = Range(match.range(at: 1), in: text), let valueRange = Range(match.range(at: 2), in: text) else { continue }
            let value = String(text[valueRange]).trimmingCharacters(in: .whitespaces)
            var label = String(text[labelRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard value.filter(\.isNumber).count >= 4, seen.insert(value.filter { !$0.isWhitespace }.lowercased()).inserted else { continue }
            if label == label.lowercased() || label == label.uppercased(), label.count > 4 { label = label.prefix(1).uppercased() + label.dropFirst().lowercased() }
            details.append(Detail(label: label, value: value))
            if details.count == 6 { break }
        }

        // Who wrote: the first address that is not the owner's, and a phone number that is no fax.
        let ns = text as NSString
        let address = all(.email).map(\.text).first { !mine.contains($0.lowercased()) } ?? ""
        let phone = all(.phone).first { hit in
            let before = ns.substring(with: NSRange(location: max(0, hit.at - 14), length: min(14, hit.at))).lowercased()
            return !before.contains("fax") && !details.contains { $0.value.contains(hit.text) }
        }?.text ?? ""
        guard !address.isEmpty || !phone.isEmpty else { return }
        var name = all(.organization).map(\.text).first { !mine.contains($0.lowercased()) } ?? ""
        if name.isEmpty, let host = address.split(separator: "@").last {
            let parts = host.split(separator: ".")
            if parts.count >= 2 {
                let word = String(parts[parts.count - 2])
                if !Self.freeMail.contains(word.lowercased()) {
                    name = word.count <= 4 ? word.uppercased() : word.prefix(1).uppercased() + word.dropFirst()
                }
            }
        }
        guard !name.isEmpty else { return }
        contact = Contact(name: name.trimmingCharacters(in: .whitespaces), address: address, phone: phone)
    }
}

extension ScreenshotDoor.Look {
    /// What its words offer the vault. Read from the words on the device, not from an answer.
    public func offers(own: [String] = []) -> VaultOffers {
        guard let email = report.outcomes.first?.email else { return VaultOffers() }
        // A saved mail's sender is a party already; its numbers are still worth keeping.
        var offers = VaultOffers(text: email.body, own: own)
        if kind == .mail { offers.contact = nil }
        return offers
    }
}

extension Matter {
    /// Takes in what the owner left ticked: the contact, and each detail not kept here already.
    public func take(_ offers: VaultOffers, role: String = "", in context: ModelContext) {
        let party = offers.contact.flatMap { addContact(name: $0.name, role: role, address: $0.address, phone: $0.phone, in: context) }
        let kept = Set((details ?? []).map { $0.value.filter { !$0.isWhitespace }.lowercased() })
        for detail in offers.details where !kept.contains(detail.value.filter { !$0.isWhitespace }.lowercased()) {
            addDetail(label: detail.label, value: detail.value, of: party, in: context)
        }
    }
}
