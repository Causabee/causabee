import MatterCore
import SwiftData
import SwiftUI

/// The assistant's thread, one with the Mac's, over a matter: that matter's part of it. Asked here,
/// a question goes out disguised by the Mac's own list of names — the copy the Mac put into the
/// store — with the key pasted on the Mac, from iCloud Keychain. The list is not changed here: a
/// name the Mac has not seen gets a stand-in for this question only.
struct AssistantSheet: View {
    let matter: Matter?
    @Environment(Navigation.self) private var navigation
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ThreadTurn.date) private var records: [ThreadTurn]
    @Query private var matters: [Matter]
    @Query private var profiles: [Profile]
    @Environment(PhoneStore.self) private var store
    @State private var draft = ""
    /// The question on its way, until its answer is in the thread.
    @State private var asking: (question: String, date: Date)?
    @State private var failure: String?
    /// The footer in full — what is seen and where it goes — or only that it goes pseudonymised.
    @State private var showsMore = false

    /// What a question here would take along: worked out only when the footer is opened.
    private var seen: String {
        FactSheet.facts(for: matter.map { [$0] } ?? activeMatters(matters), today: MatterStatus.day(Date())).seen
    }

    private var shown: [(record: ThreadTurn, turn: Navigation.Turn)] {
        records
            .filter { matter == nil || $0.matter?.persistentModelID == matter?.persistentModelID }
            .compactMap { record in navigation.turn(record).map { (record, $0) } }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollViewReader { scroller in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        let turns = shown
                        if turns.isEmpty {
                            Text(matter == nil ? "Nothing asked yet." : "Nothing asked about this matter yet.")
                                .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 40)
                        }
                        ForEach(Array(turns.enumerated()), id: \.element.turn.id) { index, item in
                            if index == 0 || !Calendar.current.isDate(turns[index - 1].turn.date, inSameDayAs: item.turn.date) {
                                Text(item.turn.date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "en_US"))))
                                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                            }
                            PhoneTurnView(record: item.record, turn: item.turn, matter: item.record.matter)
                                .id(item.turn.id)
                        }
                        // Files brought in here: read on the iPhone, sorted in on a yes.
                        ForEach(PhoneShots.shared.shots.filter { matter == nil || $0.matter == nil || $0.matter == matter?.persistentModelID }) { shot in
                            PhoneShotCard(shot: shot).id(shot.id)
                        }
                        if let asking {
                            PendingTurn(question: asking.question, scope: matter.map { "about \($0.name)" } ?? "about all matters")
                                .id("asking")
                        }
                        if let failure {
                            Label(failure, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(Theme.warning)
                                .fixedSize(horizontal: false, vertical: true).id("failure")
                        }
                    }
                    .padding(16)
                    .containerRelativeFrame(.horizontal)
                }
                .defaultScrollAnchor(.bottom)
                .onAppear { if let last = shown.last { scroller.scrollTo(last.turn.id, anchor: .bottom) } }
                .onChange(of: PhoneShots.shared.shots.count) { if let last = PhoneShots.shared.shots.last { withAnimation { scroller.scrollTo(last.id, anchor: .bottom) } } }
                .onChange(of: asking?.date) { withAnimation { scroller.scrollTo(asking == nil ? shown.last?.turn.id as AnyHashable? : "asking", anchor: .bottom) } }
            }
            composer
        }
        .background(Theme.canvas)
        .onAppear {
            // What was in hand from another matter is put down; words to send go into the field.
            if let pinned = navigation.pinned, pinned.matter != matter?.persistentModelID { navigation.pinned = nil }
            if let prefill = navigation.prefill { draft = prefill; navigation.prefill = nil }
        }
    }

    private var header: some View {
        ZStack {
            VStack(spacing: 2) {
                Text("Assistant").font(.headline)
                Text(matter?.name ?? "All matters").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(.horizontal, 60)
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                Spacer()
            }
        }
        .padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 10)
    }

    /// The field as the Mac has it: what is typed goes out pseudonymised, and only on send.
    private var composer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let pinned = navigation.pinned {
                // What is in hand, on the bee's yellow: black words in both modes — as on the Mac.
                HStack(spacing: 8) {
                    Image(systemName: "pin.fill").font(.caption).foregroundStyle(.black)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(pinned.kind.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.black.opacity(0.5))
                        Text(pinned.text).lineLimit(2).foregroundStyle(.black)
                    }
                    Spacer()
                    Button { navigation.pinned = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.black.opacity(0.5)) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Put it down")
                }
                .padding(10)
                .background(Theme.bee, in: RoundedRectangle(cornerRadius: 10))
            }
            // As on the Mac: the send button sits in the pill's round end, as far from the right as
            // from the top and bottom, and the corner's radius is that and half the button — 7 + 34 / 2.
            HStack(alignment: .bottom, spacing: 6) {
                AttachButton(matter: matter)
                TextField(matter.map { "Ask about \($0.name)" } ?? "Ask about your matters", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .submitLabel(.send)
                    .onSubmit(send)
                    // One line sits in the middle of the send button; more lines grow upwards.
                    .frame(minHeight: 34)
                Button(action: send) {
                    // A black arrow on the bee's yellow, as every yellow thing has black on it.
                    Image(systemName: "arrow.up.circle.fill").resizable().frame(width: 34, height: 34)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.black, Theme.bee)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send")
            }
            .padding(.leading, 7).padding(.trailing, 7).padding(.vertical, 7)
            .background(Theme.box, in: RoundedRectangle(cornerRadius: 24))
            // As on the Mac: "more" and "less" are links inside the line, so the full one wraps like a sentence.
            Text(LocalizedStringKey(showsMore
                ? "Always pseudonymised sent to \(ModelChoice.assistant.label) • Sees: \(seen) · goes pseudonymised, like the mails • [less](matterbee://footer)"
                : "Always pseudonymised sent • [more](matterbee://footer)"))
                .font(.caption2).foregroundStyle(.secondary).tint(Theme.gold)
                .environment(\.openURL, OpenURLAction { _ in showsMore.toggle(); return .handled })
                .padding(.horizontal, 8)
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 8)
        .background(Theme.canvas)
    }
}

extension AssistantSheet {
    /// Asks, as the Mac does: this matter's facts, what was said about it before, the owner's name.
    /// The answer goes into the thread as a turn of its own record, so the Mac shows it too.
    private func send() {
        let typed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty, asking == nil else { return }
        let scope = matter.map { [$0] } ?? activeMatters(matters)
        let (question, readAs) = NameHints.correct(typed, knowing: scope.flatMap { $0.parties.map(\.name) })
        let today = MatterStatus.day(Date())
        let pinned = navigation.pinned
        let facts = FactSheet.facts(for: scope, today: today, focus: pinned.flatMap { Navigation.Pinned.isMatter($0.kind) ? nil : $0.text })
        let inHand = pinned.flatMap { Navigation.Pinned.isMatter($0.kind) ? nil : (kind: $0.kind, text: $0.text) }
        // Only this matter's talk: what was said about another matter would go out with it.
        let earlier: [(question: String, answer: String)] = shown.compactMap { item in
            guard let answer = item.turn.answer, item.turn.note == nil else { return nil }
            return (item.turn.question, answer.reply.lines.map(\.text).joined(separator: " "))
        }
        // The model chosen in Settings, as on the Mac, with the key its service takes.
        let model = ModelChoice.assistant
        guard let claude = ModelChoice.client(for: model) else {
            failure = ModelChoice.missingKey(model)
            return
        }
        let names: (mapping: Pseudonymizer.Mapping, others: [Pseudonymizer.Entry])
        // The demo's people are made up, and no Mac has a list of them: the rules alone disguise
        // what they find. With the owner's own matters, no list means nothing is sent.
        if store.isDemo { names = (Pseudonymizer.Mapping(), []) } else { do { names = try PhoneNames.current(in: context) } catch {
            failure = error.localizedDescription
            return
        } }
        failure = nil
        draft = ""
        let date = Date()
        asking = (question, date)
        let owner = profiles.first?.names.first
        let matter = self.matter
        let context = self.context
        Task {
            do {
                let answer = try await AssistantAsk.ask(question: question, inHand: inHand, earlier: earlier, facts: facts, owner: owner,
                                                        today: today, mapping: names.mapping, others: names.others,
                                                        claude: claude, model: model)
                var turn = Navigation.Turn(question: question, scope: matter.map { "about \($0.name)" } ?? "about all matters",
                                           inHand: pinned, seen: facts.seen, refs: facts.refs, matter: matter?.persistentModelID)
                turn.date = date
                turn.readAs = readAs.map { "read “\($0.typed)” as “\($0.known)”" }
                turn.state = .answered(answer)
                let encoder = JSONEncoder()
                encoder.outputFormatting = .sortedKeys
                let record = ThreadTurn(id: turn.id, date: date, payload: try encoder.encode(turn))
                context.insert(record)
                record.matter = matter
                try context.save()
            } catch {
                failure = "\(error)"
                draft = question
            }
            asking = nil
        }
    }
}

/// The question just sent, while the answer is on its way: the bee at work.
struct PendingTurn: View {
    let question: String
    let scope: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .trailing, spacing: 4) {
                Text(scope).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Text(question)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.honey, in: RoundedRectangle(cornerRadius: 18))
                    .foregroundStyle(.black)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 40)
            HStack(spacing: 8) {
                BeeLoader()
                Text("Sending, pseudonymised …").foregroundStyle(.secondary)
            }
        }
    }
}

/// One question and what came back: lines with their sources, and the cards.
struct PhoneTurnView: View {
    let record: ThreadTurn
    let turn: Navigation.Turn
    let matter: Matter?

    var body: some View {
        if let note = turn.note {
            intake(note)
        } else if turn.hasShot {
            Label("A screenshot, brought in on the Mac", systemImage: "photo").font(.footnote).foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                question
                switch turn.state {
                case .answered(let answer): answered(answer)
                case .failed(let message):
                    Label(message, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(Theme.warning)
                }
            }
        }
    }

    private var question: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(turn.inHand.map { "\(turn.scope) · \($0.kind): \($0.text)" } ?? turn.scope)
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            Text(turn.question)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Theme.honey, in: RoundedRectangle(cornerRadius: 18))
                .foregroundStyle(.black)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 40)
    }

    @ViewBuilder
    private func answered(_ answer: AssistantAsk.Answer) -> some View {
        ForEach(Array(answer.reply.lines.enumerated()), id: \.offset) { _, line in
            VStack(alignment: .leading, spacing: 4) {
                Text(line.text).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                if !line.cites.isEmpty {
                    SourcesLine(cites: line.cites, refs: turn.refs, matter: matter)
                }
            }
        }
        if let missing = answer.reply.notInFacts {
            Label(missing, systemImage: "questionmark.circle").font(.footnote).foregroundStyle(.secondary)
        }
        ForEach(Array(answer.reply.cards.enumerated()), id: \.offset) { index, card in
            PhoneActionCard(record: record, turn: turn, index: index, card: card, matter: matter)
        }
        Text("\(answer.modelLabel) · $\(String(format: "%.3f", answer.cost))").font(.caption2).foregroundStyle(.secondary)
    }

    /// What came in with "Get new mail" on the Mac.
    private func intake(_ text: String) -> some View {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let head = (lines.first ?? "").replacingOccurrences(of: "📥", with: "").trimmingCharacters(in: .whitespaces)
        return VStack(alignment: .leading, spacing: 3) {
            Label(head, systemImage: "tray.and.arrow.down").font(.caption.weight(.semibold))
            ForEach(Array(lines.dropFirst().enumerated()), id: \.offset) { _, line in
                Text(line).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.box, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
    }
}

/// "Sources · 2 ›": what a line was read from, unfolded with a tap. A task named there is found
/// by its id where this store knows it — a thread asked on the Mac names the Mac's own.
struct SourcesLine: View {
    let cites: [String]
    let refs: [String: FactRef]
    let matter: Matter?
    @Environment(\.modelContext) private var context
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { withAnimation(.snappy) { open.toggle() } } label: {
                HStack(spacing: 4) {
                    Text("Sources · \(cites.count)")
                    Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).rotationEffect(.degrees(open ? 90 : 0))
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            if open {
                ForEach(cites, id: \.self) { cite in
                    Text("• " + label(cite)).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func label(_ cite: String) -> String {
        // The Mac's chip words, when this store knows the fact; a thread asked on another device
        // names that device's facts.
        if let ref = refs[cite], CardActions.matter(of: ref, in: context) != nil { return CardActions.label(ref, in: context) }
        switch cite.first {
        case "T": return "a task of the matter"
        case "M": return "a mail of the matter"
        case "D": return "a date of the matter"
        case "P": return "a person of the matter"
        default: return cite
        }
    }
}

/// A card the assistant suggested, as the Mac's ActionCard: what it is about, its words to change
/// before taking it in, why, and its sources; Dismiss, and the one thing it does. What it does is
/// CardActions' — the Mac's own code. A draft opens in Mail, ready to send from there; a card
/// taken in here can be undone while the app is open.
struct PhoneActionCard: View {
    let record: ThreadTurn
    let turn: Navigation.Turn
    let index: Int
    let card: AssistantPrompt.Reply.Card
    let matter: Matter?
    @Environment(Navigation.self) private var navigation
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @State private var text = ""
    @State private var subject = ""
    /// A draft opened in Mail folds to a few lines; "Edit" unfolds it again.
    @State private var editingDraft = false

    private var done: Bool { turn.applied.contains(index) }
    private var dismissed: Bool { turn.dismissedCards.contains(index) }
    private var undo: CardActions.Undo? { navigation.undos[turn.id]?[index] }
    private var editable: Bool { [.newTodo, .renameParty, .changeRole, .correctText, .addNote, .newMatter, .addLink].contains(card.kind) }
    private var recipient: (name: String, address: String?)? { CardActions.recipient(card.party, refs: turn.refs, in: context) }

    var body: some View {
        Group {
            if card.kind == .draftMessage, done, !editingDraft {
                sentDraft
            } else if dismissed, !done {
                HStack {
                    Text("Suggestion dismissed: \(title.lowercased())").font(.caption).foregroundStyle(.secondary)
                    Button("show again") { navigation.mark(record, card: index, dismissed: false, context: context) }
                        .font(.caption).foregroundStyle(Theme.gold)
                    Spacer()
                }
            } else {
                full
            }
        }
        .onAppear { text = card.text; subject = card.subject ?? "" }
    }

    private var full: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(done ? Theme.done : .primary)
            if let what { Text(what).fixedSize(horizontal: false, vertical: true) }
            if card.kind == .draftMessage {
                TextField("Subject", text: $subject)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 6))
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140, maxHeight: 320)
                    .padding(6)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 6))
            } else if editable {
                TextField("", text: $text, axis: .vertical)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 6))
                    .disabled(done)
            }
            Text(card.reason).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !card.cites.isEmpty { SourcesLine(cites: card.cites, refs: turn.refs, matter: matter) }
            if card.kind == .sameParty, !done {
                Text("Later you can only turn merging off for new mail; you cannot split it again.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                if done, card.kind == .draftMessage {
                    Button("Cancel") { withAnimation { editingDraft = false } }.buttonStyle(.phone)
                    Button("Open in Mail") { take(); withAnimation { editingDraft = false } }.buttonStyle(.phoneFilled)
                } else if done {
                    Label("Taken in", systemImage: "checkmark").font(.footnote.weight(.medium)).foregroundStyle(Theme.done)
                    Spacer()
                    if undo != nil { Button("Undo", action: takeBack).buttonStyle(.phone) }
                } else {
                    Button("Dismiss") { withAnimation { navigation.mark(record, card: index, dismissed: true, context: context) } }
                        .buttonStyle(.phone(wide: true))
                    Button(verb) { take() }.buttonStyle(.phone(filled: true, wide: true))
                }
            }
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.box, in: RoundedRectangle(cornerRadius: 12))
    }

    /// What was opened in Mail, short and not to be typed in: who, what about, how it starts.
    private var sentDraft: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Draft · opened in Mail").font(.footnote.weight(.semibold))
            Text("To: \(recipient?.name ?? "—")" + (subject.isEmpty ? "" : " · \(subject)")).font(.subheadline).lineLimit(1)
            Text(text).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            HStack(spacing: 8) {
                Button("Edit") { withAnimation { editingDraft = true } }.buttonStyle(.phone)
                Button("Open again") { take() }.buttonStyle(.phone)
            }
            .padding(.top, 6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.box, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
    }

    /// The answer's matter: one a card beside this one made, the one it was asked in, or the one
    /// its facts come from — as on the Mac.
    private var scope: Matter? {
        let made = navigation.madeMatter[turn.id].flatMap { CardActions.live($0, as: Matter.self, in: context) }
        let cited = card.cites.compactMap { turn.refs[$0] }.compactMap { CardActions.matter(of: $0, in: context) }.first
        return made ?? matter ?? cited
    }

    private func take() {
        switch CardActions.apply(card, text: text, subject: subject, refs: turn.refs, links: turn.answer?.links, scope: scope, in: context) {
        case .nothing:
            return
        case .openMail(let url):
            openURL(url)
            // The version opened is the one kept: the thread remembers what went to Mail.
            navigation.mark(record, card: index, applied: true, text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                            subject: subject, context: context)
        case .madeMatter(let made, let undo):
            navigation.madeMatter[turn.id] = made.persistentModelID
            navigation.undos[turn.id, default: [:]][index] = undo
            navigation.mark(record, card: index, applied: true, context: context)
            navigation.open(made)
        case .taken(let undo):
            navigation.undos[turn.id, default: [:]][index] = undo
            navigation.mark(record, card: index, applied: true, context: context)
        }
    }

    private func takeBack() {
        guard let undo, CardActions.undo(undo, in: context) else { return }
        if case .madeMatter = undo { navigation.madeMatter[turn.id] = nil }
        navigation.undos[turn.id]?[index] = nil
        navigation.mark(record, card: index, applied: false, context: context)
    }

    private func name(_ id: String?) -> String { id.flatMap { turn.refs[$0] }.map { CardActions.label($0, in: context) } ?? "?" }

    private var whose: String { ["me": "Mine", "we": "Ours", "other": "Waiting for"][card.owner] ?? "Unclear whose" }

    /// What the button does, in a word or two.
    private var verb: String {
        switch card.kind {
        case .markDone: "Done"
        case .newTodo: "Add"
        case .sameParty: "Merge"
        case .addNote: "Save note"
        case .draftMessage: "Open in Mail"
        case .changeDate: "Change date"
        case .newMatter: "Create"
        case .waitsFor: "Link"
        case .addLink: "Save link"
        case .renameParty, .changeRole, .correctText, .changeOwner: "Change"
        }
    }

    private var title: String {
        switch card.kind {
        case .markDone: return "Done?"
        case .newTodo: return "New task? · " + whose + (card.due.map { " · by \(Dates.short($0))" } ?? "")
        case .sameParty: return "Same person?"
        case .renameParty: return "Change name?"
        case .changeRole: return "Change role?"
        case .addNote: return "Note for the task?"
        case .draftMessage: return "Draft"
        case .changeDate: return "Change date?"
        case .newMatter: return "New matter?"
        case .waitsFor: return "Waits for another task?"
        case .addLink: return "Save link? · Name:"
        case .correctText: return "Replace in the text?"
        case .changeOwner: return "Whose task? → " + whose
        }
    }

    /// The line above the field: what the card is about.
    private var what: String? {
        switch card.kind {
        case .markDone: return card.text
        case .newTodo: return nil
        case .sameParty: return "\(name(card.party))  →  \(name(card.into))"
        case .renameParty: return "\(name(card.party))  is called:"
        case .changeRole: return "\(name(card.party))  is here:"
        case .addNote: return name(card.todo)
        case .draftMessage:
            guard let recipient else { return "To: (fill in in Mail)" }
            return "To: \(recipient.name)" + (recipient.address.map { " <\($0)>" } ?? " — address not known, fill it in in Mail")
        case .correctText: return "“\(card.from ?? "")”  becomes:"
        case .newMatter: return nil
        case .waitsFor: return "\(name(card.todo))  →  only after: \(name(card.into))"
        case .addLink: return card.todo == nil ? "to the matter" : "to: \(name(card.todo))"
        case .changeDate:
            let when = (card.due.map(Dates.short) ?? "?") + (card.time.map { " at \($0)" } ?? "")
            return "\(name(card.todo))  →  \(when)"
        case .changeOwner: return name(card.todo)
        }
    }
}
