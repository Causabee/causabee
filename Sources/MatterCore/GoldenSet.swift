import Foundation

/// What a person says is in a mail, written down before any machine has had an opinion about
/// it.
///
/// This is the thing the spike is measured against, so it is worth being blunt about what it
/// is *not*: it is not the pipeline's output corrected. The template is filled in with the
/// headers only — who wrote, when, about what — and every column that takes judgement is left
/// empty. A golden set pre-filled with the filter's own answers measures nothing, because
/// agreeing with it is the path of least effort and the numbers come out flattering.
public struct Label: Equatable, Sendable {
    /// The file name, which is how a row and a mail find each other. Message-IDs are long and
    /// easy to break in a spreadsheet; file names are visible in Finder.
    public var file: String
    public var emailID: String
    public var date: String
    public var from: String
    public var subject: String

    /// Empty until somebody says. The count of these is how far the labelling has got.
    public var isBulk: Bool?
    /// In a thread set: whether this is the mail the owner would put the Causabee label on. The
    /// replies below it are `no` — they are meant to follow by thread, and whether they do is
    /// one of the things the set measures.
    public var tapped: Bool? = nil
    /// A short name you make up, the same spelling every time: `hausverwaltung`. Empty means
    /// this mail belongs to no matter.
    public var matter: String?
    public var parties: [Party]
    public var todos: [Todo]
    public var deadlines: [Deadline]
    public var notes: String
    /// Marked in an optional `suggest` column as one of the rows to label. Most of an export is
    /// meant to stay blank; this says which rows are not, so progress can be counted against them.
    public var isSuggested: Bool

    public struct Party: Equatable, Sendable {
        public var name: String
        /// What they are to the matter: `Hausverwaltung`, `Anbieter`, `Nachbar`. Free text.
        public var role: String
    }

    public struct Todo: Equatable, Sendable {
        public var text: String
        public var owner: Judgement.Todo.Owner
        /// `YYYY-MM-DD`, or nil.
        public var due: String?
    }

    public struct Deadline: Equatable, Sendable {
        public var what: String
        public var date: String
    }

    public var isLabelled: Bool { isBulk != nil || tapped != nil }

    public init(file: String, emailID: String = "", date: String = "", from: String = "",
                subject: String = "", isBulk: Bool? = nil, matter: String? = nil,
                parties: [Party] = [], todos: [Todo] = [], deadlines: [Deadline] = [],
                notes: String = "", isSuggested: Bool = false) {
        self.file = file
        self.emailID = emailID
        self.date = date
        self.from = from
        self.subject = subject
        self.isBulk = isBulk
        self.matter = matter
        self.parties = parties
        self.todos = todos
        self.deadlines = deadlines
        self.notes = notes
        self.isSuggested = isSuggested
    }
}

/// Reading and writing `labels.csv`.
///
/// The format has to survive being edited in Numbers by a person who is on their fortieth mail
/// and would rather be doing something else, so: one row per mail, several values in a cell
/// separated by `|`, and both `->` and `→` accepted for a date because only one of them is on
/// the keyboard.
public enum GoldenSet {
    public static let columns = ["file", "email_id", "date", "from", "subject",
                                 "is_bulk", "matter", "parties", "todos", "deadlines", "notes"]

    /// Two kinds of golden set, for the two editions. The inbox set is a slice of a whole mailbox,
    /// noise included, and asks first whether a mail is bulk. The thread set is what the manual
    /// edition would be sent — whole matter threads, the owner's own replies in them — and asks
    /// instead which mail would carry the label.
    public enum Kind: Sendable { case inbox, threads }

    public static func columns(_ kind: Kind) -> [String] {
        switch kind {
        case .inbox: columns
        case .threads: ["file", "email_id", "date", "from", "subject",
                        "tapped", "matter", "todos", "parties", "deadlines", "notes"]
        }
    }

    // MARK: Writing

    /// A template with the facts filled in and every judgement left blank. A thread set comes out
    /// thread by thread, oldest first within each, so a thread is labelled from top to bottom.
    public static func template(for emails: [Email], kind: Kind = .inbox) -> String {
        let columns = columns(kind)
        var lines = [CSV.line(columns)]
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"

        let ordered = kind == .threads ? threadOrder(emails) : emails
        for email in ordered {
            lines.append(CSV.line([
                email.source.lastPathComponent,
                email.id,
                email.date.map(day.string(from:)) ?? "",
                email.from,
                email.subject,
            ] + Array(repeating: "", count: columns.count - 5)))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Mails grouped by thread — the first `References` entry is the thread's first mail; without
    /// one, the subject with its `Re:` taken off — threads ordered by when they started.
    static func threadOrder(_ emails: [Email]) -> [Email] {
        func root(_ email: Email) -> String {
            ThreadMemory.parents(of: email).first ?? ThreadMemory.subjectKey(email.subject) ?? email.id
        }
        var byID: [String: String] = [:]  // message id → thread root, so a first mail joins its replies
        for email in emails { byID[email.id] = root(email) }
        func thread(_ email: Email) -> String { byID[root(email)] ?? root(email) }
        let started = Dictionary(grouping: emails, by: thread).mapValues { $0.compactMap(\.date).min() ?? .distantPast }
        return emails.sorted {
            let (a, b) = (thread($0), thread($1))
            if a != b { return (started[a] ?? .distantPast, a) < (started[b] ?? .distantPast, b) }
            return ($0.date ?? .distantPast) < ($1.date ?? .distantPast)
        }
    }

    public static func csv(_ labels: [Label]) -> String {
        var lines = [CSV.line(columns)]
        for label in labels {
            lines.append(CSV.line([
                label.file, label.emailID, label.date, label.from, label.subject,
                label.isBulk.map { $0 ? "yes" : "no" } ?? "",
                label.matter ?? "",
                label.parties.map { $0.role.isEmpty ? $0.name : "\($0.name) (\($0.role))" }
                    .joined(separator: " | "),
                label.todos.map {
                    var text = $0.text
                    if $0.owner != .unknown { text += " (\($0.owner.rawValue))" }
                    if let due = $0.due { text += " -> \(due)" }
                    return text
                }.joined(separator: " | "),
                label.deadlines.map { "\($0.what) -> \($0.date)" }.joined(separator: " | "),
                label.notes,
            ]))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: Reading

    public struct Complaint: Equatable, Sendable {
        public var row: Int
        public var file: String
        public var text: String
    }

    public struct Reading: Sendable {
        public var labels: [Label] = []
        public var complaints: [Complaint] = []
        public var kind: Kind = .inbox
    }

    public static func read(_ text: String) -> Reading {
        var reading = Reading()
        var rows = CSV.rows(text)
        guard !rows.isEmpty else {
            reading.complaints.append(.init(row: 0, file: "", text: "the file is empty"))
            return reading
        }

        let header = rows.removeFirst().map { $0.trimmed.lowercased() }
        reading.kind = header.contains("tapped") ? .threads : .inbox
        let judgement = reading.kind == .threads ? "tapped" : "is_bulk"
        for column in ["file", judgement] where !header.contains(column) {
            reading.complaints.append(.init(row: 1, file: "", text: "no `\(column)` column"))
        }
        func value(_ row: [String], _ column: String) -> String {
            guard let index = header.firstIndex(of: column), index < row.count else { return "" }
            return row[index].trimmed
        }

        for (offset, row) in rows.enumerated() {
            let number = offset + 2  // the header is row 1, as a spreadsheet counts
            let file = value(row, "file")
            guard !file.isEmpty else {
                reading.complaints.append(.init(row: number, file: "", text: "no file name"))
                continue
            }

            var label = Label(file: file,
                              emailID: value(row, "email_id"),
                              date: value(row, "date"),
                              from: value(row, "from"),
                              subject: value(row, "subject"),
                              notes: value(row, "notes"),
                              isSuggested: !value(row, "suggest").isEmpty)

            let bulk = value(row, "is_bulk").lowercased()
            switch bulk {
            case "": label.isBulk = nil
            case "yes", "y", "ja", "true", "1", "bulk": label.isBulk = true
            case "no", "n", "nein", "false", "0": label.isBulk = false
            default:
                reading.complaints.append(.init(row: number, file: file,
                                                text: "is_bulk says `\(bulk)`; write yes or no"))
            }

            let tapped = value(row, "tapped").lowercased()
            switch tapped {
            case "": label.tapped = nil
            case "yes", "y", "ja", "true", "1": label.tapped = true
            case "no", "n", "nein", "false", "0": label.tapped = false
            default:
                reading.complaints.append(.init(row: number, file: file,
                                                text: "tapped says `\(tapped)`; write yes or no"))
            }

            let matter = value(row, "matter")
            label.matter = matter.isEmpty ? nil : matter.lowercased()
            let partyCell = value(row, "parties")
            label.parties = parties(partyCell)
            // `Gerd Achter, Zirkel AG` reads as one party. A comma is legitimate inside a name
            // written surname first, but that is rare enough that it is worth a second look —
            // and it is always fine inside the brackets, where a role names its organisation:
            // `Karin Rasch (Schadenstelle N3, Wabenversicherung)`.
            let outsideBrackets = partyCell.replacing(/\([^)]*\)/, with: "")
            if outsideBrackets.contains(","), !partyCell.contains("|") {
                reading.complaints.append(.init(row: number, file: file, text:
                    "parties `\(partyCell)` has a comma but no |: write several as `Name (role) | Name (role)`"))
            }
            label.todos = todos(value(row, "todos"))
            label.deadlines = deadlines(value(row, "deadlines"))

            for date in label.todos.compactMap(\.due) + label.deadlines.map(\.date)
            where !isADay(date) {
                reading.complaints.append(.init(row: number, file: file,
                                                text: "`\(date)` is not a date; write 2025-10-15"))
            }
            reading.labels.append(label)
        }
        return reading
    }

    static func pieces(_ cell: String) -> [String] {
        cell.split(separator: "|").map { $0.trimmed }.filter { !$0.isEmpty }
    }

    static func parties(_ cell: String) -> [Label.Party] {
        pieces(cell).map { piece in
            guard let open = piece.lastIndex(of: "("), piece.hasSuffix(")") else {
                return Label.Party(name: piece, role: "")
            }
            let role = piece[piece.index(after: open)..<piece.index(before: piece.endIndex)]
            return Label.Party(name: String(piece[piece.startIndex..<open]).trimmed, role: role.trimmed)
        }
    }

    static func todos(_ cell: String) -> [Label.Todo] {
        pieces(cell).map { piece in
            var (text, due) = splitDate(piece)
            var owner = Judgement.Todo.Owner.unknown
            for candidate in Judgement.Todo.Owner.allCases where text.lowercased().hasSuffix("(\(candidate.rawValue))") {
                owner = candidate
                text = String(text.dropLast(candidate.rawValue.count + 2)).trimmed
            }
            return Label.Todo(text: text, owner: owner, due: due)
        }
    }

    static func deadlines(_ cell: String) -> [Label.Deadline] {
        pieces(cell).map { piece in
            let (what, date) = splitDate(piece)
            return Label.Deadline(what: what, date: date ?? "")
        }
    }

    /// `Sonderumlage überweisen -> 2025-11-30`, with either arrow.
    static func splitDate(_ piece: String) -> (String, String?) {
        for arrow in ["->", "→", "=>"] {
            guard let range = piece.range(of: arrow, options: .backwards) else { continue }
            return (String(piece[piece.startIndex..<range.lowerBound]).trimmed,
                    String(piece[range.upperBound...]).trimmed)
        }
        return (piece, nil)
    }

    static func isADay(_ text: String) -> Bool {
        guard text.count == 10 else { return false }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: text) != nil
    }
}

extension Judgement.Todo.Owner: CaseIterable {
    public static var allCases: [Judgement.Todo.Owner] { [.me, .we, .other, .unknown] }
}
