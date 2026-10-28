import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// One mail read by Apple's model on the device — the Normal mode's way: nothing leaves it, no
/// key, nothing paid. The model holds about 4,000 tokens in all, so it gets a short instruction,
/// the matters as a list of names, and the newest part of the mail; it answers by filling fields
/// rather than writing, which small models do far more reliably.
public enum DeviceReader {
    /// What the record says read a mail.
    public static let modelID = "apple-on-device"
    public static let version = "device-1"

    public struct Unavailable: LocalizedError {
        public init() {}
        public var errorDescription: String? {
            "Apple Intelligence is not available on this device. Turn it on in Settings, or add a key or Causabee Pro."
        }
    }

    public struct Read: Sendable {
        public var matter: String?
        public var isNew: Bool
        public var todos: [(text: String, owner: String, due: String?)]
        public var appointments: [(what: String, date: String, time: String?, quote: String)]
        public var deadlines: [(what: String, date: String, quote: String)]
        public var digest: String
        public var seconds: Double
    }

    public static var isAvailable: Bool {
        #if canImport(FoundationModels)
        guard #available(iOS 26, macOS 26, *) else { return false }
        return SystemLanguageModel.default.isAvailable
        #else
        return false
        #endif
    }

    static let instructions = """
    You read one email from a private person's mailbox — "the owner" — and note what is in it, \
    in the email's own language. Never translate.

    matter: a matter is something that runs over weeks, with people and open steps — a job \
    application, a move, care for a parent, a claim, a trip. Use one of the listed matter names \
    exactly when the email belongs to it. If it starts a new matter of its own, give a short new \
    name and set isNew. Most email — newsletters, receipts, codes, invitations — belongs to no \
    matter: then write "none".

    asksSomething: first decide whether the email actually asks the owner to do something, or \
    names something the owner is waiting for. Most emails do not — a thank-you, a confirmation, \
    information, a reply that settles things. Then todos stays empty.

    todos: only when asksSomething is true, at most two, each something the email itself asks — \
    never a general "check everything" or "read the email". Short, starting with what to do. \
    Never a to-do to attend, join or prepare for a meeting — the appointment is enough. due only \
    when the email gives a date for it.

    dates: the dates found in the email are listed with ids (D1, D2 …). Pick the ones that \
    matter, each with its id: an appointment — a meeting, call, visit, arrival or departure that \
    is settled (agreed, booked, invited to; never a time only proposed) — or a deadline, a date \
    by which something has to happen. Name what happens then, with who or where, in the email's \
    language and from the email's own words — never just "meeting" or "a date". Leave out dates \
    that only say when something was sent or happened, and times only proposed or asked about.

    digest: two short sentences on what this email says, with the details someone would look up \
    later — amounts, dates, what was agreed.
    """

    /// The mail, cut to what fits: the newest message first, at most this many characters.
    static let mostCharacters = 7_000

    /// `matters`: each matter's name with a few words on what it is about. `thread`: the matter the
    /// thread is in already — decided by rule before the model is asked.
    public static func read(mail: String, sent: Date?, owner: [String], matters: [String], thread: String? = nil) async throws -> Read? {
        #if canImport(FoundationModels)
        guard #available(iOS 26, macOS 26, *), isAvailable else { return nil }
        let start = Date()
        var prompt: [String] = []
        if !owner.isEmpty { prompt.append("The owner appears as: \(owner.joined(separator: ", ")).") }
        if let sent {
            let format = DateFormatter()
            format.locale = Locale(identifier: "en_US_POSIX")
            format.dateFormat = "yyyy-MM-dd (EEEE)"
            prompt.append("The email was sent on \(format.string(from: sent)).")
        }
        prompt.append(matters.isEmpty ? "No matters yet." : "Matters:\n" + matters.map { "- \($0)" }.joined(separator: "\n"))
        let found = DateFinder.dates(in: String(mail.prefix(mostCharacters)), sent: sent)
        prompt.append(found.isEmpty ? "Dates found in the email: none." : "Dates found in the email:\n"
                      + found.enumerated().map { "D\($0.offset + 1): \($0.element.day)\($0.element.time.map { " " + $0 } ?? "") — “\($0.element.quote)”" }.joined(separator: "\n"))
        if let thread { prompt.append("This email is a reply in a thread that belongs to the matter `\(thread)`.") }
        prompt.append("<email>\n\(String(mail.prefix(mostCharacters)))\n</email>")
        let session = LanguageModelSession(instructions: instructions)
        let answer = try await session.respond(to: prompt.joined(separator: "\n\n"), generating: DeviceFound.self,
                                               options: GenerationOptions(sampling: .greedy)).content
        func clean(_ text: String) -> String? {
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty || t.lowercased() == "none" || t.lowercased() == "null" ? nil : t
        }
        return Read(matter: thread ?? clean(answer.matter), isNew: thread == nil && answer.isNew,
                    todos: (answer.asksSomething ? answer.todos : []).prefix(2).map { ($0.text, $0.owner, clean($0.due)) },
                    appointments: picked(answer.dates, "appointment", from: found).map { ($0.what, $0.date.day, $0.date.time, $0.date.quote) },
                    deadlines: picked(answer.dates, "deadline", from: found).map { ($0.what, $0.date.day, $0.date.quote) },
                    digest: answer.digest, seconds: Date().timeIntervalSince(start))
        #else
        return nil
        #endif
    }

    #if canImport(FoundationModels)
    /// The dates the model picked, by their ids, each once: a date it made up has no id.
    @available(iOS 26, macOS 26, *)
    static func picked(_ picks: [DevicePick], _ kind: String, from found: [DateFinder.Found]) -> [(what: String, date: DateFinder.Found)] {
        var seen = Set<Int>()
        return picks.compactMap { pick in
            guard pick.kind == kind, let number = Int(pick.id.drop { !$0.isNumber }), found.indices.contains(number - 1),
                  seen.insert(number).inserted else { return nil }
            return (pick.what, found[number - 1])
        }
    }
    #endif
}

#if canImport(FoundationModels)
@available(iOS 26, macOS 26, *)
@Generable
struct DeviceFound {
    @Guide(description: "One of the listed matter names exactly, a short new name, or none")
    var matter: String
    @Guide(description: "True only when the email starts a new matter not in the list")
    var isNew: Bool
    @Guide(description: "Does the email ask the owner to do something, or name something the owner waits for? Most do not.")
    var asksSomething: Bool
    @Guide(description: "At most two things to do", .maximumCount(2))
    var todos: [DeviceTodo]
    @Guide(description: "Dates from the list that matter: settled appointments and deadlines", .maximumCount(4))
    var dates: [DevicePick]
    @Guide(description: "Two short sentences in the email's language")
    var digest: String
}

@available(iOS 26, macOS 26, *)
@Generable
struct DeviceTodo {
    var text: String
    @Guide(description: "me: the owner does it; we: together with others; other: the owner waits for someone else", .anyOf(["me", "we", "other"]))
    var owner: String
    @Guide(description: "YYYY-MM-DD, or empty when the email gives no date for it")
    var due: String
}

@available(iOS 26, macOS 26, *)
@Generable
struct DevicePick {
    @Guide(description: "The id of the date in the list, such as D1")
    var id: String
    @Guide(.anyOf(["appointment", "deadline"]))
    var kind: String
    @Guide(description: "What it is, in a few words, in the email's language")
    var what: String
}

@available(iOS 26, macOS 26, *)
@Generable
struct DeviceDate {
    var what: String
    @Guide(description: "YYYY-MM-DD")
    var date: String
    @Guide(description: "HH:MM, or empty")
    var time: String
}

@available(iOS 26, macOS 26, *)
@Generable
struct DeviceDeadline {
    var what: String
    @Guide(description: "YYYY-MM-DD")
    var date: String
}
#endif
