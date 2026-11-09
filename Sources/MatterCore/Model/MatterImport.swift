import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Turns what the pipeline concluded about each mail into matters: an entry per mail, one to-do
/// per thing to do however often it is asked for, appointments, deadlines and the people involved.
///
/// Importing is safe to repeat. A mail already in the store adds nothing, and a to-do is found
/// again by where it first came from — the mail and its words — rather than by the pipeline's
/// `T3`, which only means something inside one run. What the owner changed stays changed: a
/// renamed or merged matter still receives its mail through its aliases, and a to-do the owner
/// reopened is not closed again by a mail it has already seen.
public enum MatterImport {
    public struct Summary: Sendable, Equatable {
        public var mattersNew = 0
        public var mails = 0
        public var mailsAlreadyThere = 0
        public var notImported = 0
        public var todosNew = 0
        public var todosAgain = 0
        public var todosDone = 0
        public var appointments = 0
        public var deadlines = 0
        public var parties = 0
        public var documents = 0
        /// Files added by hand that their matter had already: not taken in.
        public var filesAlreadyThere = 0
        /// Mails that would have started a matter the plan has no room for: not taken in — they
        /// wait among the mail without a matter.
        public var held: [String] = []
    }

    /// `owner` is the names the owner goes by; they are never made a party.
    /// The dropped file itself as a document of its matter, read already since it was taken in; nil
    /// when the matter has it.
    static func ownFile(_ file: URL, source: Source, known: Set<String>) -> Document? {
        let name = Document.ownName(of: file)
        guard !known.contains((source.messageID ?? "") + "/" + name) else { return nil }
        let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let type = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        let document = Document(name: name, contentType: type, byteCount: size, source: source)
        document.readAt = Date()
        return document
    }

    /// Files taken in before they were kept as files of their matter: each one still on this Mac
    /// becomes one. Run once when Causabee starts; returns how many it added.
    @discardableResult
    public static func addDroppedFiles(to context: ModelContext) throws -> Int {
        var added = 0
        for matter in try context.fetch(FetchDescriptor<Matter>()) {
            var known = Set((matter.documents ?? []).map { $0.messageID + "/" + $0.name })
            for entry in matter.entries ?? [] where [.screenshot, .document].contains(entry.source.kind) {
                guard let file = entry.source.fileURL, let document = ownFile(file, source: entry.source, known: known) else { continue }
                context.insert(document)
                document.matter = matter
                known.insert(document.messageID + "/" + document.name)
                added += 1
            }
        }
        if added > 0 { try context.save() }
        return added
    }

    /// `room`: how many new matters may start — nil for no limit (`Plan.room`).
    public static func apply(_ judgements: [Judgement], to context: ModelContext, owner: [String] = [], room: Int? = nil) throws -> Summary {
        var summary = Summary()
        var room = room
        var matters = try context.fetch(FetchDescriptor<Matter>())
        let partiesBefore = try context.fetchCount(FetchDescriptor<Party>())
        var book = try PartyBook(context: context, owner: OwnerNames(owner))
        // Every word of every full name in each matter, the owner's left out: a bare `Kramer` is
        // the owner only where no one else is called Kramer.
        var fullNames: [String: Set<String>] = [:]
        for judgement in judgements {
            guard let key = judgement.matter else { continue }
            for party in judgement.parties {
                let tokens = PartyNames.tokens(party.name)
                guard tokens.count > 1, !book.owner.isOwner(party.name, others: []) else { continue }
                fullNames[key, default: []].formUnion(tokens)
            }
        }
        var seen = Set(try context.fetch(FetchDescriptor<Entry>()).map(\.messageID))
        var byOrigin = Dictionary(try context.fetch(FetchDescriptor<Todo>()).map { ($0.origin, $0) }, uniquingKeysWith: { a, _ in a })
        // The run's own ids, `T3`, to the to-do each became. Filled from every mail of the log,
        // old ones too, because a new mail may repeat a to-do an old one raised.
        var byRunID: [String: Todo] = [:]

        let ordered = judgements.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        for judgement in ordered {
            guard !judgement.isBulk, let key = judgement.matter, judgement.decidedBy == .claude || judgement.decidedBy == .onDevice else {
                summary.notImported += 1
                continue
            }
            let isNew = !seen.contains(judgement.emailID)
            let matter: Matter
            if let known = matters.first(where: { $0.answers(to: key) }) {
                matter = known
            } else {
                guard isNew else { continue }
                // No room for one more: the mail waits without a matter, read and kept.
                if let left = room {
                    guard left > 0 else { summary.held.append(judgement.emailID); continue }
                    room = left - 1
                }
                // Shown by the name the model wrote for people, kept by the key it files mail under.
                matter = Matter(key: key, name: judgement.matterTitle ?? Matter.readable(key))
                context.insert(matter)
                matters.append(matter)
                summary.mattersNew += 1
            }
            let kind: Source.Kind = judgement.emailID.hasPrefix("screenshot:") ? .screenshot
                : judgement.emailID.hasPrefix("document:") ? .document : .mail
            let source = Source(kind: kind, pointer: judgement.source, messageID: judgement.emailID, date: judgement.date)
            // A file added by hand that the matter has already, to the byte — from a mail, or from
            // its own folder, where it stands with its day in front: not taken in a second time.
            if isNew, [.screenshot, .document].contains(kind), let file = source.fileURL,
               let bytes = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
               Twins.has(Document.ownName(of: file), bytes: bytes, in: matter) {
                summary.filesAlreadyThere += 1
                continue
            }

            for found in judgement.todos {
                if let id = found.id, let todo = byRunID[id], found.sameAs != nil {
                    if isNew { todo.sources.append(source.quoting(found.sourceQuote)); summary.todosAgain += 1 }
                    continue
                }
                let origin = judgement.emailID + "#" + Self.key(found.text)
                var todo = byOrigin[origin]
                if todo == nil, isNew {
                    let new = Todo(text: found.text, owner: Todo.Owner(rawValue: found.owner.rawValue) ?? .unknown,
                                   due: found.due, source: source.quoting(found.sourceQuote), origin: origin)
                    new.matter = matter
                    context.insert(new)
                    byOrigin[origin] = new
                    todo = new
                    summary.todosNew += 1
                }
                if let id = found.id, let todo { byRunID[id] = todo }
            }

            // What was attached, as files of the matter — for mail imported before files were kept too.
            let files = Set((matter.documents ?? []).map { $0.messageID + "/" + $0.name })
            for attachment in judgement.attachments where !files.contains(judgement.emailID + "/" + attachment.filename) {
                let document = Document(name: attachment.filename, contentType: attachment.contentType,
                                        byteCount: attachment.byteCount, source: source)
                context.insert(document)
                document.matter = matter
                Twins.putAway(handAddedTwinsOf: document, in: matter)
                summary.documents += 1
            }
            // A file the owner dropped in — a scanned letter, a PDF, a screenshot — is a file of the
            // matter too, not only what it says.
            if [.screenshot, .document].contains(kind), let file = source.fileURL,
               let document = ownFile(file, source: source, known: files) {
                context.insert(document)
                document.matter = matter
                summary.documents += 1
            }

            guard isNew else { summary.mailsAlreadyThere += 1; continue }
            seen.insert(judgement.emailID)
            summary.mails += 1

            let entry = Entry(title: judgement.subject, from: judgement.from, date: judgement.date, source: source)
            entry.digest = judgement.digest
            entry.replyTo = judgement.replyTo
            entry.matter = matter
            context.insert(entry)

            for done in judgement.done {
                // Someone else's, shown done by what came in, is ticked off. The owner's own — theirs,
                // shared — changes only with their tap: the brief proposes it (manifesto 5).
                guard let todo = byRunID[done.todo], !todo.isDone, todo.owner == .other else { continue }
                todo.isDone = true
                todo.doneAt = judgement.date
                todo.doneSource = source.quoting(done.sourceQuote)
                summary.todosDone += 1
            }

            for found in judgement.appointments {
                // Moved or settled at another time: the one on file changes, no second one comes.
                if let old = found.replaces, let same = Self.replaced(old, by: found, among: matter.appointments ?? []) {
                    // One the owner set is theirs: what came in does not move it (manifesto 5 and 6). Said
                    // again, it is among its sources; moved by the other side, the new date comes as one
                    // of its own, marked NEW, for the owner to keep or put away — never lost.
                    if same.isOwners {
                        let moved = found.date != same.day || (found.time != nil && found.time != same.time)
                        if !moved { same.sources.append(source.quoting(found.sourceQuote)); continue }
                    } else {
                    // The same day said again without its hour moves nothing: the time known stays
                    // (9 November: each reply of the dealer's, "bis Freitag", took the 14:30 away).
                    let moved = found.date != same.day || (found.time != nil && found.time != same.time)
                    guard moved else {
                        same.sources.append(source.quoting(found.sourceQuote))
                        continue
                    }
                    // Another day without an hour: the old hour is not carried over — "No time yet" says so.
                    let sameDay = found.date == same.day
                    if !sameDay || found.time != nil { same.endTime = found.endTime }
                    same.time = found.time ?? (sameDay ? same.time : nil)
                    same.day = found.date
                    same.what = found.what
                    if let place = found.place { same.place = place }
                    // Moved by what came in: it comes first among its sources, so it says NEW with it.
                    same.sources.insert(source.quoting(found.sourceQuote), at: 0)
                    continue
                    }
                }
                // The same visit is mentioned in three mails, worded three ways; the day and the
                // hour are what make it the same.
                if let same = (matter.appointments ?? []).first(where: {
                    $0.day == found.date && ($0.time == found.time || $0.time == nil || found.time == nil)
                        && ($0.time != nil || Self.key($0.what) == Self.key(found.what))
                }) {
                    same.sources.append(source.quoting(found.sourceQuote))
                    // The owner's own is not filled in by what came in either: theirs as they set it.
                    if same.isOwners { continue }
                    if same.time == nil { same.time = found.time }
                    if same.endTime == nil { same.endTime = found.endTime ?? Calendars.endClock(in: found.what, after: found.time) }
                    if same.endDay == nil { same.endDay = found.endDate }
                    if same.place == nil { same.place = found.place }
                    continue
                }
                let appointment = Appointment(what: Calendars.withoutEnd(found.what), day: found.date, time: found.time, place: found.place,
                                              source: source.quoting(found.sourceQuote))
                appointment.endDay = found.endDate
                appointment.endTime = found.endTime ?? Calendars.endClock(in: found.what, after: found.time)
                appointment.matter = matter
                context.insert(appointment)
                summary.appointments += 1
            }

            for found in judgement.deadlines {
                if let same = (matter.deadlines ?? []).first(where: { $0.day == found.date && Self.key($0.what) == Self.key(found.what) }) {
                    same.sources.append(source.quoting(found.sourceQuote))
                    continue
                }
                let deadline = Deadline(what: found.what, day: found.date, source: source.quoting(found.sourceQuote))
                deadline.matter = matter
                context.insert(deadline)
                summary.deadlines += 1
            }

            let others = fullNames[key, default: []].union(matter.parties.flatMap { PartyNames.tokens($0.name).count > 1 ? PartyNames.tokens($0.name) : [] })
            for found in judgement.parties {
                // Taken out by the owner: a later mail naming them does not put them back.
                if let rule = Membership.removal(of: found.name, from: matter, in: context) { rule.fired += 1; continue }
                guard let party = book.party(named: found.name, in: matter, others: others, context: context) else { continue }
                let membership: Membership
                if let known = matter.membership(of: party) {
                    membership = known
                } else {
                    membership = Membership()
                    context.insert(membership)
                    membership.party = party
                    membership.matter = matter
                }
                membership.mentions += 1
                if !found.role.isEmpty, membership.roles.last != found.role { membership.roles.append(found.role) }
            }
        }
        try context.save()
        summary.parties = try context.fetchCount(FetchDescriptor<Party>()) - partiesBefore
        return summary
    }

    /// The appointment a `replaces` names: as listed — "2026-11-13 14:30", or with its words after
    /// it — by its day and hour, not its words; of several on that day, the one its words match.
    static func replaced(_ listed: String, by found: Judgement.Appointment, among appointments: [Appointment]) -> Appointment? {
        guard let match = listed.firstMatch(of: /^\s*(\d{4}-\d{2}-\d{2})(?:\s+(\d{1,2}:\d{2}))?/) else { return nil }
        let day = String(match.output.1), time = match.output.2.map { String($0) }
        let onDay = appointments.filter { $0.day == day && (time == nil || $0.time == time) }
        guard onDay.count > 1 else { return onDay.first }
        let words = key(found.what)
        return onDay.first { key($0.what) == words } ?? onDay.first { words.contains(key($0.what)) || key($0.what).contains(words) }
            ?? onDay.sorted { ($0.time ?? "", $0.what) < ($1.time ?? "", $1.what) }.first
    }

    static func key(_ text: String) -> String {
        text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

extension Matter {
    /// A matter the owner made from nothing but its name. Its key is the name folded, made unique
    /// if another matter already answers to it.
    public static func make(named name: String, in context: ModelContext) throws -> Matter {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var key = PartyNames.key(name).isEmpty ? "sache" : PartyNames.key(name)
        let existing = try context.fetch(FetchDescriptor<Matter>())
        var number = 2
        while existing.contains(where: { $0.answers(to: key) }) {
            key = PartyNames.key(name) + "\(number)"
            number += 1
        }
        let matter = Matter(key: key, name: name.isEmpty ? "New matter" : name)
        context.insert(matter)
        try context.save()
        return matter
    }

    /// When no title came with it, the key with a capital at least: `Sperrmuell`, not `sperrmuell`.
    static func readable(_ key: String) -> String {
        key.prefix(1).uppercased() + key.dropFirst()
    }

    /// A new name. The old one is kept as an alias, so it can still be asked for.
    public func rename(to newName: String) {
        let old = name
        name = newName
        if old != key, !aliases.contains(old) { aliases.append(old) }
    }

    /// The first new mail's subject, without "Re:" and the like, and without a calendar invitation's
    /// " - date and time" tail: "Einladung: Ralf Chille and Robbie Kerr".
    public static func suggestedName(for mails: [Entry]) -> String {
        cleanSubject(mails.min { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }?.title ?? "")
    }

    /// A subject as a name: without "Re:" and the like, and without an invitation's date.
    public static func cleanSubject(_ subject: String) -> String {
        var title = subject
        let prefixes = ["re:", "aw:", "fwd:", "fw:", "wg:", "[external]"]
        while let prefix = prefixes.first(where: { title.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix($0) }) {
            title = String(title.trimmingCharacters(in: .whitespaces).dropFirst(prefix.count))
        }
        if let dash = title.range(of: " - ") { title = String(title[..<dash.lowerBound]) }
        return String(title.trimmingCharacters(in: .whitespaces).prefix(80))
    }

    /// These mails as a matter of their own, named by the owner: the model filed them here — often
    /// under a closed matter — and the owner meant a new one. What only they brought goes along:
    /// tasks, dates and decisions read out of them alone, their files and links, and the assistant's
    /// words since `turnsSince` (the "mails taken in" note). A task another mail said too stays. The
    /// people they name are in both matters.
    public func split(_ moved: [Entry], intoNewMatterNamed name: String, turnsSince: Date?, in context: ModelContext) throws -> Matter {
        let new = try Matter.make(named: name, in: context)
        try move(moved, into: new, turnsSince: turnsSince, in: context)
        return new
    }

    /// These mails into another matter, one that is there already: the model filed them here, and
    /// the owner knows better. What only they brought goes along — tasks, dates and decisions read
    /// out of them alone, their files and links; a task another mail said too stays — as long as
    /// that other mail is still here: moved one mail at a time, the last one takes it along. The
    /// people they name are in both matters.
    public func move(_ moved: [Entry], into new: Matter, turnsSince: Date? = nil, in context: ModelContext) throws {
        guard new !== self else { return }
        let ids = Set(moved.map(\.messageID))
        // What stays behind: the other mails, and the files brought in by hand.
        let staying = Set((entries ?? []).filter { !ids.contains($0.messageID) }.map(\.messageID))
            .union((documents ?? []).filter { !ids.contains($0.messageID) }.map(\.messageID))
        let onlyTheirs: ([Source]) -> Bool = { sources in
            sources.contains { ids.contains($0.messageID ?? "") } && !sources.contains { staying.contains($0.messageID ?? "") }
        }
        for entry in moved where entry.matter === self { entry.matter = new }
        for todo in todos ?? [] where onlyTheirs(todo.sources)
            || (todo.sources.isEmpty && ids.contains(String(todo.origin.split(separator: "#").first ?? ""))) {
            todo.matter = new
        }
        for item in appointments ?? [] where onlyTheirs(item.sources) { item.matter = new }
        for item in deadlines ?? [] where onlyTheirs(item.sources) { item.matter = new }
        for item in decisions ?? [] where onlyTheirs(item.sources) { item.matter = new }
        for item in documents ?? [] where ids.contains(item.messageID) { item.matter = new }
        for item in links ?? [] where ids.contains(item.messageID) { item.matter = new }
        if let since = turnsSince { for turn in turns ?? [] where turn.date > since { turn.matter = new } }
        // Who the mails name: in the new matter as well, with what they are here. Named means by a
        // full name — two words or more, as words — or by their own address: a surname alone, or a
        // mail domain, is shared with others. "Chille" took the owner's mother into every matter
        // whose mails said "Ralf Chille" or came from chille.de.
        let texts = moved.map { [$0.from, $0.title, $0.digest ?? ""].joined(separator: " ") }
        for membership in memberships ?? [] {
            guard let party = membership.party, new.membership(of: party) == nil else { continue }
            let naming = texts.filter { Self.names(party, in: $0) }.count
            guard naming > 0 else { continue }
            let copy = Membership()
            context.insert(copy)
            copy.party = party
            copy.matter = new
            copy.roles = membership.roles
            copy.mentions = naming
        }
        try context.save()
    }

    /// Whether a text names this person: by a full name of theirs, word for word, or by their address.
    static func names(_ party: Party, in text: String) -> Bool {
        let words = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map { PartyNames.fold(String($0)) }
        if let address = party.address?.lowercased(), !address.isEmpty, text.lowercased().contains(address) { return true }
        return ([party.name] + party.spellings).contains { spelling in
            let name = PartyNames.tokens(spelling)
            guard name.count >= 2, words.count >= name.count else { return false }
            return (0...(words.count - name.count)).contains { Array(words[$0..<($0 + name.count)]) == name }
        }
    }

    /// What a file the owner brought in — a scan, a photo, a PDF — brought with it alone: the tasks
    /// and dates read out of it and out of nothing else.
    public func brought(by document: Document) -> (todos: [Todo], appointments: [Appointment], deadlines: [Deadline]) {
        let id = document.messageID
        let only: ([Source]) -> Bool = { !$0.isEmpty && $0.allSatisfy { $0.messageID == id } }
        return ((todos ?? []).filter { only($0.sources) || ($0.sources.isEmpty && $0.origin.hasPrefix(id + "#")) },
                (appointments ?? []).filter { only($0.sources) }, (deadlines ?? []).filter { only($0.sources) })
    }

    /// A file the owner brought in is deleted, with what Causabee knew from it: its entry in the
    /// record, its kept words, and the tasks, dates, decisions and links only it brought — one that
    /// replaced it brings its own. A task a mail said too stays. Mail's files are not deleted: the
    /// mail is still there, and would bring them again. The file itself is left where it lies.
    /// False for a file that came with a mail.
    @discardableResult
    public func forget(_ document: Document, besides store: URL?, in context: ModelContext) -> Bool {
        guard document.isOwnFile, document.matter === self else { return false }
        let id = document.messageID
        let only: ([Source]) -> Bool = { !$0.isEmpty && $0.allSatisfy { $0.messageID == id } }
        let found = brought(by: document)
        for item in found.todos { context.delete(item) }
        for item in found.appointments { context.delete(item) }
        for item in found.deadlines { context.delete(item) }
        for item in decisions ?? [] where only(item.sources) { context.delete(item) }
        for item in links ?? [] where item.messageID == id { context.delete(item) }
        for entry in entries ?? [] where entry.messageID == id { context.delete(entry) }
        for other in documents ?? [] where other.messageID == id { context.delete(other) }
        if let store { MailText.forget(id, besides: store) }
        KeptTexts.forget(id, in: context)
        return true
    }

    /// A file the owner brought in, into another matter, with what it brought alone — its entry,
    /// its links, and the tasks, dates and decisions read out of it and nothing else. "Move to…"
    /// on the line that said where Causabee put it.
    public func carry(_ document: Document, to new: Matter, in context: ModelContext) throws {
        guard new !== self, document.matter === self else { return }
        let id = document.messageID
        let only: ([Source]) -> Bool = { !$0.isEmpty && $0.allSatisfy { $0.messageID == id } }
        let found = brought(by: document)
        for item in found.todos {
            item.matter = new
            item.waitsFor = nil
            if nextStepTodo == item.origin { nextStepTodo = nil }
        }
        for item in found.appointments { item.matter = new }
        for item in found.deadlines { item.matter = new }
        for item in decisions ?? [] where only(item.sources) { item.matter = new }
        for item in links ?? [] where item.messageID == id { item.matter = new }
        for entry in entries ?? [] where entry.messageID == id { entry.matter = new }
        for other in documents ?? [] where other.messageID == id { other.matter = new }
        try context.save()
    }

    /// Everything of `other` becomes this matter's, and `other` is gone. Its names are kept as
    /// aliases: the model will go on filing mail under `reisestornierungmutter`, and that mail
    /// has to arrive here.
    public func absorb(_ other: Matter, in context: ModelContext) {
        guard other !== self else { return }
        // Moved one relationship at a time and emptied before the delete, so the delete — which
        // takes a matter's children with it — finds none left to take.
        let entries = other.entries ?? []; other.entries = []
        for item in entries { item.matter = self }
        let todos = other.todos ?? []; other.todos = []
        for item in todos { item.matter = self }
        let appointments = other.appointments ?? []; other.appointments = []
        for item in appointments { item.matter = self }
        let deadlines = other.deadlines ?? []; other.deadlines = []
        for item in deadlines { item.matter = self }
        let decisions = other.decisions ?? []; other.decisions = []
        for item in decisions { item.matter = self }
        let documents = other.documents ?? []; other.documents = []
        for item in documents { item.matter = self }
        let links = other.links ?? []; other.links = []
        for item in links { item.matter = self }
        let turns = other.turns ?? []; other.turns = []
        for item in turns { item.matter = self }
        let memberships = other.memberships ?? []; other.memberships = []
        for membership in memberships {
            if let party = membership.party, let existing = self.membership(of: party) {
                for role in membership.roles where existing.roles.last != role { existing.roles.append(role) }
                existing.mentions += membership.mentions
                membership.party = nil
                membership.matter = nil
                context.delete(membership)
            } else {
                membership.matter = self
            }
        }
        // The owner's own words come along too, under the name they were written for.
        for note in other.noteBlocks ?? [] { note.matter = self }
        if let theirs = other.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !theirs.isEmpty {
            let mine = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            notes = mine.isEmpty ? theirs : mine + "\n\nFrom “\(other.name)”:\n" + theirs
        }
        for alias in [other.key, other.name] + other.aliases where !answers(to: alias) { aliases.append(alias) }
        context.delete(other)
    }
}
