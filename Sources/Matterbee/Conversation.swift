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

    /// A fact by its id, if it is still there (CardActions, shared with the iPhone).
    func live<T: PersistentModel>(_ id: PersistentIdentifier, as type: T.Type) -> T? { CardActions.live(id, as: type, in: context) }
    func live<T: PersistentModel>(_ ref: FactRef, as type: T.Type) -> T? { CardActions.live(ref, as: type, in: context) }
    /// What a chip says: the kind and its day, or the name — never `T20`.
    func label(_ ref: FactRef) -> String { CardActions.label(ref, in: context) }
    func matter(of ref: FactRef) -> Matter? { CardActions.matter(of: ref, in: context) }

    /// A party's address, from the mail in the store: it only fills the "To" of a draft.
    func address(of party: Party) -> String? { CardActions.address(of: party) }

    func recipient(_ id: String?, in turn: Navigation.Turn) -> (name: String, address: String?)? {
        CardActions.recipient(id, refs: turn.refs, in: context)
    }

    /// A card the owner ticked: what it does is CardActions' — the same on the iPhone; the turn
    /// keeps that it was taken in, and how to take it back.
    func apply(_ index: Int, text: String, subject: String? = nil, in turn: Navigation.Turn) {
        guard case .answered(let answer) = turn.state, answer.reply.cards.indices.contains(index),
              let position = navigation.turns.firstIndex(where: { $0.id == turn.id }) else { return }
        let card = answer.reply.cards[index]
        let cited = card.cites.compactMap { turn.refs[$0] }.compactMap(matter(of:)).first
        // A matter made by a card in this same answer is where its to-dos go.
        let made = navigation.turns[position].madeMatter.flatMap { live($0, as: Matter.self) }
        let scope = made ?? turn.matter.flatMap { live($0, as: Matter.self) } ?? cited
        switch CardActions.apply(card, text: text, subject: subject, refs: turn.refs, links: answer.links, scope: scope, in: context) {
        case .nothing:
            return
        case .openMail(let url):
            NSWorkspace.shared.open(url)
            // The version opened is the one kept: the thread remembers what went to Mail.
            if case .answered(var kept) = navigation.turns[position].state {
                kept.reply.cards[index].text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                kept.reply.cards[index].subject = subject ?? card.subject
                navigation.turns[position].state = .answered(kept)
            }
            navigation.turns[position].applied.insert(index)
        case .madeMatter(let matter, let undo):
            navigation.turns[position].madeMatter = matter.persistentModelID
            navigation.turns[position].applied.insert(index)
            navigation.turns[position].undos[index] = undo
            navigation.open(matter)
        case .taken(let undo):
            navigation.turns[position].applied.insert(index)
            navigation.turns[position].undos[index] = undo
        }
    }

    /// Puts back what a ticked card changed.
    func undo(_ index: Int, in turn: Navigation.Turn) {
        guard let position = navigation.turns.firstIndex(where: { $0.id == turn.id }),
              let undo = navigation.turns[position].undos[index], CardActions.undo(undo, in: context) else { return }
        if case .madeMatter = undo {
            navigation.turns[position].madeMatter = nil
            navigation.place = .assistant
        }
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
