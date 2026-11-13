import Foundation

/// What the owner sees of an item that found no matter, before deciding where it goes: what the
/// bee already read in it — nothing is read or sent again to show it.
public struct UnplacedLook: Sendable {
    public enum Kind: String, Sendable { case task, appointment, deadline, person }

    public struct Line: Sendable, Identifiable {
        public let kind: Kind
        public let text: String
        public var id: String { kind.rawValue + text }
        public var symbol: String {
            switch kind {
            case .task: "checkmark.circle"
            case .appointment: "calendar"
            case .deadline: "flag"
            case .person: "person"
            }
        }
    }

    public let title: String
    public let from: String
    public let date: Date?
    public let about: String?
    public let found: [Line]
    /// Why the bee put it in no matter, in her words. Nil when she said nothing worth showing.
    public let why: String?

    public init(_ judgement: Judgement) {
        title = judgement.subject.isEmpty ? String(localized: "(no subject)", bundle: .module) : judgement.subject
        from = Self.name(judgement.from)
        date = judgement.date
        about = judgement.digest.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        var found: [Line] = []
        for todo in judgement.todos {
            found.append(Line(kind: .task, text: [todo.text, todo.due.flatMap(Self.day).map { "by \($0)" }].compactMap { $0 }.joined(separator: " · ")))
        }
        for item in judgement.appointments {
            let when = [Self.day(item.date), item.time].compactMap { $0 }.joined(separator: " ")
            found.append(Line(kind: .appointment, text: [item.what, when, item.place].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · ")))
        }
        for item in judgement.deadlines {
            found.append(Line(kind: .deadline, text: [item.what, Self.day(item.date)].compactMap { $0 }.joined(separator: " · ")))
        }
        for party in judgement.parties where !party.name.isEmpty {
            found.append(Line(kind: .person, text: party.role.isEmpty ? party.name : "\(party.name) · \(party.role)"))
        }
        self.found = found
        let reason = judgement.matterReason.trimmingCharacters(in: .whitespacesAndNewlines)
        // Her working notes say nothing to the owner.
        let plain = ["", "Yours to place", "Read on this device"]
        why = plain.contains(reason) || reason.hasPrefix("not sent:") ? nil : reason
    }

    /// "Anna Berg <anna@x.org>" → "Anna Berg"; an address alone stays.
    static func name(_ from: String) -> String {
        let before = from.range(of: "<").map { String(from[..<$0.lowerBound]) } ?? ""
        let name = before.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return name.isEmpty ? from.trimmingCharacters(in: CharacterSet(charactersIn: "<> ")) : name
    }

    /// `YYYY-MM-DD` as the owner reads a day; the string itself when it is no day.
    static func day(_ text: String) -> String? {
        guard !text.isEmpty else { return nil }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: String(text.prefix(10))) else { return text }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}
