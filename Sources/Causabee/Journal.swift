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
    #else
    static let cardRadius: CGFloat = 16
    static let tileRadius: CGFloat = 12
    #endif
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

    /// What waits for the owner: yellow, and only that is. Without `forYou`, the same room with no colour.
    func waitingTile(_ forYou: Bool = true) -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(forYou ? Theme.beeSoft : Color.clear, in: RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous))
    }
}

/// The filters over the journal: words, the open one on a white pill. Only the ones with something
/// behind them are here; on a narrow screen or with large text the row scrolls.
struct JournalPills: View {
    let parts: [Journal.Part]
    @Binding var selection: Journal.Part

    private var row: some View {
        HStack(spacing: 6) {
            ForEach(parts, id: \.self) { part in
                let chosen = part == selection
                Button { selection = part } label: {
                    Text(part.label)
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
                .accessibilityLabel(part.label)
                .accessibilityAddTraits(chosen ? .isSelected : [])
                .accessibilityIdentifier("part." + part.label)
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

/// A day's tile: "THU", "1".
struct DayTile: View {
    let day: String

    var body: some View {
        let tile = Journal.tile(day)
        VStack(spacing: 0) {
            Text(tile.weekday).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(tile.number).font(.callout.weight(.medium)).monospacedDigit()
        }
        .frame(width: 44, height: 46)
        .background(Theme.box, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// What comes next, on its tile, with what can be done about it under it on the white.
struct NextCard<Head: View, Foot: View>: View {
    /// There is something for the owner to do: yellow. Nothing is: no colour at all.
    let forYou: Bool
    @ViewBuilder let head: Head
    @ViewBuilder let foot: Foot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) { head }.waitingTile(forYou)
            VStack(alignment: .leading, spacing: 8) { foot }
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .journalCard(inset: Theme.tileInset)
    }
}

/// What is ahead, in one card: the next days, and how much more there is. A tap opens the plan.
struct AheadCard: View {
    let plan: Journal.Plan
    let open: () -> Void
    /// How many days it shows: on a wide page it stands in its own column and has the room.
    var days = 2

    private static func title(_ item: Journal.Plan.Item) -> String {
        switch item {
        case .task(let todo): todo.text
        case .appointment(let appointment): (appointment.time.map { $0 + " · " } ?? "") + appointment.what
        case .deadline(let deadline): deadline.what
        }
    }

    private static func under(_ item: Journal.Plan.Item) -> String? {
        switch item {
        case .task(let todo): todo.owner == .we ? "together" : "task"
        case .appointment(let appointment): appointment.place
        case .deadline: "deadline"
        }
    }

    var body: some View {
        let all = plan.stretches.flatMap(\.days)
        let shown = Array(all.prefix(days))
        let items = all.flatMap(\.items)
        let tasks = plan.openCount - items.filter { if case .task = $0 { false } else { true } }.count
        let dates = items.count - items.filter { if case .task = $0 { true } else { false } }.count
        let moreDates = dates - shown.compactMap(\.items.first).filter { if case .task = $0 { false } else { true } }.count
        Button(action: open) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(shown) { day in
                    if let item = day.items.first {
                        HStack(alignment: .center, spacing: 14) {
                            DayTile(day: day.day)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Self.title(item)).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.leading)
                                if let under = Self.under(item) { Text(under).font(.footnote).foregroundStyle(.secondary).lineLimit(1) }
                            }
                        }
                    }
                }
                if !shown.isEmpty { Divider() }
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
            }
            .padding(.horizontal, Theme.cardInset).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
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

    private func list(_ todos: [Todo], owner: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(todos.enumerated()), id: \.element.persistentModelID) { index, todo in
                if index > 0 { Divider().padding(.leading, 50) }
                task(todo, owner)
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
                list(plan.overdue, owner: true)
            }
            ForEach(plan.stretches) { stretch in
                JournalHeading(title: stretch.title.uppercased())
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(stretch.days.enumerated()), id: \.element.id) { index, day in
                        if index > 0 { Divider().padding(.horizontal, 16) }
                        HStack(alignment: .top, spacing: 4) {
                            DayTile(day: day.day).padding(.leading, 12).padding(.top, 12)
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(day.items) { entry in self.item(entry) }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .journalRows()
            }
            if !plan.noDay.isEmpty {
                JournalHeading(title: "NO DAY YET")
                list(plan.noDay, owner: true)
            }
            if !plan.waiting.isEmpty {
                JournalHeading(title: "WAITING FOR OTHERS")
                list(plan.waiting)
            }
            if !plan.blocked.isEmpty {
                JournalHeading(title: "ONLY AFTER")
                list(plan.blocked, owner: true)
            }
            if !plan.done.isEmpty {
                folded("Done · \(plan.done.count)", open: $showsDone) { list(plan.done) }
            }
            if !plan.past.isEmpty {
                folded("Past · \(plan.past.count)", open: $showsPast) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(plan.past.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 { Divider().padding(.horizontal, 14) }
                            date(entry, true)
                        }
                    }
                    .journalRows()
                }
            }
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
