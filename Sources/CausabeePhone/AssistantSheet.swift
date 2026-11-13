import MatterCore
import MessageUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

/// The assistant's thread, one with the Mac's, over a matter: that matter's part of it. Asked here,
/// a question goes out disguised by the Mac's own list of names — the copy the Mac put into the
/// store — with the key pasted on the Mac, from iCloud Keychain. The list is not changed here: a
/// name the Mac has not seen gets a stand-in for this question only.
struct AssistantSheet: View {
    let matter: Matter?
    @Environment(Navigation.self) private var navigation
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    /// Only this matter's turns are fetched: a thread about one matter does not read what was
    /// asked about all the others each time it is drawn. With no matter: all of them.
    @Query private var records: [ThreadTurn]
    @Query private var matters: [Matter]
    @Query private var profiles: [Profile]
    @Environment(PhoneStore.self) private var store
    /// What is typed, and where the cursor is: read only by the field, so a keystroke redraws the
    /// field — not the whole sheet, with every answer and card of a long thread.
    @State private var typed = TypedWords()
    private var draft: String {
        get { typed.text }
        nonmutating set { typed.text = newValue }
    }
    /// How wide the thread's scroll view is, measured: it follows an iPad's window as it is resized.
    /// A new field after each send. Emptying the words is not enough while the keyboard still
    /// holds some of them — dictation, a word being autocorrected: the old field kept showing
    /// them, and with the words gone from `draft` nothing could be sent again.
    @State private var fieldKey = 0
    @FocusState private var typing: Bool
    /// A field nobody sees, which holds the keyboard for the moment the real one is made anew after
    /// a send: without it the keyboard began to go and came back, and everything over it dipped.
    @FocusState private var keepsKeyboard: Bool
    /// The panel over the field: what can be brought in and added. Open by itself the first time
    /// the assistant is opened, after that from the plus.
    @State private var panelOpen = false
    @AppStorage("addPanelShown") private var panelShown = false
    /// What the panel asked the plus to bring in.
    @State private var attachRequest: AttachKind?
    /// The question on its way, until its answer is in the thread. Its id is its turn's: asked and
    /// answered, it is one thing in the thread, in one place.
    @State private var asking: (id: UUID, question: String, date: Date)?
    /// What asking is doing now, and since when the question is out.
    @State private var step = AssistantAsk.Step.disguising
    @State private var sentAt: Date?
    /// The task that asks: Stop cancels it.
    @State private var ask: Task<Void, Never>?
    /// The words on their way are read on this device, by Apple's model — nothing is sent.
    @State private var readsOnDevice = false
    @State private var failure: String?
    /// The footer in full — what is seen and where it goes — or only that it goes pseudonymised.
    @State private var showsMore = false
    @State private var voice = VoiceInput()
    /// Where the thread stands, and when it moves by itself: `ThreadPlacement` has the rule, for the
    /// iPhone and the Mac.
    @State private var placement = ThreadPlacement()
    /// The thread opens with its newest turns only; the earlier ones come when asked for. Laid out
    /// whole at once, a thread of weeks took seconds to open.
    /// How many of the newest are shown: twenty, and twenty more at a time — as on the Mac.
    @State private var showsNewest = AssistantPage.size
    @AppStorage(AutoMode.key) private var auto = false
    /// On, and Pro bought: without it the line on top offers Pro, the chips under the thread offer
    /// what can be added, and nothing typed goes to an AI.
    private var pro: Bool { Plan.proIsOn(switched: auto, plan: Store.shared.plan, credit: BeeServer.hasCredit) }
    /// A task or a note picked without Pro: it is typed in its card, over where the field was —
    /// the card is the form, and the field steps back until it is added or put away.
    private var typesInCard: Bool {
        guard let add = navigation.pinned.flatMap({ AssistantAdd(rawValue: $0.kind) }) else { return false }
        return !pro || !add.asksAssistant
    }

    init(matter: Matter?) {
        self.matter = matter
        if let id = matter?.persistentModelID {
            _records = Query(filter: #Predicate<ThreadTurn> { $0.matter?.persistentModelID == id }, sort: \ThreadTurn.date)
        } else {
            _records = Query(sort: \ThreadTurn.date)
        }
    }
    /// A turn kept with nothing asked — a task, a note — and the turn an answer just came for.
    @State private var kept: UUID?
    @State private var answered: UUID?

    private static let topRoom: CGFloat = 16
    private static let padding: CGFloat = 16
    /// What a question here would take along: worked out only when the footer is opened.
    private var seen: String {
        StoredChanges.shared.kept("seen \(matter?.persistentModelID.hashValue ?? 0)") {
            FactSheet.facts(for: matter.map { [$0] } ?? activeMatters(matters), today: MatterStatus.day(Date())).seen
        }
    }

    /// Read once per change to the store — every turn is saved at once — not compared and read
    /// again with each keystroke's drawing. The query already holds only this matter's turns.
    private var shown: [(record: ThreadTurn, turn: Navigation.Turn)] {
        StoredChanges.shared.kept("thread \(matter?.persistentModelID.hashValue ?? 0) \(records.count)") {
            records
                .compactMap { record in navigation.turn(record).map { (record, $0) } }
                // Only what was asked and brought in. That mail was taken in is said on the overview, and
                // the mail is in its matter: a line for it here, too, said it a third time.
                .filter { $0.1.note == nil }
        }
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
        /// An answer with a card still to decide on: the thread shows its end, where the card is.
        var waitsWithCard: Bool {
            guard case .turn(_, let turn) = self, case .answered(let answer) = turn.state else { return false }
            return answer.reply.cards.indices.contains { !turn.applied.contains($0) && !turn.dismissedCards.contains($0) }
        }
    }

    private var shots: [PhoneShots.Shot] {
        PhoneShots.shared.shots.filter { !$0.quiet && (matter == nil || $0.matter == nil || $0.matter == matter?.persistentModelID) }
    }

    private var entries: [Entry] {
        var all = shown.map { Entry.turn($0.record, $0.turn) } + shots.map { Entry.shot($0) }
        // The question on its way, until its turn is there under the same id.
        if let asking, !all.contains(where: { $0.id == asking.id }) { all.append(.pending(asking.id, asking.question, asking.date)) }
        // By their time, and two of the same moment always the same way round.
        // The ids as text once each, not twice in every comparison.
        return all.map { ($0, $0.id.uuidString) }.sorted { ($0.0.date, $0.1) < ($1.0.date, $1.1) }.map(\.0)
    }

    /// The newest: the question on its way, else the thread's last.
    private var newestID: UUID? { asking?.id ?? entries.last?.id }
    /// How tall the field's bar is: the way back to the newest stands over it.
    @State private var barHeight = CGFloat.zero

    var body: some View {
        // Worked out once for this drawing: asked for again for every turn in the thread, the list
        // was read, filtered and sorted as many times as it has turns.
        let all = entries
        let newestID = asking?.id ?? all.last?.id
        let entries = Array(all.suffix(showsNewest))
        VStack(spacing: 0) {
            ScrollViewReader { scroller in
            // The thread is exactly as wide as its scroll view, by the width layout hands down here
            // and now: a width told a moment later (onGeometryChange) could stay behind — on an
            // iPad the thread then stood narrow in the middle of its column.
            GeometryReader { room in
            ScrollView {
                // Laid out whole, not lazily: a matter's thread is short enough.
                VStack(alignment: .leading, spacing: 20) {
                    if all.count > entries.count, let first = entries.first?.id {
                        Button {
                            // The thread is the owner's from here: it stays where it is read, the
                            // earlier turns over what was its first.
                            placement.read()
                            showsNewest += AssistantPage.size
                            DispatchQueue.main.async { scroller.scrollTo(first, anchor: .top) }
                        } label: {
                            Text("Show earlier · \(all.count - entries.count) more").font(.footnote.weight(.medium)).foregroundStyle(Theme.gold)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("thread.earlier")
                    }
                    if entries.isEmpty {
                        Text(matter == nil ? String(localized: "Nothing asked yet.") : String(localized: "Nothing asked about this matter yet."))
                            .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 40)
                        if let failure { failed(failure) }
                    }
                    // One line of time: what was asked and what was brought in, each where it
                    // happened — a file's card is not under everything asked after it.
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        let newest = entry.id == newestID
                        VStack(alignment: .leading, spacing: 20) {
                            if index == 0 || !Calendar.current.isDate(entries[index - 1].date, inSameDayAs: entry.date) {
                                Text(entry.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                                    .padding(.top, index == 0 ? 0 : 4)
                            }
                            switch entry {
                            case .turn(let record, let turn):
                                // The newest question can be asked once more, for another answer — as on the Mac.
                                PhoneTurnView(record: record, turn: turn, matter: record.matter,
                                              again: newest && asking == nil ? { again(record, turn) } : nil)
                            // A file brought in here: read on the iPhone, sorted in on a yes.
                            case .shot(let shot): PhoneShotCard(shot: shot)
                            case .pending(_, let question, _): PendingTurn(question: question, step: step, sentAt: sentAt, onDevice: readsOnDevice)
                            }
                            // A question that could not go out says why, under the newest.
                            if newest, let failure { failed(failure) }
                        }
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in if newest { placement.own(height, card: entry.waitsWithCard, with: scroller) } }
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
                .asWide(as: room.size.width)
                .environment(\.threadPlacement, placement)
            }
            // The keyboard goes when the thread is scrolled or tapped, to see all of it — the thread
            // only: put after the bars, a tap into the field itself, for the cursor or the menu to
            // copy and paste, sent the keyboard away too.
            .dismissesKeyboard()
            // The thread's top stands a little under the edge: what is put "at the top" keeps that room.
            .safeAreaPadding(.top, Self.topRoom)
            // The name on top and the field below are bars over the thread, not rows beside it: the
            // thread goes on under them and is seen through them, blurred — glass, as the system's
            // own bars are. Nothing is cut off at a line.
            .safeAreaBar(edge: .top, spacing: 0) { header }
            .safeAreaBar(edge: .bottom, spacing: 0) {
                composer.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { barHeight = $0 }
            }
            // Away from the newest: the way back, standing over the field — on the thread, lifted by
            // the bar's height. Hung on the bar itself it stood outside the bar's own bounds, where a
            // tap went through to the thread and the button did nothing. A view of its own: it alone
            // is drawn again when the thread leaves its newest or comes back to it.
            .overlay(alignment: .bottom) {
                PhoneToNewestButton(placement: placement, newest: newestID.map { AnyHashable($0) }, scroller: scroller)
                    .padding(.bottom, barHeight)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            // Below, the system's blur began a hand's breadth over the field. There the glass is the
            // field's own: the thread is sharp down to it, seen through it, and gone under its lower half.
            .scrollEdgeEffectHidden(true, for: .bottom)
            // What happens to the thread is told to the placement, which decides where it goes.
            .onScrollGeometryChange(for: CGFloat.self) { $0.containerSize.height } action: { _, height in placement.room(height, with: scroller) }
            .onScrollPhaseChange { old, new, context in placement.finger(from: old, to: new, at: context.geometry.contentOffset.y) }
            .animation(ThreadPlacement.glide, value: failure)
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
            }
        }
        .background(Theme.canvas)
        // A screenshot or a PDF dragged here, or pasted: read, as on the Mac.
        .receivesFiles(matter: matter)
        .onAppear {
            // What was in hand from another matter is put down; words to send go into the field.
            if let pinned = navigation.pinned, pinned.matter != matter?.persistentModelID { navigation.pinned = nil }
            if let prefill = navigation.prefill { draft = prefill; navigation.prefill = nil }
            // The speech model into memory now, if it is on the iPhone: what is said next is then
            // written down without waiting for it.
            Task { await Transcriber.shared.warmUp() }
        }
    }

    /// The same question once more: the answer it had goes, and the new one takes its place.
    private func again(_ record: ThreadTurn, _ turn: Navigation.Turn) {
        guard asking == nil else { return }
        context.delete(record)
        try? context.save()
        draft = turn.question
        send()
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
        VStack(spacing: 8) {
            closeRow
            if !pro { ProOffer().padding(.horizontal, 16).padding(.bottom, 4) }
        }
    }

    private var closeRow: some View {
        ZStack {
            // Nothing but the way out, on the iPhone and the iPad: that this is Causabee is known, and
            // what it is asked about stands in the field below.
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
        .padding(.horizontal, 16).padding(.top, navigation.isPad ? 0 : 16).padding(.bottom, navigation.isPad ? 0 : 4)
        .frame(height: navigation.isPad ? PadMetrics.bar : nil)
    }

    /// The panel of what can be brought in and added, over the field when it is open, and the field,
    /// on the page's ground from its middle down.
    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if panelOpen, navigation.pinned == nil {
                AddPanel(matter: matter) { kind in
                    closePanel()
                    attachRequest = kind
                } add: { add in
                    // Its card comes where the field was, and what is typed goes into it — kept as
                    // written, but a task with Pro, which the assistant reads for its day.
                    guard let matter else { return }
                    closePanel()
                    navigation.pinned = Navigation.Pinned(matter: matter.persistentModelID, matterName: matter.name, kind: add.rawValue, text: add.hint)
                    typing = true
                }
                .padding(.horizontal, 16)
                // Out of the plus, under its lower left corner, and back into it.
                .transition(.scale(scale: 0.08, anchor: UnitPoint(x: 0.07, y: 1.2)).combined(with: .opacity))
            }
            field
        }
        .onAppear {
            guard !panelShown else { return }
            panelShown = true
            withAnimation(AttachButton.panelMotion.delay(0.3)) { panelOpen = true }
        }
        // Typing puts it away: the field is what is wanted then.
        .onChange(of: typing) { if typing { closePanel() } }
    }

    private func closePanel() {
        guard panelOpen else { return }
        withAnimation(AttachButton.panelMotion) { panelOpen = false }
    }

    /// The field as the Mac has it: what is typed goes out pseudonymised, and only on send.
    private var field: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let pinned = navigation.pinned, !typesInCard {
                // What is in hand, on a pale honey: the pin and its kind in gold, the words as any
                // words — as on the Mac. Calm, so the send button stays the one yellow thing.
                HStack(spacing: 8) {
                    Image(systemName: AssistantAdd(rawValue: pinned.kind) == nil ? "pin.fill" : "plus").font(.caption).foregroundStyle(Theme.gold)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(InHand.word(pinned.kind).uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(Theme.gold)
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
            if typesInCard, let add = navigation.pinned.flatMap({ AssistantAdd(rawValue: $0.kind) }) {
                AddCard(add: add, typed: typed, typing: $typing, take: send) { navigation.pinned = nil; draft = ""; typed.second = "" }
            } else {
            HStack(alignment: .bottom, spacing: 6) {
              if voice.phase == .listening {
                ListeningBar(voice: voice)
              } else {
                // "Task" or "Note" picked: the chip says what comes; to type or to speak is chosen after.
                AttachButton(matter: matter, panel: $panelOpen, request: $attachRequest)
                    .background {
                        TextField("", text: .constant("")).focused($keepsKeyboard)
                            .frame(width: 1, height: 1).opacity(0).allowsHitTesting(false).accessibilityHidden(true)
                    }
                TypingField(typed: typed, voice: voice, typing: $typing, fieldKey: fieldKey, asking: asking != nil,
                            placeholder: voice.phase == .writing ? voice.writingWords
                                : matter.map { String(format: String(localized: "Ask about %@"), $0.name) } ?? String(localized: "Ask about your matters"),
                            send: send, stop: stop)
              }
            }
            .padding(.leading, 7).padding(.trailing, 7).padding(.vertical, 7)
            // The field itself is glass: the thread is seen through it as it passes under.
            .glassBehind(RoundedRectangle(cornerRadius: 24))
            }
            // As on the Mac: "more" and "less" are links inside the line, so the full one wraps like a sentence.
            Text(LocalizedStringKey(!pro || ModelChoice.reach != .pro ? String(localized: "Stays on this device. Asking needs Pro.")
                : showsMore
                ? String(format: String(localized: "Always pseudonymised sent to %@ • Sees: %@ • [less](causabee://footer)"), AIJob.chatSentTo, seen)
                : String(localized: "Always pseudonymised sent • [more](causabee://footer)")))
                .font(.caption2).foregroundStyle(.secondary).tint(Theme.gold)
                .environment(\.openURL, OpenURLAction { _ in showsMore.toggle(); return .handled })
                .padding(.horizontal, 8)
        }
        .padding(.horizontal, 16).padding(.top, 0).padding(.bottom, 8)
        // The page's ground from the field's middle down, thinning out upwards to its upper edge.
        .background {
            LinearGradient(stops: [.init(color: Theme.canvas.opacity(0), location: 0), .init(color: Theme.canvas, location: 0.45), .init(color: Theme.canvas, location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        }
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
        let second = self.typed.second
        if let add {
            guard add.isComplete(typed, second) else { return }
            question = add.question(typed, second)
            readAs = []
            navigation.pinned = nil
            self.typed.second = ""
        }
        let pinned = navigation.pinned
        let place = PhoneCloud.storeLocation()
        let facts = FactSheet.facts(for: scope, today: today, focus: pinned.flatMap { Navigation.Pinned.isMatter($0.kind) ? nil : $0.text },
                                    keptText: { MailText.load($0.messageID, besides: place)?.body })
        let inHand = pinned.flatMap { Navigation.Pinned.isMatter($0.kind) ? nil : (kind: $0.kind, text: $0.text) }
        // Only this matter's talk: what was said about another matter would go out with it.
        let earlier: [(question: String, answer: String)] = shown.compactMap { item in
            guard let answer = item.turn.answer, item.turn.note == nil else { return nil }
            return (item.turn.question, CardActions.earlierWords(answer.reply, applied: item.turn.applied))
        }
        // F005: light when what a quick question needs will do; never lighter than the question before it, within the cache's 30 minutes.
        let after = shown.last { $0.turn.answer != nil && $0.turn.note == nil }.flatMap { ChatDepth.following($0.turn.answer?.depth, askedAt: $0.turn.date) }
        let depth = ChatDepth.pick(question: question, facts: facts, after: after)
        // The model chosen in Settings, as on the Mac, with the key its service takes.
        let model = ModelChoice.assistant
        let client = ModelChoice.client(for: model)
        // A note is kept as typed, and so is a task when there is no key to ask for its day with:
        // nothing is sent, and it is in the matter at once.
        if let add, !add.asksAssistant || client == nil || !pro {
            failure = nil
            draft = ""
            fieldKey += 1
            var answer = add.asTyped(typed, second)
            // A day or a time in the words is the task's date, found by rule, and taken out of them.
            if add == .task, !answer.reply.cards.isEmpty {
                let filled = DeviceTask.card(typed)
                answer.reply.cards[0].text = filled.text
                answer.reply.cards[0].due = filled.due
                answer.reply.cards[0].time = filled.time
            }
            var turn = Navigation.Turn(question: question, scope: matter.map { "about \($0.name)" } ?? "about all matters",
                                       inHand: nil, seen: facts.seen, refs: facts.refs, matter: matter?.persistentModelID)
            turn.keys = CardActions.keys(of: facts.refs, in: context)
            turn.state = .answered(answer)
            keep(turn, taking: 0)
            return
        }
        // Without Pro nothing is asked: Apple's model on the device says whether the words are
        // something to do, and a task's card comes for it, to add; a question waits for Pro.
        if !pro, add == nil {
            failure = nil
            draft = ""
            fieldKey += 1
            let id = UUID(), date = Date()
            readsOnDevice = true
            asking = (id, question, date)
            let matter = self.matter
            let onPad = navigation.isPad
            ask = Task {
                let filled = await DeviceTask.understood(typed)
                guard !Task.isCancelled else { return }
                var turn = Navigation.Turn(question: question, scope: matter.map { "about \($0.name)" } ?? "about all matters",
                                           inHand: nil, seen: facts.seen, refs: facts.refs, matter: matter?.persistentModelID)
                turn.id = id
                turn.date = date
                turn.state = .answered(DeviceTask.answer(filled, onPad: onPad, inMatter: matter != nil))
                keep(turn, taking: nil)
                asking = nil
                readsOnDevice = false
            }
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
                // `-answers.after 10`: later, for a test that scrolls away first — on a busy machine five
                // seconds were not always enough to be gone before it came.
                let after = UserDefaults.standard.double(forKey: "answers.after")
                try? await Task.sleep(for: .seconds(after > 0 ? after : 5))
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
                                                        claude: claude, model: model, depth: depth) { said.yield($0) }
                // Stopped while the answer was coming: it is not put into the thread.
                guard !Task.isCancelled else { return }
                var turn = Navigation.Turn(question: question, scope: matter.map { "about \($0.name)" } ?? "about all matters",
                                           inHand: pinned, seen: facts.seen, refs: facts.refs, matter: matter?.persistentModelID)
                turn.id = id
                turn.date = date
                turn.keys = CardActions.keys(of: facts.refs, in: context)
                turn.readAs = readAs.map { String(format: String(localized: "read “%@” as “%@”"), $0.typed, $0.known) }
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
        readsOnDevice = false
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
    /// Read on the device, not asked: there are no names to disguise and nothing is sent.
    var onDevice = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(question)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Theme.honey, in: RoundedRectangle(cornerRadius: 18))
                .foregroundStyle(.black)
                .modifier(Lands(fresh: true))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, 40)
            if onDevice {
                Label(UIDevice.current.userInterfaceIdiom == .pad ? String(localized: "Reading on this iPad …") : String(localized: "Reading on this iPhone …"), systemImage: "iphone")
                    .font(.footnote).foregroundStyle(.secondary).modifier(FadesIn(fresh: true))
            } else {
                AskSteps(step: step, sentAt: sentAt, size: 12).modifier(FadesIn(fresh: true))
            }
        }
    }
}

/// One question and what came back: lines with their sources, and the cards.
struct PhoneTurnView: View {
    let record: ThreadTurn
    let turn: Navigation.Turn
    let matter: Matter?
    /// The newest question only: asked once more, for another answer.
    var again: (() -> Void)? = nil
    /// Who answered and what went out, disguised: behind what it cost, as on the Mac.
    @State private var showsSent = false
    /// Reading mode, from the window: the sheet is not always under the page that has it.
    /// Just copied: the button says so for a moment.
    @State private var copied = false
    /// Kept as a note of its matter: the button says so, and does not keep it twice.
    @State private var savedNote = false
    /// The word beside a tick: first the space opens, then the word fades in — and back.
    @State private var copyOpen = false
    @State private var copyShown = false
    @State private var noteOpen = false
    @State private var noteShown = false

    /// A small action under an answer: its sign where it always is, and once done a gold tick
    /// with a word to its right (8 November: the tick moved left when the word came).
    private func answerAction(_ symbol: String, done: Bool, word: String, open: Bool, shown: Bool) -> some View {
        HStack(spacing: -4) {
            Image(systemName: symbol).font(.footnote.weight(done ? .semibold : .regular))
                .frame(width: 30, height: 32)
            if open {
                Text(word).font(.caption).fixedSize().opacity(shown ? 1 : 0).padding(.trailing, 4)
                    .transition(.identity)
            }
        }
        .foregroundStyle(done ? Theme.gold : Color.secondary)
        .contentShape(Rectangle())
    }

    /// Opens the space, fades the word in, holds it, fades it out, closes the space.
    private func sayDone(_ open: Binding<Bool>, _ shown: Binding<Bool>, hold: Double, then: @escaping () -> Void = {}) {
        guard !open.wrappedValue else { return }
        Task { @MainActor in
            withAnimation(.snappy(duration: 0.25)) { open.wrappedValue = true }
            try? await Task.sleep(for: .seconds(0.2))
            withAnimation(.easeOut(duration: 0.2)) { shown.wrappedValue = true }
            try? await Task.sleep(for: .seconds(hold))
            withAnimation(.easeIn(duration: 0.2)) { shown.wrappedValue = false }
            try? await Task.sleep(for: .seconds(0.2))
            withAnimation(.snappy(duration: 0.25)) { open.wrappedValue = false; then() }
        }
    }
    /// The answer's sources, unfolded: one list for the whole answer.
    @State private var showsSources = false
    @Environment(Navigation.self) private var navigation
    @Environment(\.modelContext) private var context

    var body: some View {
        if let note = turn.note {
            intake(note)
        } else if let shot = turn.shot {
            // What became of a file brought in, on any device: one line, with Undo and Change.
            if let name = shot.taken {
                TakenLine(name: name, made: shot.made, file: shot.file, fileID: shot.fileID, matter: record.matter, record: record)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.viewfinder").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Document.ownName(of: shot.file)).font(.footnote.weight(.medium)).lineLimit(1)
                        Text(shot.dismissed ? String(localized: "Dismissed — nothing was taken into a matter.") : String(localized: "Not finished before the app was closed."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .trailing, spacing: 6) {
                    question
                    // A name typed a letter short, read as the person it almost is — said, as on the Mac.
                    ForEach(turn.readAs, id: \.self) { note in
                        Label(note, systemImage: "character.cursor.ibeam").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                switch turn.state {
                case .answered(let answer): answered(answer)
                case .failed(let message):
                    // Stopped by the owner is no failure: said quietly.
                    if AssistantAsk.wasStopped(message) {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Label(message, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(Theme.warning)
                    }
                    if let again {
                        Button(action: again) { Label("Try again", systemImage: "arrow.clockwise") }
                            .font(.footnote.weight(.medium)).foregroundStyle(Theme.gold).buttonStyle(.plain)
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
                                words: card.text, reason: card.reason,
                                dismissed: turn.dismissedCards.contains(index),
                                setDismissed: { put in
                                    Haptics.tap()
                                    withAnimation { navigation.mark(record, card: index, dismissed: put, context: context) }
                                })
                } else if card.kind == .lookUp {
                    // A question for the web: sent alone, only on a tap — as on the Mac.
                    LookUpCard(question: card.text, reason: card.reason, matter: record.matter ?? matter,
                               dismissed: turn.dismissedCards.contains(index),
                               setDismissed: { put in withAnimation { navigation.mark(record, card: index, dismissed: put, context: context) } })
                } else {
                    // Asked for, so it stays while reading too: an answer that is only a card showed nothing.
                    PhoneActionCard(record: record, turn: turn, index: index, card: card, matter: matter)
                }
            }
            // One line under the answer: copy it, what it rests on — and what it cost. The same
            // space seen between each of them: an icon's tap area is wider than the icon, so
            // "Sources" gets that much before it (10 November: it sat closer than the icons).
            HStack(spacing: 0) {
                Button {
                    UIPasteboard.general.string = answer.plainText
                    Haptics.tap()
                    copied = true
                    sayDone($copyOpen, $copyShown, hold: 1.6) { copied = false }
                } label: {
                    // Done says so: a gold tick and the word, for a moment (8 November: a grey tick went unseen).
                    answerAction(copied ? "checkmark" : "doc.on.doc", done: copied, word: String(localized: "Copied"), open: copyOpen, shown: copyShown)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(copied ? String(localized: "Copied") : String(localized: "Copy the answer"))
                // An answer about one matter can be kept with it, as a note.
                if let matter {
                    Button {
                        NotesPart.keep(answer.plainText, in: matter, context: context)
                        Haptics.success()
                        savedNote = true
                        sayDone($noteOpen, $noteShown, hold: 2)
                    } label: {
                        // Kept: the tick stays gold, the words for a moment.
                        answerAction(savedNote ? "checkmark" : "note.text.badge.plus", done: savedNote, word: String(localized: "Added to notes"), open: noteOpen, shown: noteShown)
                    }
                    .buttonStyle(.plain)
                    .disabled(savedNote)
                    .accessibilityLabel(savedNote ? String(localized: "Saved as note") : String(localized: "Save as note"))
                }
                // Another answer would take the place of this one: not once a card of it is taken in.
                if let again, turn.applied.isEmpty {
                    Button(action: again) {
                        Image(systemName: "arrow.clockwise").font(.footnote).foregroundStyle(.secondary)
                            .frame(width: 30, height: 32).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Try again")
                }
                if !cites.isEmpty {
                    Button { withAnimation(.snappy) { showsSources.toggle() } } label: {
                        HStack(spacing: 4) {
                            Text("Sources (\(cites.count))")
                            Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).rotationEffect(.degrees(showsSources ? 90 : 0))
                        }
                        .font(.footnote).foregroundStyle(.secondary)
                        .padding(.leading, 10)
                        .frame(minHeight: 32).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 8)
                // Kept as typed — a task or a note with nothing asked: no AI answered, and none is named.
                if answer.servedBy == DeviceTask.onDevice || (answer.sent.isEmpty && answer.reply.lines.isEmpty) {
                    Text("On this device").font(.caption2).foregroundStyle(.secondary).frame(minHeight: 32)
                } else {
                // What the disguise found in the question — so it is seen that it looked.
                // A tap shows who answered and what went out, disguised — as on the Mac.
                Button { withAnimation(.snappy) { showsSent.toggle() } } label: {
                    Text(answer.disguiseLine ?? (BeeServer.isSetUp ? "Pro" : answer.modelLabel)).font(.caption2).foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(minHeight: 32).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(answer.disguiseSentence ?? "") \(answer.modelLabel)")
                .accessibilityHint(showsSent ? String(localized: "Hides what was sent") : String(localized: "Shows what was sent, pseudonymised"))
                }
            }
            .padding(.leading, -8)
            .padding(.vertical, -6)
            if showsSent {
                VStack(alignment: .leading, spacing: 6) {
                    Text(answer.modelLabel).font(.caption2).foregroundStyle(.secondary)
                    if let sentence = answer.disguiseSentence {
                        Text(sentence).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    // Nothing went out for a made-up answer — the demo's: said, not an empty box.
                    if answer.sent.isEmpty {
                        Text("Nothing was sent for this answer.").font(.caption2).foregroundStyle(.secondary)
                    } else {
                    ScrollView {
                        Text(answer.sent).font(.caption.monospaced()).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 260)
                    .padding(8)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
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
    /// The matter's files the owner picked for a draft, besides those it names.
    @State private var attached: [PersistentIdentifier] = []
    /// What the draft named by itself and the owner took away.
    @State private var leftOut: Set<PersistentIdentifier> = []
    @State private var attaching = false
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
    private var editable: Bool { [.newTodo, .renameParty, .changeRole, .correctText, .addNote, .correctBrief, .newMatter, .addLink, .addContact, .newAppointment, .newDeadline, .addDetail, .changeField, .addDecision].contains(card.kind) }
    private var mailInHand: String? { turn.inHand.flatMap { $0.kind == "Mail" ? $0.text : nil } }
    /// Once per change: the draft's card asked for it three times each time it drew.
    private var recipient: (name: String, address: String?)? {
        StoredChanges.shared.kept("recipient \(turn.id) \(index)") {
            CardActions.recipient(card.party, refs: turn.refs, question: turn.question, mail: mailInHand, scope: scope, in: context)
        }
    }

    var body: some View {
        Group {
            if card.kind == .draftMessage, quiet, !editingDraft {
                sentDraft
            } else if quiet, !(card.kind == .draftMessage && editingDraft) {
                // An opened draft unfolded with Edit is the whole card again, not the small ticked one.
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
                    Button(Say.showAgain) { navigation.mark(record, card: index, dismissed: false, context: context) }
                        .font(.footnote.weight(.medium)).foregroundStyle(Theme.gold).buttonStyle(.plain).fixedSize()
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            } else {
                full
            }
        }
        // Undo plays it backwards; with Reduce Motion it is a short cross-fade. Taken in or out on
        // another device, it changes the same way.

        .onChange(of: done) { if quiet != done { step { quiet = done; editingDraft = false } } }
    }

    /// "To Rentscape · info@rentscape.fr": to whom the draft goes, and where, when someone is known.
    private var draftTo: String? { recipient.map(CardActions.toLine) }

    /// The small lines under the card: the files a draft takes along; for the rest, why — and what
    /// merging two people means.
    private var notes: [(text: String, symbol: String?)] {
        if card.kind == .draftMessage {
            let line = StoredChanges.shared.kept("along \(turn.id) \(index) \(text) \(attached.count) \(leftOut.count)") {
                CardActions.attachmentLine(text: text, question: turn.question, scope: scope, attach: card.attach ?? [], chosen: chosenFiles,
                                           leftOut: leftOut)
            }
            return line.map { [($0, "paperclip")] } ?? []
        }
        var notes: [(text: String, symbol: String?)] = card.reason.isEmpty ? [] : [(card.reason, nil)]
        if card.kind == .sameParty { notes.append((String(localized: "Later you can only turn merging off for new mail; you cannot split it again."), nil)) }
        if let failed = CardFailures.shared.said[CardFailures.key(turn.id, index)] { notes.insert((failed, "exclamationmark.circle"), at: 0) }
        return notes
    }

    private var full: some View {
        let draft = card.kind == .draftMessage
        return CardFace(label: draft ? String(localized: "Draft · Mail") : title,
                        subject: draft ? $subject : nil,
                        headline: draft || editable ? nil : what,
                        sub: draft ? draftTo : editable ? what : nil,
                        text: draft || editable ? $text : nil,
                        serif: draft,
                        notes: notes,
                        attach: draft && scope != nil ? { attaching = true } : nil,
                        verb: verb,
                        closeLabel: quiet ? String(localized: "Cancel") : String(localized: "Dismiss"),
                        close: {
                            // A draft opened in Mail before and unfolded to change: the × folds it again.
                            if quiet { step { editingDraft = false } }
                            else { Haptics.tap(); withAnimation { navigation.mark(record, card: index, dismissed: true, context: context) } }
                        },
                        take: { take() })
            .opacity(showsContent ? 1 : 0)
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { RoundedRectangle(cornerRadius: 20).fill(Theme.box).matchedGeometryEffect(id: "box", in: morph, isSource: !quiet || editingDraft) }
            .sheet(isPresented: $attaching) {
                if let scope {
                    AttachSheet(matter: scope, named: Set(DraftAttachments.named(in: [text, turn.question] + (card.attach ?? []),
                                                                                    among: scope.documents ?? []).map(\.persistentModelID)),
                                chosen: $attached, leftOut: $leftOut)
                }
            }
            .transition(.opacity)
    }

    /// A card taken in, small and quiet: what was done, what kind, and Undo while the app is open.
    /// The reason and the sources stay with what it made; a tap opens that in its matter.
    private var taken: some View {
        // A date change no longer true says so, and offers to set it again: never a tick on what is not so.
        let undone = CardActions.dateNow(card, refs: turn.refs, in: context).map { !$0.holds } ?? false
        return HStack(alignment: .center, spacing: 10) {
            Image(systemName: undone ? "exclamationmark.circle" : "checkmark").font(.footnote.weight(.semibold))
                .foregroundStyle(undone ? Theme.warning : Theme.done)
            VStack(alignment: .leading, spacing: 2) {
                Text(takenWhat).font(.subheadline.weight(.medium)).foregroundStyle(.primary).lineLimit(2)
                Text(takenKind).font(.caption).foregroundStyle(undone ? Theme.warning : .secondary).lineLimit(2)
                    .accessibilityIdentifier("receipt.kind")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if undone {
                Button("Set again") { take() }.font(.footnote.weight(.medium)).foregroundStyle(Theme.gold).buttonStyle(.plain)
                    .accessibilityIdentifier("receipt.again")
            } else if undo != nil {
                Button("Undo", action: takeBack).font(.footnote.weight(.medium)).foregroundStyle(Theme.gold).buttonStyle(.plain)
            }
        }
        .opacity(showsContent ? 1 : 0)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background { RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)).matchedGeometryEffect(id: "box", in: morph, isSource: quiet && !editingDraft) }
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
        case .newTodo: return String(format: String(localized: "Task added · %@"), whose) + CardWords.when(due: card.due, time: card.time)
        case .markDone: return String(localized: "Marked done")
        case .sameParty: return String(localized: "Merged into one person")
        case .renameParty: return String(localized: "Name changed")
        case .changeRole: return String(format: String(localized: "Role changed · %@"), name(card.party))
        case .addNote: return card.todo == nil ? String(localized: "Note added") : String(format: String(localized: "Note added · %@"), name(card.todo))
        case .correctBrief: return String(localized: "Brief corrected")
        case .lookUp: return String(localized: "Looked up")
        case .changeDate:
            guard let date = CardActions.dateNow(card, refs: turn.refs, in: context) else { return String(localized: "Date changed") }
            return date.holds ? String(format: String(localized: "Date changed · %@"), date.now)
                : String(format: String(localized: "Changed back since · now %@"), date.now)
        case .newMatter: return String(localized: "Matter started")
        case .waitsFor: return String(format: String(localized: "Now waits for %@"), name(card.into))
        case .addLink: return String(localized: "Link saved")
        case .addContact: return String(localized: "Contact saved")
        case .newAppointment: return String(localized: "Appointment added")
        case .newDeadline: return String(localized: "Deadline added")
        case .addDetail: return String(localized: "Detail saved")
        case .correctText: return String(localized: "Text corrected")
        case .putAway, .reopen, .changeField, .closeMatter, .moveTo, .addDecision:
            return CardActions.controlWords(card, name: { name($0) })?.taken ?? ""
        case .changeOwner: return String(format: String(localized: "Now %@"), whose.lowercased())
        case .draftMessage: return String(localized: "Opened in Mail")
        case .shortMessage: return String(localized: "Copied")
        }
    }

    /// Into its matter, at the task it made or changed when there is one.
    private func openTaken() {
        guard let target = scope ?? matter else { return }
        // What it added — a note, a date, a detail — opens where it is: Notes, Plan, the Digest.
        if case .added(let made) = undo {
            navigation.showsInItsPart = true
            navigation.open(CardActions.matter(ofAdded: made, in: context) ?? target, showing: made)
            return
        }
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
                if let preparing = MailPreparing.shared.notes[MailPreparing.key(turn.id, index)] {
                    // Before the mail opens: a file fetched from iCloud, a picture made smaller.
                    HStack(spacing: 6) {
                        BeeLoader(size: 9)
                        Text(preparing).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                } else {
                    Text("Draft opened in Mail · To: \(recipient?.name ?? "—")").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Edit") { step { editingDraft = true } }
                .font(.footnote.weight(.medium)).foregroundStyle(Theme.gold).buttonStyle(.plain)
        }
        .opacity(showsContent ? 1 : 0)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background { RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)).matchedGeometryEffect(id: "box", in: morph, isSource: quiet && !editingDraft) }
        .transition(.opacity)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { take() }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens it in Mail again")
    }

    /// The answer's matter: one a card beside this one made, the one it was asked in, or the one
    /// its facts come from — as on the Mac.
    private var scope: Matter? {
        if let made = navigation.madeMatter[turn.id].flatMap({ CardActions.live($0, as: Matter.self, in: context) }) { return made }
        if let matter { return matter }
        return card.cites.lazy.compactMap { turn.refs[$0] }.compactMap { CardActions.matter(of: $0, in: context) }.first
    }

    /// The files picked for the draft, as they are now: one taken away meanwhile is left out.
    private var chosenFiles: [MatterCore.Document] {
        attached.compactMap { CardActions.live($0, as: MatterCore.Document.self, in: context) }
    }

    private func take() {
        switch CardActions.apply(card, text: text, subject: subject, refs: turn.refs, links: turn.answer?.links, scope: scope,
                                 question: turn.question, mail: mailInHand,
                                 inHand: turn.inHand.map { ($0.kind, $0.text) }, chosen: chosenFiles, leftOut: leftOut, in: context) {
        case .nothing:
            Haptics.tap()
            CardFailures.shared.said[CardFailures.key(turn.id, index)] = CardActions.whyNot(card)
            return
        case .openMail(let url, let draft):
            Haptics.tap()
            // With a file to take along, the system's own mail sheet: it attaches what it is handed.
            if !MailSheet.open(draft, card: MailPreparing.key(turn.id, index)) { openURL(url) }
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

    /// The day and the time a card carries, as its line says them: two words of their own, so a
    /// language can put the day and the time its own way.
    private enum CardWords {
        static func at(_ time: String) -> String { String(format: String(localized: " at %@"), time) }
        static func when(due: String?, time: String?) -> String {
            guard let due else { return "" }
            return String(format: String(localized: " · by %@"), Dates.short(due)) + (time.map(at) ?? "")
        }
    }

    /// The owner is stored as "me", "we", "other": English, so only the word is looked up.
    private var whose: String {
        ["me": String(localized: "Mine"), "we": String(localized: "Ours"), "other": String(localized: "Waiting for")][card.owner] ?? String(localized: "Unclear whose")
    }

    /// What the button does, in a word or two.
    private var verb: String {
        switch card.kind {
        case .markDone: String(localized: "Done")
        case .newTodo: String(localized: "Add")
        case .sameParty: String(localized: "Merge")
        case .addNote: String(localized: "Save note")
        case .correctBrief: String(localized: "Correct the brief")
        case .lookUp: String(localized: "Look up")
        case .draftMessage: String(localized: "Open in Mail")
        case .shortMessage: String(localized: "Copy")
        case .changeDate: String(localized: "Change date")
        case .newMatter: String(localized: "Create")
        case .waitsFor: String(localized: "Link")
        case .addLink: String(localized: "Save link")
        case .addContact: String(localized: "Save contact")
        case .newAppointment, .newDeadline: String(localized: "Add")
        case .addDetail: String(localized: "Save detail")
        case .renameParty, .changeRole, .correctText, .changeOwner: String(localized: "Change")
        case .putAway, .reopen, .changeField, .closeMatter, .moveTo, .addDecision: CardActions.controlWords(card, name: { name($0) })?.verb ?? String(localized: "Do")
        }
    }

    private var title: String {
        switch card.kind {
        case .markDone: return String(localized: "Done?")
        case .newTodo: return String(format: String(localized: "New task? · %@"), whose) + CardWords.when(due: card.due, time: card.time)
        case .sameParty: return String(localized: "Same person?")
        case .renameParty: return String(localized: "Change name?")
        case .changeRole: return String(localized: "Change role?")
        case .addNote: return card.todo == nil ? String(localized: "Note for the matter?") : String(localized: "Note for the task?")
        case .correctBrief: return String(localized: "Correct the brief?")
        case .lookUp: return String(localized: "Look up on the web?")
        case .draftMessage: return String(localized: "Draft")
        case .shortMessage: return String(localized: "Message")
        case .changeDate: return String(localized: "Change date?")
        case .newMatter: return String(localized: "New matter?")
        case .waitsFor: return String(localized: "Waits for another task?")
        case .addLink: return String(localized: "Save link? · Name:")
        case .addContact: return String(localized: "Contact? · Name:")
        case .newAppointment: return String(format: String(localized: "New appointment? · %@"), card.due.map(Dates.short) ?? "?")
            + (card.time.map(CardWords.at) ?? "")
        case .newDeadline: return String(format: String(localized: "New deadline? · by %@"), card.due.map(Dates.short) ?? "?")
        case .addDetail: return String(format: String(localized: "Detail? · %@"), card.subject ?? "")
        case .correctText: return String(localized: "Replace in the text?")
        case .changeOwner: return String(format: String(localized: "Whose task? → %@"), whose)
        case .putAway, .reopen, .changeField, .closeMatter, .moveTo, .addDecision: return CardActions.controlWords(card, name: { name($0) })?.title ?? ""
        }
    }

    /// The line above the field: what the card is about.
    private var what: String? {
        switch card.kind {
        case .markDone: return card.text
        case .newTodo: return nil
        case .sameParty: return "\(name(card.party))  →  \(name(card.into))"
        case .renameParty: return String(format: String(localized: "%@  is called:"), name(card.party))
        case .changeRole: return String(format: String(localized: "%@  is here:"), name(card.party))
        case .addNote: return card.todo == nil ? nil : name(card.todo)
        case .correctBrief: return nil
        case .lookUp: return nil
        case .shortMessage: return nil
        case .draftMessage:
            guard let recipient else { return String(localized: "To: (fill in in Mail)") }
            return String(format: String(localized: "To: %@"), recipient.name)
                + (recipient.address.map { " <\($0)>" } ?? String(localized: " — address not known, fill it in in Mail"))
        case .correctText: return String(format: String(localized: "“%@”  becomes:"), card.from ?? "")
        case .putAway, .reopen, .changeField, .closeMatter, .moveTo, .addDecision: return CardActions.controlWords(card, name: { name($0) })?.what
        case .newMatter: return nil
        case .waitsFor: return String(format: String(localized: "%@  →  only after: %@"), name(card.todo), name(card.into))
        case .addLink: return card.todo == nil ? String(localized: "to the matter") : String(format: String(localized: "to: %@"), name(card.todo))
        case .newAppointment, .newDeadline: return nil
        case .addDetail: return card.party == nil ? String(localized: "its value is never among the facts sent")
            : String(format: String(localized: "of %@ · its value is never among the facts sent"), name(card.party))
        case .addContact: return [card.subject, card.from, card.time].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · ")
        case .changeDate:
            let when = (card.due.map(Dates.short) ?? "?") + (card.time.map(CardWords.at) ?? "")
            return "\(name(card.todo))  →  \(when)"
        case .changeOwner: return name(card.todo)
        }
    }
}

/// The system's mail sheet, for a draft that takes files along: a `mailto:` cannot carry one. Shown
/// over whatever is on screen; the owner sends it there, or not.
@MainActor
final class MailSheet: NSObject, MFMailComposeViewControllerDelegate {
    private static let shared = MailSheet()

    /// Every draft, with files or without, as Mail's own sheet over Causabee. False only with no
    /// account in Mail and nothing to attach: then it opens as a mail link, in whichever mail app there is.
    static func open(_ draft: CardActions.MailDraft, card key: String) -> Bool {
        guard !draft.files.isEmpty || MFMailComposeViewController.canSendMail() else { return false }
        Task {
            // Read, and a big picture made smaller, away from the screen: done while it drew, a large
            // photo — perhaps still on its way from iCloud — held the app until iOS closed it. The
            // card says meanwhile what it waits for.
            let pieces = await MailPreparing.shared.prepare(key, files: draft.files) { files in
                files.map(ImageSize.attachable).compactMap { file in FolderImport.data(of: file).map { (file, $0) } }
            }
            // The screen may still be moving — the card turning, a sheet going: shown once it rests, not
            // dropped. Dropped, the first tap did nothing, and the mail had to be written again.
            for _ in 0..<40 {
                if let top = restingTop() { show(draft, pieces: pieces, over: top); return }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        return true
    }

    /// What is on top of the screen, when nothing is coming or going; nil while something moves.
    private static func restingTop() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
        guard var top = scene?.keyWindow?.rootViewController else { return nil }
        while let over = top.presentedViewController, !over.isBeingDismissed { top = over }
        guard !top.isBeingPresented, !top.isBeingDismissed, top.presentedViewController == nil, top.view.window != nil else { return nil }
        return top
    }

    private static func show(_ draft: CardActions.MailDraft, pieces: [(file: URL, data: Data)], over top: UIViewController) {
        // No account in Mail — Gmail, Outlook and the like: the share sheet, with the files and the
        // words, so the files are not lost on the way; the address is said in the words' first line.
        guard MFMailComposeViewController.canSendMail() else {
            let words = (draft.to.isEmpty ? "" : "To: \(draft.to)\n\n") + draft.body
            let share = UIActivityViewController(activityItems: [words] + pieces.map(\.file), applicationActivities: nil)
            share.setValue(draft.subject, forKey: "subject")
            // On the iPad it stands out from the middle of the screen.
            share.popoverPresentationController?.sourceView = top.view
            share.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            share.popoverPresentationController?.permittedArrowDirections = []
            top.present(share, animated: true)
            return
        }
        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = shared
        if !draft.to.isEmpty { mail.setToRecipients([draft.to]) }
        mail.setSubject(draft.subject)
        mail.setMessageBody(draft.body, isHTML: false)
        for (file, data) in pieces {
            let type = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            mail.addAttachmentData(data, mimeType: type, fileName: file.lastPathComponent)
        }
        top.present(mail, animated: true)
    }

    nonisolated func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        Task { @MainActor in controller.dismiss(animated: true) }
    }
}

/// Away from the newest: the way back — and "New answer", when one came meanwhile.
private struct PhoneToNewestButton: View {
    let placement: ThreadPlacement
    let newest: AnyHashable?
    let scroller: ScrollViewProxy

    var body: some View {
        ZStack {
            if placement.offersButton {
                let newAnswer = placement.newAnswer != nil
                Button { placement.button(newest, with: scroller) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down").font(.body.weight(.semibold))
                        if newAnswer { Text("New answer").font(.subheadline.weight(.medium)) }
                    }
                    .foregroundStyle(newAnswer ? .primary : .secondary)
                    .padding(.horizontal, newAnswer ? 16 : 0)
                    .frame(minWidth: 40, minHeight: 40)
                    // Glass, as what floats over the chat is: it was a material with a drawn edge.
                    // Not interactive glass: on the iPad that let the tap through to the thread, and
                    // the button did nothing (6 November).
                    .glassEffect(.regular, in: .capsule)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(newAnswer ? String(localized: "To the new answer") : String(localized: "To the newest"))
                .accessibilityIdentifier("thread.toNewest")
                .padding(.bottom, 10)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: placement.offersButton)
    }
}

/// What is typed in the assistant's field, and the cursor in it.
@MainActor
@Observable
final class TypedWords {
    var text = ""
    /// A card's second field: a link's name, a detail's value, a contact's role.
    var second = ""
    /// Where dictation puts its words: at the end. The field is not bound to its cursor — bound,
    /// typed quickly, the cursor of a keystroke before came back after the next one: "Who has the"
    /// was written "Who has he…t" on the iPad, and words went missing on the iPhone, even with the
    /// cursor only told and never read back.
    @ObservationIgnored var cursor: TextSelection?
}

/// The assistant's field, the microphone and the send button: the only views that read what is
/// typed, so each keystroke redraws them alone.
private struct TypingField: View {
    @Bindable var typed: TypedWords
    let voice: VoiceInput
    var typing: FocusState<Bool>.Binding
    let fieldKey: Int
    let asking: Bool
    let placeholder: String
    let send: () -> Void
    let stop: () -> Void

    var body: some View {
        TextField(placeholder, text: $typed.text, axis: .vertical)
            .lineLimit(1...5)
            // The keyboard's Return starts a new line; the button sends. With a keyboard
            // of keys, Return sends and Shift-Return starts a new line, as on the Mac.
            .onKeyPress(.return, phases: .down) { press in
                if press.modifiers.contains(.shift) || press.modifiers.contains(.option) { return .ignored }
                send()
                return .handled
            }
            .focused(typing)
            .id(fieldKey)
            .accessibilityIdentifier("assistant.field")
            // One line sits in the middle of the send button; more lines grow upwards.
            .frame(minHeight: 34)
        MicButton(voice: voice, text: $typed.text, selection: $typed.cursor) { typing.wrappedValue = false }
        Button { if asking { stop() } else { send() } } label: {
            // A black arrow on the bee's yellow, drawn light, as every yellow thing has black
            // on it — and a black square while an answer is on its way: one question at a time.
            SendGlyph(stops: asking, mayHostBee: typed.text.isEmpty)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(asking ? String(localized: "Stop") : String(localized: "Send"))
    }
}


/// Over the assistant's field, on glass: what is brought in — a photo, a scan, files — as three
/// cards, and under them what can be added to a matter, a row of pills to scroll. It comes out of
/// the plus and goes back into it.
private struct AddPanel: View {
    let matter: Matter?
    let bring: (AttachKind) -> Void
    let add: (AssistantAdd) -> Void

    private static let pills: [(title: String, symbol: String, add: AssistantAdd)] = [
        ("Task", "checklist", .task), ("Note", "note.text", .note), ("Link", "link", .link),
        ("Detail", "info.circle", .detail), ("Contact", "person.badge.plus", .contact),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                // Taken now, or from the library: one card, the choice under it.
                if PhotoCamera.isAvailable {
                    Menu {
                        Button("Take Photo", systemImage: "camera") { Haptics.tap(); bring(.camera) }
                            .accessibilityIdentifier("plus.camera")
                        Button("Photo Library", systemImage: "photo.on.rectangle") { Haptics.tap(); bring(.photo) }
                            .accessibilityIdentifier("plus.library")
                    } label: { cardFace("Photo", "photo") }
                    .accessibilityIdentifier("plus.photo")
                } else {
                    card("Photo", "photo", .photo)
                }
                if VNDocumentCameraViewController.isSupported { card("Scan", "doc.viewfinder", .scan) }
                card("Files", "folder", .files)
            }
            .padding(.horizontal, 14)
            // A matter's own: in the thread about all matters there is none to add to.
            if matter != nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.pills, id: \.title) { pill($0.title, $0.symbol, $0.add) }
                    }
                    .padding(.horizontal, 14)
                }
            }
        }
        .padding(.vertical, 14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("add.panel")
    }

    /// The icon over its name, in a card of its own.
    private func card(_ title: String, _ symbol: String, _ kind: AttachKind) -> some View {
        Button { Haptics.tap(); bring(kind) } label: { cardFace(title, symbol) }
        .buttonStyle(.plain)
        .accessibilityIdentifier("plus." + title.lowercased())
    }

    /// Its name, looked up from the English the identifier is built from (F009).
    private static func word(_ title: String) -> String {
        switch title {
        case "Photo": String(localized: "Photo")
        case "Scan": String(localized: "Scan")
        case "Files": String(localized: "Files")
        default: title
        }
    }

    private func cardFace(_ title: String, _ symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.title3)
            Text(Self.word(title)).font(.footnote.weight(.medium))
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, minHeight: 68)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func pill(_ title: String, _ symbol: String, _ kind: AssistantAdd) -> some View {
        Button { Haptics.tap(); add(kind) } label: {
            Label(kind.title, systemImage: symbol).font(.subheadline)
                .padding(.vertical, 8).padding(.leading, 11).padding(.trailing, 14)
                .background(Color.primary.opacity(0.06), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("add." + title.lowercased())
    }
}


/// A new task or note, typed in its own card over where the field was: what it is, small, the
/// words on the writing area with the cursor in it, what becomes of a day in it, and Add. × puts it
/// away. Nothing in it goes to an AI: it is kept as written.
private struct AddCard: View {
    let add: AssistantAdd
    @Bindable var typed: TypedWords
    var typing: FocusState<Bool>.Binding
    let take: () -> Void
    let close: () -> Void

    private var empty: Bool { !add.isComplete(typed.text, typed.second) }
    @FocusState private var onSecond: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(add.title).font(.caption).foregroundStyle(.secondary)
                    .padding(.leading, 4)
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.08), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Put it away")
            }
            VStack(alignment: .leading, spacing: 0) {
                TextField(add.fields.first, text: $typed.text, axis: add.fields.second == nil ? .vertical : .horizontal)
                    .textFieldStyle(.plain)
                    // A task's words stand out; a note, an address, a label or a name are plain.
                    .font(add == .task ? .headline : .body)
                    .lineLimit(1...6)
                    .keyboardType(add == .link ? .URL : .default)
                    .textInputAutocapitalization(add == .link ? .never : .sentences)
                    .autocorrectionDisabled(add == .link)
                    .focused(typing)
                    .submitLabel(add.fields.second == nil ? .done : .next)
                    // One line where a second field follows: Return goes on to it, not to a new line.
                    .onSubmit { if add.fields.second != nil { onSecond = true } else if !empty { take() } }
                    .accessibilityIdentifier("add.text")
                    .padding(.horizontal, 16).padding(.vertical, 14)
                if let second = add.fields.second {
                    Divider().padding(.leading, 16)
                    TextField(second, text: $typed.second)
                        .textFieldStyle(.plain)
                        .focused($onSecond)
                        .submitLabel(.done)
                        .onSubmit { if !empty { take() } }
                        .accessibilityIdentifier("add.second")
                        .padding(.horizontal, 16).padding(.vertical, 14)
                }
            }
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            .padding(.top, 10)
            Text(add.hint).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10).padding(.leading, 4)
            HStack {
                Spacer(minLength: 0)
                Button("Add", action: take).buttonStyle(.phoneFilled).disabled(empty)
                    .accessibilityIdentifier("add.take")
                Spacer(minLength: 0)
            }
            .padding(.top, 14)
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 18)
        .background(Theme.box, in: RoundedRectangle(cornerRadius: 20))
        // The cursor into the card as it comes: given to the field it takes the place of, it went
        // with that field, and what was typed went nowhere.
        .onAppear { DispatchQueue.main.async { typing.wrappedValue = true } }
    }
}


/// "Attach …" under a draft: the matter's files, newest first, a tick on each one going along — as
/// "Connect to …" is for an item. What the draft names is ticked already; a tap takes it away too.
private struct AttachSheet: View {
    let matter: Matter
    /// The files the draft takes along by itself: named in it, or chosen by the assistant.
    let named: Set<PersistentIdentifier>
    @Binding var chosen: [PersistentIdentifier]
    @Binding var leftOut: Set<PersistentIdentifier>
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var files: [MatterCore.Document] {
        let words = query.trimmingCharacters(in: .whitespaces).lowercased()
        return (matter.documents ?? [])
            .filter { !$0.isHidden && (words.isEmpty || $0.shownName.lowercased().contains(words)) }
            .sorted { ($0.source.date ?? .distantPast) > ($1.source.date ?? .distantPast) }
    }

    private func isNamed(_ document: MatterCore.Document) -> Bool { named.contains(document.persistentModelID) }

    var body: some View {
        NavigationStack {
            List {
                if files.isEmpty {
                    Text(query.isEmpty ? String(localized: "This matter has no files yet.") : String(localized: "No file is called that.")).foregroundStyle(.secondary)
                }
                ForEach(files) { document in
                    let id = document.persistentModelID
                    let on = isNamed(document) ? !leftOut.contains(id) : chosen.contains(id)
                    Button {
                        withAnimation {
                            if isNamed(document) {
                                if leftOut.contains(id) { leftOut.remove(id) } else { leftOut.insert(id) }
                            } else if let at = chosen.firstIndex(of: id) { chosen.remove(at: at) } else { chosen.append(id) }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(on ? Color.primary : Color.secondary).frame(width: 22)
                            Image(systemName: document.contentType.contains("pdf") || document.name.lowercased().hasSuffix(".pdf") ? "doc.richtext" : "doc")
                                .foregroundStyle(.secondary).frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(document.shownName).lineLimit(2)
                                if isNamed(document) {
                                    Text(on ? String(localized: "Named in the draft") : String(localized: "Named in the draft · left out")).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 8)
                            if let date = document.source.date { Text(Dates.short(date)).font(.caption).foregroundStyle(.secondary) }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("attach." + document.shownName)
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, prompt: String(localized: "Search this matter's files"))
            .navigationTitle("Attach to the mail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { SheetConfirm(String(localized: "Done")) { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
