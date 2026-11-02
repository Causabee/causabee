import MatterCore
import SwiftData
import SwiftUI

// The matter's page as one journal: white cards on a grey page, what waits for the owner on a
// yellow tile, and everything else only to read. One code for the Mac, the iPhone and the iPad; the
// rows inside — a task, a date, a file — stay each device's own.

extension Theme {
    static let cardGap: CGFloat = 12
    static let cardInset: CGFloat = 20
    /// How far a tile sits inside its card: its corners stay concentric with the card's.
    static let tileInset: CGFloat = 4
    #if os(iOS)
    static let cardRadius: CGFloat = 20
    static let tileRadius: CGFloat = 16
    /// How far a plan's first line stands down, to read level with its box or mark.
    static let planTop: CGFloat = 2
    #else
    static let cardRadius: CGFloat = 16
    static let tileRadius: CGFloat = 12
    static let planTop: CGFloat = 4
    #endif
    /// The plan's one grid: a day's tile, and beside it what a task is ticked in and a date marked with.
    static let dayTile: CGFloat = 44
    static let planMark: CGFloat = 26
    /// A row's ⋯: this narrow, so that the title has the width.
    static let planMore: CGFloat = 20
}

extension View {
    /// A card of the journal: white on the page's grey, with no line round it.
    func journalCard(inset: CGFloat = Theme.cardInset) -> some View {
        padding(inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    /// A card of rows, which keep their own room.
    func journalRows() -> some View { journalCard(inset: 0) }

    /// A row of the plan. One line is as high as a day's tile, so that they stand side by side.
    func planRow() -> some View { padding(.leading, 6).padding(.trailing, 6).padding(.vertical, 10) }

    /// A date on the plan: a block of its own, told from a task at a glance. It is not to tick off.
    func planDate() -> some View {
        background(Theme.box, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// What waits for the owner: yellow, and only that is. Without `forYou`, the same room with no colour.
    func waitingTile(_ forYou: Bool = true, outOfDate: Bool = false) -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(outOfDate ? Theme.box : forYou ? Theme.beeSoft : Color.clear, in: RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous))
    }
}

/// The filters over a journal: words, the open one on a white pill. Only the ones with something
/// behind them are here; on a narrow screen or with large text the row scrolls.
struct JournalPills<Part: Hashable>: View {
    let parts: [Part]
    let label: (Part) -> String
    @Binding var selection: Part

    private var row: some View {
        HStack(spacing: 6) {
            ForEach(parts, id: \.self) { part in
                let chosen = part == selection
                Button { selection = part } label: {
                    Text(label(part))
                        #if os(iOS)
                        .font(.subheadline)
                        .padding(.horizontal, 11).padding(.vertical, 7)
                        #else
                        .font(.callout)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        #endif
                        .foregroundStyle(chosen ? Color.primary : Color.secondary)
                        .background(chosen ? Theme.card : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                        // A finger's room around the pill, on the iPhone: the pill itself stays small.
                        #if os(iOS)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        #endif
                }
                .buttonStyle(.plain)
                .fixedSize()
                .accessibilityLabel(label(part))
                .accessibilityAddTraits(chosen ? .isSelected : [])
                .accessibilityIdentifier("part." + label(part))
            }
        }
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row
            ScrollView(.horizontal, showsIndicators: false) { row }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter")
    }
}

extension JournalPills where Part == Journal.Part {
    init(parts: [Journal.Part], selection: Binding<Journal.Part>) {
        self.init(parts: parts, label: \.label, selection: selection)
    }
}

/// A day's tile: "THU", "1".
struct DayTile: View {
    let day: String
    /// Its month over its number, not its weekday: for a day that need not be this week's.
    var month = false
    /// Gone by with something still to do.
    var late = false

    var body: some View {
        let tile = Journal.tile(day, month: month)
        VStack(spacing: 0) {
            Text(tile.over).font(.caption2.weight(.semibold)).foregroundStyle(late ? Theme.warning : .secondary)
            Text(tile.number).font(.callout.weight(.medium)).monospacedDigit().foregroundStyle(late ? Theme.warning : .primary)
        }
        .frame(width: Theme.dayTile, height: 46)
        .background(Theme.box, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// What comes next, on its tile, with what can be done about it under it on the white.
struct NextCard<Head: View, Foot: View>: View {
    /// There is something for the owner to do: yellow. Nothing is: no colour at all.
    let forYou: Bool
    /// The matter has changed since this was written: grey, whatever it says.
    var outOfDate = false
    @ViewBuilder let head: Head
    @ViewBuilder let foot: Foot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) { head }.waitingTile(forYou, outOfDate: outOfDate)
            VStack(alignment: .leading, spacing: 8) { foot }
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .journalCard(inset: Theme.tileInset)
    }
}

/// Causabee's step once the matter has changed under it: still there to read, but it says it may
/// no longer hold. Struck through when it is its own task that was done.
struct OutOfDateStep: View {
    let matter: Matter

    var body: some View {
        let done = matter.nextStepTodo.flatMap { origin in (matter.todos ?? []).first { $0.origin == origin } }?.isDone == true
        BeeChip(text: "OUT OF DATE", tone: .quiet)
        Text(matter.nextStep ?? "").font(Theme.rowTitleFont).foregroundStyle(.secondary)
            .strikethrough(done, color: .secondary)
            .fixedSize(horizontal: false, vertical: true)
        Text("Something changed since this was written.").font(.footnote).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The one button that has Causabee write a matter again, wherever that is offered.
struct UpdateNowButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(Say.updateNow).font(.caption.weight(.medium)).foregroundStyle(.primary)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Theme.box, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("update.now")
    }
}

/// Under what Auto writes while the matter has changed: when it will, and the button not to wait.
struct AutoWaitLine: View {
    let matter: Matter
    /// What is said while it is being written.
    let writing: String
    private var loader: CGFloat {
        #if os(iOS)
        12
        #else
        10
        #endif
    }

    var body: some View {
        HStack(spacing: 6) {
            if AutoUpdate.shared.working.contains(matter.key) {
                BeeLoader(size: loader)
                Text(writing).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                Image(systemName: "clock").font(.caption).foregroundStyle(.secondary).accessibilityHidden(true)
                Text("When you leave").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                UpdateNowButton { AutoUpdate.shared.updateNow(matter) }
            }
        }
    }
}

/// For as long as a page shows the matter, Auto waits for the owner to finish in it.
private struct ShownToAuto: ViewModifier {
    let key: String

    func body(content: Content) -> some View {
        content.task(id: key) {
            AutoUpdate.shared.show(key)
            while !Task.isCancelled { try? await Task.sleep(for: .seconds(3_600)) }
            AutoUpdate.shared.leave(key)
        }
    }
}

extension View {
    func shownToAuto(_ matter: Matter) -> some View { modifier(ShownToAuto(key: matter.key)) }
}

/// What is ahead, in one card, on the plan's grid: the next days, and how much more there is. A
/// task's box ticks it; a tap on anything else opens the plan.
struct AheadCard: View {
    let plan: Journal.Plan
    let tick: (Todo) -> Void
    let open: () -> Void
    /// How many days it shows: on a wide page it stands in its own column and has the room.
    var days = 2

    private func name(_ text: String) -> some View {
        Text(text).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.leading).padding(.top, Theme.planTop)
    }

    /// What opens the plan, as wide as its row.
    private func opens<Label: View>(@ViewBuilder _ label: () -> Label) -> some View {
        Button(action: open) { label().frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle()) }
            .buttonStyle(.plain)
    }

    private func date(_ what: String, isDeadline: Bool, hours: String? = nil, place: String? = nil) -> some View {
        opens {
            HStack(alignment: .top, spacing: 10) {
                PlanDateMark(isDeadline: isDeadline)
                VStack(alignment: .leading, spacing: 2) {
                    name(what)
                    PlanDateLine(isDeadline: isDeadline, hours: hours, last: nil, place: place).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .planRow()
            .planDate()
        }
    }

    @ViewBuilder
    private func row(_ item: Journal.Plan.Item) -> some View {
        switch item {
        case .task(let todo):
            HStack(alignment: .top, spacing: 10) {
                PlanTick(todo: todo) { tick(todo) }
                opens {
                    VStack(alignment: .leading, spacing: 2) {
                        name(todo.text)
                        if todo.owner == .we { Text("together").font(.footnote).foregroundStyle(.secondary).lineLimit(1) }
                    }
                }
            }
            .planRow()
        case .appointment(let appointment): date(appointment.what, isDeadline: false, hours: appointment.time, place: appointment.place)
        case .deadline(let deadline): date(deadline.what, isDeadline: true)
        }
    }

    var body: some View {
        let all = plan.stretches.flatMap(\.days)
        let shown = Array(all.prefix(days))
        let items = all.flatMap(\.items)
        let tasks = plan.openCount - items.filter { if case .task = $0 { false } else { true } }.count
        let dates = items.count - items.filter { if case .task = $0 { true } else { false } }.count
        let moreDates = dates - shown.compactMap(\.items.first).filter { if case .task = $0 { false } else { true } }.count
        VStack(alignment: .leading, spacing: 0) {
            ForEach(shown) { day in
                if let item = day.items.first {
                    HStack(alignment: .top, spacing: 6) {
                        Button(action: open) { DayTile(day: day.day) }.buttonStyle(.plain)
                        row(item)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                }
                Divider().padding(.horizontal, 12)
            }
            opens {
                HStack(spacing: 8) {
                    Group {
                        if plan.overdue.isEmpty {
                            Text(Self.left(tasks: tasks, dates: moreDates))
                        } else {
                            Text("\(plan.overdue.count) overdue").foregroundColor(Theme.warning)
                                + Text(" · " + Self.left(tasks: tasks, dates: moreDates))
                        }
                    }
                    .font(.footnote).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12).padding(.vertical, 14)
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ahead")
    }

    /// "7 tasks open · 2 more dates".
    private static func left(tasks: Int, dates: Int) -> String {
        var words = ["\(tasks) \(tasks == 1 ? "task" : "tasks") open"]
        if dates > 0 { words.append("\(dates) more \(dates == 1 ? "date" : "dates")") }
        return words.joined(separator: " · ")
    }
}

/// The three kinds of thing in the one card for what has no date.
enum AtHandRow: Hashable { case summary, details, info }

/// One card for what has no date: the summary with its brief, the numbers to keep, and what mail
/// said that is worth knowing. Folded rows, each only when it has something; one tap opens one.
struct AtHandCard<SummaryFoot: View>: View {
    let matter: Matter
    @Binding var opened: Set<AtHandRow>
    /// A task's words for the assistant, from a line that is worth knowing.
    var talk: (Todo) -> Void = { _ in }
    /// "Update", Auto's line, "Write the brief": each device writes it its own way.
    @ViewBuilder let summaryFoot: SummaryFoot
    @Environment(PageFind.self) private var find
    @Environment(\.modelContext) private var context

    private var summaryLines: [String] { (matter.summary ?? "").split(separator: "\n").map(String.init) }
    private var hasBrief: Bool { matter.shownBrief.map { !$0.lines.isEmpty || !$0.said.isEmpty || !$0.answeredHere.isEmpty } ?? false }

    var body: some View {
        // Drawn again when Auto has written it.
        let _ = AutoUpdate.shared.done
        let details = matter.sortedDetails, infos = matter.infos
        let written = !summaryLines.isEmpty || hasBrief
        let closedWithout = matter.isClosed && !written
        if !closedWithout || !details.isEmpty || !infos.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if written {
                    fold(.summary, "Summary", count: nil, line: summaryLines.first ?? "The brief · what Causabee understands") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(summaryLines.enumerated()), id: \.offset) { index, line in
                                Text(line).fixedSize(horizontal: false, vertical: true)
                                    .findable(.section("summary-\(index)"), line)
                            }
                            .opacity(AutoUpdate.shared.updating(matter) ? 0.4 : 1)
                            BriefDetails(matter: matter)
                            Divider()
                            summaryFoot
                        }
                    }
                } else if !closedWithout {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Summary").font(Theme.rowTitleFont)
                        Text("A brief helps Causabee follow this matter as more mail comes.")
                            .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        summaryFoot.padding(.top, 4)
                    }
                    .padding(.vertical, 12)
                }
                if !details.isEmpty {
                    if written || !closedWithout { Divider() }
                    fold(.details, "Details", count: details.count, line: details.prefix(3).map(\.label).joined(separator: ", ")) {
                        DetailsSection(matter: matter, embedded: true)
                    }
                }
                if !infos.isEmpty {
                    if written || !closedWithout || !details.isEmpty { Divider() }
                    fold(.info, "Good to know", count: infos.count, line: infos.prefix(2).map(\.text).joined(separator: " · ")) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(infos, id: \.persistentModelID) { todo in
                                InfoLine(todo: todo, back: {
                                    withAnimation { todo.isInfo = false }
                                    try? context.save()
                                }, talk: { talk(todo) })
                                    .findable(.model(todo.persistentModelID), todo.text)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.cardInset).padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .id("details")
        }
    }

    @ViewBuilder
    private func fold<Content: View>(_ row: AtHandRow, _ title: String, count: Int?, line: String, @ViewBuilder content: () -> Content) -> some View {
        let isOpen = opened.contains(row) || find.isActive
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { if opened.remove(row) == nil { opened.insert(row) } }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title).font(Theme.rowTitleFont).foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        if let count { Text("\(count)").font(.footnote).foregroundStyle(.secondary) }
                        Image(systemName: isOpen ? "chevron.up" : "chevron.down").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    if !isOpen {
                        Text(line).font(.footnote).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("athand.\(title)")
            .accessibilityValue(isOpen ? "open" : "folded")
            if isOpen { content() }
        }
        .padding(.vertical, 12)
    }
}

/// One thing worth knowing: where it came from, and the way back to the tasks.
struct InfoLine: View {
    let todo: Todo
    let back: () -> Void
    let talk: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(todo.text).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                SourceJump(sources: todo.sources, label: Sources.origin(todo.sources.first), matter: todo.matter)
                Button("Back to tasks", action: back).buttonStyle(.gold).font(.footnote).tool()
                    .help("A task after all: it goes back to the open tasks")
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Ask Causabee", action: talk)
            Button("Back to tasks", action: back)
        }
    }
}

/// A day's heading in the journal.
struct JournalHeading: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Spacer()
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 4).padding(.top, 10)
        .accessibilityAddTraits(.isHeader)
    }
}

/// One conversation as one card: who, its subject, what its newest mail says, and how many answers.
/// A tap opens every mail in it, with all they can do; the card stays where it is.
struct JournalThreadCard<Attached: View>: View {
    let thread: MailThreads.Thread
    var links: RecordLinks? = nil
    /// The names of the files that came with it.
    var files: [String] = []
    let isOpen: Bool
    let toggle: () -> Void
    let talk: (Entry) -> Void
    @ViewBuilder let attached: Attached

    private var newest: Entry? {
        thread.rows.map(\.entry).max { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    /// "Nina Voss · you": who wrote in it, in the order they first did.
    private var who: String {
        let me = OwnerMe.current
        var names: [String] = []
        for entry in thread.rows.map(\.entry) {
            let name = me.sent(entry.from) ? "you" : entry.matter?.writerName(entry.from) ?? Email.address(in: entry.from)
            if !names.contains(name) { names.append(name) }
        }
        return names.prefix(2).joined(separator: " · ") + (names.count > 2 ? " · +\(names.count - 2)" : "")
    }

    private var unread: Int { thread.rows.filter { $0.entry.isUnread == true }.count }

    /// "NEW", or how many answers are new.
    private var new: String? {
        guard unread > 0 else { return nil }
        return thread.count == 1 ? "NEW" : "\(unread) NEW \(unread == 1 ? "ANSWER" : "ANSWERS")"
    }

    /// "1 mail", "3 answers".
    private var told: String {
        thread.count == 1 ? "1 mail" : "\(thread.count - 1) \(thread.count == 2 ? "answer" : "answers")"
    }

    private var day: String { (thread.last ?? thread.first).map(Dates.short) ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(who).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 8)
                        if let new { BeeChip(text: new) }
                    }
                    Text(thread.subject.isEmpty ? "(no subject)" : thread.subject)
                        .font(Theme.rowTitleFont).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.leading)
                    if !isOpen, let digest = newest?.digest, !digest.isEmpty {
                        Text(digest)
                            #if os(macOS)
                            .font(.callout)
                            #else
                            .font(.subheadline)
                            #endif
                            .foregroundStyle(.secondary).lineLimit(3).multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !isOpen {
                        ForEach(files.prefix(2), id: \.self) { name in
                            HStack(spacing: 8) {
                                Image(systemName: "doc").font(.caption).foregroundStyle(.secondary)
                                Text(name).font(.footnote).lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Theme.box, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("thread.card")
            .accessibilityValue(isOpen ? "open" : "folded")
            if isOpen {
                VStack(alignment: .leading, spacing: 0) {
                    let me = OwnerMe.current
                    let joined = MailThreads.joined(thread.rows, deepest: ThreadMailRow.deepest)
                    ForEach(thread.rows) { row in
                        ThreadMailRow(row: row, started: false, sent: me.sent(row.entry.from), subject: thread.subject,
                                      made: links?.made(from: row.entry) ?? RecordLinks.Made(), joinsNext: joined.contains(row.id)) { talk(row.entry) }
                            .padding(.horizontal, 10)
                            .findable(.model(row.entry.persistentModelID), row.entry.title, row.entry.from, row.entry.digest)
                            .padding(.horizontal, -10)
                    }
                    attached
                }
                .padding(.top, 6)
            }
            Divider().padding(.top, 12)
            HStack(spacing: 8) {
                Text(told)
                Spacer(minLength: 8)
                Text(day).monospacedDigit()
            }
            .font(.footnote).foregroundStyle(.secondary)
            .padding(.top, 10)
        }
        .journalCard()
        .contextMenu { Button("Ask Causabee") { if let newest { talk(newest) } } }
    }
}

/// Old days, folded into one card: which month, how much it held, and what about.
struct JournalFoldCard: View {
    let fold: Journal.Fold
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(fold.title).font(Theme.rowTitleFont).foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Text(fold.count).font(.footnote).foregroundStyle(.secondary)
                    Image(systemName: fold.isOpen ? "chevron.up" : "chevron.down").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                }
                if !fold.about.isEmpty, !fold.isOpen {
                    Text(fold.about).font(.footnote).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading)
                }
            }
            .journalCard(inset: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("journal.fold")
    }
}

/// A note in the journal, on its day. It is changed under Notes.
struct JournalNoteCard: View {
    let note: MatterNote
    let show: () -> Void

    var body: some View {
        Button(action: show) {
            VStack(alignment: .leading, spacing: 0) {
                Text(note.text).foregroundStyle(.primary).lineLimit(6).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider().padding(.top, 12)
                HStack {
                    Text(note.fromAssistant ? "From the assistant" : "Your note")
                    Spacer(minLength: 8)
                    Text(Dates.short(note.createdAt)).monospacedDigit()
                }
                .font(.footnote).foregroundStyle(.secondary).padding(.top, 10)
            }
            .journalCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A decision of the matter: what, and why.
struct JournalDecisionCard: View {
    let decision: Decision

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DECISION · \(Dates.short(decision.decidedAt).uppercased())").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(decision.what).font(Theme.rowTitleFont).fixedSize(horizontal: false, vertical: true)
            if !decision.why.isEmpty {
                Text(decision.why).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .journalCard()
        .findable(.model(decision.persistentModelID), decision.what, decision.why)
    }
}

/// What was ticked off that day: one quiet line.
struct JournalDoneLine: View {
    let todo: Todo

    var body: some View {
        if !todo.isDeleted, todo.modelContext != nil {
            Label { Text("Done: " + todo.text).lineLimit(2) } icon: { Image(systemName: "checkmark.circle") }
                .font(.footnote).foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }
}

/// The plan: what is left, by when. Dates and tasks stand together, a day at a time; late tasks
/// first, those without a day and other people's under them, what is done and gone by folded.
struct PlanList<TaskRow: View, DateRow: View, Empty: View>: View {
    let plan: Journal.Plan
    @Binding var showsDone: Bool
    @Binding var showsPast: Bool
    /// A task, and whether its row says whose it is.
    @ViewBuilder let task: (Todo, Bool) -> TaskRow
    /// A date, and whether it has gone by.
    @ViewBuilder let date: (Journal.Plan.Item, Bool) -> DateRow
    /// Over the dates: asks for the calendar when it is needed.
    @ViewBuilder let empty: Empty
    @Environment(PageFind.self) private var find

    /// A day on the plan's grid: its tile, and beside it what is on it. With no day the tile's place
    /// stays empty: what is ticked stands under what is ticked, in every card.
    private func onDay<Rows: View>(_ day: String?, month: Bool = false, late: Bool = false, @ViewBuilder rows: () -> Rows) -> some View {
        HStack(alignment: .top, spacing: 6) {
            if let day { DayTile(day: day, month: month, late: late) } else { Color.clear.frame(width: Theme.dayTile, height: 0) }
            VStack(alignment: .leading, spacing: 2) { rows() }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    /// Tasks in a card of their own, a day at a time.
    private func card(_ todos: [Todo], owner: Bool = false, late: Bool = false) -> some View {
        let days = Journal.Plan.days(of: todos) { $0.due }
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                if index > 0 { Divider().padding(.horizontal, 12) }
                onDay(day.day, month: true, late: late) {
                    ForEach(day.things, id: \.persistentModelID) { task($0, owner) }
                }
            }
        }
        .journalRows()
    }

    private func item(_ item: Journal.Plan.Item) -> some View {
        Group {
            switch item {
            case .task(let todo): task(todo, false)
            default: date(item, false)
            }
        }
    }

    private func folded<Content: View>(_ title: String, open: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        DisclosureGroup(title, isExpanded: Binding(get: { open.wrappedValue || find.isActive }, set: { open.wrappedValue = $0 })) {
            content().padding(.top, 6)
        }
        .font(.footnote).foregroundStyle(.secondary).tint(.secondary)
        .padding(.horizontal, 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.cardGap) {
            if plan.isEmpty { empty }
            if !plan.overdue.isEmpty {
                JournalHeading(title: "OVERDUE")
                card(plan.overdue, owner: true, late: true)
            }
            ForEach(plan.stretches) { stretch in
                JournalHeading(title: stretch.title.uppercased())
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(stretch.days.enumerated()), id: \.element.id) { index, day in
                        if index > 0 { Divider().padding(.horizontal, 12) }
                        onDay(day.day) {
                            ForEach(day.items) { entry in self.item(entry) }
                        }
                    }
                }
                .journalRows()
            }
            if !plan.noDay.isEmpty {
                JournalHeading(title: "NO DAY YET")
                card(plan.noDay, owner: true)
            }
            if !plan.waiting.isEmpty {
                JournalHeading(title: "WAITING FOR OTHERS")
                card(plan.waiting)
            }
            if !plan.blocked.isEmpty {
                JournalHeading(title: "ONLY AFTER")
                card(plan.blocked, owner: true)
            }
            if !plan.done.isEmpty {
                folded("Done · \(plan.done.count)", open: $showsDone) {
                    onDay(nil) { ForEach(plan.done, id: \.persistentModelID) { task($0, false) } }.journalRows()
                }
            }
            if !plan.past.isEmpty {
                folded("Past · \(plan.past.count)", open: $showsPast) {
                    let days = Journal.Plan.days(of: plan.past) { $0.day }
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                            if index > 0 { Divider().padding(.horizontal, 12) }
                            onDay(day.day, month: true) {
                                ForEach(day.things) { date($0, true) }
                            }
                        }
                    }
                    .journalRows()
                }
            }
        }
    }
}

/// A task's box. Ticked by hand the bee is glad: a little more when it was the matter's last open task.
struct PlanTick: View {
    let todo: Todo
    let toggle: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            let wasOpen = !todo.isDone
            toggle()
            if wasOpen, todo.isDone {
                BeeJoy.shared.celebrate(big: (todo.matter?.todos ?? []).allSatisfy(\.isDone), still: reduceMotion)
            }
        } label: {
            Image(systemName: todo.isDone ? "checkmark.square.fill" : "square")
                .font(.title3)
                .symbolRenderingMode(.palette)
                .foregroundStyle(todo.isDone ? Theme.onInk : .secondary, todo.isDone ? Theme.ink : .secondary)
                .frame(width: Theme.planMark, height: Theme.planMark)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(todo.isDone ? "Open again" : "Mark as done")
        .help(todo.isDone ? "Open again" : "Mark as done")
    }
}

/// A task's or a date's ⋯: small, at the row's end, close to the title, which keeps the width. The
/// target is larger than what is drawn. All of it is also there held, or right-clicked on the Mac.
struct PlanMore<Items: View>: View {
    @ViewBuilder let items: Items

    var body: some View {
        Menu { items } label: {
            Image(systemName: "ellipsis")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: Theme.planMore, height: Theme.planMark)
                .padding(10)
                .contentShape(Rectangle())
        }
        #if os(macOS)
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        .help("More")
        #endif
        .tint(.secondary)
        .padding(-10)
        .padding(.leading, -6)
        .accessibilityLabel("More")
        // While reading, holding it still has everything.
        .tool()
    }
}

/// What stands on a date's row where a task has its box: a date is not ticked off.
struct PlanDateMark: View {
    let isDeadline: Bool

    var body: some View {
        Image(systemName: isDeadline ? "flag.fill" : "calendar")
            .font(.callout)
            .foregroundStyle(isDeadline ? Theme.warning : .secondary)
            .frame(width: Theme.planMark, height: Theme.planMark)
            .accessibilityHidden(true)
    }
}

/// Under a date's name: when and where, or that it is a deadline. The block says it is a date.
struct PlanDateLine: View {
    let isDeadline: Bool
    let hours: String?
    let last: String?
    let place: String?

    static func words(hours: String?, last: String?, place: String?) -> String? {
        let words = [hours, last.map { "until " + Dates.short($0) }, place].compactMap { $0 }
        return words.isEmpty ? nil : words.joined(separator: " · ")
    }

    var body: some View {
        if isDeadline {
            Text("Deadline").font(.footnote).foregroundStyle(Theme.warning)
        } else if let line = Self.words(hours: hours, last: last, place: place) {
            Text(line).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Who has the ball, in a person's card: what they wait for from the owner, or the owner from them.
struct BallTile: View {
    let ball: Journal.Ball

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let waits = ball.waitsForYou {
                Text("Waits for you: " + waits).font(.footnote).lineLimit(2)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.beeSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            if let wait = ball.youWaitFor {
                Text("You wait for: " + wait).font(.footnote).lineLimit(2)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.box, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

/// Who has the ball, for the wide page's column: one line for each person it lies with.
struct BallCard: View {
    let matter: Matter

    var body: some View {
        let balls = matter.parties.map { ($0.name, Journal.ball(of: $0, in: matter)) }.filter { !$0.1.isEmpty }
        if !balls.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("WHO HAS THE BALL").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(balls, id: \.0) { name, ball in
                    if ball.waitsForYou != nil { Text("\(name) waits for you") }
                    if ball.youWaitFor != nil { Text("You wait for \(name)").foregroundStyle(.secondary) }
                }
            }
            .journalCard()
        }
    }
}

/// The overview's two pages: what happened across all matters, or the matters themselves.
enum OverviewPart: String, CaseIterable {
    case all, matters

    var label: String { self == .all ? "Latest updates" : "Matters" }
}

/// The journal across all matters: a day at a time, each matter once, with what its newest mail says.
struct OverviewJournal: View {
    let matters: [Matter]
    let open: (Matter) -> Void

    private struct Day: Identifiable {
        let id: String
        let title: String
        var summaries: [MatterSummary]
    }

    private func days(_ recent: [MatterSummary]) -> [Day] {
        var days: [Day] = []
        for summary in recent {
            guard let date = summary.latest?.date else { continue }
            let id = MatterStatus.day(date)
            if days.last?.id == id { days[days.count - 1].summaries.append(summary) }
            else { days.append(Day(id: id, title: Journal.dayTitle(date), summaries: [summary])) }
        }
        return days
    }

    var body: some View {
        let recent = StoredChanges.shared.overview(matters).recent
        let byID = Dictionary(matters.map { ($0.persistentModelID, $0) }, uniquingKeysWith: { first, _ in first })
        LazyVStack(alignment: .leading, spacing: Theme.cardGap) {
            ForEach(days(recent)) { day in
                JournalHeading(title: day.title)
                ForEach(day.summaries) { summary in
                    if let matter = byID[summary.id] { OverviewDayCard(summary: summary, matter: matter) { open(matter) } }
                }
            }
        }
    }
}

/// One matter's day: its name, what its newest mail says, what came that day and what is left to do.
private struct OverviewDayCard: View {
    let summary: MatterSummary
    let matter: Matter
    let open: () -> Void

    /// "4 mails · 2 files": what is not there is not said.
    private static func came(_ latest: MatterSummary.Latest) -> String {
        func say(_ count: Int, _ one: String) -> String? { count == 0 ? nil : "\(count) \(one)\(count == 1 ? "" : "s")" }
        return [say(latest.mails, "mail"), say(latest.files, "file")].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    MatterIconTile(matter: matter, size: 32)
                    Text(summary.name).font(Theme.rowTitleFont).foregroundStyle(.primary).lineLimit(1)
                    Spacer(minLength: 0)
                }
                if let latest = summary.latest {
                    Text(latest.digest ?? latest.title)
                        #if os(macOS)
                        .font(.callout)
                        #else
                        .font(.subheadline)
                        #endif
                        .foregroundStyle(.secondary).lineLimit(3).multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Divider().padding(.top, 4)
                    HStack(spacing: 8) {
                        Text(Self.came(latest))
                        Spacer(minLength: 8)
                        if summary.openCount > 0 { Text("\(summary.openCount) \(summary.openCount == 1 ? "task" : "tasks") open") }
                    }
                    .font(.footnote).foregroundStyle(.secondary).padding(.top, 2)
                }
            }
            .journalCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("overview.day")
    }
}

/// A closed matter is out of the overview, unless mail came for it after it was closed. Held, or
/// right-clicked on the Mac, that mail is ignored here: it stays in the matter and on its row among
/// the closed ones, and the next mail shows here again; or it starts a matter of its own.
struct ClosedMailRows: View {
    let matters: [Matter]
    let open: (Matter) -> Void
    @Environment(\.modelContext) private var context
    @State private var splitting: Matter?
    @State private var name = ""

    private func start() {
        guard let matter = splitting else { return }
        let mails = MatterStatus(matter).mailsSinceClosed
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mails.isEmpty, !name.isEmpty, Store.shared.mayStartMatter(in: context),
              let new = try? matter.split(mails, intoNewMatterNamed: name, turnsSince: matter.closedAt, in: context) else { return }
        open(new)
    }

    private func ignore(_ matter: Matter) {
        withAnimation(.snappy(duration: 0.2)) {
            matter.ignoredMailUntil = StoredChanges.shared.summary(matter).lastDate
            try? context.save()
        }
    }

    var body: some View {
        let waiting = matters.filter { $0.isClosed && StoredChanges.shared.summary($0).mailsToShowSinceClosed > 0 }
        if !waiting.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(waiting.enumerated()), id: \.element.persistentModelID) { index, matter in
                    let new = StoredChanges.shared.summary(matter).mailsToShowSinceClosed
                    if index > 0 { Divider().padding(.leading, 44) }
                    Button { open(matter) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "archivebox").foregroundStyle(.secondary)
                            Text("\(new) new \(new == 1 ? "mail" : "mails") in the closed matter “\(matter.name)”")
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        #if os(iOS)
                        .font(.subheadline)
                        #else
                        .font(.callout)
                        #endif
                        .padding(14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Open the matter")
                    .contextMenu {
                        Button(Say.startNewMatter, systemImage: "plus.circle") {
                            name = Matter.suggestedName(for: MatterStatus(matter).mailsSinceClosed)
                            splitting = matter
                        }
                        .tint(Color.secondary)
                        Button(Say.ignoreNewMail, systemImage: "eye.slash") { ignore(matter) }.tint(Color.secondary)
                    }
                }
            }
            .journalRows()
            .alertWhenAsked(Say.startNewMatter, isPresented: Binding(get: { splitting != nil }, set: { if !$0 { splitting = nil } })) {
                TextField("Name", text: $name)
                Button("Cancel", role: .cancel) {}
                Button("Start", action: start)
            } message: {
                Text("The new mail goes, with what only it brought. The closed matter stays closed.")
            }
        }
    }
}
