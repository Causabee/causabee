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
    /// How wide the thread's scroll view is, measured: it follows an iPad's window as it is resized.
    @State private var threadWidth = CGFloat.zero
    /// A new field after each send. Emptying the words is not enough while the keyboard still
    /// holds some of them — dictation, a word being autocorrected: the old field kept showing
    /// them, and with the words gone from `draft` nothing could be sent again.
    @State private var fieldKey = 0
    @FocusState private var typing: Bool
    /// A field nobody sees, which holds the keyboard for the moment the real one is made anew after
    /// a send: without it the keyboard began to go and came back, and everything over it dipped.
    @FocusState private var keepsKeyboard: Bool
    /// The question on its way, until its answer is in the thread. Its id is its turn's: asked and
    /// answered, it is one thing in the thread, in one place.
    @State private var asking: (id: UUID, question: String, date: Date)?
    /// What asking is doing now, and since when the question is out.
    @State private var step = AssistantAsk.Step.disguising
    @State private var sentAt: Date?
    /// The task that asks: Stop cancels it.
    @State private var ask: Task<Void, Never>?
    @State private var failure: String?
    /// The footer in full — what is seen and where it goes — or only that it goes pseudonymised.
    @State private var showsMore = false
    @State private var voice = VoiceInput()
    @State private var cursor: TextSelection?
    /// Where the thread stands, and when it moves by itself: `ThreadPlacement` has the rule, for the
    /// iPhone and the Mac.
    @State private var placement = ThreadPlacement()
    /// A turn kept with nothing asked — a task, a note — and the turn an answer just came for.
    @State private var kept: UUID?
    @State private var answered: UUID?

    private static let topRoom: CGFloat = 16
    private static let padding: CGFloat = 16
    /// What a question here would take along: worked out only when the footer is opened.
    private var seen: String {
        FactSheet.facts(for: matter.map { [$0] } ?? activeMatters(matters), today: MatterStatus.day(Date())).seen
    }

    private var shown: [(record: ThreadTurn, turn: Navigation.Turn)] {
        records
            .filter { matter == nil || $0.matter?.persistentModelID == matter?.persistentModelID }
            .compactMap { record in navigation.turn(record).map { (record, $0) } }
            // Only what was asked and brought in. That mail was taken in is said on the overview, and
            // the mail is in its matter: a line for it here, too, said it a third time.
            .filter { $0.1.note == nil }
    }

    /// What the thread holds, in the order it happened.
    private enum Entry: Identifiable {
        case turn(ThreadTurn, Navigation.Turn)
        case shot(PhoneShots.Shot)
        /// The question on its way: where its turn will stand, under the same id.
        case pending(UUID, String, Date)
        var id: UUID {
            switch self { case .turn(_, let turn): turn.id; case .shot(let shot): shot.id; case .pending(let id, _, _): id }
        }
        var date: Date {
            switch self { case .turn(_, let turn): turn.date; case .shot(let shot): shot.date; case .pending(_, _, let date): date }
        }
    }

    private var shots: [PhoneShots.Shot] {
        PhoneShots.shared.shots.filter { matter == nil || $0.matter == nil || $0.matter == matter?.persistentModelID }
    }

    private var entries: [Entry] {
        var all = shown.map { Entry.turn($0.record, $0.turn) } + shots.map { Entry.shot($0) }
        // The question on its way, until its turn is there under the same id.
        if let asking, !all.contains(where: { $0.id == asking.id }) { all.append(.pending(asking.id, asking.question, asking.date)) }
        // By their time, and two of the same moment always the same way round.
        return all.sorted { ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString) }
    }

    /// The newest: the question on its way, else the thread's last.
    private var newestID: UUID? { asking?.id ?? entries.last?.id }

    var body: some View {
        VStack(spacing: 0) {
            header
            // A column on the iPad has no bar of its own: its name and its × stand on the page's ground.
            if !navigation.isPad { Divider() }
            ScrollViewReader { scroller in
            ScrollView {
                // Laid out whole, not lazily: a matter's thread is short enough.
                VStack(alignment: .leading, spacing: 20) {
                    let entries = entries
                    if entries.isEmpty {
                        Text(matter == nil ? "Nothing asked yet." : "Nothing asked about this matter yet.")
                            .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 40)
                        if let failure { failed(failure) }
                    }
                    // One line of time: what was asked and what was brought in, each where it
                    // happened — a file's card is not under everything asked after it.
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        let newest = entry.id == newestID
                        VStack(alignment: .leading, spacing: 20) {
                            if index == 0 || !Calendar.current.isDate(entries[index - 1].date, inSameDayAs: entry.date) {
                                Text(entry.date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "en_US"))))
                                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                                    .padding(.top, index == 0 ? 0 : 4)
                            }
                            switch entry {
                            case .turn(let record, let turn): PhoneTurnView(record: record, turn: turn, matter: record.matter)
                            // A file brought in here: read on the iPhone, sorted in on a yes.
                            case .shot(let shot): PhoneShotCard(shot: shot)
                            case .pending(_, let question, _): PendingTurn(question: question, step: step, sentAt: sentAt)
                            }
                            // A question that could not go out says why, under the newest.
                            if newest, let failure { failed(failure) }
                        }
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in if newest { placement.own(height, with: scroller) } }
                        // The newest is at least as tall as the screen shows: it can stand at the top,
                        // and its answer grows into the room under it.
                        .modifier(TallAsThread(on: newest))
                        .id(entry.id)
                        // What has just come fades in — by itself: the thread's layout changes at once.
                        // A question just sent comes up from the field instead.
                        .modifier(FadesIn(fresh: Date().timeIntervalSince(entry.date) < 3 && entry.id != asking?.id))
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .scrollView(axis: .vertical)) } action: { frame in
                            placement.laidOut(AnyHashable(entry.id), at: frame, newest: newest, with: scroller)
                        }
                    }
                }
                .padding(Self.padding)
                .asWide(as: threadWidth)
                .environment(\.threadRoom, placement.viewport)
            }
            .tellsItsWidth($threadWidth)
            // The thread's top stands a little under the edge: what is put "at the top" keeps that room.
            .safeAreaPadding(.top, Self.topRoom)
            // The keyboard goes when the thread is scrolled or tapped, to see all of it.
            .dismissesKeyboard()
            // What happens to the thread is told to the placement, which decides where it goes.
            .onScrollGeometryChange(for: CGFloat.self) { $0.containerSize.height } action: { _, height in placement.room(height, with: scroller) }
            .onScrollPhaseChange { old, new, context in placement.finger(from: old, to: new, at: context.geometry.contentOffset.y) }
            .overlay(alignment: .bottom) {
                // Away from the newest: the way back — and "New answer", when one came meanwhile.
                if placement.offersButton {
                    let newAnswer = placement.newAnswer != nil
                    Button { placement.button(newestID.map { AnyHashable($0) }, with: scroller) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: newAnswer ? "arrow.down" : "chevron.down").font(.body.weight(.semibold))
                            if newAnswer { Text("New answer").font(.subheadline.weight(.medium)) }
                        }
                        .foregroundStyle(newAnswer ? .primary : .secondary)
                        .padding(.horizontal, newAnswer ? 16 : 0)
                        .frame(minWidth: 40, minHeight: 40)
                        .background(.regularMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Theme.line))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(newAnswer ? "To the new answer" : "To the newest")
                    .accessibilityIdentifier("thread.toNewest")
                    .padding(.bottom, 10)
                    .transition(.opacity)
                }
            }
            .animation(ThreadPlacement.glide, value: failure)
            .animation(.easeOut(duration: 0.15), value: placement.offersButton)
            // Opened; sent or brought in; something new as the thread's last — an answer, a task
            // kept at once, a turn from the Mac; the keyboard.
            .onAppear { placement.opened(newestID.map { AnyHashable($0) }, with: scroller) }
            .onChange(of: asking?.id) { if let asking { placement.follow(AnyHashable(asking.id), with: scroller) } }
            .onChange(of: shots.count) { old, new in if new > old { placement.follow(newestID.map { AnyHashable($0) }, with: scroller) } }
            .onChange(of: entries.last?.id) { old, new in
                guard let new, new != old, new != asking?.id else { return }
                // A task or a note kept with nothing asked is the owner's own doing.
                if kept == new { placement.follow(AnyHashable(new), with: scroller) }
                else { placement.arrived(AnyHashable(new), newest: newestID.map { AnyHashable($0) }, with: scroller) }
            }
            .onChange(of: answered) { if let answered { placement.arrived(AnyHashable(answered), newest: newestID.map { AnyHashable($0) }, with: scroller) } }
            .onChange(of: typing) { placement.typing(typing, with: scroller) }
            }
            composer
        }
        .background(Theme.canvas)
        .onAppear {
            // What was in hand from another matter is put down; words to send go into the field.
            if let pinned = navigation.pinned, pinned.matter != matter?.persistentModelID { navigation.pinned = nil }
            if let prefill = navigation.prefill { draft = prefill; navigation.prefill = nil }
            // The speech model into memory now, if it is on the iPhone: what is said next is then
            // written down without waiting for it.
            Task { await Transcriber.shared.warmUp() }
        }
    }

    /// The question is back in the field: sending it is trying again.
    private func failed(_ failure: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(failure, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(Theme.warning)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: send) { Label("Try again", systemImage: "arrow.clockwise") }
                .font(.footnote.weight(.medium)).foregroundStyle(Theme.gold).buttonStyle(.plain)
        }
        .transition(.opacity)
    }

    private var header: some View {
        ZStack {
            VStack(spacing: 2) {
                Text("Causabee").font(.headline)
                Text(matter?.name ?? "All matters").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(.horizontal, 60)
            HStack {
                // A column on the iPad: put away at its outer edge, as the Mac's.
                if navigation.isPad { Spacer() }
                Button { navigation.closeAssistant() } label: {
                    Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .onGlass(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                if !navigation.isPad { Spacer() }
            }
        }
        // On the iPad on the line of the page's bar and the sidebar's controls.
        .padding(.horizontal, 16).padding(.top, navigation.isPad ? 0 : 18).padding(.bottom, navigation.isPad ? 0 : 10)
        .frame(height: navigation.isPad ? PadMetrics.bar : nil)
    }

    /// The field as the Mac has it: what is typed goes out pseudonymised, and only on send.
    private var composer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let pinned = navigation.pinned {
                // What is in hand, on a pale honey: the pin and its kind in gold, the words as any
                // words — as on the Mac. Calm, so the send button stays the one yellow thing.
                HStack(spacing: 8) {
                    Image(systemName: AssistantAdd(rawValue: pinned.kind) == nil ? "pin.fill" : "plus").font(.caption).foregroundStyle(Theme.gold)
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
            // `--demo --shot listening`: the picture of the field while it listens.
            Color.clear.frame(height: 0).onAppear { if PhoneShot.isListening { voice.stageListening() } }
            if voice.asksModel { SpeechModelCard(voice: voice) }
            if let problem = voice.problem {
                Text(problem).font(.caption).foregroundStyle(Theme.warning).padding(.horizontal, 8)
            }
            HStack(alignment: .bottom, spacing: 6) {
              if voice.phase == .listening {
                ListeningBar(voice: voice)
              } else {
                // "Task" or "Note" picked: the chip says what comes; to type or to speak is chosen after.
                AttachButton(matter: matter)
                    .background {
                        TextField("", text: .constant("")).focused($keepsKeyboard)
                            .frame(width: 1, height: 1).opacity(0).allowsHitTesting(false).accessibilityHidden(true)
                    }
                TextField(voice.phase == .writing ? voice.writingWords : matter.map { "Ask about \($0.name)" } ?? "Ask about your matters", text: $draft, selection: $cursor, axis: .vertical)
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
                    .accessibilityIdentifier("assistant.field")
                    // One line sits in the middle of the send button; more lines grow upwards.
                    .frame(minHeight: 34)
                MicButton(voice: voice, text: $draft, selection: $cursor) { typing = false }
                Button { if asking == nil { send() } else { stop() } } label: {
                    // A black arrow on the bee's yellow, drawn light, as every yellow thing has black
                    // on it — and a black square while an answer is on its way: one question at a time.
                    SendGlyph(stops: asking != nil)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(asking == nil ? "Send" : "Stop")
              }
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
        var (question, readAs) = NameHints.correct(typed, knowing: scope.flatMap { $0.parties.map(\.name) })
        let today = MatterStatus.day(Date())
        // "Task" or "Note" picked from the plus: what was typed is that, and says so in the thread.
        let add = navigation.pinned.flatMap { AssistantAdd(rawValue: $0.kind) }
        if let add {
            question = add.question(typed)
            readAs = []
            navigation.pinned = nil
        }
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
        let client = ModelChoice.client(for: model)
        // A note is kept as typed, and so is a task when there is no key to ask for its day with:
        // nothing is sent, and it is in the matter at once.
        if let add, !add.asksAssistant || client == nil {
            failure = nil
            draft = ""
            fieldKey += 1
            let answer = add.asTyped(typed)
            var turn = Navigation.Turn(question: question, scope: matter.map { "about \($0.name)" } ?? "about all matters",
                                       inHand: nil, seen: facts.seen, refs: facts.refs, matter: matter?.persistentModelID)
            turn.keys = CardActions.keys(of: facts.refs, in: context)
            turn.state = .answered(answer)
            keep(turn, taking: 0)
            return
        }
        // `--demo --answers`: an answer made up after a moment, with nothing sent — for the tests that
        // measure where the thread stands while an answer comes.
        if store.isDemo, CommandLine.arguments.contains("--answers") {
            failure = nil
            let wasTyping = typing
            if wasTyping { keepsKeyboard = true } else { typing = false }
            draft = ""
            fieldKey += 1
            if wasTyping { DispatchQueue.main.async { typing = true } }
            let id = UUID(), date = Date()
            asking = (id, question, date)
            step = .disguising
            sentAt = nil
            let matter = self.matter
            ask = Task {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                var turn = Navigation.Turn(question: question, scope: matter.map { "about \($0.name)" } ?? "about all matters",
                                           inHand: nil, seen: facts.seen, refs: facts.refs, matter: matter?.persistentModelID)
                turn.id = id
                turn.date = date
                turn.state = .answered(DemoData.standIn(for: question))
                keep(turn, taking: nil)
                asking = nil
            }
            return
        }
        guard let claude = client else {
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
        let wasTyping = typing
        // The keyboard stays up, as in Messages — when it was there: a question spoken and sent
        // without it does not bring it up. It is handed to the unseen field while this one is made
        // anew, and back.
        if wasTyping { keepsKeyboard = true } else { typing = false }
        draft = ""
        fieldKey += 1
        if wasTyping { DispatchQueue.main.async { typing = true } }
        let date = Date()
        let id = UUID()
        asking = (id, question, date)
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
                turn.id = id
                turn.date = date
                turn.keys = CardActions.keys(of: facts.refs, in: context)
                turn.readAs = readAs.map { "read “\($0.typed)” as “\($0.known)”" }
                if let add {
                    // The card for what was picked is taken in without a tap: the owner said so already.
                    let settled = add.settled(answer, words: typed)
                    turn.state = .answered(settled.answer)
                    keep(turn, taking: settled.card)
                } else {
                    turn.state = .answered(answer)
                    keep(turn, taking: nil)
                }
            } catch {
                guard !Task.isCancelled else { return }
                Haptics.failure()
                failure = plainWords(error)
                draft = question
                fieldKey += 1
            }
            asking = nil
        }
    }

    /// Puts an answered turn into the thread — and, for what was picked from the plus, takes its card
    /// in as it stands.
    private func keep(_ turn: Navigation.Turn, taking card: Int?) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let payload = try? encoder.encode(turn) else { return }
        let record = ThreadTurn(id: turn.id, date: turn.date, payload: payload)
        context.insert(record)
        record.matter = matter
        try? context.save()
        // Told to the thread: a task or a note kept with nothing asked, or the answer to a question.
        if asking == nil { kept = turn.id } else { answered = turn.id }
        Haptics.success()
        guard let index = card, let answer = turn.answer, answer.reply.cards.indices.contains(index) else { return }
        let made = answer.reply.cards[index]
        if case .taken(let undo) = CardActions.apply(made, text: made.text, subject: nil, refs: turn.refs, links: answer.links, scope: matter,
                                                     question: turn.question, mail: nil, in: context) {
            navigation.undos[turn.id, default: [:]][index] = undo
            navigation.mark(record, card: index, applied: true, context: context)
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
                .modifier(Lands(fresh: true))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, 40)
            AskSteps(step: step, sentAt: sentAt, size: 12).modifier(FadesIn(fresh: true))
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
                if card.kind == .shortMessage {
                    // A message for a chat: copied, not taken in.
                    MessageCard(id: "\(turn.id)-\(index)", asked: turn.date, to: card.party.map { id in turn.refs[id].map { CardActions.label($0, in: context) } ?? id },
                                words: card.text, reason: card.reason)
                } else {
                    PhoneActionCard(record: record, turn: turn, index: index, card: card, matter: matter)
                }
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
                // What the disguise found in the question — so it is seen that it looked — and what it cost.
                Text((answer.disguiseLine.map { $0 + " · " } ?? "") + "$\(String(format: "%.3f", answer.cost))").font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .accessibilityLabel("\(answer.disguiseSentence ?? "") \(answer.modelLabel), $\(String(format: "%.3f", answer.cost))")
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
    private var editable: Bool { [.newTodo, .renameParty, .changeRole, .correctText, .addNote, .newMatter, .addLink, .addContact, .newAppointment, .newDeadline, .addDetail].contains(card.kind) }
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
                // As tall as its words: the same words, unseen, take the room, and the field lies on
                // them. Left to size itself, the field was cut to half a line under a long answer.
                Text(text.isEmpty ? " " : text + (text.hasSuffix("\n") ? " " : ""))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .hidden()
                    .overlay(alignment: .topLeading) { TextField("", text: $text, axis: .vertical) }
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
        case .newTodo: return "Task added · " + whose + (card.due.map { " · by \(Dates.short($0))" + (card.time.map { " at \($0)" } ?? "") } ?? "")
        case .markDone: return "Marked done"
        case .sameParty: return "Merged into one person"
        case .renameParty: return "Name changed"
        case .changeRole: return "Role changed · " + name(card.party)
        case .addNote: return card.todo == nil ? "Note added" : "Note added · " + name(card.todo)
        case .changeDate: return "Date changed"
        case .newMatter: return "Matter started"
        case .waitsFor: return "Now waits for " + name(card.into)
        case .addLink: return "Link saved"
        case .addContact: return "Contact saved"
        case .newAppointment: return "Appointment added"
        case .newDeadline: return "Deadline added"
        case .addDetail: return "Detail saved"
        case .correctText: return "Text corrected"
        case .changeOwner: return "Now " + whose.lowercased()
        case .draftMessage: return "Opened in Mail"
        case .shortMessage: return "Copied"
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
        case .shortMessage: "Copy"
        case .changeDate: "Change date"
        case .newMatter: "Create"
        case .waitsFor: "Link"
        case .addLink: "Save link"
        case .addContact: "Save contact"
        case .newAppointment, .newDeadline: "Add"
        case .addDetail: "Save detail"
        case .renameParty, .changeRole, .correctText, .changeOwner: "Change"
        }
    }

    private var title: String {
        switch card.kind {
        case .markDone: return "Done?"
        case .newTodo: return "New task? · " + whose + (card.due.map { " · by \(Dates.short($0))" + (card.time.map { " at \($0)" } ?? "") } ?? "")
        case .sameParty: return "Same person?"
        case .renameParty: return "Change name?"
        case .changeRole: return "Change role?"
        case .addNote: return card.todo == nil ? "Note for the matter?" : "Note for the task?"
        case .draftMessage: return "Draft"
        case .shortMessage: return "Message"
        case .changeDate: return "Change date?"
        case .newMatter: return "New matter?"
        case .waitsFor: return "Waits for another task?"
        case .addLink: return "Save link? · Name:"
        case .addContact: return "Contact? · Name:"
        case .newAppointment: return "New appointment? · " + (card.due.map(Dates.short) ?? "?") + (card.time.map { " at \($0)" } ?? "")
        case .newDeadline: return "New deadline? · by " + (card.due.map(Dates.short) ?? "?")
        case .addDetail: return "Detail? · " + (card.subject ?? "")
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
        case .addNote: return card.todo == nil ? nil : name(card.todo)
        case .shortMessage: return nil
        case .draftMessage:
            guard let recipient else { return "To: (fill in in Mail)" }
            return "To: \(recipient.name)" + (recipient.address.map { " <\($0)>" } ?? " — address not known, fill it in in Mail")
        case .correctText: return "“\(card.from ?? "")”  becomes:"
        case .newMatter: return nil
        case .waitsFor: return "\(name(card.todo))  →  only after: \(name(card.into))"
        case .addLink: return card.todo == nil ? "to the matter" : "to: \(name(card.todo))"
        case .newAppointment, .newDeadline: return nil
        case .addDetail: return card.party == nil ? "its value is never among the facts sent" : "of \(name(card.party)) · its value is never among the facts sent"
        case .addContact: return [card.subject, card.from, card.time].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · ")
        case .changeDate:
            let when = (card.due.map(Dates.short) ?? "?") + (card.time.map { " at \($0)" } ?? "")
            return "\(name(card.todo))  →  \(when)"
        case .changeOwner: return name(card.todo)
        }
    }
}
