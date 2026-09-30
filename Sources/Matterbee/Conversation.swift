import AppKit
import MatterCore
import SwiftData
import SwiftUI

/// Asking, and what a ticked card does: the same in the assistant and in a matter's status, so a
/// question asked in either lands in the one thread.
@MainActor
struct Conversation {
    let context: ModelContext
    let navigation: Navigation
    let owner: String?


    /// Asks, and adds the question to the thread at once; the answer arrives into it.
    func ask(_ question: String, about scope: [Matter], pinnedMatter: Matter?) {
        let typed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return }
        // "Geor" is Georg when Georg is the only one near it: read on the device, and said.
        let names = scope.flatMap { $0.parties.map(\.name) }
        let (question, readAs) = NameHints.correct(typed, knowing: names)
        let today = MatterStatus.day(Date())
        let pinned = navigation.pinned
        let facts = FactSheet.facts(for: scope, today: today, focus: pinned.flatMap { Navigation.Pinned.isMatter($0.kind) ? nil : $0.text })
        let inHand = pinned.flatMap { Navigation.Pinned.isMatter($0.kind) ? nil : (kind: $0.kind, text: $0.text) }
        // Only this matter's talk: what was said about another matter is not needed here, and
        // would go out with this question.
        let earlier: [(question: String, answer: String)] = navigation.turns.compactMap { turn in
            guard turn.matter == pinnedMatter?.persistentModelID, case .answered(let answer) = turn.state else { return nil }
            return (turn.question, answer.reply.lines.map(\.text).joined(separator: " "))
        }
        navigation.turns.append(.init(question: question, scope: pinnedMatter.map { "about \($0.name)" } ?? "about all matters", inHand: pinned,
                                      seen: facts.seen, refs: facts.refs, matter: pinnedMatter?.persistentModelID))
        navigation.turns[navigation.turns.count - 1].readAs = readAs.map { "read “\($0.typed)” as “\($0.known)”" }
        let id = navigation.turns.last!.id
        let model = ModelChoice.assistant
        guard let claude = ModelChoice.client(for: model) else {
            setState(of: id, .failed(ModelChoice.missingKey(model)))
            return
        }
        let mapping = navigation.mapping
        let owner = self.owner
        let navigation = self.navigation
        Task {
            do {
                let answer = try await AssistantAsk.ask(question: question, inHand: inHand, earlier: earlier, facts: facts,
                                                        owner: owner, today: today, mapping: mapping, claude: claude, model: model)
                Conversation.set(id, .answered(answer), in: navigation)
            } catch {
                Conversation.set(id, .failed("\(error)"), in: navigation)
            }
        }
    }

    // MARK: Screenshots

    /// A screenshot brought in: kept where it is if it has a home, copied in if not, then read on
    /// the device. Nothing is sent.
    func bring(_ file: URL, document: MatterCore.Document? = nil) {
        var file = file
        var copied = false
        if document == nil, !ScreenshotDoor.hasHome(file) {
            let folder = ScreenshotDoor.attachments(besides: navigation.store)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let target = folder.appendingPathComponent(UUID().uuidString.prefix(8) + "-" + file.lastPathComponent)
            if (try? FileManager.default.copyItem(at: file, to: target)) != nil { file = target; copied = true }
        }
        var turn = Navigation.Turn(question: file.lastPathComponent, scope: "File", inHand: nil, seen: "", refs: [:], matter: nil)
        turn.shot = Navigation.Shot(file: file, copied: copied)
        if case .matter(let open) = navigation.place { turn.matter = open }
        if let document {
            turn.shot?.document = document.persistentModelID
            turn.matter = document.matter?.persistentModelID
        }
        navigation.turns.append(turn)
        read(turn.id, file)
    }

    /// An image on the pasteboard has no home: it is written beside the store, then brought in.
    func bringPasted(_ data: Data) {
        let folder = ScreenshotDoor.attachments(besides: navigation.store)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let file = folder.appendingPathComponent("Pasted-\(formatter.string(from: Date())).png")
        guard (try? data.write(to: file)) != nil else { return }
        var turn = Navigation.Turn(question: file.lastPathComponent, scope: "Screenshot", inHand: nil, seen: "", refs: [:], matter: nil)
        turn.shot = Navigation.Shot(file: file, copied: true)
        if case .matter(let open) = navigation.place { turn.matter = open }
        navigation.turns.append(turn)
        read(turn.id, file)
    }

    /// Reads on the device, away from the window — Vision takes a moment — and hands back only
    /// what it read.
    private func read(_ id: UUID, _ file: URL) {
        let door = ScreenshotDoor(besides: navigation.store, model: ModelChoice.mail)
        let owner = self.owner ?? "Ich"
        let navigation = self.navigation
        Task {
            let stage = await Task.detached { () -> Navigation.Shot.Stage in
                do { return .read(try door.look(at: file, owner: owner)) } catch { return .failed("\(error)") }
            }.value
            Conversation.set(shot: id, stage, in: navigation)
        }
    }

    /// Sends it, pseudonymised, after "Einordnen".
    func classify(shot id: UUID, owner: [String]) {
        guard let turn = navigation.turns.first(where: { $0.id == id }), case .read(let look) = turn.shot?.stage else { return }
        var door = ScreenshotDoor(besides: navigation.store, model: ModelChoice.mail)
        door.strict = ModelChoice.strict
        guard let claude = ModelChoice.client(for: door.model) else {
            Self.set(shot: id, .failed(ModelChoice.missingKey(door.model)), in: navigation)
            return
        }
        Self.set(shot: id, .sending(look), in: navigation)
        let matters = Unplaced.matters(in: context)
        let navigation = self.navigation
        Task {
            do {
                let judgement = try await door.classify(look, claude: claude, owner: owner, matters: matters)
                Conversation.set(shot: id, .answered(look, judgement), in: navigation)
            } catch {
                Conversation.set(shot: id, .failed("\(error)"), in: navigation)
            }
        }
    }

    /// Takes what the screenshot said into a matter: the one the owner chose, or a new one with
    /// the name the owner left on the card.
    func take(shot id: UUID, into matter: Matter?, newName: String, owner: [String], keep: Set<String>? = nil) {
        guard let turn = navigation.turns.first(where: { $0.id == id }), case .answered(let look, var judgement) = turn.shot?.stage else { return }
        // Only what the owner left checked: nothing already in the matter twice.
        if let keep {
            judgement.todos = judgement.todos.enumerated().filter { keep.contains("t\($0.offset)") }.map(\.element)
            judgement.appointments = judgement.appointments.enumerated().filter { keep.contains("a\($0.offset)") }.map(\.element)
            judgement.deadlines = judgement.deadlines.enumerated().filter { keep.contains("d\($0.offset)") }.map(\.element)
        }
        if let matter {
            judgement.matter = matter.key
            judgement.matterTitle = nil
        } else {
            let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = PartyNames.key(name).isEmpty ? (judgement.matter ?? "chat") : PartyNames.key(name)
            if (try? context.fetch(FetchDescriptor<Matter>()))?.contains(where: { $0.answers(to: key) }) == true {
                judgement.matter = key + "-" + String(id.uuidString.prefix(4)).lowercased()
            } else {
                judgement.matter = key
            }
            judgement.matterTitle = name.isEmpty ? nil : name
        }
        judgement.decidedBy = .claude
        // A mail file is kept inside Matterbee once taken in: its attachments are read from it,
        // and Downloads gets cleaned up.
        if look.kind == .mail, !look.file.path.hasPrefix(ScreenshotDoor.attachments(besides: navigation.store).path) {
            let folder = ScreenshotDoor.attachments(besides: navigation.store)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let target = folder.appendingPathComponent(UUID().uuidString.prefix(8) + "-" + look.file.lastPathComponent)
            if (try? FileManager.default.copyItem(at: look.file, to: target)) != nil { judgement.source = target.path }
        }
        do {
            _ = try MatterImport.apply([judgement], to: context, owner: owner)
            let taken = (try? context.fetch(FetchDescriptor<Matter>()))?.first { $0.answers(to: judgement.matter ?? "") }
            // A mail dropped in brings its important links along, as suggestions.
            if look.kind == .mail, let email = look.report.outcomes.first?.email, let taken {
                MailLinks.suggest(email.links, messageID: email.id, to: taken, in: context)
                MailText.save(email, besides: navigation.store)
            }
            if let taken { try? context.save(); FolderSaver.shared.save([taken]) }
            // The people in a chat are its parties, whatever the model thought of the chat: read on
            // the device from who spoke and who the header names, the owner left out. Taking the
            // same screenshot in again adds them if they were missing.
            if let taken {
                var book = try PartyBook(context: context, owner: OwnerNames(owner))
                let others = Set(look.transcript.people.flatMap(PartyNames.tokens))
                for name in look.transcript.people {
                    guard let party = book.party(named: name, in: taken, others: others, context: context) else { continue }
                    let membership = taken.membership(of: party) ?? {
                        let new = Membership()
                        context.insert(new)
                        new.party = party
                        new.matter = taken
                        return new
                    }()
                    membership.mentions += look.transcript.messages.filter { $0.speaker == name }.count
                    if membership.roles.isEmpty { membership.roles = ["in the chat"] }
                }
                try context.save()
            }
            Self.set(shot: id, .taken(taken?.name ?? judgement.matter ?? "", taken?.persistentModelID), in: navigation)
            if let index = navigation.turns.firstIndex(where: { $0.id == id }) { navigation.turns[index].matter = taken?.persistentModelID }
            if let document = turn.shot?.document.flatMap({ live($0, as: MatterCore.Document.self) }) {
                document.readAt = Date()
                try? context.save()
            }
        } catch {
            Self.set(shot: id, .failed("\(error)"), in: navigation)
        }
    }

    static func set(shot id: UUID, _ stage: Navigation.Shot.Stage, in navigation: Navigation) {
        guard let index = navigation.turns.firstIndex(where: { $0.id == id }) else { return }
        navigation.turns[index].shot?.stage = stage
    }

    static func set(_ id: UUID, _ state: Navigation.Turn.State, in navigation: Navigation) {
        guard let index = navigation.turns.firstIndex(where: { $0.id == id }) else { return }
        navigation.turns[index].state = state
    }

    func setState(of id: UUID, _ state: Navigation.Turn.State) { Self.set(id, state, in: navigation) }

    // MARK: Doors

    /// A cited fact is a door into the status of the matter it belongs to.
    func open(_ ref: FactRef) {
        if let matter = matter(of: ref) { navigation.open(matter) }
    }

    /// A fact by its id, if it is still there. A party merged away or a to-do deleted is gone,
    /// and `context.model(for:)` would hand back an object that crashes when read.
    func live<T: PersistentModel>(_ id: PersistentIdentifier, as type: T.Type) -> T? {
        var descriptor = FetchDescriptor<T>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func live<T: PersistentModel>(_ ref: FactRef, as type: T.Type) -> T? {
        switch ref {
        case .matter(let id), .entry(let id), .todo(let id), .appointment(let id), .deadline(let id), .party(let id):
            return live(id, as: type)
        }
    }

    /// What a chip says: the kind and its day, or the name — never `T20`.
    func label(_ ref: FactRef) -> String {
        switch ref {
        case .matter: return live(ref, as: Matter.self)?.name ?? "Matter (no longer there)"
        case .entry: return "Mail " + (live(ref, as: Entry.self)?.date.map(Dates.short) ?? "")
        case .todo:
            guard let todo = live(ref, as: Todo.self) else { return "Task (no longer there)" }
            let words = todo.text.split(separator: " ").prefix(4).joined(separator: " ")
            return (todo.isDone ? "✓ " : "") + words + (todo.text.split(separator: " ").count > 4 ? " …" : "")
        case .appointment: return "Appointment " + (live(ref, as: Appointment.self).map { Dates.short($0.day) } ?? "")
        case .deadline: return "Deadline " + (live(ref, as: Deadline.self).map { Dates.short($0.day) } ?? "")
        case .party: return live(ref, as: Party.self)?.name ?? "merged"
        }
    }

    func matter(of ref: FactRef) -> Matter? {
        switch ref {
        case .matter: return live(ref, as: Matter.self)
        case .entry: return live(ref, as: Entry.self)?.matter
        case .todo: return live(ref, as: Todo.self)?.matter
        case .appointment: return live(ref, as: Appointment.self)?.matter
        case .deadline: return live(ref, as: Deadline.self)?.matter
        case .party: return live(ref, as: Party.self)?.matters.first
        }
    }

    /// A card the owner ticked, with its text as the owner left it. Only now does anything
    /// change in the store.
    /// A party's address, from the mail on this Mac: the sender line of a mail they wrote. It is
    /// never sent anywhere; it only fills the "To" of a draft the owner opens.
    func address(of party: Party) -> String? {
        let keys = Set(([party.name] + party.spellings).map(PartyNames.key))
        for matter in party.matters {
            for entry in matter.entries ?? [] {
                guard let name = Email.displayName(in: entry.from), keys.contains(PartyNames.key(name)) else { continue }
                let address = Email.address(in: entry.from)
                if address.contains("@") { return address }
            }
        }
        return nil
    }

    /// Puts the draft into the mailbox's Drafts folder — the one write Matterbee makes, on this
    /// click only. Answering a mail of the matter, it goes into that mail's conversation.
    func putDraft(_ index: Int, text: String, subject: String, in turn: Navigation.Turn) {
        guard case .answered(let answer) = turn.state, answer.reply.cards.indices.contains(index),
              answer.reply.cards[index].kind == .draftMessage,
              let position = navigation.turns.firstIndex(where: { $0.id == turn.id }) else { return }
        guard let account = Keychain.accounts().first else {
            navigation.turns[position].drafting[index] = "No mail account saved. First: matter-spike login"
            return
        }
        let card = answer.reply.cards[index]
        let to = recipient(card.party, in: turn)
        let matter = turn.matter.flatMap { live($0, as: Matter.self) }
            ?? card.cites.compactMap { turn.refs[$0] }.compactMap(matter(of:)).first
        let answering = to?.address.flatMap { address in
            (matter?.entries ?? []).filter { Email.address(in: $0.from).lowercased() == address.lowercased() && !$0.messageID.isEmpty }
                .max { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }?.messageID
        }
        let message = DraftMessage(from: account.user, to: to?.address.map { (name: to?.name, address: $0) }, subject: subject,
                                   body: text, replyingTo: answering).data
        // The version put into Gmail is the one kept.
        if case .answered(var kept) = navigation.turns[position].state {
            kept.reply.cards[index].text = text
            kept.reply.cards[index].subject = subject
            navigation.turns[position].state = .answered(kept)
        }
        navigation.turns[position].drafting[index] = "Putting the draft into Gmail …"
        let navigation = navigation
        let id = turn.id
        Task {
            func set(_ change: (inout Navigation.Turn) -> Void) {
                if let at = navigation.turns.firstIndex(where: { $0.id == id }) { change(&navigation.turns[at]) }
            }
            do {
                guard let password = try await MailSecret.secret(for: account) else { throw MailFetch.Failure.gone(account.user) }
                let folder = try await DraftDoor.put(message, account: account, password: password)
                set { $0.drafted[index] = folder; $0.drafting[index] = nil; $0.applied.insert(index) }
            } catch {
                set { $0.drafting[index] = "Not saved: \(error)" }
            }
        }
    }

    func recipient(_ id: String?, in turn: Navigation.Turn) -> (name: String, address: String?)? {
        guard let id, let ref = turn.refs[id], let party = live(ref, as: Party.self) else { return nil }
        return (party.name, address(of: party))
    }

    func apply(_ index: Int, text: String, subject: String? = nil, in turn: Navigation.Turn) {
        guard case .answered(let answer) = turn.state, answer.reply.cards.indices.contains(index),
              let position = navigation.turns.firstIndex(where: { $0.id == turn.id }) else { return }
        let card = answer.reply.cards[index]
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = Source(kind: .conversation, pointer: "assistant", date: Date(), quote: card.reason)
        func model<T: PersistentModel>(_ id: String?, as type: T.Type) -> T? {
            guard let id, let ref = turn.refs[id] else { return nil }
            return live(ref, as: type)
        }
        let cited = card.cites.compactMap { turn.refs[$0] }.compactMap(matter(of:)).first
        // A matter made by a card in this same answer is where its to-dos go.
        let made = navigation.turns[position].madeMatter.flatMap { live($0, as: Matter.self) }
        let scope = made ?? turn.matter.flatMap { live($0, as: Matter.self) } ?? cited
        let origin = "you, in the assistant\(scope.map { ", in \($0.name)" } ?? ""), \(Dates.short(Date()))"

        let undo: Navigation.Undo
        switch card.kind {
        case .markDone:
            guard let todo = model(card.todo, as: Todo.self), !todo.isDone else { return }
            todo.isDone = true
            todo.doneAt = Date()
            todo.doneSource = source
            undo = .reopen(todo.persistentModelID)
        case .newTodo:
            guard let matter = scope, !text.isEmpty else { return }
            let todo = Todo(text: text, owner: Todo.Owner(rawValue: card.owner) ?? .me, due: card.due, source: source,
                            origin: "assistant#" + text.lowercased())
            context.insert(todo)
            todo.matter = matter
            try? context.save()
            undo = .remove(todo.persistentModelID)
        case .sameParty:
            guard let party = model(card.party, as: Party.self), let into = model(card.into, as: Party.self), party !== into,
                  let matter = scope ?? into.matters.first else { return }
            PartyBook.confirmSame(party, as: into, in: matter, context: context, origin: origin)
            try? context.save()
            let rules = (try? context.fetch(FetchDescriptor<Rule>())) ?? []
            guard let rule = rules.max(by: { $0.createdAt < $1.createdAt }) else { return }
            undo = .merged(rule: rule.persistentModelID)
        case .changeRole:
            guard let party = model(card.party, as: Party.self), !text.isEmpty,
                  let membership = (scope ?? party.matters.first)?.membership(of: party) else { return }
            undo = .roles(membership.persistentModelID, membership.roles)
            membership.setRole(text)
            try? context.save()
            navigation.turns[position].applied.insert(index)
            navigation.turns[position].undos[index] = undo
            return
        case .renameParty:
            guard let party = model(card.party, as: Party.self), !text.isEmpty, text != party.name else { return }
            let old = party.name
            party.rename(to: text)
            let rule = Rule(.partyName, subject: old, object: text, matterKey: scope?.key, origin: origin)
            context.insert(rule)
            try? context.save()
            undo = .name(party.persistentModelID, old, rule: rule.persistentModelID)
        case .correctText:
            guard let matter = scope, let from = card.from, !from.isEmpty, !text.isEmpty else { return }
            var before: [(PersistentIdentifier, String)] = []
            for todo in matter.todos ?? [] where todo.text.contains(from) {
                before.append((todo.persistentModelID, todo.text))
                todo.text = todo.text.replacingOccurrences(of: from, with: text)
            }
            for item in matter.appointments ?? [] where item.what.contains(from) {
                before.append((item.persistentModelID, item.what))
                item.what = item.what.replacingOccurrences(of: from, with: text)
            }
            for item in matter.deadlines ?? [] where item.what.contains(from) {
                before.append((item.persistentModelID, item.what))
                item.what = item.what.replacingOccurrences(of: from, with: text)
            }
            undo = .texts(before)
        case .draftMessage:
            // The one door out: Mail opens with the draft in it, and the owner sends it — or not.
            let to = recipient(card.party, in: turn)?.address ?? ""
            var parts = URLComponents()
            parts.scheme = "mailto"
            parts.path = to
            parts.queryItems = [URLQueryItem(name: "subject", value: subject ?? card.subject ?? ""), URLQueryItem(name: "body", value: text)]
            if let url = parts.url { NSWorkspace.shared.open(url) }
            // The version opened is the one kept: the thread remembers what went to Mail.
            if case .answered(var kept) = navigation.turns[position].state {
                kept.reply.cards[index].text = text
                kept.reply.cards[index].subject = subject ?? card.subject
                navigation.turns[position].state = .answered(kept)
            }
            navigation.turns[position].applied.insert(index)
            return
        case .newMatter:
            guard !text.isEmpty, let matter = try? Matter.make(named: text, in: context) else { return }
            navigation.turns[position].madeMatter = matter.persistentModelID
            undo = .madeMatter(matter.persistentModelID)
            navigation.turns[position].applied.insert(index)
            navigation.turns[position].undos[index] = undo
            navigation.open(matter)
            return
        case .changeDate:
            guard let day = card.due else { return }
            if let todo = model(card.todo, as: Todo.self) {
                undo = .date(todo.persistentModelID, day: todo.due, time: todo.dueTime)
                todo.due = day
                todo.dueTime = card.time ?? todo.dueTime
            } else if let appointment = model(card.todo, as: Appointment.self) {
                undo = .date(appointment.persistentModelID, day: appointment.day, time: appointment.time)
                appointment.day = day
                appointment.time = card.time ?? appointment.time
            } else if let deadline = model(card.todo, as: Deadline.self) {
                undo = .date(deadline.persistentModelID, day: deadline.day, time: nil)
                deadline.day = day
            } else { return }
        case .addNote:
            guard let todo = model(card.todo, as: Todo.self), !text.isEmpty else { return }
            undo = .note(todo.persistentModelID, todo.note)
            todo.note = [todo.note, text].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: "\n")
        case .addLink:
            guard let standIn = card.from, let address = answer.links?[standIn] ?? WebLink.address(in: standIn) else { return }
            let todo = model(card.todo, as: Todo.self)
            guard let matter = todo?.matter ?? scope else { return }
            let link = WebLink(address: address, title: text)
            context.insert(link)
            link.matter = matter
            link.todo = todo
            try? context.save()
            undo = .removeLink(link.persistentModelID)
        case .waitsFor:
            guard let todo = model(card.todo, as: Todo.self), let other = model(card.into, as: Todo.self) else { return }
            let before = todo.waitsFor?.persistentModelID
            guard todo.wait(for: other) else { return }
            undo = .waits(todo.persistentModelID, before)
        case .changeOwner:
            guard let todo = model(card.todo, as: Todo.self), let owner = Todo.Owner(rawValue: card.owner) else { return }
            undo = .owner(todo.persistentModelID, todo.owner)
            todo.owner = owner
        }
        try? context.save()
        navigation.turns[position].applied.insert(index)
        navigation.turns[position].undos[index] = undo
    }

    /// Puts back what a ticked card changed.
    func undo(_ index: Int, in turn: Navigation.Turn) {
        guard let position = navigation.turns.firstIndex(where: { $0.id == turn.id }),
              let undo = navigation.turns[position].undos[index] else { return }
        switch undo {
        case .reopen(let id):
            if let todo = live(id, as: Todo.self) { todo.isDone = false; todo.doneAt = nil; todo.doneSource = nil }
        case .remove(let id):
            if let todo = live(id, as: Todo.self) { context.delete(todo) }
        case .owner(let id, let owner):
            live(id, as: Todo.self)?.owner = owner
        case .name(let id, let old, let rule):
            if let party = live(id, as: Party.self) { party.name = old }
            if let rule = live(rule, as: Rule.self) { context.delete(rule) }
        case .texts(let before):
            for (id, text) in before {
                if let todo = live(id, as: Todo.self) { todo.text = text }
                else if let item = live(id, as: Appointment.self) { item.what = text }
                else if let item = live(id, as: Deadline.self) { item.what = text }
            }
        case .madeMatter(let id):
            // Only while it is still empty: a matter with mail or to-dos in it is not undone by a click.
            if let matter = live(id, as: Matter.self), (matter.entries ?? []).isEmpty, (matter.todos ?? []).isEmpty {
                context.delete(matter)
                navigation.turns[position].madeMatter = nil
                navigation.place = .assistant
            } else { return }
        case .date(let id, let day, let time):
            if let todo = live(id, as: Todo.self) { todo.due = day; todo.dueTime = time }
            else if let item = live(id, as: Appointment.self), let day { item.day = day; item.time = time }
            else if let item = live(id, as: Deadline.self), let day { item.day = day }
        case .note(let id, let note):
            live(id, as: Todo.self)?.note = note
        case .removeLink(let id):
            if let link = live(id, as: WebLink.self) { context.delete(link) }
        case .waits(let id, let before):
            live(id, as: Todo.self)?.waitsFor = before.flatMap { live($0, as: Todo.self) }
        case .roles(let id, let roles):
            live(id, as: Membership.self)?.roles = roles
        case .merged(let rule):
            // Switched off, so the next mail's spelling is its own party again.
            live(rule, as: Rule.self)?.isOn = false
        }
        try? context.save()
        navigation.turns[position].applied.remove(index)
        navigation.turns[position].undos[index] = nil
    }

}

/// The field at the bottom: what is in hand above it, what it can see below it.
struct Composer: View {
    @Binding var draft: String
    var focused: FocusState<Bool>.Binding
    let pinned: Navigation.Pinned?
    /// Worked out only when the footer is opened: not again at every letter typed.
    let seen: () -> String
    let placeholder: String
    let unpin: () -> Void
    /// Opens a panel to choose a screenshot.
    var attach: (() -> Void)? = nil
    let send: () -> Void
    /// The footer in full — what is seen and where it goes — or only that it goes pseudonymised.
    @State private var showsMore = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let pinned {
                // What is in hand, on the bee's yellow: black words in both modes.
                HStack(spacing: 8) {
                    Image(systemName: "pin.fill").font(.caption).foregroundStyle(.black)
                    VStack(alignment: .leading, spacing: 1) {
                        // The matter is in the field's placeholder below; the chip says only what it is.
                        Text(pinned.kind.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.black.opacity(0.5))
                        Text(pinned.text).lineLimit(2).foregroundStyle(.black)
                    }
                    Spacer()
                    Button(action: unpin) { Image(systemName: "xmark.circle.fill").foregroundStyle(.black.opacity(0.5)) }
                        .buttonStyle(.plain)
                        .help("Put it down")
                }
                .padding(10)
                .background(Theme.bee, in: RoundedRectangle(cornerRadius: 10))
            }
            // The send button sits in the pill's round end: as far from the right as from the top
            // and bottom, and the corner's radius is half its height — 10 + 26 / 2.
            HStack(alignment: .bottom) {
                if let attach {
                    Button(action: attach) { Image(systemName: "paperclip").font(.title3).frame(height: 26) }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Attach a screenshot, a mail (.eml) or a PDF — or drag it here, or paste it (⌘V). It is read on the Mac.")
                }
                TextField(placeholder, text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...8)
                    // One line sits in the middle of the send button; more lines grow upwards.
                    .frame(minHeight: 26)
                    .focused(focused)
                    // Return sends; Shift-Return starts a new line, as in Messages.
                    .onKeyPress(.return, phases: .down) { press in
                        if press.modifiers.contains(.shift) || press.modifiers.contains(.option) {
                            draft += "\n"
                        } else {
                            send()
                        }
                        return .handled
                    }
                Button(action: send) {
                    // The bee's yellow with a black arrow, like the other yellow pills.
                    Image(systemName: "arrow.up.circle.fill").resizable().frame(width: 26, height: 26)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.black, Theme.bee)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: .command)
                .help("Send (↩) · new line with ⇧↩")
            }
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 23))
            // "more" and "less" are links inside the line, so the full one wraps like a sentence.
            Text(LocalizedStringKey(showsMore
                ? "Always pseudonymised sent to \(ModelChoice.assistant.label) • Sees: \(seen()) · goes pseudonymised, like the mails • [less](matterbee://footer)"
                : "Always pseudonymised sent • [more](matterbee://footer)"))
                .font(.caption2).foregroundStyle(.secondary).tint(Theme.gold)
                .environment(\.openURL, OpenURLAction { _ in showsMore.toggle(); return .handled })
                .padding(.horizontal, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }
}
