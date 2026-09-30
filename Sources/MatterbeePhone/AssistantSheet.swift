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
                .onChange(of: asking?.date) { withAnimation { scroller.scrollTo(asking == nil ? shown.last?.turn.id as AnyHashable? : "asking", anchor: .bottom) } }
            }
            composer
        }
        .background(Theme.canvas)
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
            // As on the Mac: the send button sits in the pill's round end, as far from the right as
            // from the top and bottom, and the corner's radius is that and half the button — 7 + 34 / 2.
            HStack(alignment: .bottom, spacing: 10) {
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
            .padding(.leading, 16).padding(.trailing, 7).padding(.vertical, 7)
            .background(Theme.box, in: RoundedRectangle(cornerRadius: 24))
            Text("Always pseudonymised: names are disguised on the iPhone, with your Mac's list, before anything is sent.")
                .font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 8)
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
        let facts = FactSheet.facts(for: scope, today: today)
        // Only this matter's talk: what was said about another matter would go out with it.
        let earlier: [(question: String, answer: String)] = shown.compactMap { item in
            guard let answer = item.turn.answer, item.turn.note == nil else { return nil }
            return (item.turn.question, answer.reply.lines.map(\.text).joined(separator: " "))
        }
        let model = Claude.Model.opus
        guard let key = Claude.key(for: model) else {
            failure = "No Claude key yet. Open Matterbee on your Mac once — its key comes here through iCloud Keychain — or paste it in Settings (⋯ on the overview)."
            return
        }
        let names: (mapping: Pseudonymizer.Mapping, others: [Pseudonymizer.Entry])
        // The demo's people are made up, and no Mac has a list of them: the rules alone disguise
        // what they find. With the owner's own matters, no list means nothing is sent.
        if store.isDemo { names = (Pseudonymizer.Mapping(), []) } else { do { names = try NameLists.current(in: context) } catch {
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
                let answer = try await AssistantAsk.ask(question: question, inHand: nil, earlier: earlier, facts: facts, owner: owner,
                                                        today: today, mapping: names.mapping, others: names.others,
                                                        claude: Claude(key: key), model: model)
                var turn = Navigation.Turn(question: question, scope: matter.map { "about \($0.name)" } ?? "about all matters",
                                           inHand: nil, seen: facts.seen, refs: facts.refs, matter: matter?.persistentModelID)
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
        if case .todo(let id) = refs[cite], let todo = (matter?.todos ?? []).first(where: { $0.persistentModelID == id }) {
            return "Task: " + todo.text
        }
        switch cite.first {
        case "T": return "a task of the matter"
        case "M": return "a mail of the matter"
        case "D": return "a date of the matter"
        case "P": return "a person of the matter"
        default: return cite
        }
    }
}

/// A card the assistant suggested. A new task and "done?" can be taken in on the iPhone; the
/// others wait for the Mac, which knows how to undo them.
struct PhoneActionCard: View {
    let record: ThreadTurn
    let turn: Navigation.Turn
    let index: Int
    let card: AssistantPrompt.Reply.Card
    let matter: Matter?
    @Environment(Navigation.self) private var navigation
    @Environment(\.modelContext) private var context
    @State private var text = ""

    private var applied: Bool { turn.applied.contains(index) }
    private var dismissed: Bool { turn.dismissedCards.contains(index) }
    private var canTake: Bool { matter != nil && (card.kind == .newTodo || (card.kind == .markDone && target != nil)) }

    var body: some View {
        if dismissed {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.footnote.weight(.semibold))
                if card.kind == .newTodo && !applied {
                    TextField("Task", text: $text, axis: .vertical)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 6))
                } else {
                    Text(card.kind == .markDone ? (target?.text ?? card.text) : card.text)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 6))
                }
                Text(card.reason).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if !card.cites.isEmpty { SourcesLine(cites: card.cites, refs: turn.refs, matter: matter) }
                if applied {
                    Label("Taken in", systemImage: "checkmark").font(.footnote.weight(.medium)).foregroundStyle(Theme.done)
                } else if canTake {
                    HStack(spacing: 8) {
                        Button("Dismiss") { navigation.mark(record, dismissed: index, context: context) }.buttonStyle(.phone(wide: true))
                        Button(card.kind == .markDone ? "Mark done" : "Add") { take() }.buttonStyle(.phone(filled: true, wide: true))
                    }
                } else {
                    HStack {
                        Text("Take it in on the Mac.").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Dismiss") { navigation.mark(record, dismissed: index, context: context) }.buttonStyle(.phone)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.box, in: RoundedRectangle(cornerRadius: 12))
            .onAppear { text = card.text }
        }
    }

    private var whose: String { ["me": "Mine", "we": "Ours", "other": "Waiting for"][card.owner] ?? "Unclear whose" }

    private var title: String {
        switch card.kind {
        case .markDone: "Done?"
        case .newTodo: "New task? · " + whose + (card.due.map { " · by \(Dates.short($0))" } ?? "")
        case .sameParty: "Same person?"
        case .renameParty: "Change name?"
        case .changeRole: "Change role?"
        case .addNote: "Note for the task?"
        case .draftMessage: "Draft"
        case .changeDate: "Change date?"
        case .newMatter: "New matter?"
        case .waitsFor: "Waits for another task?"
        case .addLink: "Save link?"
        case .correctText: "Replace in the text?"
        case .changeOwner: "Whose task? → " + whose
        }
    }

    /// The task a "done?" card names: by the fact id it cites, when this store knows it.
    private var target: Todo? {
        guard let key = card.todo, case .todo(let id) = turn.refs[key] else { return nil }
        return (matter?.todos ?? []).first { $0.persistentModelID == id && !$0.isDone }
    }

    private func take() {
        guard let matter else { return }
        let source = Source(kind: .conversation, pointer: "assistant", date: Date(), quote: card.reason)
        switch card.kind {
        case .newTodo:
            let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !words.isEmpty else { return }
            // As the Mac takes it in: the same origin, so a second device does not add it twice.
            let made = Todo(text: words, owner: Todo.Owner(rawValue: card.owner) ?? .me, due: card.due, source: source,
                            origin: "assistant#" + words.lowercased())
            context.insert(made)
            made.matter = matter
        case .markDone:
            guard let todo = target else { return }
            todo.isDone = true
            todo.doneAt = Date()
            todo.doneSource = source
        default:
            return
        }
        navigation.mark(record, applied: index, context: context)
    }
}
