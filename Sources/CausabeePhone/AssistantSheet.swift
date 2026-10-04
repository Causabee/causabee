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
    /// A new field after each send. Emptying the words is not enough while the keyboard still
    /// holds some of them — dictation, a word being autocorrected: the old field kept showing
    /// them, and with the words gone from `draft` nothing could be sent again.
    @State private var fieldKey = 0
    @FocusState private var typing: Bool
    /// The question on its way, until its answer is in the thread.
    @State private var asking: (question: String, date: Date)?
    /// What asking is doing now, and since when the question is out.
    @State private var step = AssistantAsk.Step.disguising
    @State private var sentAt: Date?
    /// The task that asks: Stop cancels it.
    @State private var ask: Task<Void, Never>?
    @State private var failure: String?
    /// The footer in full — what is seen and where it goes — or only that it goes pseudonymised.
    @State private var showsMore = false
    /// Scrolled up from the newest: a button over the thread's lower edge brings it down again.
    @State private var scrolledUp = false
    /// An answer that arrived while the thread was scrolled up: the thread stays where it is being
    /// read, and the button says "New answer" and goes to where the answer begins.
    @State private var newAnswer: UUID?

    /// What a question here would take along: worked out only when the footer is opened.
    private var seen: String {
        FactSheet.facts(for: matter.map { [$0] } ?? activeMatters(matters), today: MatterStatus.day(Date())).seen
    }

    private var shown: [(record: ThreadTurn, turn: Navigation.Turn)] {
        records
            .filter { matter == nil || $0.matter?.persistentModelID == matter?.persistentModelID }
            .compactMap { record in navigation.turn(record).map { (record, $0) } }
    }

    private static let bottom = "thread-bottom"

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollViewReader { scroller in
                ScrollView {
                    // Laid out whole, not lazily: rows measured only as they came into view made the
                    // thread jump while scrolling. A matter's thread is short enough.
                    VStack(alignment: .leading, spacing: 20) {
                        let turns = shown
                        if turns.isEmpty {
                            Text(matter == nil ? "Nothing asked yet." : "Nothing asked about this matter yet.")
                                .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 40)
                        }
                        ForEach(Array(turns.enumerated()), id: \.element.turn.id) { index, item in
                            if index == 0 || !Calendar.current.isDate(turns[index - 1].turn.date, inSameDayAs: item.turn.date) {
                                Text(item.turn.date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "en_US"))))
                                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                                    .padding(.top, index == 0 ? 16 : 24)
                            }
                            PhoneTurnView(record: item.record, turn: item.turn, matter: item.record.matter)
                                .id(item.turn.id)
                        }
                        // Files brought in here: read on the iPhone, sorted in on a yes.
                        ForEach(PhoneShots.shared.shots.filter { matter == nil || $0.matter == nil || $0.matter == matter?.persistentModelID }) { shot in
                            PhoneShotCard(shot: shot).id(shot.id)
                        }
                        if let asking {
                            PendingTurn(question: asking.question, step: step, sentAt: sentAt)
                                .id("asking")
                        }
                        if let failure {
                            // The question is back in the field: sending it is trying again.
                            VStack(alignment: .leading, spacing: 8) {
                                Label(failure, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(Theme.warning)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button(action: send) { Label("Try again", systemImage: "arrow.clockwise") }
                                    .font(.footnote.weight(.medium)).foregroundStyle(Theme.gold).buttonStyle(.plain)
                            }
                            .id("failure")
                        }
                        Color.clear.frame(height: 1).id(Self.bottom)
                    }
                    .padding(16)
                    .containerRelativeFrame(.horizontal)
                }
                .defaultScrollAnchor(.bottom)
                // The keyboard goes when the thread is scrolled or tapped, to see all of it.
                .dismissesKeyboard()
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.visibleRect.maxY < geometry.contentSize.height - 60
                } action: { _, up in
                    withAnimation(.easeOut(duration: 0.15)) { scrolledUp = up }
                    // Down at the newest again: the answer has been reached.
                    if !up { newAnswer = nil }
                }
                .overlay(alignment: .bottom) {
                    if scrolledUp {
                        Button {
                            withAnimation {
                                if let newAnswer { scroller.scrollTo(newAnswer, anchor: .top) } else { scroller.scrollTo(Self.bottom, anchor: .bottom) }
                                newAnswer = nil
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: newAnswer != nil ? "arrow.down" : "chevron.down").font(.body.weight(.semibold))
                                if newAnswer != nil { Text("New answer").font(.subheadline.weight(.medium)) }
                            }
                            .foregroundStyle(newAnswer != nil ? .primary : .secondary)
                            .padding(.horizontal, newAnswer != nil ? 16 : 0)
                            .frame(minWidth: 40, minHeight: 40)
                            .background(.regularMaterial, in: Capsule())
                            .overlay(Capsule().stroke(Theme.line))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(newAnswer != nil ? "To the new answer" : "To the newest")
                        .padding(.bottom, 10)
                        .transition(.opacity)
                    }
                }
                .onAppear { if let last = shown.last { scroller.scrollTo(last.turn.id, anchor: .bottom) } }
                .onChange(of: PhoneShots.shared.shots.count) { if let last = PhoneShots.shared.shots.last { withAnimation { scroller.scrollTo(last.id, anchor: .bottom) } } }
                // A question just asked is followed down, wherever the thread was.
                .onChange(of: asking?.date) {
                    guard asking != nil else { return }
                    newAnswer = nil
                    withAnimation { scroller.scrollTo("asking", anchor: .bottom) }
                }
                // The answer — or a turn the Mac added — from where it begins, unless the thread is
                // being read further up: then it stays, and the button says there is a new answer.
                .onChange(of: shown.count) { old, new in
                    guard new > old, let last = shown.last else { return }
                    if scrolledUp { newAnswer = last.turn.id } else { withAnimation { scroller.scrollTo(last.turn.id, anchor: .top) } }
                }
                // A question that could not go out says why, where it can be seen.
                .onChange(of: failure) { if failure != nil { withAnimation { scroller.scrollTo("failure", anchor: .bottom) } } }
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
                Text("Causabee").font(.headline)
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
                // What is in hand, on a pale honey: the pin and its kind in gold, the words as any
                // words — as on the Mac. Calm, so the send button stays the one yellow thing.
                HStack(spacing: 8) {
                    Image(systemName: "pin.fill").font(.caption).foregroundStyle(Theme.gold)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(pinned.kind.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(Theme.gold)
                        Text(pinned.text).lineLimit(2).foregroundStyle(.primary)
                    }
                    Spacer()
                    Button { navigation.pinned = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Put it down")
                }
                .padding(10)
                .background(Theme.beeSoft, in: RoundedRectangle(cornerRadius: 10))
            }
            // As on the Mac: the send button sits in the pill's round end, as far from the right as
            // from the top and bottom, and the corner's radius is that and half the button — 7 + 34 / 2.
            HStack(alignment: .bottom, spacing: 6) {
                AttachButton(matter: matter)
                TextField(matter.map { "Ask about \($0.name)" } ?? "Ask about your matters", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    // The keyboard's Return starts a new line; the button sends. With a keyboard
                    // of keys, Return sends and Shift-Return starts a new line, as on the Mac.
                    .onKeyPress(.return, phases: .down) { press in
                        if press.modifiers.contains(.shift) || press.modifiers.contains(.option) { return .ignored }
                        send()
                        return .handled
                    }
                    .focused($typing)
                    .id(fieldKey)
                    // One line sits in the middle of the send button; more lines grow upwards.
                    .frame(minHeight: 34)
                Button { if asking == nil { send() } else { stop() } } label: {
                    // A black arrow on the bee's yellow, drawn light, as every yellow thing has black
                    // on it — and a black square while an answer is on its way: one question at a time.
                    SendGlyph(stops: asking != nil)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(asking == nil ? "Send" : "Stop")
            }
            .padding(.leading, 7).padding(.trailing, 7).padding(.vertical, 7)
            .background(Theme.box, in: RoundedRectangle(cornerRadius: 24))
            // As on the Mac: "more" and "less" are links inside the line, so the full one wraps like a sentence.
            Text(LocalizedStringKey(showsMore
                ? "Always pseudonymised sent to \(ModelChoice.assistant.label) • Sees: \(seen) · goes pseudonymised, like the mails • [less](causabee://footer)"
                : "Always pseudonymised sent • [more](causabee://footer)"))
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
        Haptics.tap()
        let scope = matter.map { [$0] } ?? activeMatters(matters)
        let (question, readAs) = NameHints.correct(typed, knowing: scope.flatMap { $0.parties.map(\.name) })
        let today = MatterStatus.day(Date())
        let pinned = navigation.pinned
        let place = PhoneCloud.storeLocation()
        let facts = FactSheet.facts(for: scope, today: today, focus: pinned.flatMap { Navigation.Pinned.isMatter($0.kind) ? nil : $0.text },
                                    keptText: { MailText.load($0.messageID, besides: place)?.body })
        let inHand = pinned.flatMap { Navigation.Pinned.isMatter($0.kind) ? nil : (kind: $0.kind, text: $0.text) }
        // Only this matter's talk: what was said about another matter would go out with it.
        let earlier: [(question: String, answer: String)] = shown.compactMap { item in
            guard let answer = item.turn.answer, item.turn.note == nil else { return nil }
            return (item.turn.question, answer.reply.lines.map(\.text).joined(separator: " "))
        }
        // The model chosen in Settings, as on the Mac, with the key its service takes.
        let model = ModelChoice.assistant
        guard let claude = ModelChoice.client(for: model) else {
            Haptics.failure()
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
        // The keyboard lets go of what it holds first, then the field starts afresh, empty.
        typing = false
        draft = ""
        fieldKey += 1
        // The new field keeps the keyboard, as in Messages.
        DispatchQueue.main.async { typing = true }
        let date = Date()
        asking = (question, date)
        step = .disguising
        sentAt = nil
        let owner = profiles.first?.names.first
        let matter = self.matter
        let context = self.context
        // The steps are said away from the screen, and read here.
        let (steps, said) = AsyncStream.makeStream(of: AssistantAsk.Step.self)
        Task {
            for await next in steps where asking?.date == date {
                step = next
                if next == .waiting { sentAt = Date() }
            }
        }
        ask = Task {
            defer { said.finish() }
            do {
                let answer = try await AssistantAsk.ask(question: question, inHand: inHand, earlier: earlier, facts: facts, owner: owner,
                                                        today: today, mapping: names.mapping, others: names.others,
                                                        claude: claude, model: model) { said.yield($0) }
                // Stopped while the answer was coming: it is not put into the thread.
                guard !Task.isCancelled else { return }
                var turn = Navigation.Turn(question: question, scope: matter.map { "about \($0.name)" } ?? "about all matters",
                                           inHand: pinned, seen: facts.seen, refs: facts.refs, matter: matter?.persistentModelID)
                turn.date = date
                turn.keys = CardActions.keys(of: facts.refs, in: context)
                turn.readAs = readAs.map { "read “\($0.typed)” as “\($0.known)”" }
                turn.state = .answered(answer)
                let encoder = JSONEncoder()
                encoder.outputFormatting = .sortedKeys
                let record = ThreadTurn(id: turn.id, date: date, payload: try encoder.encode(turn))
                context.insert(record)
                record.matter = matter
                try context.save()
                Haptics.success()
            } catch {
                guard !Task.isCancelled else { return }
                Haptics.failure()
                failure = "\(error)"
                draft = question
                fieldKey += 1
            }
            asking = nil
        }
    }

    /// Stops the question on its way. Nothing comes back for it, and it is in the field again, to
    /// change or to send once more — unless something else was typed meanwhile.
    private func stop() {
        guard let asking else { return }
        Haptics.stop()
        ask?.cancel()
        ask = nil
        self.asking = nil
        if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft = asking.question
            fieldKey += 1
        }
    }
}

/// The question just sent, while the answer is on its way: the bee at work.
struct PendingTurn: View {
    let question: String
    let step: AssistantAsk.Step
    let sentAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(question)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Theme.honey, in: RoundedRectangle(cornerRadius: 18))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, 40)
            AskSteps(step: step, sentAt: sentAt, size: 12)
        }
    }
}

/// One question and what came back: lines with their sources, and the cards.
struct PhoneTurnView: View {
    let record: ThreadTurn
    let turn: Navigation.Turn
    let matter: Matter?
    /// Just copied: the button says so for a moment.
    @State private var copied = false
    /// Kept as a note of its matter: the button says so, and does not keep it twice.
    @State private var savedNote = false
    /// The answer's sources, unfolded: one list for the whole answer.
    @State private var showsSources = false
    @Environment(Navigation.self) private var navigation
    @Environment(\.modelContext) private var context

    var body: some View {
        if let note = turn.note {
            intake(note)
        } else if turn.hasShot {
            Label("A screenshot, brought in on the Mac", systemImage: "photo").font(.footnote).foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                question
                switch turn.state {
                case .answered(let answer): answered(answer)
                case .failed(let message):
                    // Stopped by the owner is no failure: said quietly.
                    if AssistantAsk.wasStopped(message) {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Label(message, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(Theme.warning)
                    }
                }
            }
        }
    }

    private var question: some View {
        Text(turn.question)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Theme.honey, in: RoundedRectangle(cornerRadius: 18))
            .foregroundStyle(.black)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 40)
    }

    private func answered(_ answer: AssistantAsk.Answer) -> some View {
        // What the answer and its cards rest on, each once, in the order it is cited.
        let cites = (answer.reply.lines.flatMap(\.cites) + answer.reply.cards.flatMap(\.cites))
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(answer.reply.lines.enumerated()), id: \.offset) { _, line in
                Text(line.text).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
            // What the facts do not say is part of the answer, said like the rest of it — not a notice.
            if let missing = answer.reply.notInFacts {
                Text(missing).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(answer.reply.cards.enumerated()), id: \.offset) { index, card in
                PhoneActionCard(record: record, turn: turn, index: index, card: card, matter: matter)
            }
            // One line under the answer: copy it, what it rests on — and what it cost.
            HStack(spacing: 6) {
                Button {
                    UIPasteboard.general.string = answer.plainText
                    Haptics.tap()
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.footnote).foregroundStyle(.secondary)
                        .frame(width: 32, height: 32).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(copied ? "Copied" : "Copy the answer")
                // An answer about one matter can be kept with it, as a note.
                if let matter {
                    Button {
                        NotesPart.keep(answer.plainText, in: matter, context: context)
                        Haptics.success()
                        savedNote = true
                    } label: {
                        Image(systemName: savedNote ? "checkmark" : "note.text.badge.plus").font(.footnote).foregroundStyle(.secondary)
                            .frame(width: 32, height: 32).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(savedNote)
                    .accessibilityLabel(savedNote ? "Saved as note" : "Save as note")
                }
                if !cites.isEmpty {
                    Button { withAnimation(.snappy) { showsSources.toggle() } } label: {
                        HStack(spacing: 4) {
                            Text("Sources (\(cites.count))")
                            Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).rotationEffect(.degrees(showsSources ? 90 : 0))
                        }
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(minHeight: 32).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 8)
                Text("$\(String(format: "%.3f", answer.cost))").font(.caption2).foregroundStyle(.secondary)
                    .accessibilityLabel("\(answer.modelLabel), $\(String(format: "%.3f", answer.cost))")
            }
            .padding(.leading, -8)
            .padding(.vertical, -6)
            if showsSources, !cites.isEmpty {
                // A tap closes the assistant and shows that very mail, task or date in its matter.
                SourceList(cites: cites, refs: turn.refs) { ref in
                    if let target = CardActions.matter(of: ref, in: context) { navigation.open(target, showing: CardActions.row(of: ref)) }
                }
                .padding(.top, 4)
            }
        }
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
        // Nothing to decide here, only to read: white, as a card taken in — grey is what waits.
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
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

    /// In its own state and size from the first frame: a card that came in full and shrank — or
    /// got its words a moment later — made the thread jump while scrolling past it.
    init(record: ThreadTurn, turn: Navigation.Turn, index: Int, card: AssistantPrompt.Reply.Card, matter: Matter?) {
        (self.record, self.turn, self.index, self.card, self.matter) = (record, turn, index, card, matter)
        _text = State(initialValue: card.text)
        _subject = State(initialValue: card.subject ?? "")
        _quiet = State(initialValue: turn.applied.contains(index))
    }
    @Environment(Navigation.self) private var navigation
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @State private var text = ""
    @State private var subject = ""
    /// A draft opened in Mail folds to a few lines; "Edit" unfolds it again.
    @State private var editingDraft = false
    /// Taken in, the card turns into its small quiet box in three steps, so nothing jumps: its
    /// content fades out, the empty grey box closes to its new size — the thread moving with it —
    /// and the new content fades in. Undo and Edit go back the same way.
    @Namespace private var morph
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Shown small: follows "taken in", changed only inside `step`.
    @State private var quiet = false
    @State private var showsContent = true

    /// Out, change, in. With Reduce Motion: a short cross-fade.
    private func step(_ change: @escaping () -> Void) {
        if reduceMotion { withAnimation(.easeInOut(duration: 0.2), change); return }
        withAnimation(.easeOut(duration: 0.14)) { showsContent = false } completion: {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) { change() } completion: {
                withAnimation(.easeIn(duration: 0.16)) { showsContent = true }
            }
        }
    }

    private var done: Bool { turn.applied.contains(index) }
    private var dismissed: Bool { turn.dismissedCards.contains(index) }
    private var undo: CardActions.Undo? { navigation.undos[turn.id]?[index] }
    private var editable: Bool { [.newTodo, .renameParty, .changeRole, .correctText, .addNote, .newMatter, .addLink].contains(card.kind) }
    private var mailInHand: String? { turn.inHand.flatMap { $0.kind == "Mail" ? $0.text : nil } }
    private var recipient: (name: String, address: String?)? {
        CardActions.recipient(card.party, refs: turn.refs, question: turn.question, mail: mailInHand, scope: scope, in: context)
    }

    var body: some View {
        Group {
            if card.kind == .draftMessage, quiet, !editingDraft {
                sentDraft
            } else if quiet {
                taken
            } else if dismissed, !done {
                // Put aside, not gone: a small white card — nothing waits in it — that says what was
                // suggested, and brings it back.
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You dismissed this suggestion").font(.caption2)
                        Text(card.text.isEmpty ? title : card.text).font(.footnote)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("Show again") { navigation.mark(record, card: index, dismissed: false, context: context) }
                        .font(.footnote.weight(.medium)).foregroundStyle(Theme.gold).buttonStyle(.plain).fixedSize()
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
            } else {
                full
            }
        }
        // Undo plays it backwards; with Reduce Motion it is a short cross-fade. Taken in or out on
        // another device, it changes the same way.

        .onChange(of: done) { if quiet != done { step { quiet = done; editingDraft = false } } }
    }

    private var full: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.primary)
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
            if card.kind == .sameParty, !done {
                Text("Later you can only turn merging off for new mail; you cannot split it again.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                if quiet, card.kind == .draftMessage {
                    Button("Cancel") { step { editingDraft = false } }.buttonStyle(.phone)
                    Button("Open in Mail") { take() }.buttonStyle(.phoneFilled)
                } else if quiet {
                    Label("Taken in", systemImage: "checkmark").font(.footnote.weight(.medium)).foregroundStyle(Theme.done)
                    Spacer()
                    if undo != nil { Button("Undo", action: takeBack).buttonStyle(.phone) }
                } else {
                    Button("Dismiss") { Haptics.tap(); withAnimation { navigation.mark(record, card: index, dismissed: true, context: context) } }
                        .buttonStyle(.phone(wide: true))
                    Button(verb) { take() }.buttonStyle(.phone(filled: true, wide: true))
                }
            }
            .padding(.top, 4)
        }
        .opacity(showsContent ? 1 : 0)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { RoundedRectangle(cornerRadius: 12).fill(Theme.box).matchedGeometryEffect(id: "box", in: morph, isSource: !quiet || editingDraft) }
        .transition(.opacity)
    }

    /// A card taken in, small and quiet: what was done, what kind, and Undo while the app is open.
    /// The reason and the sources stay with what it made; a tap opens that in its matter.
    private var taken: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "checkmark").font(.footnote.weight(.semibold)).foregroundStyle(Theme.done)
            VStack(alignment: .leading, spacing: 2) {
                Text(takenWhat).font(.subheadline.weight(.medium)).foregroundStyle(.primary).lineLimit(2)
                Text(takenKind).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if undo != nil {
                Button("Undo", action: takeBack).font(.footnote.weight(.medium)).foregroundStyle(Theme.gold).buttonStyle(.plain)
            }
        }
        .opacity(showsContent ? 1 : 0)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background { RoundedRectangle(cornerRadius: 12).fill(Theme.card).matchedGeometryEffect(id: "box", in: morph, isSource: quiet && !editingDraft) }
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
        .transition(.opacity)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(perform: openTaken)
        .accessibilityAddTraits(.isButton)
    }

    /// What the card did, in its own words.
    private var takenWhat: String {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? card.text : text
        switch card.kind {
        case .sameParty: return "\(name(card.party))  →  \(name(card.into))"
        case .waitsFor, .changeOwner: return name(card.todo)
        default: return words
        }
    }

    /// What kind of thing it was, and the little that tells it apart.
    private var takenKind: String {
        switch card.kind {
        case .newTodo: return "Task added · " + whose + (card.due.map { " · by \(Dates.short($0))" } ?? "")
        case .markDone: return "Marked done"
        case .sameParty: return "Merged into one person"
        case .renameParty: return "Name changed"
        case .changeRole: return "Role changed · " + name(card.party)
        case .addNote: return "Note added · " + name(card.todo)
        case .changeDate: return "Date changed"
        case .newMatter: return "Matter started"
        case .waitsFor: return "Now waits for " + name(card.into)
        case .addLink: return "Link saved"
        case .correctText: return "Text corrected"
        case .changeOwner: return "Now " + whose.lowercased()
        case .draftMessage: return "Opened in Mail"
        }
    }

    /// Into its matter, at the task it made or changed when there is one.
    private func openTaken() {
        guard let target = scope ?? matter else { return }
        var todo: PersistentIdentifier?
        if case .remove(let id) = undo { todo = id }
        if todo == nil, let ref = card.todo.flatMap({ turn.refs[$0] }), case .todo(let id) = ref { todo = id }
        if todo == nil, card.kind == .newTodo {
            let words = takenWhat.lowercased()
            todo = target.openTodos.first { $0.text.lowercased() == words }?.persistentModelID
        }
        navigation.open(target, showing: todo)
    }

    /// What was opened in Mail, as small and quiet as a card taken in: its subject, where it went
    /// and to whom. A tap opens it in Mail again; Edit unfolds it. Opened is not sent: the
    /// envelope, not a tick.
    private var sentDraft: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "envelope").font(.footnote).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(subject.isEmpty ? text : subject).font(.subheadline.weight(.medium)).foregroundStyle(.primary).lineLimit(2)
                Text("Draft opened in Mail · To: \(recipient?.name ?? "—")").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Edit") { step { editingDraft = true } }
                .font(.footnote.weight(.medium)).foregroundStyle(Theme.gold).buttonStyle(.plain)
        }
        .opacity(showsContent ? 1 : 0)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background { RoundedRectangle(cornerRadius: 12).fill(Theme.card).matchedGeometryEffect(id: "box", in: morph, isSource: quiet && !editingDraft) }
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
        .transition(.opacity)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { take() }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens it in Mail again")
    }

    /// The answer's matter: one a card beside this one made, the one it was asked in, or the one
    /// its facts come from — as on the Mac.
    private var scope: Matter? {
        let made = navigation.madeMatter[turn.id].flatMap { CardActions.live($0, as: Matter.self, in: context) }
        let cited = card.cites.compactMap { turn.refs[$0] }.compactMap { CardActions.matter(of: $0, in: context) }.first
        return made ?? matter ?? cited
    }

    private func take() {
        switch CardActions.apply(card, text: text, subject: subject, refs: turn.refs, links: turn.answer?.links, scope: scope,
                                 question: turn.question, mail: mailInHand, in: context) {
        case .nothing:
            return
        case .openMail(let url):
            Haptics.tap()
            openURL(url)
            // Opened again from the small box: it stays small. Edited and opened: it folds.
            if editingDraft { step { editingDraft = false } }
            // The version opened is the one kept: the thread remembers what went to Mail.
            navigation.mark(record, card: index, applied: true, text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                            subject: subject, context: context)
        case .madeMatter(let made, let undo):
            Haptics.success()
            navigation.madeMatter[turn.id] = made.persistentModelID
            navigation.undos[turn.id, default: [:]][index] = undo
            navigation.mark(record, card: index, applied: true, context: context)
            navigation.open(made)
        case .taken(let undo):
            Haptics.success()
            navigation.undos[turn.id, default: [:]][index] = undo
            navigation.mark(record, card: index, applied: true, context: context)
        }
    }

    private func takeBack() {
        guard let undo, CardActions.undo(undo, in: context) else { return }
        Haptics.tap()
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
